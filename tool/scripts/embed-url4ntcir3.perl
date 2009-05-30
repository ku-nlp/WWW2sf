#!/usr/bin/env perl

use strict;
use utf8;
use CDB_Reader;
use Getopt::Long;

binmode(STDOUT, ":encoding(euc-jp)");
binmode(STDERR, ":encoding(euc-jp)");

my (%opt);
GetOptions(\%opt, 'did2url=s', 'dir=s');

&main();

sub main {
    my $cdb = new CDB_Reader($opt{did2url});

    opendir (DIR, $opt{dir}) or die "$!";
    foreach my $file (readdir(DIR)) {
	next if ($file eq '.' || $file eq '..');

	my $fp = sprintf ("%s/%s", $opt{dir}, $file);
	my ($did) = ($file =~ /(?:NW)?(\d+).html/);

	my $gzipf = 0;
	if ($file =~ /.gz$/) {
	    $gzipf = 1;
	    open (FILE, "zcat $fp |") or die "$!";
	} else {
	    open (FILE, $fp) or die "$!";
	}

	my $buf;
	while (<FILE>) {
	    $buf .= $_;
	}
	close (FILE);

	if ($gzipf) {
	    open (FILE, "| gzip > $fp") or die "$!";
	} else {
	    open (FILE, "> $fp") or die "$!";
	}

	my $url = $cdb->get("NW$did");
	print FILE "HTML $url\n";
	print FILE "\x0D";
	print FILE $buf;
	close (FILE);
    }
    close (DIR);
}
