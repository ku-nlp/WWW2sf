#!/usr/bin/env perl

# Read SF data

# Input : XML (utf8)

use XML::DOM;
use Encode qw(decode);
use encoding 'utf8';
use strict;

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

my $parser = new XML::DOM::Parser;
my $doc = $parser->parse($buf);
&read_sf($doc);

sub read_sf {
    my ($doc) = @_;

    my $sentences = $doc->getElementsByTagName('S');
    for my $i (0 .. $sentences->getLength - 1) { # for each S
	my $sentence = $sentences->item($i);
	for my $s_child_node ($sentence->getChildNodes) {
#	    if ($s_child_node->getNodeName eq 'RawString') { # one of the children of S is Text
	    if ($s_child_node->getNodeName eq 'Juman') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->getNodeValue;
#		    print $text, "\n";
		    print $text;
		}
	    }
	}
    }
}

