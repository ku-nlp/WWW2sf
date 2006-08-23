#!/usr/bin/env perl

# Add the KNP result

# Input : XML (utf8)
# Output: XML (utf8)

# $Id$

use XML::DOM;
use Encode qw(decode);
use encoding 'utf8';
use KNP;
use strict;

my $knp = new KNP;

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

my $parser = new XML::DOM::Parser;
my $doc = $parser->parse($buf);
&add_knp_result($doc);
print $doc->toString();
$doc->dispose();

sub add_knp_result {
    my ($doc) = @_;

    my $sentences = $doc->getElementsByTagName('S');
    for my $i (0 .. $sentences->getLength - 1) { # for each S
	my $sentence = $sentences->item($i);
	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->getNodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->getNodeValue;

		    my $newchild = $doc->createElement('Knp');

		    # Parse
		    my $result = $knp->parse($text);
		    my $result_string = $result->all;

		    my $cdata = $doc->createCDATASection($result_string);

		    $newchild->appendChild($cdata);

		    $sentence->appendChild($newchild);
		}
	    }
	}
    }
}
