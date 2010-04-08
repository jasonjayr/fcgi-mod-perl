package FCGI::ModPerl13;
use Apache::Table;
use Apache::Constants;
use Apache::TableHash;
use CGI::Fast;
use Carp;
use strict;
use warnings;

sub new {
    my $class = shift;
    my %p = @_;
    my $self = bless {
		  headers_out     => Apache::Table->new,
		  err_headers_out => Apache::Table->new,
		  pnotes          => {},
		  _rstate		  => {},
		  _handlers	      => {},
		 }, $class;
	
	$self->{_sstate} = FCGI::ModPerl13::Server->new();
	return $self;
}

sub _initialize {
	my ($self, $args) = @_;
	# reinitialize some vars.
	%$self = (
			%$self,
			headers_out     => Apache::Table->new,
		  err_headers_out => Apache::Table->new,
		  pnotes          => {},
		  _rstate		  => {
 			starttime=>time(),
		  	fcgi_req => $args->{req},
			path_info => $args->{req}{SCRIPT_NAME}
		  },
		  
		  %$args,
	);
	
}	
sub request { 
	my ($self) = @_;

	return $self;
}
sub _query { 
	my ($self) = @_;	
	return $self->{query}||=CGI::Fast->new();
};

sub get_handlers {
	my ($self, $hook) = @_;
	
	return [@{$self->{_handlers}{$hook}}];
}

sub set_handlers {
	my ($self, $hook, $handlers) = @_;
	
	$self->{_handlers}{$hook} = [@{$handlers}];
}

sub push_handlers { 
	my ($self, $hook, $handler) = @_;

	push @{$self->{_handlers}{$hook}}, $handler;
}

# CGI request are _always_ main, and there is never a previous or a next
# internal request.
sub main {}
sub prev {}
sub next {}
sub is_main {1}
sub is_initial_req {1}

# What to do with this?
# sub allowed {}

sub method {
    $_[0]->_query->request_method;
}

# There mut be a mapping for this.
sub method_number {
	my ($self,$newvalue) = @_;
	if(defined($newvalue)) { warn "method_number: setting a new method is not supported yet" }

	return { 
		GET=>0,
		PUT=>1,
		POST=>2,
		DELETE=>3,
		CONNECT=>4,
		OPTIONS=>5,
		TRACE=>6,
		INVALID=>7
	}->{uc($self->method)}

}

# Can CGI.pm tell us this?
# sub bytes_sent {0}

# The request line sent by the client." Poached from Apache::Emulator.
sub the_request {
    my $self = shift;
    $self->{the_request} ||= join ' ', $self->method,
      ( $self->_query->query_string
        ? $self->uri . '?' . $self->_query->query_string
        : $self->uri ),
      $self->_query->server_protocol;
}

# Is CGI ever a proxy request?
# sub proxy_req {}

sub header_only { (uc $_[0]->method) eq 'HEAD' }

sub protocol { $ENV{SERVER_PROTOCOL} || 'HTTP/1.0' }

sub hostname { $_[0]->_query->server_name }

sub request_time { $_[0]->{_rstate}{starttime} }

sub uri {
    my $self = shift;

    $self->{uri} ||= $self->_query->script_name . $self->path_info || '';
}

# Is this available in CGI?

sub filename {
	my $self = shift;
	my ($filename) = (@_);
	$self->{_rstate}{filename} = $filename if $filename;
	return $self->{_rstate}{filename};
}

# hard code OPT_EXECCGI, cuz, why else would we be 
# using FastCGI
sub allow_options { &Apache::Constants::OPT_EXECCGI }

# "The $r->location method will return the path of the
# <Location> section from which the current "Perl*Handler"
# is being called." This is irrelevant, I think.
# sub location {}

sub path_info { return $_[0]->{_rstate}{path_info}; }

sub args {
    my $self = shift;
    if (@_) {
        # Assign args here.
    }
    return $self->_query->Vars unless wantarray;
    # Do more here to return key => arg values.
}

