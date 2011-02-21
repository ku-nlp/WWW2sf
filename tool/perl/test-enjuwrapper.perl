#!/usr/bin/env perl

use EnjuWrapper;
use strict;

my $enju = new EnjuWrapper;
while (<STDIN>) {
    my $buf = $enju->analyze($_);
    print $buf;
}
