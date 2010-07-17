package AddKNPResult;

# $Id$

# 文のみからなる標準フォーマットにJuman/KNP/SynGraphの解析結果をうめこむモジュール

use utf8;
use strict;
use Error qw(:try);
use Data::Dumper;

binmode(STDERR, ':encoding(euc-jp)');

sub new {
    my ($clazz, $opt) = @_;

    my $this = ();
    # th_of_knp_use 回ごとに KNP を new しなおす（デットロックに陥るため）
    $this->{th_of_knp_use} = $opt->{th_of_knp_use};
    $this->{num_of_knp_use} = 0;
    $this->{opt} = $opt;

    if ($this->{opt}{usemodule}) {
	# ツールのモジュールを new する
	&createJumanObject($this);
	&createKnpObject($this);
	&createSynGraphObject($this);
	&createMaltParserObject($this);
    }

    if ($this->{opt}{use_knpresult_cache}) {
	require CDB_Reader;
	$this->{knpresult_reader} = new CDB_Reader($opt->{knpresult_keymap});

	require IO::Uncompress::Gunzip;
    }

    bless $this;
}

sub createJumanObject {
    my ($this) = @_;

    if ($this->{opt}{jmn}) {
	$this->{juman} = new Juman (-Command => $this->{opt}{jmncmd},
				    -Rcfile => $this->{opt}{jmnrc},
				    -Option => '-i \#');
    }
}

sub createKnpObject {
    my ($this) = @_;

    if ($this->{opt}{case}) {
	if ($this->{opt}{knp} || $this->{opt}{syngraph}) {
	    my $knp = new KNP (-Command => $this->{opt}{knpcmd},
			       -Rcfile => $this->{opt}{knprc},
			       -JumanCommand => $this->{opt}{jmncmd},
			       -JumanRcfile => $this->{opt}{jmnrc},
			       -JumanOption => '-i \#',
			       -Option => '-tab -postprocess');
	    $this->{knp_w_case} = $knp;
	}
    }

    if ($this->{opt}{anaphora}) {
	if ($this->{opt}{knp} || $this->{opt}{syngraph}) {
	    my $knp = new KNP (-Command => $this->{opt}{knpcmd},
			       -Rcfile => $this->{opt}{knprc},
			       -JumanCommand => $this->{opt}{jmncmd},
			       -JumanRcfile => $this->{opt}{jmnrc},
			       -JumanOption => '-i \#',
			       -Option => '-tab -postprocess -anaphora-normal -relation-noun -ne-crf');
	    $this->{knp_w_anaphora} = $knp;
	}
    }

    if ($this->{opt}{knp} || $this->{opt}{syngraph}) {
	my $knp = new KNP (-Command => $this->{opt}{knpcmd},
			   -Rcfile => $this->{opt}{knprc},
			   -JumanCommand => $this->{opt}{jmncmd},
			   -JumanRcfile => $this->{opt}{jmnrc},
			   -JumanOption => '-i \#',
			   -Option => '-tab -dpnd -postprocess');
	$this->{knp} = $knp;
    }
}

sub createSynGraphObject {
    my ($this) = @_;

    if ($this->{opt}{syngraph}) {
	require SynGraph;
	my $syngraph = new SynGraph($this->{opt}{syndbdir}, undef, $this->{opt}{syngraph_option});
	$this->{syngraph} = $syngraph;
    }
}

sub createMaltParserObject {
    my ($this) = @_;

    if ($this->{opt}{english}) {
	require MaltParser;
	$this->{maltparser} = new MaltParser({lemmatize => 1});
    }
}


sub DESTROY {
    my ($this) = @_;
}

sub AddKnpResult {
    my ($this, $doc, $tagName) = @_;

    for my $sentence ($doc->getElementsByTagName($tagName)) { # for each $tagName
	my $jap_sent_flag = $sentence->getAttribute('is_Normal_Sentence');
	$jap_sent_flag = 1 if ($tagName ne 'S');
	next if !$this->{opt}{all} and !$jap_sent_flag; # not Japanese

	if ($this->{opt}{blocktype}) {
	    my $BlockType = $sentence->getAttribute('BlockType');

	    next if $BlockType ne $this->{opt}{blocktype};
	}
	if ($this->{opt}{remove_annotation}) {
	    &remove_annotation_node($sentence);
	}

	my $rawstring;
	for my $s_child_node ($sentence->getChildNodes) {
	    if (!$this->{opt}{recycle_knp}) {
		if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
		    for my $node ($s_child_node->getChildNodes) {
			my $text = $node->string_value;

			next if $text eq '';
			$text =~ s/(?:\n|\r)/ /g;

			# キャッシュをひく
			if ($this->{opt}{use_knpresult_cache}) {
			    my $value = $this->{knpresult_reader}->get($text);

			    # キャッシュがひけた
			    if ($value) {
				my ($file, $address) = split(':', $value);

				$text = &get_knpresult_cache($file, $address);
			    }
			}

			if (defined $this->{opt}{sentence_length_max} && length($text) > $this->{opt}{sentence_length_max}) {
			    print STDERR "Too Long Sentence: $text\n" if ($this->{opt}{verbose});
			    next;
			}

			if ($this->{opt}{usemodule}) {
			    print STDERR "$text\n" if $this->{opt}{debug};

			    # jmn
			    if ($this->{opt}{jmn}) {
				$this->AppendNode($doc, $sentence, $text, 'Juman', $jap_sent_flag);
			    }
			    # SynGraph
			    elsif ($this->{opt}{syngraph}) {
				$this->AppendNode($doc, $sentence, $text, 'SynGraph', $jap_sent_flag);
			    }
			    # knp
			    elsif ($this->{opt}{knp}) {
				$this->AppendNode($doc, $sentence, $text, 'Knp', $jap_sent_flag);
			    }
			    # 英語
			    elsif ($this->{opt}{english}) {
				$this->AppendNode($doc, $sentence, $text, 'CoNLL', $jap_sent_flag);
			    }
			}
		    }
		}
	    }
	    else {
		if ($s_child_node->nodeName eq 'Annotation') {

		    # 埋め込まれている解析結果の種類を取得
		    my $type = $s_child_node->getAttribute('Scheme');

		    if ($type eq 'Knp' || $type eq 'SynGraph') {
			# 解析結果の取得
			my @nodes = $s_child_node->getChildNodes();
			next if (scalar(@nodes) < 1);

			my $annotation = $nodes[0]->string_value;
			# 現在のAnnotation要素を削除する
			$sentence->removeChild($s_child_node);

			if ($this->{opt}{syngraph}) {
			    my @buf;
			    foreach my $line (split(/\n/, $annotation)) {
				next if ($line =~ /^!/);
				# SynGraphのバージョンを消す
				$line =~ s/ *SynGraph:\d+.\d+.*-\d+// if ($line =~ /^#/);
				push(@buf, $line);
			    }

			    my $knp_result = new KNP::Result(join("\n", @buf));
			    $this->AppendNode($doc, $sentence, $knp_result, 'SynGraph', $jap_sent_flag);
			}
			else {
			    print "パラメータの指定が不正です (-recycle_knpオプションを指定時は-syngraphのみ有効です)\n";
			    exit 1;
			}
		    }
		    else {
			print "パラメータの指定が不正です (KNPの解析結果が埋め込まれていない標準フォーマットを対象に-recycle_knpオプションを指定した解析はできません)\n";
			exit 1;
		    }
		}
	    }
	}
    }
}

