#!/usr/bin/env perl

# Add the Juman/KNP result

# Input : XML (utf8)
# Output: XML (utf8)

# Usage: zcat IPSJ-TOM4815001.xml.gz | perl -I ../perl -I ~/ipsj/SynGraph/perl  ./add-knp-result.perl -knp -syndbdir ~/ipsj/SynGraph/syndb/x86_64 -antonymy -sentence_length_max 130 -all -syndb_on_memory -usemodule

# $Id$

use XML::LibXML;
use Encode qw(decode);
use encoding 'utf8';
binmode STDERR, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
use Getopt::Long;
use Juman;
use KNP;
use strict;
use AddKNPResult;
use HTML::Entities;
use Error qw(:try);



my (%opt);
GetOptions(\%opt,
	   'jmn',
	   'knp',
	   'case',
	   'anaphora',
	   'syngraph',
	   'conll',
	   'help',
	   'usemodule',
	   'all',
	   'syndbdir=s',
	   'hyponymy',
	   'antonymy',
	   'hypocut=i',
	   'sentence_length_max=i',
	   'jmncmd=s',
	   'knpcmd=s',
	   'jmnrc=s',
	   'knprc=s',
	   'syndb_on_memory',
	   'recycle_knp',
	   'remove_annotation',
	   'no_regist_adjective_stem',
	   'title',
	   'outlink',
	   'inlink',
	   'keywords',
	   'description',
	   'sentence',
	   'timeout=s',
	   'th_of_knp_use=s',
	   'use_knpresult_cache',
	   'knpresult_keymap=s',
	   'blocktype=s',
	   'debug');

if (!$opt{title} && !$opt{outlink} && !$opt{inlink} && !$opt{keywords} && !$opt{description} && !$opt{sentence}) {
    $opt{title} = 1;
    $opt{outlink} = 1;
    $opt{inlink} = 1;
    $opt{keywords} = 1;
    $opt{description} = 1;
    $opt{sentence} = 1;
}

# 処理全体の timeout 時間
$opt{timeout} = 60 unless ($opt{timeout});
# th_of_knp_use文ごとに KNP を new する
$opt{th_of_knp_use} = 100 unless ($opt{th_of_knp_use});

# SynGraphの設定
if ($opt{usemodule} && $opt{syngraph}) {
    require SynGraph;

    # SynGraphのオプション
    my ($regnode_option, $syngraph_option);

    if (!$opt{syndbdir}) {
	print STDERR "Please specify 'syndbdir'!\n";
	exit;
    }

    # option
    $regnode_option->{relation} = ($opt{hyponymy}) ? 1 : 0;
    $regnode_option->{antonym} = ($opt{antonymy}) ? 1 : 0;
    $regnode_option->{hypocut_attachnode} = $opt{hypocut} if $opt{hypocut};

    # 準内容語を除いたものもノードに登録するオプション(ネットワーク化 -> ネットワーク, 深み -> 深い)
    $syngraph_option = {
	regist_exclude_semi_contentword => 1,
	no_regist_adjective_stem => $opt{no_regist_adjective_stem}
    };

    $opt{regnode_option} = $regnode_option;
    $opt{syngraph_option} = $syngraph_option;

    $syngraph_option->{db_on_memory} = 1 if $opt{syndb_on_memory};
}


my $addknpresult = new AddKNPResult(\%opt);

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

# \n(\x0a) 以外のコントロールコードは削除する
$buf =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;

my $parser = new XML::LibXML;
my $doc = $parser->parse_string($buf);

if ($opt{usemodule}) {
    try {
	# タイムアウトの設定
	local $SIG{ALRM} = sub {die sprintf ("Time out occured! (time=%d [sec]\n)", $opt{timeout})};
	alarm $opt{timeout};

	$addknpresult->AddKnpResult($doc, 'Title') if ($opt{title});
	$addknpresult->AddKnpResult($doc, 'OutLink') if ($opt{outlink});
	$addknpresult->AddKnpResult($doc, 'InLink') if ($opt{inlink});
	$addknpresult->AddKnpResult($doc, 'Keywords') if ($opt{keywords});
	$addknpresult->AddKnpResult($doc, 'Description') if ($opt{description});
	$addknpresult->AddKnpResult($doc, 'S') if ($opt{sentence});

	# 時間内に終了すればタイムアウトの設定を解除
	alarm 0;
    } catch Error with {
	my $err = shift;
	my $file = $err->{-file};
	my $line = $err->{-line};
	my $text = $err->{-text};
	printf STDERR (qq([WARNING] %s (line: %d ad %s)\n), $text, $line, $file);
	exit;
    };
}
# 解析結果を読み込む
else {
    my $inputfile = $ARGV[0];
    $addknpresult->ReadResult($doc, $inputfile);
}

# XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
my $string = $doc->toString();

print utf8::is_utf8($string) ? $string : decode($doc->actualEncoding(), $string);
