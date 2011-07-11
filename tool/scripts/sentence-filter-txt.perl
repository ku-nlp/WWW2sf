#!/usr/bin/env perl

# SentenceFilter.pmを使って日本語文かどうかを判定し、日本語文だけを出力

# 入力形式: (utf8)
# S-ID:...
# 日本語の文です

use SentenceFilter;
use encoding 'utf8';
use Getopt::Long;
use strict;
use warnings;

binmode(STDERR, ':utf8');

our (%opt);
&GetOptions(\%opt, 'threshold=f', 'debug');
our $Threshold_Filter = $opt{threshold} ? $opt{threshold} : 0.3;
our $Filter = new SentenceFilter;

my ($sid);
while (<STDIN>) {
    if (/^\# S-ID/) {
	$sid = $_;
    }
    else {
	chomp;
	my $score = $Filter->JapaneseCheck($_);
	if ($score > $Threshold_Filter) {
	    if ($sid) {
		print "$sid$_\n";
	    }
	    else {
		print "$_\n";
	    }
	}
	elsif ($opt{debug}) {
	    printf STDERR "Not Japanese (%.3f):%s\n", $score, $_;
	}
    }
}
