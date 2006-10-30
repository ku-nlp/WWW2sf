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
GetOptions(\%opt, 'jmn', 'knp', 'help', 'usemodule', 'all');

my ($juman, $knp);
$juman = new Juman if $opt{jmn};
$knp = new KNP if $opt{knp};

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

my $parser = new XML::DOM::Parser;
my $doc = $parser->parse($buf);

if ($opt{usemodule}) {
    &add_knp_result($doc);
}
# 解析結果を読み込む
else {
    &read_result($doc);
}

print $doc->toString();
$doc->dispose();

sub read_result {
    my ($doc) = @_;

    my $sentences = $doc->getElementsByTagName('S');
    
    open (F, "<:encoding(euc-jp)", "$ARGV[0]");

    my ($sid, $result);
    while (<F>) {
	if (/S-ID:(\d+)/) {
	    $sid = $1;
	}
	elsif (/^EOS$/) {
	    $result .= $_;
	    my $sentence = $sentences->item($sid - 1);
	    for my $s_child_node ($sentence->getChildNodes) {
		if ($s_child_node->getNodeName eq 'RawString') { # one of the children of S is Text
		    for my $node ($s_child_node->getChildNodes) {
			my $text = $node->getNodeValue;

			my $type;
			if ($opt{jmn}) {
			    $type = 'Juman';
			}
			elsif ($opt{knp}) {
			    $type = 'Knp';
			}
			my $newchild = $doc->createElement($type);

			my $cdata = $doc->createCDATASection($result);
			$newchild->appendChild($cdata);
			$sentence->appendChild($newchild);
		    }
		}
	    }
	    $result = '';
	}
	else {
	    $result .= $_;
	}
    }
    close F;
}

sub add_knp_result {
    my ($doc) = @_;

    my $sentences = $doc->getElementsByTagName('S');
    for my $i (0 .. $sentences->getLength - 1) { # for each S
	my $sentence = $sentences->item($i);

	# skip non-Japanese sentences
	my $jap_sent_flag = $sentence->getAttribute('is_Japanese_Sentence');
	next if !$opt{all} and !$jap_sent_flag; # not Japanese

	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->getNodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->getNodeValue;

		    next if $text eq '';

		    if ($opt{usemodule}) {
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
