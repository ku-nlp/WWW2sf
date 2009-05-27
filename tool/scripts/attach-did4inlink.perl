#!/usr/bin/env perl

# $Id$

# h?????.outlinksファイルにinlinkの文書IDを付与する

use strict;
use utf8;
use CDB_Reader;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

my (%opt);
GetOptions(\%opt, 'url2did=s', 'z');

&main();

sub main {
    my $url2did = new CDB_Reader($opt{url2did});

    foreach my $file (@ARGV) {
	if ($opt{z}) {
	    open (FILE, "zcat $file |") or die "$!";
	    binmode (FILE, ':utf8');
	} else {
	    open (FILE, '<:utf8', $file) or die "$!";
	}


	my %buf;
	my $outf = $file;
	$outf =~ s/gz$//;
	$outf .= ".w_inlink_did";

	open (WRITER, '>:utf8', $outf) or die "$!";
	while (<FILE>) {
	    my ($did, $url, $in_url, $anchortext) = split (/\t/, $_);
	    my $in_did = $buf{$in_url};

	    unless (defined $in_did) {
		$in_did = $url2did->get($in_url);
	    }

	    if (defined $in_did) {
		$buf{$in_url} = $in_did;

		printf WRITER "%s\t%s\t%s\t\%s\t%s", $did, $url, $in_did, $in_url, $anchortext;
	    }
	}
	close (FILE);
	close (WRITER);
    }
}
