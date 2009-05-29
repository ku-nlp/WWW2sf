#!/usr/bin/env perl

# Add the Juman/KNP result

# Input : XML (utf8)
# Output: XML (utf8)

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
	   'syngraph',
	   'help',
	   'usemodule',
	   'all',
	   'replace',
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
	   'no_regist_adjective_stem',
	   'title',
	   'outlink',
	   'inlink',
	   'keywords',
	   'description',
	   'sentence',
	   'timeout=s',
	   'debug');

if (!$opt{title} && !$opt{outlink} && !$opt{inlink} && !$opt{keywords} && !$opt{description} && !$opt{sentence}) {
    $opt{title} = 1;
    $opt{outlink} = 1;
    $opt{inlink} = 1;
    $opt{keywords} = 1;
    $opt{description} = 1;
    $opt{sentence} = 1;
}

$opt{timeout} = 60 unless ($opt{timeout});

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
    $syngraph_option = {
	regist_exclude_semi_contentword => 1,
	no_regist_adjective_stem => $opt{no_regist_adjective_stem}
    };

    $opt{regnode_option} = $regnode_option;
    $opt{syngraph_option} = $syngraph_option;

    $syngraph_option->{db_on_memory} = 1 if $opt{syndb_on_memory};
}

my ($juman, $knp, $knp_w_case, $syngraph);
$juman = new Juman (-Command => $opt{jmncmd},
		    -Rcfile => $opt{jmnrc},
		    -Option => '-i \#') if $opt{jmn};

$knp = new KNP (-Command => $opt{knpcmd},
		-Rcfile => $opt{knprc},
		-JumanCommand => $opt{jmncmd},
		-JumanRcfile => $opt{jmnrc},
		-JumanOption => '-i \#',
		-Option => '-tab -dpnd -postprocess') if $opt{knp} || $opt{syngraph};

$knp_w_case = new KNP (-Command => $opt{knpcmd},
		       -Rcfile => $opt{knprc},
		       -JumanCommand => $opt{jmncmd},
		       -JumanRcfile => $opt{jmnrc},
		       -JumanOption => '-i \#',
		       -Option => '-tab -postprocess') if (($opt{knp} || $opt{syngraph}) && $opt{case});

$syngraph = new SynGraph($opt{syndbdir}, undef, $syngraph_option) if $opt{syngraph};

my $addknpresult = new AddKNPResult($juman, $knp, $knp_w_case, $syngraph, \%opt);

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
