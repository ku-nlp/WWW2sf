package SentenceFormatter;

# 文をチェックして、全体削除、括弧の検出などを行う
# method: FormatSentence

# 以下のオプションはnewに渡す
# --include_paren: 括弧は処理せず、元の文に含める
# --divide_paren: 括弧を原文から取り除き、別の文として分割する
#                 原文のIDに"-01"を付加し、括弧文のIDは"-02", "-03",.. となる
#                 (括弧がなくても、原文のIDに"-01"が付加される)

# $Id$

use utf8;
use strict;

our @enu = ('０', '１', '２', '３', '４', '５', '６', '７', '８', '９');

sub new {
    my ($this, $opt) = @_;

    $this = {opt => $opt};

    bless $this;
}

sub FormatSentence {
    my ($this, $sentence, $sid) = @_;
    my (@check_array, $comment, $new_sentence, @paren_sentences);

    $sid .= '-01' if $this->{opt}{'divide_paren'}; # 括弧を別文に分けるとき

    # 字単位に分割
    my (@char_array) = split(//, $sentence);

     # "【"，"◇"，"▽"，"●"，"＜"，"《"で始まる文は全体を削除
    if ($sentence =~ /^(　)*(□|■|◇|◆|▽|△|▼|▲|○|◎|●|〇|◯|★|☆|・|＜|《|【|［)/) { # ］
	return ({sid => $sid, comment => "全体削除:$sentence", sentence => undef});
    }

    # "。"が内部に5回以上または長さ256文字以上(多くは引用文)は全体を削除
    if ($sentence =~ /^.+。.+。.+。.+。.+。.+/ || length($sentence) >= 256) {
	return ({sid => $sid, comment => "全体削除:$sentence", sentence => undef});
    }

    # "………"だけの文は全体を削除
    if ($sentence =~ /^(…)+$/) {
	return ({sid => $sid, comment => "全体削除:$sentence", sentence => undef});
    }

    # "｜"を含む文は全体を削除 (メニューなど)
    if (&CheckChar(\@char_array, '｜|┃')) {
	return ({sid => $sid, comment => "全体削除:$sentence", sentence => undef});
    }

    # すべて漢字なら全体を削除
    if (&CheckKanji(\@char_array)) {
	return ({sid => $sid, comment => "全体削除:$sentence", sentence => undef});
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
	}                       # 有効部分がなければ全体削除
    }
    if (!$this->{opt}{'include_paren'} && $enu_num > 2) {         # （１）（２）とあれば全体削除
	$flag = 0;
    }

    if ($flag == 0) {
	if ($this->{opt}{'include_paren'}) {
	    return ({sid => $sid, comment => "全体削除:$sentence", sentence => $sentence});
	}
	else {
	    return ({sid => $sid, comment => "全体削除:$sentence", sentence => undef});
	}
    }
    else {
	unless ($this->{opt}{'include_paren'}) { # 括弧を部分削除してS-ID行に出す場合
	    for (my $i = 0; $i < @char_array; $i++) {
		if ($check_array[$i] == 0) {
		    $comment .= " 部分削除:$i:" if $i == 0 || $check_array[$i-1] == 1;
		    $comment .= $char_array[$i];
		}
	    }
	}

	for (my $i = 0; $i < @char_array; $i++) {
	    if ($check_array[$i] == 1 || ($this->{opt}{'include_paren'} && !$this->{opt}{'divide_paren'})) {
		$new_sentence .= $char_array[$i];
	    }
	}

	# 括弧を別文として出力する場合
	if ($this->{opt}{'divide_paren'}) {
	    $paren_start = -1;
	    my $paren_start_char = '';
	    my $paren_count = 2;
	    my $current_sid;
	    for (my $i = 0; $i < @char_array; $i++) {
		if ($check_array[$i] == 0) {
		    if ($i == 0 || $check_array[$i - 1] == 1) {
			$current_sid = $sid;
			$current_sid =~ s/01$/sprintf("%02d", $paren_count)/e;
			$paren_start = $i;
			$paren_start_char = $char_array[$i]; # 括弧始
		    }
		}
		elsif ($paren_start >= 0) {
		    my $paren_type = &CheckParenType([@char_array[$paren_start + 1 .. $i - 2]]);
		    push(@paren_sentences, {sid => $current_sid, 
					    comment => "括弧タイプ:$paren_type 括弧位置:$paren_start 括弧始:$paren_start_char 括弧終:$char_array[$i - 1]", 
					    sentence => join('', @char_array[$paren_start + 1 .. $i - 2])});
		    $paren_start = -1;
		    $paren_count++;
		}
	    }

	    # 最後のひとつ
	    if ($paren_start >= 0) {
		my $paren_type = &CheckParenType([@char_array[$paren_start + 1 .. scalar(@char_array) - 1]]);
		push(@paren_sentences, {sid => $current_sid, 
					comment => "括弧タイプ:$paren_type 括弧位置:$paren_start 括弧始:$paren_start_char", 
					sentence => join('', @char_array[$paren_start + 1 .. scalar(@char_array) - 1])});
	    }
	}
    }

    return ({sid => $sid, comment => $comment, sentence => $new_sentence}, @paren_sentences);
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

# すべてひらがななら1
sub CheckHiragana {
    my ($list) = @_;

    for my $str (@$list) {
	if ($str !~ /^p{Hiragana}/) {
	    return 0;
	}
    }

    return 1;
}

# すべて数字なら1
sub CheckNum {
    my ($list) = @_;

    for my $str (@$list) {
	if ($str !~ /^[０-９]/) {
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

# 括弧タイプを判定
sub CheckParenType {
    my ($chrs) = @_;

    if (&CheckNum($chrs)) {
	return '年齢';
    }
    elsif (&CheckHiragana($chrs)) {
	return '読み';
    }
    else {
	return 'その他';
    }
}

1;
