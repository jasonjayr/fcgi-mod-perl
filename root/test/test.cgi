use strict;
use warnings;
#use Template;

our $global;

&display(@_);


sub display { 
	my ($r) = @_;
	$|++;
	print "Content-type: text/html\n\n";
#sleep 2;	
	$global++;
	print "I have an pid:$$   $global doing r: $r\n";
	print scalar(localtime)."\n";
}
