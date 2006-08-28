#!/usr/bin/env perl

# WWWから収集した文を整形, 削除, S-ID付与

# Input : XML (utf8)
# Output: XML (utf8)

# $Id$

use XML::DOM;
use Encode qw(decode);
use encoding 'utf8';
use strict;

our @enu = ('０', '１', '２', '３', '４', '５', '６', '７', '８', '９');

my ($buf);
while (<STDIN>) {
    $buf .= $_;
}

my $parser = new XML::DOM::Parser;
my $doc = $parser->parse($buf);
&xml_check_sentence($doc);
#print decode('utf8', $doc->toString());
print $doc->toString();
$doc->dispose();


sub xml_check_sentence {
    my ($doc) = @_;
    my $count = 1;

    my $sentences = $doc->getElementsByTagName('S');
    for my $i (0 .. $sentences->getLength - 1) { # for each S
	my $sentence = $sentences->item($i);
	if ($sentence->getAttribute('is_Japanese') == 0) { # do not process non-Japanese
	    $sentence->setAttribute('is_Japanese_Sentence', '0');
	    $sentence->setAttribute('Id', $count++);
	    next;
	}
	for my $s_child_node ($sentence->getChildNodes) {
	    if ($s_child_node->getNodeName eq 'RawString') { # one of the children of S is Text
		for my $node ($s_child_node->getChildNodes) {
		    my ($log, $new_sentence) = &check_sentence($node->getNodeValue);
		    if ($new_sentence) {
			$node->setNodeValue($new_sentence);
			$sentence->setAttribute('is_Japanese_Sentence', '1');
		    }
		    else {
			$sentence->setAttribute('is_Japanese_Sentence', '0');
			$node->setNodeValue('');
		    }
		    $sentence->setAttribute('Id', $count++);
		    $sentence->setAttribute('Log', $log);
		}
	    }
	}
    }
}

sub check_sentence {
    my ($sentence) = @_;
    my (@check_array, $comment, $new_sentence);

    # 字単位に分割
    my (@char_array) = split(//, $sentence);

     # "【"，"◇"，"▽"，"●"，"＜"，"《"で始まる文は全体を削除
    if ($sentence =~ /^(　)*(□|■|◇|◆|▽|△|▼|▲|○|◎|●|〇|◯|★|☆|・|＜|《|【|［)/) { # ］
	return ("全体削除:$sentence", undef);
    }

    # "。"が内部に5回以上または長さ256文字以上(多くは引用文)は全体を削除
    if ($sentence =~ /^.+。.+。.+。.+。.+。.+/ || length($sentence) >= 256) {
	return ("全体削除:$sentence", undef);
    }

    # "………"だけの文は全体を削除
    if ($sentence =~ /^(…)+$/) {
	return ("全体削除:$sentence", undef);
    }

    # "｜"を含む文は全体を削除 (メニューなど)
    if (&CheckChar(\@char_array, '｜|┃')) {
	return ("全体削除:$sentence", undef);
    }

    # すべて漢字なら全体を削除
    if (&CheckKanji(\@char_array)) {
	return ("全体削除:$sentence", undef);
    }

    for (my $i = 0; $i < @char_array; $i++) {
	$check_array[$i] = 1;
    }

    # 文頭の'　'は削除
    $check_array[0] = 0 if ($char_array[0] eq '　');

    # 文頭の'　――'は削除
    if ($sentence =~ /^　――/) {
	$check_array[1] = 0;
	$check_array[2] = 0;
    }

    # '（…）'の削除，ただし，'（１）'，'（２）'の場合は残す
    my $enu_num = 1;
    my $paren_start = -1;
    my $paren_level = 0;
    my $paren_str = '';
    for (my $i = 0; $i < @char_array; $i++) {
	if ($char_array[$i] eq '（') {
	    $paren_start = $i if $paren_level == 0;
	    $paren_level++;
	}
	elsif ($char_array[$i] eq '）') {
	    $paren_level--;
	    if ($paren_level == 0) {
		if ($paren_str eq $enu[$enu_num]) {
		    $enu_num++;
		}
		else {
		    for (my $j = $paren_start; $j <= $i; $j++) {
			$check_array[$j] = 0;
		    }
		}
	    $paren_start = -1;
	    $paren_str = '';
	    }
	}
	else {
	    $paren_str .= $char_array[$i] if $paren_level != 0;
	}
    }

    # '＝…＝'の削除，ただし間に'、'がくればRESET

    $paren_start = -1;
    $paren_level = 0;
    $paren_str = '';
    for (my $i = 0; $i < @char_array; $i++) {
	if ($check_array[$i] == 0) {
	    ; # '（…）'の中はスキップ
	}
	elsif ($char_array[$i] eq '＝') {
	    if ($paren_level == 0) {
		$paren_start = $i;
		$paren_level++;
	    }
	    elsif ($paren_level == 1) {
		for (my $j = $paren_start; $j <= $i; $j++) {
		    $check_array[$j] = 0;
		}
		$paren_start = -1;
		$paren_level = 0;
		$paren_str = '';
	    }
	}
	elsif ($char_array[$i] eq '、') {
	    if ($paren_level == 1) {

		# "＝…"となっていても，"、"がくればRESET
		# 例 "「中高年の星」＝米長と、若き天才＝羽生"
		# print STDERR "＝…，…＝RESET:$paren_str:$sentence\n";

		$paren_start = -1;
		$paren_level = 0;
		$paren_str = '';
	    }
	}
	else {
	    $paren_str .= $char_array[$i] if $paren_level == 1;
	}
    }

    # '＝…(文末)'で，文末に'。'がないか，'…'が'写真。'であれば除削
    if ($paren_level == 1) {
	if ($paren_str =~ /^写真/ || $paren_str !~ /。$/) {
	    for (my $j = $paren_start; $j < @char_array; $j++) {
		$check_array[$j] = 0;
	    }
	}
    }

    my $flag = 0;
    for (my $i = 0; $i < @char_array; $i++) {
	if ($check_array[$i] == 1) {
	    $flag = 1;
	    last;
	}			# 有効部分がなければ全体削除
    }
    if ($enu_num > 2) {		# （１）（２）とあれば全体削除
	$flag = 0;
    }

    if ($flag == 0) {
	return ("全体削除:$sentence", undef);
    }
    else {
	for (my $i = 0; $i < @char_array; $i++) {
	    if ($check_array[$i] == 0) {
		$comment .= " 部分削除:$i:" if $i == 0 || $check_array[$i-1] == 1;
		$comment .= $char_array[$i];
	    }
	}

	for (my $i = 0; $i < @char_array; $i++) {
	    $new_sentence .= $char_array[$i] if $check_array[$i] == 1;
	}
    }

    return ($comment, $new_sentence);
}

# すべて漢字なら1
sub CheckKanji {
    my ($list) = @_;

    for my $str (@$list) {
	if ($str !~ /^\p{Han}$/) {
	    return 0;
	}
    }

    return 1;
}

# 指定された文字パターンにマッチするなら1
sub CheckChar {
    my ($list, $pat) = @_;

    for my $str (@$list) {
	if ($str =~ /^(?:$pat)$/) {
	    return 1;
	}
    }
    return 0;
}
