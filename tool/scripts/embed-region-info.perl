#!/usr/bin/env perl

# $Id$

# Usage: zcat h/041690000.html.gz | nkf -w | perl -I $HOME/cvs/DetectBlocks/perl scripts/embed-region-info.perl -add_blockname2alltag -add_class2html

use utf8;
use strict;
use RepeatCheck;
use DetectBlocks;
use Getopt::Long;

binmode (STDIN, ':utf8');
binmode (STDOUT, ':utf8');

my (%opt);
GetOptions(\%opt,
	   'get_source=s',
	   'proxy=s',
	   'debug',
	   'add_class2html',
	   'printtree',
	   'get_more_block',
	   'rel2abs',
	   'add_blockname2alltag',
	   'juman=s'
	   );


########################
# HTMLファイルの読み込み
########################

my $crawler_html = 0;
my $flag = 0;
my $header;
my $content;
my $url;
while (<STDIN>) {
    if (/^HTML (.+?)[\r|\n]+$/ && $flag < 1) { # 1行目からURLを取得(read-zaodataが出力している)
	$crawler_html = 1;
	my @data = split (/ /, $1);
	$url = shift @data;
    }
    if ($crawler_html) {
	if ($flag) {
	    $content .= $_;
	} else {
	    $header .= $_;
	}

	if ($_ =~ /^(\x0D\x0A|\x0D|\x0A)$/ && !$flag) {
	    $flag = 1;
	    $content = '';
	}
    }
    else {
	$content .= $_;
    }
}
close (HTML);



########################
# 領域情報の埋め込み
########################

my $DetectBlocks = new DetectBlocks(\%opt);

# 領域情報の検出
$DetectBlocks->maketree($content, $url);
$DetectBlocks->detectblocks;

# 領域情報の埋め込み
my $DOMtree = $DetectBlocks->gettree;
$DetectBlocks->addCSSlink($DOMtree, 'style.css');

# 出力
print $header if ($header);
# 先頭から３行に � を出力している
print $DOMtree->as_HTML("<>&","\t");
