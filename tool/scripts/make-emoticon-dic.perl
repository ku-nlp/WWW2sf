#!/usr/bin/env perl

# Usage: $0 facemark_kuntt071204.txt > ../perl/Emoticon.dic
# the encoding of facemark_kuntt071204.txt is utf8

use Data::Dumper;
use strict;

my (@array);
while (<>) {
    chomp;
    push(@array, $_) if $_;
}

print Dumper(\@array);
