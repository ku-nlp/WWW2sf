#!/usr/bin/env perl

# Add the Juman/KNP result

# Input : XML (utf8)
# Output: XML (utf8)

# $Id$

use XML::LibXML;
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

my $parser = new XML::LibXML;
my $doc = $parser->parse_string($buf);

if ($opt{usemodule}) {
    &add_knp_result($doc);
}
# 解析結果を読み込む
else {
    &read_result($doc);
}

# XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
my $string = $doc->toString();

print utf8::is_utf8($string) ? $string : decode($doc->actualEncoding(), $string);

sub read_result {
    my ($doc) = @_;

    my @sentences = $doc->getElementsByTagName('S');
    my $start_sent = 0;

    open (F, "<:encoding(euc-jp)", "$ARGV[0]");

    my ($sid, $result);
    while (<F>) {
	if (/S-ID:(\d+)/) {
	    $sid = $1;
	}
	elsif (/^EOS$/) {
	    $result .= $_;
	    for my $i ($start_sent .. $#sentences) {
		my $sentence = $sentences[$i];
		my $xml_sid = $sentence->getAttribute('Id');
		if ($sid eq $xml_sid) {
		    my $type;
		    if ($opt{jmn}) {
			$type = 'Juman';
		    }
		    elsif ($opt{knp}) {
			$type = 'Knp';
		    }
		    my $newchild = $doc->createElement('Annotation');
		    $newchild->setAttribute('Scheme', $type);
		    my $cdata = $doc->createCDATASection($result);
		    $newchild->appendChild($cdata);
		    $sentence->appendChild($newchild);

		    $start_sent = $i + 1;
		    last;
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

    for my $sentence ($doc->getElementsByTagName('S')) { # for each S
	my $jap_sent_flag = $sentence->getAttribute('is_Japanese_Sentence');
	next if !$opt{all} and !$jap_sent_flag; # not Japanese

	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->string_value;

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

    my $newchild = $doc->createElement('Annotation');
    $newchild->setAttribute('Scheme', $type);

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
