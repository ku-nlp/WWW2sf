#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
use XML::LibXML;

&main();

sub main {
    foreach my $file (@ARGV) {
	my $is_gzipped = ($file =~ /gz$/) ? 1 : 0;

	if ($is_gzipped) {
	    open (READER, "zcat $file |") or die "$!";
	} else {
	    open (READER, $file) or die "$!";
	}
	binmode (READER, ':utf8');


	my ($buf);
	while (<READER>) {
	    $buf .= $_;
	}
	close (READER);


	my $parser = new XML::LibXML;
	my $doc = $parser->parse_string($buf);

	my $tagname = 'S';
	&extract_rawstring($doc, $tagname);
    }
}


sub extract_rawstring {
    my ($doc, $tagName) = @_;

    for my $sentence ($doc->getElementsByTagName($tagName)) {
	my $sid = $sentence->getAttribute('Id');
	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->nodeName eq 'RawString') {
		for my $node ($s_child_node->getChildNodes) {
		    my $rawstring = $node->string_value;

		    print $sid . " " . $rawstring . "\n";
		}
	    }
	}
    }
}
