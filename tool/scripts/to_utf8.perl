#!/usr/bin/env perl

# $Id$

# HTML文書の文字コードをutf8に変更するプログラム
# (metaタグにてcharset属性が指定されている場合は、値をutf8に変更する)

use strict;
use utf8;
use Encode;
use Getopt::Long;
use HtmlGuessEncoding;

my (%opt);
# gzip圧縮済ファイルを処理するためのオプション
GetOptions(\%opt, 'z');

&main();

sub main {
    my $file = shift(@ARGV);
    my $HtmlGuessEncoding = new HtmlGuessEncoding({language => 'japanese'});
    if ($opt{z}) {
	open(READER, "zcat $file |");
    } else {
	open(READER, $file);
    }

    my $buff;
    while (<READER>) {
	$buff .= $_;
    }
    close(READER);

    # HTML文書の文字コードを取得すると同時にutf8に変更
    if ($HtmlGuessEncoding->ProcessEncoding(\$buff, {change_to_utf8 => 1})) {
	# charset属性が指定されている場合は、その値をutf8に変更
	if ($buff =~ /(<meta [^>]*content=[" ]*text\/html[; ]*)(charset=([^" >]+))/i) {
	    my $fwd = $1;
	    my $match = $2;
	    $buff =~ s/$fwd$match/${fwd}charset=utf\-8/;
	}
	print $buff;
    } else {
	die "error\n";
    }
}

