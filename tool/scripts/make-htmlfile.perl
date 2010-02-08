#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
use Getopt::Long;
use PerlIO::gzip;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');

my (%opt);
GetOptions(\%opt, 'outdir=s', 'kuhp', 'ipsj', 'z');

$opt{outdir} = './htmls' unless (defined $opt{outdir});

&main();

sub main {

    `mkdir -p $opt{outdir}` unless (-d $opt{outdir});
    if ($opt{kuhp}) {
	&make_htmlfile_kuhp(\@ARGV);
    }
    elsif ($opt{ipsj}) {
    }
}


sub make_htmlfile_kuhp {
    my ($files) = @_;

    my %VERSION = ();
    my $count = 0;
    foreach my $file (@$files) {
	open (F, '<:utf8', $file) or die $!;
	# skip attribute names
	my $dumy = <F>;
	while (<F>) {
	    chop;
	    my @data = split (/\t/, $_);
	    my $fid = $data[0];
	    $fid =~ s/ /_/g;
	    my $findings = $data[5];
	    my $imp = $data[6];
	    my ($order) = ($data[7] =~ /●依頼コメント：(.+?)●/);

	    # 特殊文字を削除
	    $findings =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;
	    $imp =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;
	    $order =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;

	    # save
	    my $version = '';
	    if (exists $VERSION{$fid}) {
		$version = '-' . $VERSION{$fid};
	    } else {
		$VERSION{$fid} = 0;
	    }
	    $VERSION{$fid}++;

	    if ($opt{z}) {
		open (OUTF, '>:gzip', sprintf ("%s/%s%s.html.gz", $opt{outdir}, $fid, $version)) or die $!;
		binmode(OUTF, ':utf8');
	    } else {
		open (OUTF, '>:utf8', sprintf ("%s/%s%s.html", $opt{outdir}, $fid, $version)) or die $!;
	    }

	    print  OUTF "<HTML>\n";
	    print  OUTF "<BODY>\n";
	    printf OUTF (qq(<DIV myblocktype="findings">%s</DIV>\n), $findings);
	    printf OUTF (qq(<DIV myblocktype="imp">%s</DIV>\n), $imp);
	    printf OUTF (qq(<DIV myblocktype="order">%s</DIV>\n), $order);
	    print  OUTF "</BODY>\n";
	    print  OUTF "</HTML>\n";
	    close (OUTF);

	    last if ($count++ > 200);
	}
	close (F);
    }
}
