#!/usr/bin/env perl

# Add the Juman/KNP result

# Input : XML (utf8)
# Output: XML (utf8)

# $Id$

use XML::DOM;
use Encode qw(decode);
use encoding 'utf8';
use Getopt::Long;
use Juman;
use KNP;
use strict;

my (%opt);
GetOptions(\%opt, 'jmn', 'knp', 'help');

my ($juman, $knp);
$juman = new Juman if $opt{jmn};
$knp = new KNP if $opt{knp};

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

		    # jmn
		    if ($opt{jmn}) {
			&append_node($sentence, $text, 'Juman');
		    }
		    # knp
		    if ($opt{knp}) {
			&append_node($sentence, $text, 'Knp');
		    }
		}
	    }
	}
    }
}

# ノードを追加する
# $type: Juman or Knp
sub append_node {
    my ($sentence, $text, $type) = @_;

    my $newchild = $doc->createElement($type);

    my $result_string;
    if ($type eq 'Juman') {
	my $result = $juman->analysis($text);
	$result_string = $result->all;
	# 暫定的
	$result_string .= "EOS\n";
    }
    elsif ($type eq 'Knp') {
	my $result = $knp->parse($text);
	$result_string = $result->all;
    }

    my $cdata = $doc->createCDATASection($result_string);

    $newchild->appendChild($cdata);

    $sentence->appendChild($newchild);
}
