#!/usr/bin/env perl

# Merge SID to CoNLL format
# Usage: $0 test.txt test.conll > test.w-sid.conll

use strict;


my (@sid);
my $scount = 0;
open(TXT, $ARGV[0]) or die;
while (<TXT>) {
    if (/^\#/) {
	$sid[$scount++] = $_;
    }
}
close(TXT);

my ($buf);
$scount = 0;
open(CONLL, $ARGV[1]) or die;
while (<CONLL>) {
    if (/^\s*$/) {
	print $sid[$scount], $buf, "EOS\n";
	$scount++;
	$buf = '';
    }
    else {
	$buf .= $_;
    }
}
close(CONLL);
