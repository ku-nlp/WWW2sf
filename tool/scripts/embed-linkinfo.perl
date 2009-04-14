#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
use Encode;
use Getopt::Long;
use POSIX qw(strftime);
use CDB_File;
use File::Basename;
use XML::LibXML;
use XML::Writer;
use CDB_Reader;
use Error qw(:try);
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

# binmode(STDOUT, ':encoding(euc-jp)');

my (%opt);
GetOptions(\%opt, 'in=s', 'out=s', 'url2did=s', 'indir=s', 'outdir=s', 'z', 'compress', 'verbose', 'help', 'remove_old_link', 'inlink_sf');

if (!defined $opt{in}) {
    print STDERR "Please set -in option.\n";
    exit;
}

if (!$opt{out} && !$opt{url2did} && !$opt{inlink_sf}) {
    print STDERR "Please set -out or -url2did option.\n";
    exit;
}


mkdir $opt{outdir} unless (-e $opt{outdir});



if ($opt{inlink_sf}) {
    &main4make_inlink_sf();
}
elsif ($opt{url2did}) {
    &main4embed_inlinks_and_dids();
} else {
    &main();
}

# InLinksだけからなる標準フォーマットを作成する関数（リンクDB更新に伴うアンカーインデックス更新用）
sub main4make_inlink_sf {
    my $VERSION;
    my $version_file = sprintf("%s/../data/VERSION", dirname($0));
    if (-e $version_file) {
	open F, "< $version_file" or die $!;
	$VERSION = <F>;
	chomp $VERSION;
	close F;
    } else {
	print STDERR "[WARNING] $version_file was not found.\n";
    }

    my $incdb = new CDB_Reader($opt{in});

    foreach my $cdb (@{$incdb->getCDBs()}) {
	while (my ($fid, $inlinks) = each (%$cdb)) {
	    my $inlinkNode = &create_inlink_node(decode('utf8', $inlinks));


	    my $formatTime = strftime("%Y-%m-%d %T %Z", localtime(time));
	    my $xmldat = qq(<?xml version="1.0" encoding="utf-8"?>\n);
	    $xmldat .= sprintf (qq(<StandardFormat FormatTime="%s" FormatProgVersion="%s">\n), $formatTime, $VERSION);
	    $xmldat .= "<Header>\n";
	    $xmldat .= $inlinkNode;
	    $xmldat .= "</Header>\n";
	    $xmldat .= "<Text/>\n";
	    $xmldat .= "</StandardFormat>\n";

	    my $file = sprintf ("%09d.xml", $fid);
	    # 出力
	    if ($opt{compress}) {
		$file .= '.gz';
		open(WRITER, "| gzip > $opt{outdir}/$file");
	    } else {
		open(WRITER, "> $opt{outdir}/$file");
	    }
 	    binmode(WRITER, ':utf8');
 	    print WRITER $xmldat;
 	    close(WRITER);
	}
    }
}

