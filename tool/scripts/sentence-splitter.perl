#!/usr/bin/env perl

# Split Japanese text to sentences

use SentenceExtractor;
use encoding 'euc-jp';
use strict;

while (<STDIN>) {
    for my $sentence (SentenceExtractor->new($_, 'japanese')->GetSentences()) {
	print $sentence, "\n";
    }
}
