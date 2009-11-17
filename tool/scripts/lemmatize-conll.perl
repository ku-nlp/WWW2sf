#!/usr/bin/env perl

# add lemma to CoNLL format

use strict;
use Lemmatize;

our $lem = new Lemmatize;

while (<>) {
    if (/^\s*$/) {
	print;
	next;
    }
    else {
	chomp;
	my @line = split(/\s+/, $_);
	my ($word, $pos) = ($line[1], $line[3]);
	$line[2] = &lemmatize($word, $pos);
	print join("\t", @line), "\n";
    }
}

sub lemmatize {
    my ($word, $pos) = @_;
    my @lemmas = $lem->lemmatize(lc($word), $pos);
    if (@lemmas) {
	return $lemmas[0];
    }
    else {
	return $word;
    }
}
