#!/usr/bin/env perl

use StanfordParser;
use strict;
use Getopt::Long;

our (%opt);
&GetOptions(\%opt, 'parser_dir=s', 'parser_command=s', 'output_sf');

my $parser = new StanfordParser(\%opt);
while (<STDIN>) {
    my $result = $parser->analyze($_);
    print $result;
}
