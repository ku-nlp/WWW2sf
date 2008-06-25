#!/usr/bin/env perl

# $Id$

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
use Error qw(:try);



my (%opt);
GetOptions(\%opt, 'jmn', 'knp', 'syngraph', 'help', 'all', 'replace', 'syndbdir=s', 'hyponymy', 'antonymy', 'hypocut=i', 'sentence_length_max=i', '-indir=s', '-outdir=s', 'jmncmd=s', 'knpcmd=s', 'jmnrc=s', 'knprc=s', 'syndb_on_memory', 'recycle_knp', 'debug');

if (!$opt{indir} || !$opt{outdir}) {
    print STDERR "Please specify '-indir and -outdir'!\n";
    exit;
}

$opt{usemodule} = 1;

$opt{jmncmd} = '/share09/home/skeiji/local/080512/bin/juman' unless ($opt{jmncmd});
$opt{jmnrc} = '/share09/home/skeiji/local/080512/etc/jumanrc' unless ($opt{jmnrc});
$opt{knpcmd} = '/share09/home/skeiji/local/080512/bin/knp' unless ($opt{knpcmd});
$opt{knprc} = '/share09/home/skeiji/local/080512/etc/knprc' unless ($opt{knprc});


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
$juman = new Juman (-Command => $opt{jmncmd},
		    -Rcfile => $opt{jmnrc},
		    -Option => '-i \#') if $opt{jmn};
$knp = new KNP (-Command => $opt{knpcmd},
		-Rcfile => $opt{knprc},
		-JumanCommand => $opt{jmncmd},
		-JumanRcfile => $opt{jmnrc},
		-JumanOption => '-i \#',
		-Option => '-tab -dpnd -postprocess') if $opt{knp} || $opt{syngraph};

my $syngraph_option;
$syngraph_option->{db_on_memory} = 1 if $opt{syndb_on_memory};
$syngraph = new SynGraph($opt{syndbdir}, undef, $syngraph_option) if $opt{syngraph};

my $addknpresult = new AddKNPResult($juman, $knp, $syngraph, \%opt);

for my $file (glob ("$opt{indir}/*")) {
    if ($file =~ /\.gz$/) {
	open F, "zcat $file |" or die;
    } else {
	open F, $file or die;
    }
    binmode(F, ':utf8');

    print STDERR $file, "\n" if ($opt{debug});

    my ($buf);
    while (<F>) {
	$buf .= $_;
    }
    $buf =~ s/\&/\&amp;/g;

    close F;

    my $parser = new XML::LibXML;
    my $doc;
    try {
	$doc = $parser->parse_string($buf);
    } catch Error with {
	    my $err = shift;
	    print STDERR "Exception at line ",$err->{-line}," in ",$err->{-file}," at $file.\n";
    };
    next unless ($doc);

    $addknpresult->AddKnpResult($doc, 'Title');
    $addknpresult->AddKnpResult($doc, 'OutLink');
    $addknpresult->AddKnpResult($doc, 'InLink');
    $addknpresult->AddKnpResult($doc, 'Keywords');
    $addknpresult->AddKnpResult($doc, 'Description');
    $addknpresult->AddKnpResult($doc, 'S');

    my $string = $doc->toString();

    # XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
    unless (utf8::is_utf8($string)) {
	$string = decode($doc->actualEncoding(), $string);
    }
    $string =~ s/&amp;/&/g;


    my $outfilename = $opt{outdir} . '/' . basename($file);
    $outfilename =~ s/\.gz$//;
    open F, '>:encoding(utf8)', $outfilename or die;
    print F $string;
    close F;
}
