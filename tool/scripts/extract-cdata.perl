#!/usr/bin/env perl

# a script to extract CDATA from standard format
# $Id$

# --id ID: specify document ID
# --encoding ENCODING: specify output encoding (e.g., shift_jis)
# --crlf: specify output newline to CRLF

# sentence ID:
# Title:       -T
# Description: -D
# Keyword:     -K
# S:           -1, -2, ...

use strict;
use Getopt::Long;
my %opt;
&GetOptions(\%opt, 'id=s', 'encoding=s', 'crlf');

my $encoding = ':crlf' if $opt{crlf};
$encoding .= $opt{encoding} ? ":encoding($opt{encoding})" : ':utf8'; # default output encoding is utf8
binmode STDIN, ':utf8';
binmode STDOUT, $encoding;

my $print_flag = 0;
my $buf = '';
my $sentence_id;
my $document_id = $opt{id} ? $opt{id} : 'NULL';

while (<STDIN>) {
    if (/<Title/) {
	$sentence_id = 'T';
    }
    elsif (/<Description/) {
	$sentence_id = 'D';
    }
    elsif (/<Keyword/) {
	$sentence_id = 'K';
    }
    elsif (/<S/) {
	if (/Id="(\d+)"/) {
	    $sentence_id = $1;
	}
    }
    elsif (m|<Annotation Scheme="SynGraph"><!\[CDATA\[(.*)|) {
	$buf .= $1 . "\n";
	$print_flag = 1;
    }
    elsif (m|^\]\]></Annotation|) {
	my $sid = "# S-ID:$document_id-$sentence_id ";
	print $sid, $buf;
	$buf = '';
	$print_flag = 0;
    }
    elsif ($print_flag) {
	$buf .= $_;
    }
}
