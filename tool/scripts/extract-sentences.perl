#!/usr/bin/env perl

# htmlを文リストに変換

# $Id$

use strict;
use TextExtor2;
use Encode qw(from_to);
use Encode::Guess;
use XML::Writer;
use File::stat;
use POSIX qw(strftime);
use HtmlGuessEncoding;
use SentenceFilter;
use Getopt::Long;

sub usage {
    $0 =~ /([^\/]+)$/;
    print "Usage: $1 [--language english|japanese] [--xml] [--url string] file.html\n";
    exit 1;
}

our (%opt, $writer, $filter);
&GetOptions(\%opt, 'language=s', 'url=s', 'xml', 'checkjapanese', 'checkzyoshi');
$opt{language} = 'japanese' unless $opt{language};

my ($buf, $timestamp, $url);

my $HtmlGuessEncoding = new HtmlGuessEncoding(\%opt);
my $Filter = new SentenceFilter if $opt{checkjapanese};

our $Threshold_Filter = 0.6;
our $Threshold_Zyoshi = 0.005;

# ファイル名が与えられていればタイムスタンプを取得
if ($ARGV[0] and -f $ARGV[0]) {
    my $st = stat($ARGV[0]);
    $timestamp = strftime("%Y-%m-%d %T", localtime($st->mtime));
}

while (<>) {
    if (!$buf and /^HTML (\S+)/) { # 1行目からURLを取得(read-zaodataが出力している)
	$url = $1;
    }
    $buf .= $_;
}
exit 0 unless $buf;

my $encoding = $HtmlGuessEncoding->ProcessEncoding(\$buf, {change_to_utf8 => 1});

# HTMLを文のリストに変換
my $parsed = new TextExtor2(\$buf, 'utf8', \%opt);

# 助詞含有率をチェック
if ($opt{checkzyoshi}) {
    my $allbuf;
    for my $i (0 .. $#{$parsed->{TEXT}}) {
	$allbuf .= $parsed->{TEXT}[$i];
    }
    my $ratio = &postp_check($allbuf);
    exit if $ratio <= $Threshold_Zyoshi;
}

# XML出力の準備
if ($opt{xml}) {
    require XML::Writer;
    $writer = new XML::Writer(OUTPUT => *STDOUT, DATA_MODE => 'true', DATA_INDENT => 2);
    $writer->xmlDecl('utf-8');
}

# 文に分割して出力
&print_page_header($opt{url} ? $opt{url} : $url, $encoding, $timestamp);
&print_extract_sentences($buf);
&print_page_footer();

sub print_page_header {
    my ($url, $encoding, $timestamp) = @_;

    if ($opt{xml}) {
	$writer->startTag('StandardFormat', Url => $url, OriginalEncoding => $encoding, Time => $timestamp);
	$writer->startTag('Text');
    }
    else {
	if ($url) {
	    printf qq(<PAGE URL="%s">\n), $url;
	}
	else {
	    print "<PAGE>\n";
	}
    }
}

sub print_extract_sentences {
    my ($buf) = @_;
    my ($prev_offset, $prev_length);

    for my $i (0 .. $#{$parsed->{TEXT}}) {
	my $line = $parsed->{TEXT}[$i];
	if ($opt{xml}) {
	    $prev_offset = $parsed->{PROPERTY}[$i]{offset};
	    $prev_length = $parsed->{PROPERTY}[$i]{length};

 	    $line = &convert_code($line, 'euc-jp', 'utf8');

	    if ($opt{checkjapanese}) {
		my $score = sprintf("%.5f", $Filter->JapaneseCheck($line));
		my $is_Japanese = $score > $Threshold_Filter ? '1' : '0';

		$writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length}, is_Japanese => $is_Japanese, JapaneseScore => $score);
	    }
	    else {
		$writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length});
	    }
	    $writer->startTag('RawString');
	    $writer->characters($line);
	    $writer->endTag('RawString');
	    $writer->endTag('S');
	}
	else {
	    print $line, "\n";
	}
    }
}

sub print_page_footer {
    if ($opt{xml}) {
	$writer->endTag('Text');
	$writer->endTag('StandardFormat');
	$writer->end();
    }
    else {
	print "</PAGE>\n";
    }
}

sub convert_code {
    my ($buf, $from_enc, $to_enc) = @_;

    eval {from_to($buf, $from_enc, $to_enc)};
    if ($@) {
	print STDERR $@;
	return undef;
    }

    return $buf;
}

sub postp_check {
    my ($buf) = @_;
    my ($pp_count, $count);

#    $buf = &convert_code($buf, 'utf8', 'euc-jp');

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
