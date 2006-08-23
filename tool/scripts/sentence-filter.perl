#!/usr/local/bin/perl

# 日本語と思われる文だけを出力

# $Id$

use strict;
use vars qw($Threshold);

$Threshold = 0.6;

my ($buf, $score, $start_tag);

while (<>) {
    if (/^\<(?:FILE|SITE|PAGE)/) {
	$buf = undef;
	$start_tag = $_;
	next;
    }
    elsif (/^\<\/(?:FILE|SITE|PAGE)\>/) {
	if ($buf) {
	    print $start_tag, $buf, $_;
	}
    }
    chomp;
    $score = &japanese_check($_);
    $buf .= "$_\n" if $score > $Threshold;
}

sub japanese_check {
    my ($buf) = @_;
    my ($str, $acount, $count, $hira_count);

    while ($buf =~ /([^\x80-\xfe]|[\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/g) {
	$str = $1;
	# ひらがな,カタカナ,漢字をカウント
	if ($str =~ /^[\xa4\xa5\xb0-\xf3]/) {
	    $count++;
	}
	if ($str =~ /^\xa4/) {
	    $hira_count++;
	}
	$acount++;
    }
    return 0 unless $acount;
    # return 0 if $hira_count == 0;
    return $count/$acount;
}
