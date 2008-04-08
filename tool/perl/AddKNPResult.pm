package AddKNPResult;

# $Id$

# 文のみからなる標準フォーマットにJuman/KNP/SynGraphの解析結果をうめこむモジュール

use utf8;
use strict;

sub new {
    my ($this, $juman, $knp, $syngraph, $opt) = @_;

    $this = {
	juman => $juman,
	knp => $knp,
	syngraph => $syngraph,
	opt => $opt
	};
    
    bless $this;
}

sub DESTROY {
    my ($this) = @_;
}

sub AddKnpResult {
    my ($this, $doc, $tagName) = @_;

    for my $sentence ($doc->getElementsByTagName($tagName)) { # for each $tagName
	my $jap_sent_flag = $sentence->getAttribute('is_Japanese_Sentence');
	next if !$this->{opt}{all} and !$jap_sent_flag; # not Japanese

	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my $text = $node->string_value;

		    next if $text eq '';

		    if ($this->{opt}{usemodule}) {
			print STDERR "$text\n" if $this->{opt}{debug};

			# jmn
			if ($this->{opt}{jmn}) {
			    $this->AppendNode($doc, $sentence, $text, 'Juman');
			}
			# SynGraph
			elsif ($this->{opt}{syngraph}) {
			    $this->AppendNode($doc, $sentence, $text, 'SynGraph');
			}
			# knp
			elsif ($this->{opt}{knp}) {
			    $this->AppendNode($doc, $sentence, $text, 'Knp');
			}
		    }
		}
	    }
	}
    }
}

# ノードを追加する
# $type: Juman or Knp or SynGraph
sub AppendNode {
    my ($this, $doc, $sentence, $text, $type) = @_;

    my $newchild = $doc->createElement('Annotation');
    $newchild->setAttribute('Scheme', $type);

    my $result_string;
    if ($type eq 'Juman') {
	my $result = $this->{juman}->analysis($text);
	$result_string = $result->all;
	# 暫定的
	$result_string .= "EOS\n";
    }
    elsif ($type eq 'Knp' || $type eq 'SynGraph') {
	my $result = $this->{knp}->parse($text);

	return unless $result;

	if ($type eq 'SynGraph') {
	    $result_string = $this->{syngraph}->OutputSynFormat($result, $this->{opt}{regnode_option}, $this->{opt}{syngraph_option});
	}
	# knp
	else {
	    $result_string = $result->all;
	}
    }

    my $cdata = $doc->createCDATASection($result_string);

    $newchild->appendChild($cdata);

    $sentence->appendChild($newchild);
}

sub ReadResult {
    my ($this, $doc, $inputfile) = @_;

    my @title = $doc->getElementsByTagName('Title');
    my @sentences = $doc->getElementsByTagName('S');
    unshift(@sentences, $title[0]) if (defined(@title));
    my $start_sent = 0;

    open (F, "<:encoding(euc-jp)", $inputfile) or die;

    my ($sid, $result);
    while (<F>) {
	if (/S-ID:(\d+)?/) {
	    $sid = $1;
	}
	elsif (/^EOS$/) {
	    $result .= $_;
	    for my $i ($start_sent .. $#sentences) {
		my $sentence = $sentences[$i];
		my $xml_sid = $sentence->getAttribute('Id');
		if ($sid eq $xml_sid) {
		    my $type;
		    if ($this->{opt}{syngraph}) {
			$type = 'SynGraph';
		    }
		    elsif ($this->{opt}{jmn}) {
			$type = 'Juman';
		    }
		    elsif ($this->{opt}{knp}) {
			$type = 'Knp';
		    }
		    my $newchild = $doc->createElement('Annotation');
		    $newchild->setAttribute('Scheme', $type);
		    my $cdata = $doc->createCDATASection($result);
		    $newchild->appendChild($cdata);

		    if ($this->{opt}{replace}) {
			my $oldchild = shift(@{$sentence->getElementsByTagName('Annotation')});
			$sentence->replaceChild($newchild, $oldchild);
		    } else {
			$sentence->appendChild($newchild);
		    }
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

1;
