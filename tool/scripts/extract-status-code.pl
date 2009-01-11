#!/usr/bin/env perl

# $Id$

# usage: gzip -dc /somewhere/026986847.html.gz | perl extract-status-code.pl -id 026986847

use strict;
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'id=s');

while (<>) {
    # HTTP/1.1 404 Not Found
    if (/HTTP\/1\.1 (\d+) /) {
	my $status_code = $1;
	print "$opt{id} $status_code\n" if $status_code != 200;
	last;
    }
}
