#!/usr/bin/env perl

# WWWから収集した文を整形, 削除, S-ID付与

# $Id$

use SentenceFormatter;
use utf8;
use Getopt::Long;
use strict;

our (%opt);

GetOptions(\%opt, 'head:s', 'include_paren', 'divide_paren', 'pagenum=i', 'save_all', 'encoding=s');
# --save_all: 全体削除しない
# --include_paren: 括弧を削除しない
# --divide_paren: 括弧を別文として出力
# --pagenum: 開始ページ番号を指定

$opt{'include_paren'} = 1 if $opt{'divide_paren'};
my $encoding = $opt{encoding} ? ":encoding($opt{encoding})" : ':encoding(euc-jp)'; # default encoding is euc-jp

binmode(STDIN, $encoding);
binmode(STDOUT, $encoding);
binmode(STDERR, $encoding);

my ($head, $site, $file, $fileflag, $count, $url, $comment);
my ($sid, $sentence) = @_;
my (@char_array, @check_array, $i, $j, $flag);
my ($enu_num, $paren_start, $paren_level, $paren_str);

if (defined($opt{head})) {
    if ($opt{head}) {
	$head = $opt{head};
    }
    else {
	my ($tmp_filename);
	if ($ARGV[0] =~ /([^\/]+)\/([^\/]+)$/) {
	    ($head, $tmp_filename) = ($1, $2);
	    $head = (split(/\./, $head))[0]; # tsubame00.kototoi.org => tsubame00
	    ($site) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
	}
	else {
	    ($tmp_filename) = ($ARGV[0] =~ /([^\/]+)$/);
	    ($head) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
	}
    }
}
else {
    my ($tmp_filename) = ($ARGV[0] =~ /([^\/]+)$/);
    ($head) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
}

$file = $opt{pagenum} - 1 if $opt{pagenum};

my $formatter = new SentenceFormatter(\%opt);

while (<STDIN>) {
    chomp;

    if (/^\<PAGE(?:\s*URL=\"([^\"]+)\")?\>/) {
	$comment .= "URL:$1" if $1;
	$file++;
	$fileflag = 0;
	$count = 0;
	next;
    }
    elsif (/^\<\/PAGE\>/) {
	$file-- if $fileflag == 0;
	$comment = undef;
	next;
    }
    else {
	$fileflag = 1;
    }

    $count++;
    $sid = sprintf("%s%s%s-%d", $head, defined($site) ? "-$site" : '', defined($file) ? "-$file" : '', $count);

    # 全文削除や括弧の処理
    my ($main, @parens) = $formatter->FormatSentence($_, $sid);

    # 原文の表示
    &print_sentence($main);

    # 括弧文の表示
    for my $paren (@parens) {
	&print_sentence($paren);
    }
}

sub print_sentence {
    my ($ref) = @_;

    printf "# S-ID:%s", $ref->{sid};
    printf " %s", $ref->{comment} if $ref->{comment};
    print "\n";
    print $ref->{sentence}, "\n" if $ref->{sentence};
}
