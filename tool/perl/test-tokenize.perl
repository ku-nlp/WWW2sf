#!/usr/bin/env perl

use Tokenize;
use strict;
use Getopt::Long;

our (%opt);
&GetOptions(\%opt, 'language=s');

my $tokenizer = new Tokenize(\%opt);
while (<STDIN>) {
    my $result = $tokenizer->tokenize($_);
    print $result;
}
