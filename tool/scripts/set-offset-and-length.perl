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
use HTML::Entities;
use Unicode::Japanese;
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
$opt{max_num_of_discardable_chars_for_rawstring} = 5;
$opt{max_num_of_discardable_chars_for_html} = 10;


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
	open(READER, "zcat $opt{html} |");
    } else {
	open(READER, $opt{html});
    }
#   binmode(READER, ':utf8'); # オフセットが文字数になるのでフラグは立てない

    my $flag = -1;
    my $htmldat;
    my $ignored_chars;
    my $crawler_html;
    while (<READER>) {
	if (!$htmldat and /^HTML (\S+)/) { # 1行目からURLを取得(read-zaodataが出力している)
	    $crawler_html = 1;
	}

	# ヘッダーが読み終わるまでバッファリングしない
	if (!$crawler_html || $flag > 0) {
	    $htmldat .= $_;
	} else {
	    $ignored_chars .= $_;
	    if ($_ =~ /^\r$/) {
		$flag = 1;
	    }
	}
    }
    close(READER);

    # クローラのヘッダはアライメントの対象としない
    if ($crawler_html) {
	if ($htmldat =~ /^((\d|.|\n)*)?(<html(.|\n|\r)+)$/i) {
	    $ignored_chars .= $1;
	    $htmldat = $3;
	}
    }

    # HTML文書からテキストを取得
    my $ext = new TextExtractor({language => 'japanese', offset => length($ignored_chars)});
    my ($text, $property) = $ext->detag(\$htmldat, {always_countup => 1});

    for (my $i = 0; $i < scalar(@$text); $i++) {
	$text->[$i] = decode('utf8', $text->[$i]);
	$text->[$i] =~ s/&nbsp;/ /g;
	$text->[$i] = decode_entities($text->[$i]);
    }

    # 標準フォーマットから文情報を取得
    my $parser = new XML::LibXML;
    my $doc = $parser->parse_string($xmldat);
    my $sentences = &get_sentence_nodes($doc);


    # HTML文書、標準フォーマット間 のアライメントをとる
    foreach my $s (@$sentences) {
	my $rawstring = &get_rawstring($s);
	my ($offset, $length, $is_successful) = &get_offset_and_length($rawstring, $text, $property);
	$s->setAttribute('Offset', $offset);
	$s->setAttribute('Length', $length);

	unless ($is_successful) {
	    print STDERR "Fail to set offset alignment: " . $opt{xml} . "\n";
#	    &seek_common_char();
	}
    }

    my $string = $doc->toString();
    print utf8::is_utf8($string) ? $string : decode($doc->actualEncoding(), $string);
}

# オフセットと長さを求める関数
sub get_offset_and_length {
    my ($rawstring, $text, $property) = @_;

    my @chars_r = split(//, $rawstring);
    my @chars_h = split(//, $text->[0]);

    print "[" . $text->[0] . "]\n" if ($opt{verbose});

    my $i = 0; # @chars_rの添字
    my $j = 0; # @chars_hの添字

    my $offset = -1;
    my $miss = -1;
    while ($i < scalar(@chars_r)) {

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

	($i, $j, $offset, $miss) = &alignment(\@chars_r, \@chars_h, $i, $j, $offset, $property);

	last if ($miss > 0);
    }

    # アライメント失敗
    if ($miss > 0) {
	return (-1, -1, 0);
    } else {
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

	return ($offset, $length, 1);
    }
}


# アライメントをとる関数
sub alignment {
    my ($chars_r, $chars_h, $r, $h, $offset, $property) = @_;

    my $ch_r = $chars_r->[$r];
    my $ch_h = &normalized($chars_h->[$h]);

    print "r:[$ch_r] cmp h:[$ch_h] off=$offset\n" if ($opt{verbose});

    # マッチ
    if ($ch_r eq $ch_h) {
	if ($offset < 0) {
	    $offset = $property->[0]{offset};
	}
	$r++;
	$h++;
    }
    # HTML側が空文字の時はスキップ
    elsif ($ch_h eq '') {
	$h++;
    }
    # HTML側が空白の時はスキップ
    elsif ($ch_h eq '　') {
	$h++;
    }
    # 標準フォーマット側で文字化けを起こしてる時はスキップ
    elsif ($ch_r eq '?') {
	$r++;
	$h++;
    }
    # 標準フォーマット側で箇条書き処理により挿入された空白はスキップ
    elsif ($ch_r eq '　') {
	$r++;
    }
    # マッチ失敗
    # 適当に一文字ずつずらして、共通する文字を求める
    else {
	my $flag = -1;
	for (my $i = 0 ; $i  < $opt{max_num_of_discardable_chars_for_rawstring}; $i++) {
	    my $next_char_r = $chars_r->[$i + $r + 1];
	    for (my $j = 0; $j < $opt{max_num_of_discardable_chars_for_html}; $j++) {
		my $next_char_h = &normalized($chars_h->[$j + $h + 1]);

		print "r:[$next_char_r] cmp h:[$next_char_h] off=$offset miss\n" if ($opt{verbose});

		# ズレの吸収
		if ($next_char_r eq $next_char_h) {
		    $r += ($i + 2);
		    $h += ($j + 2);
		    $flag = 1;
		    last;
		}
	    }
	    last if ($flag > 0);

	    return (-1, -1, $offset, 1) if ($flag < 0);
	}
    }

    return ($r, $h, $offset, -1);
}


# HTML文書側の文字に対して標準フォーマット生成時の変換処理を適用
sub normalized {
    my ($ch) = @_;

    # 制御コードを空白に変換
    $ch = '　' if ($ch =~ /[\x00-\x1f\x7f-\x9f]/);

    # 半角文字を全角に変換
    $ch = Unicode::Japanese->new($ch)->h2z->getu();

    # `ー'は汎化
    $ch =~ s/(?:ー|―|−|─|━|‐)/ー/;

    return $ch;
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