# InLinks, 文書IDの埋め込み
sub main4embed_inlinks_and_dids {
    my $incdb = new CDB_Reader($opt{in});
    my $url2did = new CDB_Reader($opt{url2did});

    opendir(DIR, $opt{indir}) or die;
    foreach my $file (sort {$a cmp $b} readdir(DIR)) {
	next unless ($file =~ /xml/);

	# インリンク情報の読み込み
	my ($fid) = ($file =~ /(\d+).xml/);
	my $inlinks = $incdb->get($fid);


	# 標準フォーマットデータの読み込み
	if ($opt{z}) {
	    open(READER, "zcat $opt{indir}/$file |");
	} else {
	    open(READER, "$opt{indir}/$file");
	}
	binmode(READER, ':utf8');

	my $buf;
	my $outsideOfLink = 1;
	while (<READER>) {
 	    if ($opt{remove_old_link}) {
 		$outsideOfLink = 0 if ($_ =~ /<InLinks>/ || $_ =~ /<OutLinks>/);

 		$buf .= $_ if ($outsideOfLink);

 		$outsideOfLink = 1 if ($_ =~ /<\/InLinks>/ || $_ =~ /<\/OutLinks>/);
 	    } else {
		$buf .= $_;
	    }
	}
	close(READER);


	# インリンクがあれば埋め込む
	if (defined($inlinks)) {
	    my $inlinkNode = &create_inlink_node(decode('utf8', $inlinks));

	    if ($buf =~ /<\/Header>/) {
		$buf =~ s/<\/Header>/$inlinkNode<\/Header>/;
	    } elsif ($buf =~ /<Header\/>/) {
		$buf =~ s/<Header\/>/<Header>\n$inlinkNode<\/Header>/;
	    }
	}


	# OutLinkに文書IDを埋め込む
	my $parser = new XML::LibXML;
	my $dom = $parser->parse_string($buf);

	foreach my $outlink ($dom->getElementsByTagName('OutLink')) { # for each OutLink
	    foreach my $docid ($outlink->getElementsByTagName('DocID')) { # for each DocID
		my $url = $docid->getAttribute('Url');
		$url =~ s!^http://!!;
		my $did = $url2did->get($url);
		$docid->appendChild($dom->createTextNode($did)) if ($did);
	    }
	}


	# 出力
	my $string = $dom->toString();
	$string = decode($dom->actualEncoding(), $string) unless (utf8::is_utf8($string));

	if ($opt{compress}) {
	    $file .= '.gz' unless ($file =~ /gz$/);
	    open(WRITER, "| gzip > $opt{outdir}/$file");
	} else {
	    $file =~ s/.gz$// if ($file =~ /gz$/);
	    open(WRITER, "> $opt{outdir}/$file");
	}
	binmode(WRITER, ':utf8');
	print WRITER $string;
	close(WRITER);
    }
    closedir(DIR);
}

sub main {

    my $incdb = new CDB_Reader($opt{in});
    my $outcdb = new CDB_Reader($opt{out});

    opendir(DIR, $opt{indir}) or die;
    foreach my $file (sort {$a cmp $b} readdir(DIR)) {
	next unless ($file =~ /xml/);

	# リンク情報の読み込み
	my ($fid) = ($file =~ /(\d+).xml/);
	my $inlinks = $incdb->get($fid);
	my $outlinks = $outcdb->get($fid);



	# 標準フォーマットデータの読み込み
	if ($opt{z}) {
	    open(READER, "zcat $opt{indir}/$file |");
	} else {
	    open(READER, "$opt{indir}/$file");
	}
	binmode(READER, ':utf8');

	my $buf;
	my $outsideOfLink = 1;
	while (<READER>) {
	    if ($opt{remove_old_link}) {
		$outsideOfLink = 0 if ($_ =~ /<InLinks>/ || $_ =~ /<OutLinks>/);

		$buf .= $_ if ($outsideOfLink);

		$outsideOfLink = 1 if ($_ =~ /<\/InLinks>/ || $_ =~ /<\/OutLinks>/);
	    } else {
		$buf .= $_;
	    }
	}
	close(READER);



	# インリンク・アウトリンクのどちらかがあれば埋め込む
	if (defined($inlinks) || defined($outlinks)) {
	    my $inlink_node = &create_inlink_node(decode('utf8', $inlinks));
	    my $outlink_node = &create_outlink_node(decode('utf8', $outlinks));

	    if ($buf =~ /<\/Header>/) {
		$buf =~ s/( )*<\/Header>/$outlink_node$inlink_node  <\/Header>/;
	    }
	    elsif ($buf =~ /<Header\/>/) {
		$buf =~ s/<Header\/>/<Header>\n$outlink_node$inlink_node  <\/Header>/;
	    }
	}



	# 出力
	if ($opt{compress}) {
	    $file .= '.gz' unless ($file =~ /gz$/);
	    open(WRITER, "| gzip > $opt{outdir}/$file");
	} else {
	    $file =~ s/.gz$// if ($file =~ /gz$/);
	    open(WRITER, "> $opt{outdir}/$file");
	}
	binmode(WRITER, ':utf8');
	print WRITER $buf;
	close(WRITER);
    }
    closedir(DIR);
}


