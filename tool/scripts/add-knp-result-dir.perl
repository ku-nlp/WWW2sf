#!/usr/bin/env perl

# $Id$

use XML::LibXML;
use Encode qw(decode);
use encoding 'utf8';
binmode STDERR, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
use Getopt::Long;
use File::Basename;
use Juman;
use KNP;
use strict;
use AddKNPResult;
use Error qw(:try);
use HTML::Entities;
use Data::Dumper;
use Error qw(:try);



my (%opt);
GetOptions(\%opt, 
	   'jmn',
	   'knp',
	   'syngraph',
	   'help',
	   'all',
	   'replace',
	   'syndbdir=s',
	   'hyponymy',
	   'antonymy',
	   'hypocut=i',
	   'sentence_length_max=i',
	   'indir=s',
	   'outdir=s',
	   'jmncmd=s',
	   'knpcmd=s',
	   'jmnrc=s',
	   'knprc=s',
	   'syndb_on_memory',
	   'recycle_knp',
	   'remove_annotation',
	   'no_regist_adjective_stem',
	   'logfile=s',
	   'nologfile',
	   'title',
	   'outlink',
	   'inlink',
	   'keywords',
	   'description',
	   'sentence',
	   'timeout=s',
	   'debug');

if (!$opt{indir} || !$opt{outdir}) {
    print STDERR "Please specify '-indir and -outdir'!\n";
    exit;
}

$opt{timeout} = 60 unless ($opt{timeout});

$opt{usemodule} = 1;

$opt{jmncmd} = '/share09/home/skeiji/local/080512/bin/juman' unless ($opt{jmncmd});
$opt{jmnrc} = '/share09/home/skeiji/local/080512/etc/jumanrc' unless ($opt{jmnrc});
$opt{knpcmd} = '/share09/home/skeiji/local/080512/bin/knp' unless ($opt{knpcmd});
$opt{knprc} = '/share09/home/skeiji/local/080512/etc/knprc' unless ($opt{knprc});

if (!$opt{title} && !$opt{outlink} && !$opt{inlink} && !$opt{keywords} && !$opt{description} && !$opt{sentence}) {
    $opt{title} = 1;
    $opt{outlink} = 1;
    $opt{inlink} = 1;
    $opt{keywords} = 1;
    $opt{description} = 1;
    $opt{sentence} = 1;
}

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
    $syngraph_option = {
	regist_exclude_semi_contentword => 1,
	no_regist_adjective_stem => $opt{no_regist_adjective_stem}
    };

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

$syngraph_option->{db_on_memory} = 1 if $opt{syndb_on_memory};
$syngraph = new SynGraph($opt{syndbdir}, undef, $syngraph_option) if $opt{syngraph};

my $addknpresult = new AddKNPResult($juman, $knp, $syngraph, \%opt);

# -logfile が指定されていない場合は終了
unless (defined $opt{logfile} || $opt{nologfile}) {
    print STDERR "Please set -logfile option !\n";
    exit;
}

my %alreadyAnalyzedFiles = ();
if (-f $opt{logfile}) {
    open(LOG, $opt{logfile}) or die $!;
    while (<LOG>) {
	chomp;

	my ($file, $status) = split(/ /, $_);
	if ($status =~ /(success|error|timeout)/) {
	    $alreadyAnalyzedFiles{$file} = $status;
	}
	# ログのフォーマットにマッチしない = エラーにより終了
	else {
	    $alreadyAnalyzedFiles{$file} = "error";
	}
    }
    close(LOG);
}

# ログフォーマットを整形して出力
unless ($opt{nologfile}) {
    open(LOG, "> $opt{logfile}") or die $!;
    foreach my $file (sort {$a cmp $b} keys %alreadyAnalyzedFiles) {
	my $status = $alreadyAnalyzedFiles{$file};
	print LOG "$file $status\n";
    }
    close(LOG);
}

open(LOG, ">> $opt{logfile}") or die $! unless $opt{nologfile};
for my $file (glob ("$opt{indir}/*")) {
    # 既に解析済みのファイルはスキップ
    next if (!$opt{nologfile} && exists $alreadyAnalyzedFiles{$file});

    syswrite LOG, "$file " unless $opt{nologfile};
    if ($file =~ /\.gz$/) {
	unless (open F, "zcat $file |") {
	    print STDERR "Can't open file: $file\n";
	}
    } else {
	unless (open F, $file) {
	    print STDERR "Can't open file: $file\n";
	}
    }
    binmode(F, ':utf8');

    print STDERR $file, "\n" if ($opt{debug});

    my ($buf);
    while (<F>) {
	my $line = $_;
	if ($line =~ /DocID /) {
	    my ($url, $did) = ($line =~ /Url=\"(.+)\">(\d+)<\/DocID>/);

	    # エンティティの変換
	    $url = &encode_entities($url);

	    $line = sprintf qq(          <DocID Url="%s">%09d</DocID>\n), $url, $did;
	}

	$buf .= $line;
    }
    close F;

    # \n(\x0a) 以外のコントロールコードは削除する
    $buf =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;

    my $parser = new XML::LibXML;
    my $doc;
    try {
	$doc = $parser->parse_string($buf);
    } catch Error with {
	my $err = shift;
	print STDERR "Exception at line ",$err->{-line}," in ",$err->{-file}," at $file.\n";
    };
    next unless ($doc);



    try {
	# タイムアウトの設定
	local $SIG{ALRM} = sub {die "timeout"};
	alarm $opt{timeout};

	$addknpresult->AddKnpResult($doc, 'Title') if ($opt{title});
 	$addknpresult->AddKnpResult($doc, 'OutLink') if ($opt{outlink});
 	$addknpresult->AddKnpResult($doc, 'InLink') if ($opt{inlink});
 	$addknpresult->AddKnpResult($doc, 'Keywords') if ($opt{keywords});
 	$addknpresult->AddKnpResult($doc, 'Description') if ($opt{description});
 	$addknpresult->AddKnpResult($doc, 'S') if ($opt{sentence});

	# 時間内に終了すればタイムアウトの設定を解除
	alarm 0;


	# 解析結果が埋め込まれたXMLデータを取得
	my $string = $doc->toString();

	# XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
	unless (utf8::is_utf8($string)) {
	    $string = decode($doc->actualEncoding(), $string);
	}


	my $outfilename = $opt{outdir} . '/' . basename($file);
	$outfilename =~ s/\.gz$//;
	open F, '>:encoding(utf8)', $outfilename or die;
	print F $string;
	close F;

	syswrite LOG, "success\n" unless $opt{nologfile};
	print STDERR "$file is success\n" if ($opt{debug});
    } catch Error with {
	syswrite LOG, "timeout\n";
	printf STDERR (qq([WARNING] Time out occured! (time=%d [sec], file=%s)\n), $opt{timeout}, $file);
    };
}

print LOG "finish.\n" unless $opt{nologfile};
close (LOG) unless $opt{nologfile};
