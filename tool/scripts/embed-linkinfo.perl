#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
use Encode;
use Getopt::Long;
use CDB_File;
use XML::LibXML;
use CDB_Reader;
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

# binmode(STDOUT, ':encoding(euc-jp)');


my (%opt);
GetOptions(\%opt, 'in=s', 'out=s', 'indir=s', 'outdir=s', 'z', 'compress', 'verbose', 'help');

if (!defined $opt{in}) {
    print STDERR "Please set -in option.\n";
    exit;
}

if (!defined $opt{out}) {
    print STDERR "Please set -out option.\n";
    exit;
}


mkdir $opt{outdir} unless (-e $opt{outdir});

&main();

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
	while (<READER>) {
	    $buf .= $_;
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
    my $str = '';
    foreach my $rawstring (keys %$inbuff) {
	$str .= "      <InLink>\n";
	$str .= "        <RawString>$rawstring</RawString>\n";
	# $str .= qq(<Annotation Scheme="KNP"><![CDATA[$inbuff->{$rawstring}{knpresult}]]></Annotation>\n);
	$str .= "        <DocIDs>\n";
	foreach my $a (@{$inbuff->{$rawstring}{inlinks}}) {
	    $str .= qq(          <DocID Url="$a->{from_url}">$a->{from_id}</DocID>\n);
	}
	$str .= "        </DocIDs>\n";
	$str .= "      </InLink>\n";
    }
    if ($str ne '') {
	$str  = "    <InLinks>\n$str";
	$str .= "    </InLinks>\n";
    }

    return $str;
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
