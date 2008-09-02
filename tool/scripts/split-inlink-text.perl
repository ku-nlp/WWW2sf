#!/usr/bin/env/perl

# $Id$

# インリンクしている文書IDに従ってソートされたテキストデータを、文書IDの上位5桁に従って区切る

use strict;
use utf8;
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'compress', 'file=s', 'outdir=s');

my $file = $opt{file};

if ($file =~ /gz$/) {
    open(READER, "zcat $file |");
} else {
    open(READER, $file);
}
binmode(READER, ':utf8');

my $N = 2;
my $prev_key = -1;
while (<READER>) {
    chop;
    my @data = split(/ /, $_);

    my $key = sprintf ("%05d", $data[$N] / 10000);

    if ($key ne $prev_key) {
	close(WRITER) if ($prev_key > -1);

	my $outf = "$opt{outdir}/u$key.inlinks";
	if ($opt{compress}) {
	    open(WRITER, "> $outf") or die $!;
	} else {
	    open(WRITER, "| gzip > $outf.gz") or die $!;
	}
	binmode(WRITER, ':utf8');
    }
    print WRITER $_ . "\n";
    $prev_key = $key;
}
close(READER);
close(WRITER);