# TODO: i need to make this fcgi-magical
sub headers_in {
    my $self = shift;

    # Create the headers table if necessary. Decided how to build it based on
    # information here:
    # http://cgi-spec.golux.com/draft-coar-cgi-v11-03-clean.html#6.1
    #
    # Try to get as much info as possible from CGI.pm, which has
    # workarounds for things like the IIS PATH_INFO bug.
    #
    $self->{headers_in} ||= Apache::Table->new
      ( 'Authorization'       => $self->_query->auth_type, # No credentials though.
        'Content-Length'      => $ENV{CONTENT_LENGTH},
        'Content-Type'        =>
        ( $self->_query->can('content_type') ?
          $self->_query->content_type :
          $ENV{CONTENT_TYPE}
        ),
        # Convert HTTP environment variables back into their header names.
        map {
            my $k = ucfirst lc;
            $k =~ s/_(.)/-\u$1/g;
            ( $k => $self->_query->http($_) )
        } grep { s/^HTTP_// } keys %ENV
      );


    # Give 'em the hash list of the hash table.
    return wantarray ? %{$self->{headers_in}} : $self->{headers_in};
}

sub header_in {
    my ($self, $header) = (shift, shift);
    my $h = $self->headers_in;
    return @_ ? $h->set($header, shift) : $h->get($header);
}


#           The $r->content method will return the entity body
#           read from the client, but only if the request content
#           type is "application/x-www-form-urlencoded".  When
#           called in a scalar context, the entire string is
#           returned.  When called in a list context, a list of
#           parsed key => value pairs are returned.  *NOTE*: you
#           can only ask for this once, as the entire body is read
#           from the client.
# Not sure what to do with this one.
# sub content {}

# I think this may be irrelevant under CGI.
# sub read {}

# Use LWP?
sub get_remote_host {}
sub get_remote_logname {}

sub http_header {
    my $self = shift;
    my $h = $self->headers_out;
    my $e = $self->err_headers_out;
    my $method = exists $h->{Location} || exists $e->{Location} ?
      'redirect' : 'header';
    return $self->_query->$method(tied(%$h)->cgi_headers,
                                 tied(%$e)->cgi_headers);
}

sub send_http_header {
    my $self = shift;

    print STDOUT $self->http_header;

    $self->{http_header_sent} = 1;
}

sub http_header_sent { shift->{http_header_sent} }

# How do we know this under CGI?
# sub get_basic_auth_pw {}
# sub note_basic_auth_failure {}

# I think that this just has to be empty.
sub handler {
	my ($self, $handler) = @_;
	
	warn "[sub handler] Attempt to set handler to something other than perl-script" unless $handler eq 'perl-script';
}

sub notes {
    my ($self, $key) = (shift, shift);
    $self->{_rstate}{notes} ||= Apache::Table->new;
    return wantarray ? %{$self->{_rstate}{notes}} : $self->{_rstate}{notes}
      unless defined $key;
    return $self->{_rstate}{notes}{$key} = "$_[0]" if @_;
    return $self->{_rstate}{notes}{$key};
}

sub pnotes {
    my ($self, $key) = (shift, shift);
    return wantarray ? %{$self->{_rstate}{pnotes}} : $self->{_rstate}{pnotes}
      unless defined $key;
    return $self->{_rstate}{pnotes}{$key} = $_[0] if @_;
    return $self->{_rstate}{pnotes}{$key};
}

sub subprocess_env {
    my ($self, $key) = (shift, shift);
    unless (defined $key) {
        $self->{subprocess_env} = Apache::Table->new(%ENV);
        return wantarray ? %{$self->{subprocess_env}} :
          $self->{subprocess_env};

    }
    $self->{subprocess_env} ||= Apache::Table->new(%ENV);
    return $self->{subprocess_env}{$key} = "$_[0]" if @_;
    return $self->{subprocess_env}{$key};
}

sub content_type {
    shift->header_out('Content-Type', @_);
}

sub content_encoding {
    shift->header_out('Content-Encoding', @_);
}

sub content_languages {
    my ($self, $langs) = @_;
    return unless $langs;
    my $h = shift->headers_out;
    for my $l (@$langs) {
        $h->add('Content-Language', $l);
    }
}

sub status {
    shift->header_out('Status', @_);
}

sub status_line {
    # What to do here? Should it be managed differently than status?
    my $self = shift;
    if (@_) {
        my $status = shift =~ /^(\d+)/;
        return $self->header_out('Status', $status);
    }
    return $self->header_out('Status');
}

sub headers_out {
    my $self = shift;
    return wantarray ? %{$self->{headers_out}} : $self->{headers_out};
}

sub header_out {
    my ($self, $header) = (shift, shift);
    my $h = $self->headers_out;
    return @_ ? $h->set($header, shift) : $h->get($header);
}

sub err_headers_out {
    my $self = shift;
    return wantarray ? %{$self->{err_headers_out}} : $self->{err_headers_out};
}

sub err_header_out {
    my ($self, $err_header) = (shift, shift);
    my $h = $self->err_headers_out;
    return @_ ? $h->set($err_header, shift) : $h->get($err_header);
}

sub no_cache {
    my $self = shift;
    $self->header_out(Pragma => 'no-cache');
    $self->header_out('Cache-Control' => 'no-cache');
}

sub print {
	my $self = shift;
# this is a 'feature' in 1.3 that's going away:
	if(ref($_[0])) { 
		print ${$_[0]}
	}  else { 
		print @_;
	}
}

sub send_fd {
    my ($self, $fd) = @_;
    local $_;

    print STDOUT while defined ($_ = <$fd>);
}

# Should this perhaps throw an exception?
# sub internal_redirect {}
# sub internal_redirect_handler {}

# Do something with ErrorDocument?
# sub custom_response {}

# I think we'ev made this essentially the same thing.
BEGIN {
    local $^W;
    *send_cgi_header = \&send_http_header;
}

# Does CGI support logging?
sub log_reason {
	shift()->warn(@_);
}
sub log_error {
	shift()->warn(@_);

}
sub warn {
    shift;
    print STDERR @_, "\n";
}

sub params {
    my $self = shift;
    return HTML::Mason::Utils::cgi_request_args($self->_query,
                                                $self->_query->request_method);
}

sub server { 
	my ($self) = @_;

	return $self->{_sstate};
}

#TODO -------------- \
sub chdir_file { 
# TODO: wtf does this do
}
sub clear_rgy_endav { 
#TODO: wtf does this do
}
sub stash_rgy_endav {
	my $self = shift;
	print STDERR ('sath_rgy_endav: '. join(",",@_)."\n");
}
sub seqno { 1 }
# ------------------ /


sub slurp_filename { 
	my ($self, $file) = @_;
	
	open FILE,"<$file" or die "Cannot open $file for reading: $!";
	my $buf;
	my $text;
	while(read(FILE,$buf,1024)) { 
		$text.=$buf;
	}
	close FILE;

	return \$text;
	
}

package Apache;
use Scalar::Util qw(tainted);

sub untaint {
	($_[0]) = $_[0] =~ m/(.*)/ if tainted($_[0]);	

	#TODO i may need to do some XS

	#warn Carp::shortmess("Someone called on me to untaint something, but it's tainted, and I'm not implemented!") if tainted($sv);
} 

package FCGI::ModPerl13::Server;

sub new {
	my ($class,$request) = @_;
	return bless {_r=>$request}, $class; 
}

sub is_virtual { 
	return 0;
}



1;

__END__

=head1 NAME

HTML::Mason::FakeApache - An Apache object emulator for use with Mason

=head1 SYNOPSIS

See L<HTML::Mason::CGIHandler|HTML::Mason::CGIHandler>.

=head1 DESCRIPTION

This class's API is documented in L<HTML::Mason::CGIHandler|HTML::Mason::CGIHandler>.

=cut

1;
