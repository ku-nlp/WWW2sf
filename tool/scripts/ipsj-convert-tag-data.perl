#!/usr/bin/env perl

# $Id$

use strict;
use utf8;

binmode (STDOUT, ':utf8');
binmode (STDIN,  ':utf8');

&main();

sub main {
    my $fid;
    my %buf;

    # 読み込み
    foreach my $file (@ARGV) {
	open (F, '<:utf8', $file) or die "$!";
	while (<F>) {
	    if ($_ =~ /\<PAPER.+?source=(.+)\.txt>/) {
		$fid = $1;
	    }
	    elsif ($_ =~ m!<MATCH type=(.+?) pattern_type=(.+?)>(.+?)</MATCH>!) {
		my $mch_type = $1;
		my $ptn_type = $2;
		my $string   = $3;

		push (@{$buf{$fid}{$mch_type}{$ptn_type}}, $string);
	    }

	}
	close (F);
    }

    # 包含関係にある string を削除
    while (my ($fid, $data) = each %buf) {
	foreach my $mch_type (keys %$data) {
	    foreach my $ptn_type (keys %{$data->{$mch_type}}) {
		my %_buf = ();
		my $_strings = $data->{$mch_type}{$ptn_type};
		foreach my $string (@$_strings) {
		    next if (exists $_buf{$string});

		    my $is_included = 0;
		    foreach my $_string (@$_strings) {
			next if ($string eq $_string);

			if (index($_string, $string) > -1) {
			    $is_included = 1;
			    last;
			}
		    }
		    unless ($is_included) {
			print $fid . " " . $mch_type . " " . $ptn_type . " " . $string . "\n";
		    }
		    $_buf{$string} = 1;
		}
	    }
	}
    }
}


sub printout {
    my ($data) = @_;

    printf ("%s %s %s %s\n", $data->{fid}, $data->{match_type}, $data->{pattern_type}, $data->{string});
}
