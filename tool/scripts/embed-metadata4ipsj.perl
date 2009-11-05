#!/usr/bin/env perl

# $Id$

# 論文誌のメタ情報データベースを引き、素の標準フォーマットに、タイトル、著者名、アブストラクト、キーワードを挿入するスクリプト

use strict;
use utf8;
use Getopt::Long;
use CDB_File;
use Encode;
use XML::Writer;
use Unicode::Japanese;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');

my (%opt);
GetOptions(\%opt, 'cdb=s', 'file=s');


&main();

sub main {
    my $dbfp = $opt{cdb};
    tie my %cdb, 'CDB_File', $dbfp or die "$0: can't tie to $dbfp $!\n";

    my ($fid) = ($opt{file} =~ /([^\/]+?)\./);

    my $metadata = decode ('utf8', $cdb{$fid});

    my $xmlbuf;
    if (-f $opt{file}) {
	open (READER, '<:utf8', $opt{file}) or die "$!";
	while (<READER>) {
	    $xmlbuf .= $_;
	}
	close (READER);
    }

    unless ($metadata) {
	print $xmlbuf;
	exit;
    }


    my @attrs = ("TITLE", "AUTH", "ABST", "KYWD");
    my %buf;
    foreach my $tagname (@attrs) {
	while ($metadata =~ m/<$tagname>(.+?)<\/$tagname>/g) {
	    my $value = $1;
	    next if ($value eq '');

	    $value =~ s/-/−/g;
	    $value =~ s/, /,/g;
	    $value =~ s/\. /\./g;

	    if ($tagname =~ /AUTH/) {
		while ($value =~ m/<AUTH_NAME>(.+?)<\/AUTH_NAME>/g) {
		    push (@{$buf{$tagname}}, uc(Unicode::Japanese->new($1)->h2z->getu()));
		}
	    } else {
		$buf{$tagname} = uc(Unicode::Japanese->new($value)->h2z->getu());

	    }
	}
    }


    my $xmldat;
    my $writer = new XML::Writer(OUTPUT => \$xmldat, DATA_MODE => 'true', DATA_INDENT => 2);
    $writer->xmlDecl('utf-8');


    $writer->startTag('Header');

    if ($buf{'TITLE'}) {
	$writer->startTag('Title', blockType => 'title');
	$writer->startTag('RawString');
	$writer->characters($buf{'TITLE'});
	$writer->endTag('RawString');
	$writer->endTag('Title');
    }


    if ($buf{'AUTH'}) {
	$writer->startTag('Authors', blockType => 'author');
	foreach my $author (@{$buf{'AUTH'}}) {
	    # 姓と名の間の空白を消す
	    $author =~ s/([\p{Hiragana}|\p{Katakana}|\p{Han}])　([\p{Hiragana}|\p{Katakana}|\p{Han}])/\1\2/g;
	    $writer->startTag('Author');
	    $writer->startTag('RawString');
	    $writer->characters($author);
	    $writer->endTag('RawString');
	    $writer->endTag('Author');
	}
	$writer->endTag('Authors');
    }


    if ($buf{'ABST'}) {
	$writer->startTag('Abstract', blockType => 'abstract');
	foreach my $str (split (/[。|．]/, $buf{'ABST'})) {
	    $writer->startTag('S');
	    $writer->startTag('RawString');
	    $str =~ s/(\p{Hiragana}|\p{Katakana}|\p{Han})　(\p{Hiragana}|\p{Katakana}|\p{Han})/\1\2/g;
	    $writer->characters($str . "。");
	    $writer->endTag('RawString');
	    $writer->endTag('S');
	}
	$writer->endTag('Abstract');
    }


    if ($buf{KYWD}) {
	$writer->startTag('Keywords', blockType => 'keyword');
	foreach my $keywd (split /[\t+|／|，|、]/, $buf{KYWD}) {
	    $writer->startTag('Keyword');
	    $writer->startTag('RawString');
	    $keywd =~ s/^　+//;
	    $keywd =~ s/　+$//;
	    $writer->characters($keywd);
	    $writer->endTag('RawString');
	    $writer->endTag('Keyword');
	}
	$writer->endTag('Keywords');
    }

    $writer->endTag('Header');

    $xmldat =~ s/<\?xml version="1.0" encoding="utf\-8"\?>\n\n//;

    $xmlbuf =~ s/\s*<Header\/>/\n  $xmldat/;
    print $xmlbuf . "\n";
}
