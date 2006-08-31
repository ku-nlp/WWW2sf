#!/usr/local/bin/perl

# zaodataを読み込むスクリプト
# Usage: $0 doc0000000001.idx (doc0000000001.zlが必要)

# $Id$

use Compress::Zlib;
use File::Basename;
use Getopt::Long;
use HtmlGuessEncoding;
use strict;
use vars qw(%opt $RequireContentType $SplitSize $HtmlGuessEncoding $Threshold_for_zyoshi $OFFSET);

sub usage {
    $0 =~ /([^\/]+)$/;
    print "Usage: $0 [--split filesize] doc0000000001.idx\n";
    exit 1;
}

&GetOptions(\%opt, 'split=i', 'splithtml', 'language=s', 'checkzyoshi', 'offset=i', 'help', 'debug');

$RequireContentType = 'text/html'; # htmlだけを抽出
$SplitSize = $opt{split};

$HtmlGuessEncoding = new HtmlGuessEncoding(\%opt);

my ($z, $status, $output, $buf);

$Threshold_for_zyoshi = 0.005;
$OFFSET = $opt{offset} ? $opt{offset} : 0;

# for splithml
my $filenum_in_dir = 10000;

for my $f (@ARGV) {
    my ($head) = ($f =~ /^([^.]+)/);
    my ($filename, $path, $suffix) = fileparse($f, ".idx");

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

    my ($dirname, $xnum);
    # 最初のディレクトリの作成
    if ($opt{splithtml}) {
	($xnum = $filename) =~ s/^doc//;
	$xnum += $OFFSET;
	$dirname = sprintf("%sh%04d", $path, $xnum);
	mkdir $dirname or die unless -d $dirname;
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

			# 助詞含有率をチェック
			if ($opt{checkzyoshi}) {
			    if (&postp_check($output) <= $Threshold_for_zyoshi) {
				next;
			    }
			}

			# $filenum_in_dirファイル出力されたら新しいディレクトリの作成
# 			if ($fnum % $filenum_in_dir == 1) {
# 			    $dirname = $head . "/" . int ($fnum / $filenum_in_dir);
# 			    mkdir "$dirname" or die;
# 			}
			    
#			$write_filename = sprintf "%s/%s-%05d.html", $dirname, $head, $fnum;
			$write_filename = sprintf "%s/%04d%04d.html", $dirname, $xnum, $fnum;
		        open(DATA, "> $write_filename") or die "$write_filename: $!\n";
			$fnum++;
			exit if $fnum eq '10000';
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

sub postp_check {
    my ($buf) = @_;
    my ($pp_count, $count);

    while ($buf =~ /([^\x80-\xfe]|[\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/g) {
	my $chr = $1;
	next if $chr eq "\n";
	if ($chr =~ /^が|を|に|は|の|で$/) {
	    $pp_count++;
	}
	$count++;
    }

    return eval {$pp_count/$count};
}
