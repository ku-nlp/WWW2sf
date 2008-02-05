#!/usr/bin/env perl

#$Id$

# 文のオフセットと長さを求めるプログラム

# usage:
# perl -I perl scripts/set-offset-and-length.perl -html 30215120.html -xml 30215120.xml

use strict;
use utf8;
use Encode;
use Getopt::Long;
use XML::LibXML;
use TextExtractor;
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;



# 入出力のエンコードを設定
binmode(STDIN,  ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');



my (%opt);
GetOptions(\%opt, 'html=s', 'xml=s', 'html_encoding=s', 'max_length_of_html_entity=s', 'verbose', 'z');
my $MAX_LENGTH_OF_HTML_ENTITY = ($opt{max_length_of_html_entity}) ? $opt{max_length_of_html_entity} : 10;
$opt{html_encoding} = 'utf8' unless ($opt{html_encoding});


&main();

sub main {
    if ($opt{z}) {
	open(READER, "zcat  $opt{xml} |");
    } else {
	open(READER, $opt{xml});
    }
    binmode(READER, ':utf8');

    my $xmldat;
    while (<READER>) {
	$xmldat .= $_;
    }
    close(READER);

    if ($opt{z}) {
	open(READER, "zcat  $opt{html} |");
    } else {
	open(READER, $opt{html});
    }
#   binmode(READER, ':utf8'); # オフセットが文字数になるのでフラグは立てない

    my $htmldat;
    while (<READER>) {
	$htmldat .= $_;
    }
    close(READER);



    # HTML文書からテキストを取得
    my $ext = new TextExtractor({language => 'japanese'});
    my ($text, $property) = $ext->detag(\$htmldat, {always_countup => 1});

    for (my $i = 0; $i < scalar(@$text); $i++) {
	$text->[$i] = decode('utf8', $text->[$i]);
    }

    # 標準フォーマットから文情報を取得
    my $parser = new XML::LibXML;
    my $doc = $parser->parse_string($xmldat);
    my $sentences = &get_sentence_nodes($doc);



    # HTML文書、標準フォーマット間 のアライメントをとる
    foreach my $s (@$sentences) {
	my $rawstring = &get_rawstring($s);
	my ($offset, $length) = &get_offset_and_length($rawstring, $text, $property);
	$s->setAttribute('Offset', $offset);
	$s->setAttribute('Length', $length);
    }

    print $doc->toString;
}

sub get_offset_and_length {
    my ($rawstring, $text, $property) = @_;

    my @chars_r = split(//, $rawstring);
    my @chars_h = split(//, $text->[0]);

    print "[" . $text->[0] . "]\n" if ($opt{verbose});

    my $offset = -1;
    my $j = 0; # @chars_hの添字
    for (my $i = 0; $i < scalar(@chars_r); $i++) {
	# @chars_hを読みきった時の処理 length(@chars_r) > length(@chars_h)
	if ($j >= scalar(@chars_h)) {
	    # 使い切った分を削除
	    shift(@$text);
	    shift(@$property);

	    print "-----\n" if ($opt{verbose});
	    print "[" . $text->[0] . "]\n" if ($opt{verbose});
	    @chars_h = split(//, $text->[0]);
	    $j = 0;
	}

	my $ch_r = $chars_r[$i];
	my $ch_h = $chars_h[$j];

	if ($opt{ignore_html_entity}) {
	    # HTMLエンティティの処理
	    if ($ch_h eq '&') {
		my $flag = -1;
		for (my $k = 1; $k < scalar(@chars_h) && $k < $MAX_LENGTH_OF_HTML_ENTITY; $k++) {
		    # エンティティであれば標準フォーマット側を強制的に一文字飛ばし、エンティティの長さの分かえインクリメント
		    if ($chars_h[$j + $k] eq ';') {
			$j += ($k + 1);

			$flag = 1; # 多重ループ脱出用
			last;
		    }
		}
		next if ($flag > 0);
	    }
	}

	# 制御コードを空白に変換
	$ch_h = '　' if ($ch_h =~ /[\x00-\x1f\x7f-\x9f]/);
	# 半角文字を全角に変換
	$ch_h = Unicode::Japanese->new($ch_h)->h2z->getu();

	print "r:[$ch_r] cmp h:[$ch_h] off=$offset\n" if ($opt{verbose});

	if ($ch_r eq $ch_h) {
	    if ($offset < 0) {
		$offset = $property->[0]{offset};
	    }
	    $j++;
	}
	elsif ($ch_h eq '') {
	    $i--;
	    $j++;
	}
	# HTML側の空白はスキップ
	elsif ($ch_h eq '　') {
	    $i--;
	    $j++;
	}
	# `ー'は汎化
	elsif ($ch_r eq 'ー' && $ch_h =~ /(?:ー|―|−|─|━|‐)/) {
	    $j++;
	}
	# 標準フォーマット側で文字化けを起こしてる時はスキップ
	elsif ($ch_r eq '?') {
	    $j++;
	}
	# マッチしない
	else {
	    $i--;
	}
    }

    # アライメントに使用した分を除去
    my @removed = splice(@chars_h, 0, $j);
    my $removed_string = join('', @removed);
    my $length = length(encode($opt{html_encoding}, $removed_string));
    if ($property->[0]{offset} - $offset > 0) {
	$length += ($property->[0]{offset} - $offset);
    }

    # 未使用部分を文字列に戻す
    my $substring_unused = join('', @chars_h);
    $text->[0] = $substring_unused;

    # 使用した分だけオフセットをずらす
    $property->[0]{offset} += $length;

    return ($offset, $length);
}

sub get_sentence_nodes {
    my ($doc) = @_;
    my @sentences = ();

    my $title = $doc->getElementsByTagName('Title')->[0];
    push(@sentences, $title) if (defined $title);

    foreach my $sentence ($doc->getElementsByTagName('S')) { # for each S
	push(@sentences, $sentence);
    }

    return \@sentences;
}

sub get_rawstring {
    my ($sentence) = @_;
    for my $s_child_node ($sentence->getChildNodes) {
	if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
	    for my $node ($s_child_node->getChildNodes) {
		return $node->string_value;
	    }
	}
    }
}
