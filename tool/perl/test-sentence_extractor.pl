#!/usr/bin/env perl

# $Id$

# usage: echo 'あまり気の毒だから「行く事は行くがじき帰る。来年の夏休みにはきっと帰る」と慰めてやった。' | perl test-sentence_extractor.pl  

use strict;
use utf8;
use SentenceExtractor;
use utf8;
binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');

while (<STDIN>) {
    chomp;

    my @sentences = SentenceExtractor->new($_, 'Japanese')->GetSentences();
    for my $sentence (@sentences) {
	print $sentence, "\n";
    }
}