# ノードを追加する
# $type: Juman or Knp or SynGraph or CoNLL
sub AppendNode {
    my ($this, $doc, $sentence, $text, $type, $jap_sent_flag) = @_;

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
	my $result;
	try {
	    if ((ref $text) =~ /KNP::Result/) {
		$result = $text;
	    } else {
		$text = "# VERSION:\n$text";
		if ($this->{opt}{case} && $jap_sent_flag) {
		    $result = $this->{knp_w_case}->parse_mlist($this->{knp_w_case}->juman($text));
		}
		elsif ($this->{opt}{anaphora} && $jap_sent_flag) {
		    $result = $this->{knp_w_anaphora}->parse_mlist($this->{knp_w_anaphora}->juman($text));
		}
		else {
		    # 格解析,省略解析オプションが指定されていない場合, もしくは日本語文でない場合
		    $result = $this->{knp}->parse_mlist($this->{knp}->juman($text));
		}
		$this->{num_of_knp_use}++;
		if ($this->{num_of_knp_use} > $this->{th_of_knp_use}) {
		    # KNP を close する
		    $this->{num_of_knp_use} = 0;
		    $this->{knp_w_case}->close() if ($this->{opt}{case});
		    $this->{knp_w_anaphora}->close() if ($this->{opt}{anaphora});
		}
	    }

	    return unless $result;

	    if ($type eq 'SynGraph') {
		$result_string = $this->{syngraph}->OutputSynFormat($result, $this->{opt}{regnode_option}, $this->{opt}{syngraph_option});
	    }
	    # knp
	    else {
		$result_string = $result->all;
	    }
	} catch Error with {
	    my $err = shift;
	    print STDERR "Exception at line ",$err->{-line}," in ",$err->{-file}," msg=[",$err->{-text},"]\n";
	    return;
	};
    }
    elsif ($type eq 'CoNLL') { # 英語: CoNLL format
	$result_string = $this->{maltparser}->analyze($text);
	$result_string =~ s/\n\n$/\nEOS\n/;
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

    my $scheme;
    if ($this->{opt}{syngraph}) {
	$scheme = 'SynGraph';
    }
    elsif ($this->{opt}{jmn}) {
	$scheme = 'Juman';
    }
    elsif ($this->{opt}{knp}) {
	$scheme = 'Knp';
    }
    elsif ($this->{opt}{english}) {
	$scheme = 'CoNLL';
    }

    if ($this->{opt}{jmn} or $this->{opt}{knp} or $this->{opt}{syngraph}) {
	open (F, "<:encoding(euc-jp)", $inputfile) or die; # use 'euc-jp' for Japanese
    }
    else {
	open (F, $inputfile) or die;
    }

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
		    my $newchild = $doc->createElement('Annotation');
		    $newchild->setAttribute('Scheme', $scheme);
		    my $cdata = $doc->createCDATASection($result);
		    $newchild->appendChild($cdata);

		    if ($this->{opt}{remove_annotation}) {
			&remove_annotation_node($sentence);
		    }

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

sub remove_annotation_node {
    my ($sentence) = @_;

    for my $s_child_node ($sentence->getChildNodes) {
	if ($s_child_node->nodeName eq 'Annotation') {
	    $sentence->removeChild($s_child_node);
	}
    }
}

sub get_knpresult_cache {
    my ($file, $address) = @_;

    my $z = new IO::Uncompress::Gunzip $file;

    $z->seek($address, 0);

    my $buf;
    while (my $line = $z->getline) {
	$buf .= $line;

	last if ($line =~ /EOS/);
    }
    $z->close;

    return new KNP::Result(Encode::decode('euc-jp', $buf));
}

1;
