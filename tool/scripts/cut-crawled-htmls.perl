#!/usr/bin/env perl

# Cut htmls from raw crawl data (page.gz)

# Usage: $0 [-z] [--count start_count] page.gz
# output directories (h000000...) will be automatically created

use PerlIO::gzip;
use Getopt::Long;
use strict;

our (%opt);
&GetOptions(\%opt, 'count=i', 'z');

our $MAX_HTMLS = 10000;
our $dir_count = $opt{count} ? $opt{count} : 0; # the number of directory

my $file_count = 0;
my ($url, $date);

open(F, '<:gzip', $ARGV[0]) or die;
while (<F>) {
    if (/^:::URL:::\s+\d+ (.+)/) {
	$url = $1;
    }
    if (/^:::HDR:::\s+\d+ Date: (.+)/) {
	$date = $1;
    }
    elsif (/^:::CON:::\s+(\d+) ((?:.|\r|\n)+)$/) {
	my $head_buf = $2;
	my $length = $1 - length($head_buf);
	my $buf;
	read(F, $buf, $length) if $length > 0;
	$buf = $head_buf . $buf;
	&write_buf2file($url, \$buf, $dir_count, $file_count++);
	if ($file_count >= $MAX_HTMLS) { # split at MAX_HTMLS htmls
	    $dir_count++;
	    $file_count = 0;
	}
    }
}
close(F);


sub write_buf2file {
    my ($url, $buf_sr, $dir_num, $html_num) = @_;

    my $dirname = sprintf("h%06d", $dir_num);
    my $filename = sprintf("%s/%06d%04d.html", $dirname, $dir_num, $html_num);
    $filename .= '.gz' if $opt{z};
    mkdir($dirname, 0755) if ! -d $dirname;

    print "$filename\n";
    if ($opt{z}) {
	open(OUT, '>:gzip', $filename) or die;
    }
    else {
	open(OUT, '>', $filename) or die;
    }
    print OUT "HTML $url\n";
    print OUT ${$buf_sr};
    close(OUT);
}
