#!/usr/bin/env perl

use strict;
use utf8;
use Juman;
use KNP;
use Unicode::Japanese;
use XML::LibXML;
use Encode;
use Getopt::Long;
use PerlIO::gzip;

binmode (STDOUT, ":utf8");

my (%opt);
GetOptions(\%opt, 'outdir=s', 'debug', 'z');

my $juman = new Juman();
$opt{outdir} = './output' unless ($opt{outdir});

&main();

sub main {

    my %ipsj2kj;
    my %kj2ipsj;
    open (F, '<:encoding(utf8)', shift @ARGV) or die "$!";
    while (<F>) {
	chop;

	my @field = split (/\s/, $_);
	my $ipsj = $field[0];
	my $kj   = $field[2];

	$ipsj2kj{$ipsj} = $kj;
	$kj2ipsj{$kj} = $ipsj;
    }
    close (F);

    my %db;
    open (F, '<:encoding(utf8)', shift @ARGV) or die "$!";
    while (<F>) {
	chop;

	my @_buf = split (/ /, $_);
	my ($fid, $type, $tag, $_rawstring) = (shift @_buf, shift @_buf, shift @_buf, join (" ", @_buf));
	$_rawstring =~ s/\\/ /g;
	$_rawstring =~ s/^ +//;
	$_rawstring =~ s/ +$//;
	$_rawstring = uc($_rawstring);
	my $rawstring = Unicode::Japanese->new($_rawstring)->h2z->getu;

	$tag =~ s/^a/A/;
	$tag =~ s/^t/T/;


	push (@{$db{$fid}{$tag}{$rawstring}}, $type);
	if ($fid =~ /^IPSJ/) {
	    push (@{$db{$ipsj2kj{$fid}}{$tag}{$rawstring}}, $type);
	} else {
	    push (@{$db{$kj2ipsj{$fid}}{$tag}{$rawstring}}, $type);
	}
    }
    close (F);

    `mkdir $opt{outdir}` unless (-d $opt{outdir});

    while (<STDIN>) {
	chop;

	my $file = $_;
	my ($fid) = ($file =~ /([^\/]+?).txt.xml/);
	my $outf = sprintf ("%s/%s.xml", $opt{outdir}, $fid);
	if (-f $outf) {
#	    print STDERR "[EXISTS] $outf\n";
	}

	my $docstr;
	if ($file =~ /gz$/) {
	    open (F, "zcat $file |") or die "$!";
	    binmode (F, ':utf8');
	} else {
	    open (F, '<:utf8', $file) or die "$!";
	}

	while (<F>) {
	    $docstr .= $_;
	}
	close (F);
	# 標準フォーマットをDOM木に変換
	my $parser = new XML::LibXML;
	my $domtree = $parser->parse_string($docstr);

	my $modified = 0;
	if (exists $db{$fid}) {
#	    print $fid . "\n";
	}

	while (my ($tag, $data) = each %{$db{$fid}}) {
	    foreach my $node ($domtree->getElementsByTagName($tag)) {
		my @nodes = ();
		if ($tag eq 'Abstract') {
		    foreach my $nd ($node->getElementsByTagName('S')) {
			push (@nodes, $nd);
		    }
		} else {
		    push (@nodes, $node);
		}

		foreach my $nd (@nodes) {
		    my %attrs = ();
		    foreach my $annotation ($nd->getElementsByTagName('Annotation')) {
			my $knpstr = $annotation->getFirstChild()->getValue();
			my @mrphls = (new KNP::Result($knpstr))->mrph();

			my $chlist = &get_chlist(\@mrphls);
			my $size_i = scalar(@$chlist);

			foreach my $rawstring (keys %$data) {
			    my $jmnret = $juman->analysis($rawstring);
			    my @_mrphls = $jmnret->mrph();

			    my $_chlist = &get_chlist(\@_mrphls);
			    my $size_j = scalar(@$_chlist);
			    for (my $i = 0; $i < $size_i; $i++) {
				my $k = $i;
				my $match = 1;
				for (my $j = 0; $j < $size_j; $j++, $k++) {
				    print $rawstring . " $chlist->[$k]{ch}  $_chlist->[$j]{ch}\n" if ($opt{debug});
				    if ($chlist->[$k]{ch} ne $_chlist->[$j]{ch}) {
					$match = 0;
					last;
				    }
				}

				if ($match) {
				    my @buf;
				    for (my $j = $i; $j < $i + $size_j; $j++) {
					push (@buf, $chlist->[$j]{ch});
				    }
				    my $beg = $chlist->[$i]{pos};
				    my $end = $chlist->[$i + $size_j - 1]{pos};

				    foreach my $type (@{$data->{$rawstring}}) {
					push (@{$attrs{$type}}, {begin => $beg, end => $end});
					print "(" . $rawstring . ") " . $type . " " . $beg . " " . $end . "\n" if ($opt{debug});
				    }
				    $i = $k;
				}
			    }
			}
		    }

		    foreach my $type (keys %attrs) {
			my @_buf;
			foreach my $dat (@{$attrs{$type}}) {
			    push (@_buf, sprintf ("B:%d,E:%d", $dat->{begin}, $dat->{end}));
			}

			$nd->setAttribute($type, join("/", @_buf));
			$modified = 1;
		    }
		}
	    }
	}


	if ($opt{z}) {
	    $outf .= ".gz";
	    open (F, '>:gzip', $outf) or die $!;
	    binmode(F, ':utf8');
	} else {
	    open (F, '>:utf8', $outf) or die $!;
	}

	my $string = $domtree->toString();
	print F utf8::is_utf8($string) ? $string : decode($domtree->actualEncoding(), $string);
	close (F);
    }
}

sub get_chlist {
    my ($mrphs) = @_;

    my $i = 0;
    my @chlist;
    foreach my $m (@$mrphs) {
	foreach my $ch (split (//, $m->midasi)) {
	    push (@chlist, {ch => $ch, pos => $i});
	}
	$i++;
    }

    return \@chlist;
}

