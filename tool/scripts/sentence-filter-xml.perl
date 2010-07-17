#!/usr/bin/env perl

# Mark Japanese sentences that are judged as Japanese

# Input : XML (utf8)
# Output: XML (utf8)

# $Id$

use XML::DOM;
use Encode qw(decode);
use encoding 'utf8';
use strict;

our $Threshold = 0.6;

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

my $parser = new XML::DOM::Parser;
my $doc = $parser->parse($buf);
&xml_japanese_check($doc);
#print decode('utf8', $doc->toString());
print $doc->toString();
$doc->dispose();


sub xml_japanese_check {
    my ($doc) = @_;

    my $sentences = $doc->getElementsByTagName('S');
    for my $i (0 .. $sentences->getLength - 1) { # for each S
	my $sentence = $sentences->item($i);
	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->getNodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $score = &japanese_check($node->getNodeValue); # calculate Japanese score of text
		    $sentence->setAttribute('JapaneseScore', sprintf("%.5f", $score));
		}
	    }
	}
    }
}

sub japanese_check {
    my ($buf) = @_;
    my ($acount, $count);

    for my $str (split(//, $buf)) {
	# count Hiragana, Katakana or Kanji
	if ($str =~ /^\p{Hiragana}|\p{Katakana}|ー|\p{Han}$/) {
	    $count++;
	}
	$acount++;
    }
    return 0 unless $acount;
    return $count / $acount;
}
