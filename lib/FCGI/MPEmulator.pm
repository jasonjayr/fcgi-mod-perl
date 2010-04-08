package FCGI::MPEmulator;

use strict;
use warnings;
use FCGI;
use FCGI::ProcManager;
use CGI::Fast;
use Data::Dumper;


sub run { 
	my ($class, $instance) = @_;

	my $pm = FCGI::ProcManager->new({n_processes=>5});

	my $socket = FCGI::OpenSocket("cgi.sock", 20);
	open NULL, ">/dev/null";
	my (%req_params);
	my $request =  FCGI::Request( \*STDIN, \*STDOUT, \*NULL,
						\%req_params, $socket, &FCGI::FAIL_ACCEPT_ON_INTR);

	use lib '.';
	use MPTest;
	use Apache::Registry;

	my $r = $instance->new();
	
	# TODO.  In Testing, we're manually setting the handler
	# in production, this should be driven by some kind of configuration file
	$r->set_handlers(PerlHandler=>[
		\&Apache::Registry::handler
		#\&MPTest::handler
	]);

	$pm->pm_manage();
	while($request->Accept >= 0) { 
		$pm->pm_pre_dispatch();
		
		# the CGI query should not be read by us here, but by the handlers below, or the modules they use...
		
		$r->_initialize({
			req=>\%req_params,
		});
		
		$r->filename($req_params{DOCUMENT_ROOT}.$req_params{SCRIPT_NAME});

		my @phases = qw(PerlHandler);
		$Apache::Registry::Debug = 5;
	#print STDERR Dumper({req=>\%req_params,env=>\%ENV});
		warn "PATH INFO is ".$r->path_info;
		foreach my $phase (@phases) { 
			my $handlers = $r->get_handlers($phase);
			if($phase eq 'PerlHandler' && @$handlers == 0 && $r->filename) { 
				warn " Warning: Serving file instead of running a perl handler : ".$r->filename;
			} else { 
				foreach my $handler (@$handlers) { 
					$handler->($r);	
				}
			}
		}


		$pm->pm_post_dispatch();
	}
}

1;
