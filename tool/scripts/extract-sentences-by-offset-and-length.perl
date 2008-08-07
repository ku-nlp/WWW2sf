#!/usr/bin/env perl

# $Id$

# 標準フォーマット中のオフセット・長さに従ってHTMLページから文を切り出すプログラム

# usage:
# perl extract-sentence-by-offset-and-length.perl -html 30215120.html -xml 30215120.xml

use strict;
use utf8;
use Encode;
use Getopt::Long;
use XML::LibXML;

binmode(STDOUT, ':encoding(utf8)');

my %opt;
GetOptions(\%opt, 'html=s', 'xml=s', 'z');

&main();

sub main {
    if ($opt{z}) {
	open(READER, "zcat  $opt{xml} |");
    } else {
	open(READER, $opt{xml});
    }
    binmode(READER, ':utf8');

    my $xmldat;
    while (<READER>) {
	$xmldat .= $_;
    }
    close(READER);

    my $htmldat;
    my $DAT;
    open($DAT, $opt{html});
    my $parser = new XML::LibXML;
    my $doc = $parser->parse_string($xmldat);
    &extract_rawstring($doc, $htmldat, $DAT, $opt{xml});

    close($DAT);
}

sub extract_rawstring {
    my ($doc, $texts, $READER, $file) = @_;

    my $title = $doc->getElementsByTagName('Title')->[0];
    if (defined $title) {
	my $sid = $title->getAttribute('Id');
	my $offset = $title->getAttribute('Offset');
	my $length = $title->getAttribute('Length');
	for my $s_child_node ($title->getChildNodes) {
	    if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->string_value;

		    if ($offset > -1 && $length > 0) {
			seek($READER, $offset, 0);
			my $rawstring;
			read($READER, $rawstring, $length);
			print "=====\n";
			print "file:$file offset:$offset length:$length\n";
			print "xml  " . $text . "\n";
			print $text . "\n";
			print "-----\n";
			print "html " . decode('utf8', $rawstring) . "\n";
		    }
		}
	    }
	}
    }

    my $sid;
    for my $sentence ($doc->getElementsByTagName('S')) { # for each S
	my $sid = $sentence->getAttribute('Id');
	my $offset = $sentence->getAttribute('Offset');
	my $length = $sentence->getAttribute('Length');

	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->string_value;

#		    if ($offset > -1 && $length > 0) {
			seek($READER, $offset, 0);
			my $rawstring;
			read($READER, $rawstring, $length);
			$rawstring = decode('utf8', $rawstring);
			print "=====\n";
			print "offset:$offset length:$length\n";
			print "xml  " . $text . "\n";
			print "-----\n";
			print "html " . $rawstring . "\n";
#		    }
		}
	    }
	}
    }
}
