#!/usr/bin/env perl

# 先頭1文を削除

use strict;

my $print = 0;

while (<>) {
    if ($print == 0 && /^\#\s*S-ID:/) {
	$print = 2;
    }
    elsif ($print == 2 && /^EOS/) {
	$print = 1;
	next;
    }

    if ($print == 1) {
	print;
    }
}
