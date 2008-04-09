#!/usr/bin/env perl

# Add the Juman/KNP result

# Input : XML (utf8)
# Output: XML (utf8)

# $Id$

use XML::LibXML;
use Encode qw(decode);
use encoding 'utf8';
binmode STDERR, ':encoding(utf8)';
use Getopt::Long;
use Juman;
use KNP;
use strict;
use AddKNPResult;

my (%opt);
GetOptions(\%opt, 'jmn', 'knp', 'syngraph', 'help', 'usemodule', 'all', 'replace', 'syndbdir=s', 'hyponymy', 'antonymy', 'hypocut=i', 'sentence_length_max=i', 'debug');

my ($regnode_option, $syngraph_option);
if ($opt{syngraph}) {
    require SynGraph;

    if (!$opt{syndbdir}) {
	print STDERR "Please specify 'syndbdir'!\n";
	exit;
    }

    # option
    $regnode_option->{relation} = ($opt{hyponymy}) ? 1 : 0;
    $regnode_option->{antonym} = ($opt{antonymy}) ? 1 : 0;
    $regnode_option->{hypocut_attachnode} = $opt{hypocut} if $opt{hypocut};
    
    # 準内容語を除いたものもノードに登録するオプション(ネットワーク化 -> ネットワーク, 深み -> 深い)
    $syngraph_option = { regist_exclude_semi_contentword => 1 };

    $opt{regnode_option} = $regnode_option;
    $opt{syngraph_option} = $syngraph_option;
}

my ($juman, $knp, $syngraph);
$juman = new Juman if $opt{jmn};
$knp = new KNP (-Option => '-tab -dpnd') if $opt{knp} || $opt{syngraph};
$syngraph = new SynGraph($opt{syndbdir}) if $opt{syngraph};

my $addknpresult = new AddKNPResult($juman, $knp, $syngraph, \%opt);

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

my $parser = new XML::LibXML;
my $doc = $parser->parse_string($buf);

if ($opt{usemodule}) {
    $addknpresult->AddKnpResult($doc, 'Title');
    $addknpresult->AddKnpResult($doc, 'S');
}
# 解析結果を読み込む
else {
    my $inputfile = $ARGV[0];
    $addknpresult->ReadResult($doc, $inputfile);
}

# XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
my $string = $doc->toString();

print utf8::is_utf8($string) ? $string : decode($doc->actualEncoding(), $string);
