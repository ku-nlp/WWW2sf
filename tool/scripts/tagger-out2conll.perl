#!/usr/bin/env perl

# tagger output to CoNLL format

use strict;
use Getopt::Long;

our (%opt, $lem);
&GetOptions(\%opt, 'lemmatize');

if ($opt{lemmatize}) {
    require Lemmatize;
    $lem = new Lemmatize;
}

while (<>) {
    chomp;
    my $i = 1;
    for my $pair (split(' ', $_)) {
	my ($word, $pos) = split('/', $pair, 2);
	$pos = &change_parenthesis_pos($pos);
	my $h = 0;
	my $rel = '_';
	my $lemma = $opt{lemmatize} ? &lemmatize($word, $pos) : '_';
	printf "%d\t%s\t%s\t%s\t%s\t\_\t%d\t%s\t\_\t\_\n", $i, $word, $lemma, $pos, $pos, $h, $rel;
	$i++;
    }
    print "\n";
}

sub change_parenthesis_pos {
    my ($pos) = @_;

    $pos =~ s/\(/-LRB-/;
    $pos =~ s/\)/-RRB-/;
    $pos =~ s/\[/-LSB-/;
    $pos =~ s/\]/-RSB-/;
    $pos =~ s/\{/-LCB-/;
    $pos =~ s/\}/-RCB-/;

    return $pos;
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
