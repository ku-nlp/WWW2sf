#!/usr/bin/env perl

use KNP;
use strict;
use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

our $LENGTH_THRESHOLD = 80;
our $BEGINNING_CHECKED_DELIMITER = 0.3;
our $ENDING_CHECKED_DELIMITER = 0.7;

my $knp = new KNP(-Option => '-tab -dpnd');
while (<STDIN>) {
    chomp;
    my $len = length($_);
    my $beginning_checked_pos = $len * $BEGINNING_CHECKED_DELIMITER;
    my $ending_checked_pos = $len * $ENDING_CHECKED_DELIMITER;
    my $split_flag = 0;
    my (@pre_splitted, @post_splitted);
    if ($len > $LENGTH_THRESHOLD) {
	# KNP
	my $result = $knp->parse($_);
	my $pos = 0;
	my @mrphs;
	for my $tag ($result->tag) {
	    if ($pos > $ending_checked_pos && $split_flag == 0) {
		last;
	    }
	    if ($pos > $beginning_checked_pos && $tag->fstring =~ /<ID:〜が>/) {
		$split_flag = 1;
		# 「が」より後を捨てる
		for my $mrph ($tag->mrph) {
		    if ($mrph->midasi eq 'が' && $mrph->hinsi eq '助詞') {
			last;
		    }
		    push(@mrphs, $mrph);
		}
		@pre_splitted = @mrphs;
		@mrphs = ();
		next;
	    }
	    for my $mrph ($tag->mrph) {
		$pos += length($mrph->midasi);
		push(@mrphs, $mrph);
	    }
	}
	if ($split_flag) {
	    push(@post_splitted, @mrphs);
	}
    }

    if ($split_flag) {
	&print_splitted_sentence(\@pre_splitted, \@post_splitted);
    }
    else {
	# そのままプリント
	print $_, "\n";
    }
}

sub print_splitted_sentence {
    my ($pre_splitted_ar, $post_splitted_ar) = @_;

    for my $mrph (@{$pre_splitted_ar}) {
	print $mrph->midasi;
    }
    # 句点を挿入
    print "。\n";
    for my $mrph (@{$post_splitted_ar}) {
	print $mrph->midasi;
    }
    print "\n";
}
