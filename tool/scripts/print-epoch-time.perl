#!/usr/bin/env perl

# print epoch time of a given file

use strict;

my $file = $ARGV[0];
my $lastmodified = (stat $file)[9];
print $lastmodified, "\n";
