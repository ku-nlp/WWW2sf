#!/usr/bin/env perl

# Extract RawString from standard format

# Input : XML (utf8)
# Output: RawFile (utf8)

# --all: extract all the sentences including "蜈ｨ菴灘炎髯､"
# --sid-head str: string added before S-ID

# $Id$

use XML::LibXML;
use Encode qw(decode);
use encoding 'utf8';
use Getopt::Long;
use strict;

my (%opt);
GetOptions(\%opt, 'all', 'sid-head=s');

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

# URL中などに含まれる「&」を「&amp;」に変更
$buf =~ s/&/&amp;/g;

my $parser = new XML::LibXML;
my $doc = $parser->parse_string($buf);
&extract_rawstring($doc, 'Title');
&extract_rawstring($doc, 'S');


sub extract_rawstring {
    my ($doc, $tagName) = @_;

    for my $sentence ($doc->getElementsByTagName($tagName)) { # for each S
	my $jap_sent_flag = $sentence->getAttribute('is_Japanese_Sentence');
	my $sid = $sentence->getAttribute('Id'); # the title string has 0 as its Id.
	next if !$opt{all} and !$jap_sent_flag; # not Japanese

	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->string_value;

		    printf "\# S-ID:%s%s\n", $opt{'sid-head'}, $sid;
		    print $text, "\n";
		}
	    }
	}
    }
}

