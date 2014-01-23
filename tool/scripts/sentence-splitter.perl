#!/usr/bin/env perl

# Split Japanese text to sentences
# usage: echo 'あまり気の毒だから「行く事は行くがじき帰る。来年の夏休みにはきっと帰る」と慰めてやった。' | perl -I../perl sentence-splitter.perl

use SentenceExtractor;
use encoding 'utf-8';
use strict;

while (<STDIN>) {
    for my $sentence (SentenceExtractor->new($_, 'japanese')->GetSentences()) {
	print $sentence, "\n";
    }
}
