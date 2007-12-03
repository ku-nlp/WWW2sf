#!/usr/bin/env perl

# S-ID付きのフォーマットを入力として、括弧を別文として分割する
# 入出力コード: euc-jp

use encoding 'euc-jp';
use SentenceFormatter;
use strict;

my $formatter = new SentenceFormatter({'divide_paren' => 1, 'include_paren' => 1, 'save_all' => 1});

my ($sid, $comment);
while (<STDIN>) {
    if (/^\# S-ID:(\S+)(.*)/) {
	$sid = $1; # . '-01';
	$comment = $2;
	$comment =~ s/^\s+//;
    }
    elsif ($sid) {
	chomp;
	# 全文削除や括弧の処理
	my ($main, @parens) = $formatter->FormatSentence($_, $sid);

	# 原文の表示
	&print_sentence($main);

	# 括弧文の表示
	for my $paren (@parens) {
	    &print_sentence($paren);
	}

	$sid = '';
    }
}

sub print_sentence {
    my ($ref) = @_;

    printf "# S-ID:%s", $ref->{sid};
    printf " %s", $ref->{comment} if $ref->{comment};
    print "\n";
    print $ref->{sentence}, "\n" if $ref->{sentence};
}
