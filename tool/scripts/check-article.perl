#!/usr/bin/env perl

# Usage: $0 orig.jmn new.knp

use strict;
use Getopt::Long;
use vars qw(%opt);

GetOptions(\%opt, 'data=s');

my ($sidj, $sidk, $line);

open(JMN, $ARGV[0]) or die;
open(KNP, $ARGV[1]) or die;

while (1) {
    $sidj = undef;
    $sidk = undef;

    while (<JMN>) {
	$line = $_;
	if (/^\#\s*S-ID:(\S+)/ && 
	    $_ !~ /(?:全体|人手)削除/) {
	    $sidj = $1;
	    last;
	}
    }

    last unless $sidj;

    while (<KNP>) {
	if (/^\#\s*S-ID:(\S+)/ && 
	    $_ !~ /(?:全体|人手)削除/) {
	    $sidk = $1;
	    last;
	}
    }

    # knpの方が最後までいったとき
    unless ($sidk) {
	print $sidj, " 以降\n";
	if ($opt{data}) {
	    open(DATA, "> $opt{data}") or die;
	    print DATA $line;
	    while (<JMN>) {
		print DATA $_;
	    }
	    close(DATA);
	}
	last;
    }

    # 一致しないとき
    # == knpの方が次に進んでいる
    if ($sidj ne $sidk) {
	print $sidj, "\n";
	while (<JMN>) {
	    if (/^\#\s*S-ID:(\S+)/ && 
		$_ !~ /(?:全体|人手)削除/) {
		if ($sidk eq $1) {
		    last;
		}
		else {
		    print $1, "\n";
		}
	    }
	}
    }
}

END {
    close(KNP);
    close(JMN);
}
