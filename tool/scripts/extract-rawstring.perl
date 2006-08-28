#!/usr/bin/env perl

# Add the Juman/KNP result

# Input : XML (utf8)
# Output: RawFile (utf8)

# $Id$

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
&extract_rawstring($doc);
# print $doc->toString();
$doc->dispose();

sub extract_rawstring {
    my ($doc) = @_;

    my $sid;
    my $sentences = $doc->getElementsByTagName('S');
    for my $i (0 .. $sentences->getLength - 1) { # for each S
	my $sentence = $sentences->item($i);
	my $sid = $sentence->getAttribute('Id');
	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->getNodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->getNodeValue;

		    print "\# S-ID:$sid\n";
		    print $text, "\n";
		}
	    }
	}
    }
}

