package MPTest;

sub handler { 
	my ($r) = @_;


	$r->send_http_header('text/html');

	$r->print("Hello world!\n");

}

1;
