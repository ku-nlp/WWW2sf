package StandardFormatLib;

# Common settings for StandardFormat

use base 'Exporter';
use strict;

our @EXPORT = qw/conll2sf/;
our %pf_order = (id => 0, head => 1, category => 2, feature => 3, type => 4); # print order of phrase attributes
our %wf_order = (id => 0, surf => 1, orig => 2, read => 3, pos1 => 4, repname => 5, conj => 6, feature => 99); # print order of word attributes
our %synnodesf_order = (head => 0, phraseid => 1);
our %synnodef_order = (wordid => 0, synid => 1, score => 2);

# CoNLL形式を標準フォーマットに変換
sub conll2sf {
    my ($result) = @_;

    require XML::LibXML;
    my $doc = XML::LibXML::Document->new('1.0');
    my $sf_node = $doc->createElement('StandardFormat');
    my $annotation_node = undef;

    for my $line (split("\n", $result)) {
	if ($line =~ /^$/) {
	    $annotation_node = undef;
	    next;
	}
	my @line = split(/\t/, $line);
	my $head = 'c' . $line[6]; # c1, c2, ...
	$head = 'c-1' if $head eq 'c0'; # ROOT
	my %pf = (id => 'c' . $line[0], head => $head, type => $line[7]);
	my %wf = (id => 't' . $line[0], surf => $line[1], orig => $line[2], pos1 => $line[3]);

	my $phrase_node = $doc->createElement('Chunk');
	for my $key (sort {$pf_order{$a} <=> $pf_order{$b}} keys %pf) {
	    $phrase_node->setAttribute($key, $pf{$key});
	}

	my $word_node = $doc->createElement('Token');
	for my $key (sort {$wf_order{$a} <=> $wf_order{$b}} keys %wf) {
	    $word_node->setAttribute($key, $wf{$key});
	}

	if (!defined($annotation_node)) {
	    my $sentence_node = $doc->createElement('S');
	    $sf_node->appendChild($sentence_node);
	    $annotation_node = $doc->createElement('Annotation');
	    $sentence_node->appendChild($annotation_node);
	}

	$phrase_node->appendChild($word_node);
	$annotation_node->appendChild($phrase_node);
    }

    $doc->setDocumentElement($sf_node);
    return $doc->toString();
}

1;
