#!/usr/bin/env perl

# WWWから収集した文を整形, 削除, S-ID付与

# Input : XML (utf8)
# Output: XML (utf8)

# $Id$

use Getopt::Long;
use XML::LibXML;
use SentenceFormatter;
use Encode qw(decode);
use encoding 'utf8';
use strict;

our (%opt);
GetOptions(\%opt, 'include_paren', 'divide_paren');
# --include_paren: 括弧を削除しない
# --divide_paren: 括弧を別文として出力

$opt{'include_paren'} = 1 if $opt{'divide_paren'};

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

my $formatter = new SentenceFormatter(\%opt);

my $parser = new XML::LibXML;
my $doc = $parser->parse_string($buf);
&xml_check_sentence($doc);

# XML-LibXML 1.63以降ではバイト列が返ってくるので、decodeする
my $string = $doc->toString();

print utf8::is_utf8($string) ? $string : decode($doc->actualEncoding(), $string);


sub xml_check_sentence {
    my ($doc) = @_;
    my $count = 1;

    for my $sentence ($doc->getElementsByTagName('S')) { # for each S
	my $is_japanese_flag = $sentence->getAttribute('is_Japanese');
	if (defined($is_japanese_flag) and $is_japanese_flag == 0) { # do not process non-Japanese
	    $sentence->setAttribute('is_Japanese_Sentence', '0');
	    $sentence->setAttribute('Id', $count++);
	    next;
	}

	my (@parens);
	for my $raw_string_node ($sentence->getChildNodes) {
	    if ($raw_string_node->nodeName eq 'RawString') {
		my $raw_string_element = $raw_string_node->getFirstChild; # text content node
		my ($main);

		# 全文削除や括弧の処理
		($main, @parens) = $formatter->FormatSentence($raw_string_element->string_value, $count);
		if ($main->{sentence}) {
		    $sentence->setAttribute('is_Japanese_Sentence', '1');
		    $raw_string_node->removeChild($raw_string_element);
		    $raw_string_node->appendChild(XML::LibXML::Text->new($main->{sentence}));
		}
		else { # 全文削除されても、RawStringには残す
		    $sentence->setAttribute('is_Japanese_Sentence', '0');
		    # $raw_string_node->removeChild($raw_string_element);
		    # $raw_string_node->appendChild(XML::LibXML::Text->new(''));
		}
		$sentence->setAttribute('Id', $main->{sid});
		$sentence->setAttribute('Log', $main->{comment}) if $main->{comment};
		$count++;
		last;
	    }
	}

	# 括弧文の処理 (--divide_paren時)
	if (@parens) {
	    my $paren_node = $doc->createElement('Parenthesis');
	    for my $paren (@parens) {
		my $new_sentence_node = $doc->createElement('S');
		$new_sentence_node->setAttribute('Id', $paren->{sid});
		$new_sentence_node->setAttribute('Log', $paren->{comment}) if $paren->{comment};

		my $string_node = $doc->createElement('RawString');
		$string_node->appendChild(XML::LibXML::Text->new($paren->{sentence}));

		$new_sentence_node->appendChild($string_node);
		$paren_node->appendChild($new_sentence_node);
	    }

	    $sentence->appendChild($paren_node);
	    @parens = ();
	}
    }
}
