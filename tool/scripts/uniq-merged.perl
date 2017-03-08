#!/usr/bin/env perl

use strict;
use Getopt::Long;

our (%opt);
&GetOptions(\%opt, 'merged');

my ($pre_comment, $pre_str, $count);
while (<>) {
    chomp;
    my ($str, $comment) = (/^(\S+)\s(.+)/);

    my $this_count = 1;
    if ($comment =~ s/ COUNT:(\d+)//) {
	$this_count = $1;
    }

    if ($str ne $pre_str) {
	if ($opt{merged}) {
	    print "$pre_str $pre_comment COUNT:$count\n" if $pre_str;
	}
	else {
	    print "$pre_comment COUNT:$count\n$pre_str\n" if $pre_str;
	}
	$pre_comment = $comment;
	$pre_str = $str;
	$count = $this_count;
    }
    else {
	$count += $this_count;
    }
}

if ($opt{merged}) {
    print "$pre_str $pre_comment COUNT:$count\n" if $pre_str;
}
else {
    print "$pre_comment COUNT:$count\n$pre_str\n" if $pre_str;
}
