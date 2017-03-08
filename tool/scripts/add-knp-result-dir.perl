#!/usr/bin/env perl

# $Id$

use XML::LibXML;
use Encode qw(decode);
use utf8;
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';
use Getopt::Long;
use File::Basename;
use Juman;
use KNP;
use strict;
use AddKNPResult;
use Error qw(:try);
use HTML::Entities;
use Data::Dumper;

select(STDERR);
$| = 1; # auto-flush STDERR
select(STDOUT);

my $PRINT_PROGRESS_INTERVAL = 10; # -print_progress時に、何文書ごとに*を表示するか

my (%opt);
GetOptions(\%opt,
	   'jmn',
	   'knp',
	   'case',
	   'anaphora',
	   'assignf',
	   'syngraph',
	   'english',
	   'enju',
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
	   'use_jmnpp',
	   'english_parser_dir=s',
	   'javacmd=s',
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
	   'th_of_knp_use=s',
	   'wikipedia_entry_db=s',
	   'imi_list_db=s',
	   'find_recursive',
	   'embed_result_in_xml',
	   'print_progress',
	   'debug');

if (!$opt{indir} || !$opt{outdir}) {
    print STDERR "Please specify '-indir and -outdir'!\n";
    exit;
}

# 処理全体の timeout 時間
$opt{timeout} = 60 unless ($opt{timeout});
# th_of_knp_use文ごとに KNP を new する
$opt{th_of_knp_use} = 250 unless ($opt{th_of_knp_use});

$opt{usemodule} = 1;

if (!$opt{title} && !$opt{outlink} && !$opt{inlink} && !$opt{keywords} && !$opt{description} && !$opt{sentence}) {
    $opt{title} = 1;
    $opt{outlink} = 1;
    $opt{inlink} = 1;
    $opt{keywords} = 1;
    $opt{keyword} = 1;
    $opt{author} = 1;
    $opt{description} = 1;
    $opt{sentence} = 1;
}

if (! -d $opt{outdir}) {
    mkdir $opt{outdir};
}

my @files = ();
unless ($opt{find_recursive}) {
    for my $file (glob ("$opt{indir}/*")) {
	push (@files, $file);
    }
} else {
    &findFiles(\@files, $opt{indir});
}

# SynGraphの設定
if ($opt{syngraph}) {
    require SynGraph;

    # SynGraphのオプション
    my ($regnode_option, $syngraph_option);

    if (!$opt{syndbdir}) {
	print STDERR "Please specify 'syndbdir'!\n";
	exit;
    }

    # option
    $regnode_option->{no_attach_synnode_in_wikipedia_entry} = 1;
    $regnode_option->{attach_wikipedia_info} = 1 if ($opt{wikipedia_entry_db});
    $regnode_option->{wikipedia_entry_db} = $opt{wikipedia_entry_db} if ($opt{wikipedia_entry_db});
    $regnode_option->{imi_list_db} = $opt{imi_list_db} if ($opt{imi_list_db});

    $regnode_option->{relation} = ($opt{hyponymy}) ? 1 : 0;
    $regnode_option->{relation_recursive} = ($opt{hyponymy}) ? 1 : 0;
    $regnode_option->{antonym} = ($opt{antonymy}) ? 1 : 0;
    $regnode_option->{hypocut_attachnode} = $opt{hypocut} if $opt{hypocut};

    # 準内容語を除いたものもノードに登録するオプション(ネットワーク化 -> ネットワーク, 深み -> 深い)
    $syngraph_option = {
	regist_exclude_semi_contentword => 1,
	no_regist_adjective_stem => $opt{no_regist_adjective_stem},
	db_on_memory => $opt{syndb_on_memory}
    };
    $syngraph_option->{no_attach_synnode_in_wikipedia_entry} = 1;
    $syngraph_option->{attach_wikipedia_info} = 1 if ($opt{wikipedia_entry_db});
    $syngraph_option->{wikipedia_entry_db} = $opt{wikipedia_entry_db} if ($opt{wikipedia_entry_db});

    $opt{regnode_option} = $regnode_option;
    $opt{syngraph_option} = $syngraph_option;
}



