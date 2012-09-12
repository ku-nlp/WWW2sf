package AddKNPResult;

# $Id$

# 文のみからなる標準フォーマットにJuman/KNP/SynGraphの解析結果をうめこむモジュール

use utf8;
use strict;
use Error qw(:try);
use Data::Dumper;

our %pf_order = (id => 0, head => 1, category => 2, feature => 3, dpndtype => 4); # print order of phrase attributes
our %wf_order = (id => 0, str => 1, lem => 2, read => 3, pos => 4, repname => 5, conj => 6, feature => 99); # print order of word attributes
our %synnodesf_order = (head => 0, phraseid => 1);
our %synnodef_order = (wordid => 0, synid => 1, score => 2);
our %case_map = ('ガ' => 'ga', 'ヲ' => 'wo', 'ニ' => 'ni', 'カラ' => 'kara', 'ヘ' => 'he', 'ヨリ' => 'yori', 'ト' => 'to', 'デ' => 'de', 'ノ' => 'no', 'ガ２' => 'ga2');

sub new {
    my ($clazz, $opt) = @_;

    if ($opt->{embed_result_in_xml}) {
	$opt->{syngraph_option}{word_basic_unit} = 1;
	$opt->{syngraph_option}{get_content_word_ids} = 1;
    }

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
			next if ($text =~ /[０１２３４５６７８９　]{10,}/);

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

# KNPオブジェクトをXML化する
sub Annotation2XMLforKNP {
    my ($this, $writer, $result, $annotation_node, $option) = @_;

    my $version = $result->version;

    my $JUMAN_tool_node = $writer->createElement('Annotation');
    $JUMAN_tool_node->setAttribute('tool', 'JUMAN');
    $JUMAN_tool_node->setAttribute('version', '7.0'); # とりあえず
    $annotation_node->appendChild($JUMAN_tool_node);

    my $KNP_tool_node = $writer->createElement('Annotation');
    $KNP_tool_node->setAttribute('tool', 'KNP');
    $KNP_tool_node->setAttribute('version', $version);
    $annotation_node->appendChild($KNP_tool_node);

    if (!$option->{simple}) {
	my ($prob) = ($result->comment =~ /SCORE:([\-\d\.]+)/);
	$annotation_node->setAttribute('score', $prob);
    }

    my $abs_wnum = 0;
    my $pnum = 0;

    my %head_id;
    for my $tag ($result->tag) {
	for my $mrph (reverse $tag->mrph) {
	    if ($mrph->fstring =~ /<(?:準)?内容語>/) {
		$head_id{$tag->id} = $mrph->id;
		last;
	    }
	}
    }

    for my $bnst ($result->bnst) {
	my @tags = $this->{opt}{bnst} ? ( $bnst ) : $bnst->tag_list;
	my $bnst_end_pnum = $pnum + @tags - 1;
	for my $tag_num (0 .. @tags - 1) {
	    my $bnst_start_flag = 1 if $tag_num == 0;
	    my $tag = $tags[$tag_num];
	    my (%pf);

	    $pf{id} = 'c' . $pnum;

	    # 係り先
	    if ($tag->parent) {
		$pf{head} = 'c' . $tag->parent->id;
		$pf{type} = $tag->dpndtype;
	    }
	    else {
		$pf{head} = 'c' . '-1';
		$pf{type} = 'D';
	    }

	    # feature processing
	    my $fstring = $tag->fstring;

	    if (!$option->{simple}) {
		# phrase category
		# 判定詞は 用言:判
		if ($fstring =~ s/<(用言[^>]*)>//) {
		    $pf{category} = $1;
		}
		elsif ($fstring =~ s/<(体言[^>]*)>//) {
		    $pf{category} = $1;
		}
		else {
		    $pf{category} = 'NONE';
		}

		# feature残り
		$pf{feature} = $this->{opt}{filter_fstring} ? &filter_fstring($fstring) : $fstring;

		# 文節
		$pf{feature} .= sprintf("<文節:%d-%d>", $pnum, $bnst_end_pnum) if $bnst_start_flag;

		$pf{feature} .= '...' if $this->{opt}{filter_fstring};
	    }

	    my $phrase_node = $writer->createElement('Chunk');
	    for my $key (sort {$pf_order{$a} <=> $pf_order{$b}} keys %pf) {
		$phrase_node->setAttribute($key, $pf{$key});
	    }

 	    # synnode
	    my %synnode;
	    if (!$this->{opt}{bnst}) { 
		for my $synnode ($tag->synnode) {
		    my %synnode_f;
		    my $word_id = $synnode->tagid; # 要修正
		    my $last_word_id = (split(',', $word_id))[-1]; # 最後の単語idにsynnodeを付与する
		    $synnode_f{synid} = $synnode->synid;
		    $synnode_f{score} = $synnode->score;
		    # 例: t0 t0,t1など
		    my @out_word_ids;
		    for my $word_id (split(',', $word_id)) {
			push @out_word_ids, 't' . $word_id;
		    }
		    $synnode_f{wordid} = join(',', @out_word_ids);

		    push @{$synnode{$last_word_id}}, { f => \%synnode_f };
		}
	    }
	    # 格解析結果
	    # 見る:動80:ガ/E/不特定:人/-/-/-;ヲ/C/出来上がり/2/0/tsubame00-0000000100-12-5;外の関係/U/-/-/-/-;ノ/U/-/-/-/-
	    my ($case_analysis_result_string, $tag_id) = $this->GetCaseAnalysisResultString($fstring, $bnst);
	    my %case_analysis_result;

	    if ($case_analysis_result_string) {
		my $case_components = (split(':', $case_analysis_result_string))[2];
		for my $cc (split(';', $case_components)) {
		    my ($case, $type, $midasi, $tid, $sid, $id) = split('/', $cc);
		    next if $tid eq '-';
		    if (defined $case_map{$case}) {
			$case_analysis_result{$case_map{$case}} = $tid;
		    }
		}
	    }

	    # word
	    for my $mrph ($tag->mrph) {

		$fstring = $mrph->fstring;

		# 代表表記
		my $rep;
		if ($fstring =~ /<代表表記:([^\s\"\>]+)/) {
		    $rep = $1;
		}
		elsif ($fstring =~ /<疑似代表表記:([^\s\"\>]+)/) {
		    $rep = $1;
		}
		else {
		    $rep = $mrph->genkei . '/' . $mrph->genkei;
		}

		# 活用
		my $conj;
		if ($mrph->katuyou1 ne '*') {
		    $conj = $mrph->katuyou1 . ':' . $mrph->katuyou2;
		}
		else {
		    $conj = '';
		}

		# 内容語かどうか
		my $content_p;
		if ($fstring =~ /<(?:準)?内容語>/) {
		    $content_p = 1;
		}
		else {
		    $content_p = 0;
		}

		my %wf = (surf => $mrph->midasi,
			  orig => $mrph->genkei,
			  read => $mrph->yomi,
			  repname => $rep, 
			  pos1 => $mrph->hinsi,
			  id => 't' . $abs_wnum,
			 );
		if (!$option->{simple}) {
		    $wf{content_p} = $content_p;
		    $wf{conj} = $conj;
		    $wf{feature} = $this->{opt}{filter_fstring} ? &filter_fstring($fstring) . '...' : $fstring;
		}

		$wf{pos2} .= $mrph->bunrui if ($mrph->bunrui ne '*');
		$wf{pos3} .= $mrph->katuyou1 if ($mrph->katuyou1 ne '*');
		$wf{pos4} .= $mrph->katuyou2 if ($mrph->katuyou2 ne '*');

		my $word_node = $writer->createElement('Token');
		for my $key (sort {$wf_order{$a} <=> $wf_order{$b}} keys %wf) {
		    $word_node->setAttribute($key, $wf{$key});
		}

		# 格解析結果の付与
		if ($content_p && %case_analysis_result && ($this->{opt}{bnst} && $head_id{$tag_id} eq $abs_wnum || !$this->{opt}{bnst})) {
		    my $predicate_node = $writer->createElement('Predicate');
		    for my $case (keys %case_analysis_result) {
			$predicate_node->setAttribute($case, $head_id{$case_analysis_result{$case}});
		    }
		    $word_node->appendChild($predicate_node);
		}

		for my $synnode (@{$synnode{$abs_wnum}}) {
		    my $syn_node = $writer->createElement('synnode');
		    for my $key (sort {$synnodef_order{$a} <=> $synnodef_order{$b}} keys %{$synnode->{f}}) {
			$syn_node->setAttribute($key, $synnode->{f}{$key});
		    }
		    $word_node->appendChild($syn_node);
		}

		$phrase_node->appendChild($word_node);
		$abs_wnum++;
	    }
	    $annotation_node->appendChild($phrase_node);
	    $pnum++;
	}
    }

    return $annotation_node;
}

sub GetCaseAnalysisResultString {
    my ($this, $fstring, $bnst) = @_;

    if ($this->{opt}{bnst}) {
	for my $tag (reverse $bnst->tag) {
	    if ($tag->fstring =~ /<格解析結果:([^\s\"\>]+)/) {
		return ($1, $tag->id);
	    }
	}
    }
    else {
	if ($fstring =~ /<格解析結果:([^\s\"\>]+)/) {
	    return $1;
	}
    }
}

# CoNLL結果をXML化する
sub Annotation2XMLforCoNLL {
    my ($this, $writer, $result, $annotation_node) = @_;

    $annotation_node->setAttribute('tool', "CoNLL");

    for my $line (split("\n", $result)) {
	last if $line =~ /^EOS/;
	my @line = split(/\t/, $line);
	my %pf = (id => $line[0], head => $line[6], dpndtype => $line[7]);
	my %wf = (id => $line[0], str => $line[1], lem => $line[2], pos => $line[3]);

	my $phrase_node = $writer->createElement('phrase');
	for my $key (sort {$pf_order{$a} <=> $pf_order{$b}} keys %pf) {
	    $phrase_node->setAttribute($key, $pf{$key});
	}

	my $word_node = $writer->createElement('word');
	for my $key (sort {$wf_order{$a} <=> $wf_order{$b}} keys %wf) {
	    $word_node->setAttribute($key, $wf{$key});
	}

	$phrase_node->appendChild($word_node);
	$annotation_node->appendChild($phrase_node);
    }

    return $annotation_node;
}

sub filter_fstring {
    my ($str) = @_;

    my (@f);
    if ($str =~ /(<係:[^>]+>)/) {
	push(@f, $1);
    }
    elsif ($str =~ /(<(?:自立|接頭|付属|内容語|準内容語)>)/) {
	push(@f, $1);
    }

    return join('', @f);
}

# ノードを追加する
# $type: Juman or Knp or SynGraph or CoNLL
sub AppendNode {
    my ($this, $doc, $sentence, $text, $type, $jap_sent_flag) = @_;

    my $newchild = $doc->createElement('Annotation');
    $newchild->setAttribute('Scheme', $type);

    # 言語解析結果
    my $result_string = $this->linguisticAnalysis($text, $type, $jap_sent_flag);

    if ($this->{opt}{embed_result_in_xml}) { # 解析結果をXMLとして埋め込む場合
	if ($type eq 'Juman') {
	    die "Embedding the result of JUMAN in XML is not supported.\n";
	}
	elsif ($type eq 'CoNLL') {
	    $this->Annotation2XMLforCoNLL($doc, $result_string, $newchild); # Annotation($newchild)を渡して中で追加
	}
	else {
	    if ($result_string) {
		my $result = new KNP::Result($result_string);
		$this->Annotation2XMLforKNP($doc, $result, $newchild); # Annotation($newchild)を渡して中で追加
	    }
	}
    }
    else {
	# 言語解析結果を収める新しい NODE(CDATA) を作成
	my $cdata = $doc->createCDATASection($result_string);
	# 新規に作成したNODEへ追加
	$newchild->appendChild($cdata);
    }

    # 本体へ追加
    $sentence->appendChild($newchild);
}

# typeに対応したツールで言語解析を行う
# $type: Juman or Knp or SynGraph or CoNLL
sub linguisticAnalysis {
    my ($this, $text, $type, $jap_sent_flag, $returnKnpObj) = @_;

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
		if ($returnKnpObj) {
		    return $result;
		} else {
		    $result_string = $result->all;
		}
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

    return $result_string;
}

sub ReadResult {
    my ($this, $doc, $inputfile) = @_;

    my @title = $doc->getElementsByTagName('Title');
    my @sentences = $doc->getElementsByTagName('S');
    unshift(@sentences, $title[0]) if (@title);
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
