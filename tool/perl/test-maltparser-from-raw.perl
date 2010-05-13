#!/usr/bin/env perl

use MaltParser;
use strict;

my $parser = new MaltParser();

while (<STDIN>) {
    my $result = $parser->analyze($_);
    print $result;
}
