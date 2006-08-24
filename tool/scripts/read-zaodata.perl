#!/usr/local/bin/perl

# zaodataを読み込むスクリプト
# Usage: $0 doc0000000001.idx (doc0000000001.zlが必要)

# $Id$

use Compress::Zlib;
use Getopt::Long;
use HtmlGuessEncoding;
use strict;
use vars qw(%opt $RequireContentType $SplitSize $HtmlGuessEncoding);

sub usage {
    $0 =~ /([^\/]+)$/;
    print "Usage: $0 [--split filesize] doc0000000001.idx\n";
    exit 1;
}

&GetOptions(\%opt, 'split=i', 'splithtml', 'language=s', 'help', 'debug');

$RequireContentType = 'text/html'; # htmlだけを抽出
$SplitSize = $opt{split};

$HtmlGuessEncoding = new HtmlGuessEncoding(\%opt);

my ($z, $status, $output, $buf);

# for splithml
my $filenum_in_dir = 10000;

for my $f (@ARGV) {
    my ($head) = ($f =~ /^([^.]+)/);
    my $fnum = $opt{splithtml} ? 0 : 1;
    my $filesize = 0;

    # INDEXファイル
    open(IDX, $f) or die "$f: $!\n";
    print STDERR "processing $f ... \n" if $opt{debug};

    my $zl_f = $f;
    $zl_f =~ s/\.idx$/.zl/;

    # DATAファイル
    open(ZL, $zl_f) or die "$zl_f: $!\n";

    # 書き込むファイル
    my $write_filename = $opt{split} ? "$head-$fnum.html" : "$head.html";
    open(DATA, "> $write_filename") or die "$write_filename: $!\n" unless $opt{splithtml};

    my $dirname;
    # 最初のディレクトリの作成
     if ($opt{splithtml}) {
# 	$dirname = $head . "/0";
 	$dirname = $head;
 	mkdir $head or die unless -d $head;
     }

    while (<IDX>) {
	my @line = split(/\s+/, $_);

	# ページ本体取得済みのURLのみ処理
	if (scalar(@line) == 6) {
	    my ($host, $port, $urlpath, $address, $size) = @line[0,1,2,4,5];
	    $status = seek(ZL, $address, 0);
	    if ($status == 0) {
		print STDERR "SEEKFAILED $_\n";
		next;
	    }
	    $status = read(ZL, $buf, $size);
	    if (!defined($status)) {
		print STDERR "READFAILED $_\n";
		next;
	    }

	    # 圧縮バッファを展開
	    ($z, $status) = inflateInit();
	    ($output, $status) = $z->inflate(\$buf);
	    if ($status == Z_OK || 
		$status == Z_STREAM_END) {
		if ($output =~ /\nContent-Type:\s*$RequireContentType/) {
		    if ($opt{splithtml}) {

			# 日本語判定
			if ($opt{language} eq 'japanese') {
			    unless ($HtmlGuessEncoding->ProcessEncoding(\$output)) {
				next;
			    }
			}

			# $filenum_in_dirファイル出力されたら新しいディレクトリの作成
# 			if ($fnum % $filenum_in_dir == 1) {
# 			    $dirname = $head . "/" . int ($fnum / $filenum_in_dir);
# 			    mkdir "$dirname" or die;
# 			}
			    
#			$write_filename = sprintf "%s/%s-%05d.html", $dirname, $head, $fnum;
			$write_filename = sprintf "%s/%08d.html", $dirname, $fnum;
		        open(DATA, "> $write_filename") or die "$write_filename: $!\n";
			$fnum++;
		    }

		    print DATA "HTML $host:$port$urlpath $size\n";
		    print DATA $output;
		    $filesize += length($output);
		    if ($opt{split} && $filesize > $SplitSize) {
			$filesize = 0;
			$fnum++;
			close(DATA);
			open(DATA, "> $head-$fnum.html") or die "$head-$fnum.html: $!\n";
		    }
		    elsif ($opt{splithtml}) {
			close DATA;
		    }
		}
	    }
	    undef $z;
	}
    }
    close(DATA);
    close(ZL);
    close(IDX);
}
