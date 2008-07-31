#!/usr/bin/env perl

# $Id$

# HTML文書の文字コードをutf8に変更するプログラム

use strict;
use utf8;
use Encode;
use Getopt::Long;
use HtmlGuessEncoding;

my (%opt);
# gzip圧縮済ファイルを処理するためのオプション
GetOptions(\%opt, 'utf8', 'overwrite', 'z', 'force');

&main();

sub usage {
    print "Usage: $0 [-utf8] [-overwrite] [-z] [-force] htmlfile\n";
}

sub main {
    my $file = shift(@ARGV);
    if (!$file) {
	&usage();
	exit;
    }

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
    if ($HtmlGuessEncoding->ProcessEncoding(\$buff, {force_change_to_utf8_with_flag => $opt{force}, change_to_utf8 => !$opt{utf8}})) {
	if ($opt{overwrite}) {
	    if ($opt{z}) {
		open(WRITER, "| gzip > $file");
	    } else {
		open(WRITER, "> $file");
	    }

	    print WRITER $buff;
	    close(WRITER);
	} else {
	    print $buff;
	}
    } else {
	print STDERR "Cannot guess character encoding.\n";
	exit 1;
    }
}

