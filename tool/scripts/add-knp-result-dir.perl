#!/usr/bin/env perl

# $Id:

use XML::LibXML;
use Encode qw(decode);
use encoding 'utf8';
binmode STDERR, ':encoding(utf8)';
use Getopt::Long;
use File::Basename;
use Juman;
use KNP;
use strict;
use AddKNPResult;

my (%opt);
GetOptions(\%opt, 'jmn', 'knp', 'syngraph', 'help', 'all', 'replace', 'syndbdir=s', 'hyponymy', 'antonymy', 'hypocut=i', 'sentence_length_max=i', '-indir=s', '-outdir=s', 'debug');

if (!$opt{indir} || !$opt{outdir}) {
    print STDERR "Please specify '-indir and -outdir'!\n";
    exit;
}

$opt{usemodule} = 1;

if (! -d $opt{outdir}) {
    mkdir $opt{outdir};
}

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

for my $file (glob ("$opt{indir}/*")) {
    open F, '<:encoding(utf8)', $file or die;

    print STDERR $file, "\n";

    my ($buf);
    while (<F>) {
	$buf .= $_;
    }

    close F;

    my $parser = new XML::LibXML;
    my $doc = $parser->parse_string($buf);

    $addknpresult->AddKnpResult($doc, 'Title');
    $addknpresult->AddKnpResult($doc, 'S');

    my $string = $doc->toString();

    # XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
    unless (utf8::is_utf8($string)) {
	$string = decode($doc->actualEncoding(), $string);
    }

    my $outfilename = $opt{outdir} . '/' . basename($file);
    open F, '>:encoding(utf8)', $outfilename or die;
    print F $string;
    close F;
}
