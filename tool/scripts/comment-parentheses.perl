#!/usr/bin/env perl

# S-ID付きのフォーマットを入力として、括弧を別文として分割する
# 入出力コード: utf8

use encoding 'utf8';
use SentenceFormatter;
use strict;

my $formatter = new SentenceFormatter({'divide_paren' => 1, 'include_paren' => 1, 'save_all' => 1});

my ($sid, $comment);
while (<STDIN>) {
    if (/^\# S-ID:(\S+)(.*)/) {
	$sid = $1;
	$comment = $2;
	$comment =~ s/^\s+//;
    }
    elsif ($sid) {
	chomp;

	# 文の表示
	&print_sentence($_, $sid, $comment);

	$sid = '';
    }
}

sub print_sentence {
    my ($str, $sid, $comment) = @_;

    # 全文削除や括弧の処理
    my ($ref, @parens) = $formatter->FormatSentence($str, $sid);

    printf "# S-ID:%s", $sid;
    printf " %s", $comment if $comment;

    for my $paren_ref (@parens) {
	my ($pos) = ($paren_ref->{comment} =~ /括弧位置:(\d+)/);
	my ($paren_start_str) = ($paren_ref->{comment} =~ /括弧始:(\S+)/);
	my ($paren_end_str)   = ($paren_ref->{comment} =~ /括弧終:(\S+)/);
	printf " 部分削除:%d:%s%s%s", $pos, $paren_start_str, $paren_ref->{sentence}, $paren_end_str;
    }

    print "\n";
    print $ref->{sentence}, "\n" if $ref->{sentence};
}
