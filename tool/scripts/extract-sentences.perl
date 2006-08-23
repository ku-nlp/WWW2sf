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
use Getopt::Long;

sub usage {
    $0 =~ /([^\/]+)$/;
    print "Usage: $1 [--language english|japanese] [--xml] [--url string] file.html\n";
    exit 1;
}

our (%opt, $writer);
&GetOptions(\%opt, 'language=s', 'url=s', 'xml');
$opt{language} = 'japanese' unless $opt{language};

my ($buf, $timestamp);

# ファイル名が与えられていればタイムスタンプを取得
if ($ARGV[0] and -f $ARGV[0]) {
    my $st = stat($ARGV[0]);
    $timestamp = strftime("%Y-%m-%d %T", localtime($st->mtime));
}

while (<>) {
    $buf .= $_;
}
exit 0 unless $buf;

# XML出力の準備
if ($opt{xml}) {
    require XML::Writer;
    $writer = new XML::Writer(OUTPUT => *STDOUT, DATA_MODE => 'true', DATA_INDENT => 2);
    $writer->xmlDecl('utf-8');
}

# エンコーディングをチェック
my $encoding = &process_encoding(\$buf);

# 文に分割して出力
if ($encoding) {
    &print_page_header($opt{url}, $encoding, $timestamp);
    &print_extract_sentences($buf);
    &print_page_footer();
}
else {
    die "Encoding error!\n";
}


sub process_encoding {
    my ($buf_ref) = @_;
    my ($language, $encoding);

    # 指定した言語とページの言語が一致するか判定

    # meta情報のチェック
    if ($$buf_ref =~ /<meta [^>]*content=[" ]*text\/html[; ]*charset=([^" >]+)/) {
	my $charset = lc($1);
	# 英語/西欧言語
	if ($charset =~ /^iso-8859-1|iso-8859-15|windows-1252|macintosh|x-mac-roman$/) {
	    $language = 'english';
	}
	# 日本語EUC
	elsif ($charset =~ /^euc-jp|x-euc-jp$/) {
	    $language = 'japanese';
	    $encoding = 'euc-jp';
	}
	# 日本語JIS
	elsif ($charset =~ /^iso-2022-jp$/) {
	    $language = 'japanese';
	    $encoding = '7bit-jis';
	}
	# 日本語SJIS
	elsif ($charset =~ /^shift_jis|windows-932|x-sjis|shift-jp$/) {
	    $language = 'japanese';
	    $encoding = 'shiftjis';
	}
	# UTF-8
	elsif ($charset =~ /^utf-8$/) {
	    $language = 'japanese'; # ?????
	    $encoding = 'utf8';
	}
	else {
	    return undef;
	}
    }
    # metaがない場合は推定
    else {
	my $enc = guess_encoding($$buf_ref, qw/ascii euc-jp shiftjis 7bit-jis utf8/); # range
	return unless ref($enc);
	if ($enc->name eq 'ascii') {
	    $language = 'english';
	}
	else {
	    $language = 'japanese';
	    $encoding = $enc->name;
	}
    }

    # 日本語指定
    if ($opt{language} eq 'japanese') {
	if ($language ne 'japanese') {
	    return undef;
	}
	else {
	    if ($encoding ne 'utf8') {
		# utf-8で扱う
		$$buf_ref = &convert_code($$buf_ref, $encoding, 'utf8');
	    }
	}
    }
    # 英語指定
    elsif ($opt{language} eq 'english') {
	if ($language ne 'english') {
	    return undef;
	}
    }
    else {
	return undef;
    }

    return $language eq 'english' ? 'ascii' : $encoding;
}

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

    # HTMLを文のリストに変換
    my $parsed = new TextExtor2(\$buf, 'utf8', \%opt);

    for my $i (0 .. $#{$parsed->{TEXT}}) {
	my $line = $parsed->{TEXT}[$i];
	if ($opt{xml}) {
	    $prev_offset = $parsed->{PROPERTY}[$i]{offset};
	    $prev_length = $parsed->{PROPERTY}[$i]{length};

	    $line = &convert_code($line, 'euc-jp', 'utf8');
	    $writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length});
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