sub create_inlink_node {
    my ($inlink) = @_;

    my $inbuff = &get_inlinks($inlink);

    my $xmldat = '';
    my $writer = new XML::Writer(OUTPUT => \$xmldat, DATA_MODE => 'true', DATA_INDENT => 2);
    $writer->xmlDecl('utf-8');

    $writer->startTag('InLinks');
    foreach my $rawstring (keys %$inbuff) {
	$writer->startTag('InLink');

	my $properRawstring = 1;
	$writer->startTag('RawString');
	try {
	    $writer->characters($rawstring);
	} catch Error with {
	    my $err = shift;
	    printf STDERR ("Exception at line %d in %s (%s)\n"), $err->{-line}, $err->{-file}, $err->{-text};
	    $properRawstring = 0;
	};
	$writer->endTag('RawString');

	# RawString要素が適切に書き込めなかった場合は、DocIDsは書き出さない
	if ($properRawstring) {
	    $writer->startTag('DocIDs');
	    foreach my $a (@{$inbuff->{$rawstring}{inlinks}}) {
		$writer->startTag('DocID', Url => $a->{from_url});
		$writer->characters($a->{from_id});
		$writer->endTag('DocID');
	    }
	    $writer->endTag('DocIDs');
	}

	$writer->endTag('InLink');
    }
    $writer->endTag('InLinks');
    $writer->end();


    # 自動的に付与されるxml宣言を削除
    $xmldat =~ s/<\?xml version="1.0" encoding="utf-8"\?>\n\n//;

    return $xmldat;
}


sub create_outlink_node {
    my ($outlink) = @_;

    my $outbuff = &get_outlinks($outlink);

    my $str = '';
    foreach my $rawstring (keys %$outbuff) {
	$str .= "      <OutLink>\n";
	$str .= "        <RawString>$rawstring</RawString>\n";
	# $str .= qq(<Annotation Scheme="KNP"><![CDATA[$outbuff->{$rawstring}{knpresult}]]></Annotation>\n);
	$str .= "        <DocIDs>\n";
	foreach my $a (@{$outbuff->{$rawstring}{outlinks}}) {
	    $str .= qq(          <DocID Url="$a->{to_url}">$a->{to_id}</DocID>\n);
	}
	$str .= "        </DocIDs>\n";
	$str .= "      </OutLink>\n";
    }

    if ($str ne '') {
	$str  = "    <OutLinks>\n$str";
	$str .= "    </OutLinks>\n";
    }

    return $str;
}

sub get_inlinks {
    my ($inlinks) = @_;

    my %inbuff = ();
    foreach my $result (split(/\t\t/, $inlinks)) {
	my @items = split(/\t/, $result);

	my $rawstring = $items[6];
	unless (exists($inbuff{$rawstring})) {
	    my $knpresult = $items[7];
	    # $inbuff{$rawstring}->{knpresult} = $knpresult;
	    $inbuff{$rawstring}->{inlinks} = [];
	}
	push(@{$inbuff{$rawstring}->{inlinks}}, {from_id => $items[0], from_url => $items[1]});
    }

    return (\%inbuff);
}

sub get_outlinks {
    my ($outlinks) = @_;

    my %outbuff = ();
    foreach my $r (split(/\t\t/, $outlinks)) {
	my @items = split(/\t/, $r);

	my $rawstring = $items[6];
	print "[$rawstring]\n" if ($opt{verbose});

	unless (exists($outbuff{$rawstring})) {
	    my $knpresult = $items[7];
	    # $outbuff{$rawstring}->{knpresult} = $knpresult;
	    $outbuff{$rawstring}->{outlinks} = [];
	}
	push(@{$outbuff{$rawstring}->{outlinks}}, {to_id => $items[2], to_url => $items[3]});
    }

    return \%outbuff;
}
