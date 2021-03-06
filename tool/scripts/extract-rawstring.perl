#!/usr/bin/env perl

# Extract RawString from standard format

# Input : XML (utf8)
# Output: RawFile (utf8)

# --all: extract all the sentences including "全体削除" (including a title)
# --title: extract a title as well

# --text-only: do not print S-ID
# --sid-head str: string added before S-ID

# $Id$

use XML::LibXML;
use Encode qw(decode);
use encoding 'utf8';
use Getopt::Long;
use strict;

my (%opt);
GetOptions(\%opt, 'all', 'title', 'text-only', 'sid-head=s', 'delete-space', 'specified-sids=s', 'blocktype=s', 'preserve-blocktype');

# 特定のsidの文のみを抽出するオプション
my %specified_sid;
if ($opt{'specified-sids'}) {
    for my $sid (split (':', $opt{'specified-sids'})) {
	$specified_sid{$sid} = 1;
    }
}

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

# URL中などに含まれる「&」を「&amp;」に変更
$buf =~ s/&/&amp;/g;

my $parser = new XML::LibXML;
my $doc = $parser->parse_string($buf);
&extract_rawstring($doc, 'Title') if $opt{title} or $opt{all};
&extract_rawstring($doc, 'S');


sub extract_rawstring {
    my ($doc, $tagName) = @_;

    for my $sentence ($doc->getElementsByTagName($tagName)) { # for each S
	my $jap_sent_flag = $sentence->getAttribute('is_Normal_Sentence');
	next if !$opt{all} and !($opt{title} and $tagName eq 'Title') and !$jap_sent_flag; # not Japanese
	my $sid = $sentence->getAttribute('Id'); # the title string has 0 as its Id.
	$sid = 0 if $tagName eq 'Title' and !defined($sid); # set the sid of title to 0

	next if $opt{'specified-sids'} && !defined $specified_sid{$sid};

	my $blocktype = $sentence->getAttribute('BlockType') if $opt{blocktype} || $opt{'preserve-blocktype'};
	next if $opt{blocktype} && $blocktype ne $opt{blocktype};

	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->string_value;

		    $text =~ s/\s+//g if $opt{'delete-space'};

		    unless ($opt{'text-only'}) {
			printf "\# S-ID:%s%s", $opt{'sid-head'}, $sid;
			print " BlockType:$blocktype" if $blocktype;
			print "\n";
		    }
		    print $text, "\n";
		}
	    }
	}
    }
}