my $addknpresult = new AddKNPResult(\%opt);

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
my $count = 1;
foreach my $file (@files) {
    # 既に解析済みのファイルはスキップ
    next if (!$opt{nologfile} && exists $alreadyAnalyzedFiles{$file});

    print STDERR '*' if $opt{print_progress} && !($count % $PRINT_PROGRESS_INTERVAL);
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
	$buf .= $_;
    }
    close F;

    # \n(\x0a) 以外のコントロールコードは削除する
    $buf =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;

    my $parser = new XML::LibXML;
    my $parser = XML::LibXML->new({huge=>1});
    my $doc;
    try {
	$doc = $parser->parse_string($buf);
    } catch Error with {
	my $err = shift;
	printf STDERR ("[SKIP] An exception was detected in %s (file: %s, line: %s, msg; %s)\n", $file, $err->{-file}, $err->{-line}, $err->{-text});
    };
    unless ($doc) {
	&writeFile(undef, $file); # 空ファイル出力
	next;
    }

    try {
	# タイムアウトの設定
	local $SIG{ALRM} = sub {die sprintf ("Time out occured! (time=%d [sec]\n)", $opt{timeout})};
	alarm $opt{timeout};

	$addknpresult->AddKnpResult($doc, 'Title') if ($opt{title});
 	$addknpresult->AddKnpResult($doc, 'OutLink') if ($opt{outlink});
 	$addknpresult->AddKnpResult($doc, 'InLink') if ($opt{inlink});
 	$addknpresult->AddKnpResult($doc, 'Keywords') if ($opt{keywords});
 	$addknpresult->AddKnpResult($doc, 'Keyword') if ($opt{keyword});
 	$addknpresult->AddKnpResult($doc, 'Author') if ($opt{author});
 	$addknpresult->AddKnpResult($doc, 'Description') if ($opt{description});
 	$addknpresult->AddKnpResult($doc, 'S') if ($opt{sentence});

	# 時間内に終了すればタイムアウトの設定を解除
	alarm 0;

	# 結果のXMLを書き込み
	&writeFile($doc, $file);

	syswrite LOG, "success\n" unless $opt{nologfile};
	print STDERR "$file is success\n" if ($opt{debug});
	$count++;
    } catch Error with {
	&writeFile($doc, $file);

	syswrite LOG, "timeout\n";
	my $err = shift;
	my $file = $err->{-file};
	my $line = $err->{-line};
	my $text = $err->{-text};
	printf STDERR (qq([WARNING] %s (line: %d ad %s)\n), $text, $line, $file);
    };
}

print STDERR "\n" if $opt{print_progress};
print LOG "finish.\n" unless $opt{nologfile};
close (LOG) unless $opt{nologfile};

sub writeFile {
    my ($doc, $file) = @_;
    my $string;

    if ($doc) {
	# 解析結果が埋め込まれたXMLデータを取得
	$string = $doc->toString();

	# XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
	unless (utf8::is_utf8($string)) {
	    $string = decode($doc->actualEncoding(), $string);
	}
    }

    my $outfilename = $opt{outdir} . '/' . basename($file);
    if ($outfilename =~ /\.gz$/) {
	open F, '>:encoding(utf8):gzip', $outfilename or die $! . $outfilename;
	binmode (F, ':utf8');
    }
    else {
	open F, '>:encoding(utf8)', $outfilename or die;
    }
    print F $string;
    close F;
}

sub findFiles {
    my ($files, $dir) = @_;

    opendir (D, $dir) or die $!;
    foreach my $file_or_dir (readdir(D)) {
	next if ($file_or_dir eq '.' || $file_or_dir eq '..');

	unless (-d "$dir/$file_or_dir") {
	    push (@$files, "$dir/$file_or_dir");
	} else {
	    &findFiles($files, sprintf ("%s/%s", $dir, $file_or_dir));
	}
    }
    closedir (D);
}
