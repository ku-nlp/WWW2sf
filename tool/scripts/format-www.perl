#!/usr/bin/env perl

# WWWから収集した文を整形, 削除, S-ID付与

# $Id$

use Getopt::Long;
use strict;
use vars qw(%opt @enu);

@enu = ("０", "１", "２", "３", "４", "５", "６", "７", "８", "９");

GetOptions(\%opt, 'head:s', 'include_paren', 'divide_paren', 'pagenum=i');
# --include_paren: 括弧を削除しない
# --divide_paren: 括弧を別文として出力
# --pagenum: 開始ページ番号を指定

$opt{'include_paren'} = 1 if $opt{'divide_paren'};

my ($head, $site, $file, $fileflag, $count, $url, $comment);
my ($sid, $sentence) = @_;
my (@char_array, @check_array, $i, $j, $flag);
my ($enu_num, $paren_start, $paren_level, $paren_str);

if (defined($opt{head})) {
    if ($opt{head}) {
	$head = $opt{head};
    }
    else {
	my ($tmp_filename);
	if ($ARGV[0] =~ /([^\/]+)\/([^\/]+)$/) {
	    ($head, $tmp_filename) = ($1, $2);
	    $head = (split(/\./, $head))[0]; # tsubame00.kototoi.org => tsubame00
	    ($site) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
	}
	else {
	    ($tmp_filename) = ($ARGV[0] =~ /([^\/]+)$/);
	    ($head) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
	}
    }
}
else {
    my ($tmp_filename) = ($ARGV[0] =~ /([^\/]+)$/);
    ($head) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
}

$file = $opt{pagenum} - 1 if $opt{pagenum};

while (<>) {
    chomp;

    if (/^\<PAGE(?:\s*URL=\"([^\"]+)\")?\>/) {
	$comment .= "URL:$1" if $1;
	$file++;
	$fileflag = 0;
	$count = 0;
	next;
    }
    elsif (/^\<\/PAGE\>/) {
	$file-- if $fileflag == 0;
	$comment = undef;
	next;
    }
    else {
	$fileflag = 1;
    }

    $count++;
    $sid = defined($site) ? "$head-$site-$file-$count" : "$head-$file-$count";
    $sid .= '-01' if $opt{'divide_paren'}; # 括弧を別文に分けるとき
    $sentence = $_;
    @char_array = ();

    # 字単位に分割 (EUC)
    while (/([^\x80-\xfe]|[\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/g) {
	push(@char_array, $1);
    }

     # "【"，"◇"，"▽"，"●"，"＜"，"《"で始まる文は全体を削除
    if (!$opt{'include_paren'} && $sentence =~ /^(　)*(□|■|◇|◆|▽|△|▼|▲|○|◎|●|〇|◯|★|☆|・|＜|《|【|［)/) {
	print "# S-ID:$sid 全体削除:$sentence\n";
	next;
    }

    # "。"が内部に5回以上または長さ512バイト以上(多くは引用文)は全体を削除
    if ($sentence =~ /^.+。.+。.+。.+。.+。.+/ ||
	length($sentence) >= 512) {
	print "# S-ID:$sid 全体削除:$sentence\n";
	next;
    }

    # "………"だけの文は全体を削除
    if ($sentence =~ /^(…)+$/) {
	print "# S-ID:$sid 全体削除:$sentence\n";
	next;
    }

    # "｜"を含む文は全体を削除 (メニューなど)
    if (&CheckChar(\@char_array, '｜|┃')) {
	print "# S-ID:$sid 全体削除:$sentence\n";
	next;
    }

    # すべて漢字なら全体を削除
    if (&CheckKanji(\@char_array)) {
	print "# S-ID:$sid 全体削除:$sentence\n";
	next;
    }


    for ($i = 0; $i < @char_array; $i++) {
	$check_array[$i] = 1;
    }

    # 文頭の"　"は削除
    $check_array[0] = 0 if ($char_array[0] eq "　");

    # 文頭の"　――"は削除
    if ($sentence =~ "^　――") {
	$check_array[1] = 0;
	$check_array[2] = 0;
    }

    # "（…）"の削除，ただし，"（１）"，"（２）"の場合は残す
    $enu_num = 1;
    $paren_start = -1;
    $paren_level = 0;
    $paren_str = "";

    for ($i = 0; $i < @char_array; $i++) {
	if ($char_array[$i] eq "（") {
	    $paren_start = $i if ($paren_level == 0);
	    $paren_level++;
	}
	elsif ($char_array[$i] eq "）") {
	    $paren_level--;
	    if ($paren_level == 0) {
		if ($paren_str eq $enu[$enu_num]) {
		    $enu_num++;
		}
		else {
		    for ($j = $paren_start; $j <= $i; $j++) {
			$check_array[$j] = 0;
		    }
		}
		$paren_start = -1;
		$paren_str = "";
	    }
	}
	else {
	    $paren_str .= $char_array[$i] if ($paren_level != 0);
	}
    }
    # print STDERR "enu_num(+1) = $enu_num\n" if ($enu_num > 1);

    # "＝…＝"の削除，ただし間に"，"がくればRESET

    $paren_start = -1;
    $paren_level = 0;
    $paren_str = "";
    for ($i = 0; $i < @char_array; $i++) {
	if ($check_array[$i] == 0) {
	    ; # "（…）"の中はスキップ
	} elsif ($char_array[$i] eq "＝") {
	    if ($paren_level == 0) {
		$paren_start = $i; 
		$paren_level++;
	    } 
	    elsif ($paren_level == 1) {
		for ($j = $paren_start; $j <= $i; $j++) {
		    $check_array[$j] = 0;
		}
		$paren_start = -1;
		$paren_level = 0;
		$paren_str = "";
	    }
	}
	elsif ($char_array[$i] eq "、") {
	    if ($paren_level == 1) {

		# "＝…"となっていても，"、"がくればRESET
		# 例 "「中高年の星」＝米長と、若き天才＝羽生"
		# print STDERR "＝…，…＝RESET:$paren_str:$sentence\n";

		$paren_start = -1;
		$paren_level = 0;
		$paren_str = "";
	    }
	}
	else {
	    $paren_str .= $char_array[$i] if ($paren_level == 1);
	}
    }

    # "＝…(文末)"で，文末に"。"がないか，"…"が"写真。"であれば除削
    if ($paren_level == 1) {
	if ($paren_str =~ /^写真/ || $paren_str !~ /。$/) {
	    for ($j = $paren_start; $j < $i; $j++) {
		$check_array[$j] = 0;
	    }
	    # print STDERR "＝…DELETE:$paren_str:$sentence\n";
	} else {
	    # print STDERR "＝…KEEP:$paren_str:$sentence\n";
	}
    }

    $flag = 0;
    for ($i = 0; $i < @char_array; $i++) {
	if ($check_array[$i] == 1) {
	    $flag = 1;
	    last;
	}			# 有効部分がなければ全体削除
    }
    if (!$opt{'include_paren'} && $enu_num > 2) {		# （１）（２）とあれば全体削除
	# print STDERR "# S-ID:$sid 全体削除:$sentence\n";
	$flag = 0;
    }

    if ($flag == 0) {
	if ($opt{'include_paren'}) {
	    print "# S-ID:$sid\n$sentence\n";
	}
	else {
	    print "# S-ID:$sid 全体削除:$sentence\n";
	}
    } else {
	print "# S-ID:$sid $comment";

	unless ($opt{'include_paren'}) { # 括弧を部分削除してS-ID行に出す場合
	    for ($i = 0; $i < @char_array; $i++) {
		if ($check_array[$i] == 0) {
		    print " 部分削除:$i:" 
			if ($i == 0 || $check_array[$i-1] == 1);
		    print $char_array[$i];
		}
	    }
	}

	print "\n";

	for ($i = 0; $i < @char_array; $i++) {
	    if ($check_array[$i] == 1 || ($opt{'include_paren'} && !$opt{'divide_paren'})) {
		print $char_array[$i];
	    }
	}
	print "\n";

	# 括弧を別文として出力する場合
	if ($opt{'divide_paren'}) {
	    $paren_start = -1;
	    my $paren_start_char = '';
	    my $paren_count = 2;
	    my $current_sid;
	    for ($i = 0; $i < @char_array; $i++) {
		if ($check_array[$i] == 0) {
		    if ($i == 0 || $check_array[$i-1] == 1) {
			$current_sid = $sid;
			$current_sid =~ s/01$/sprintf("%02d", $paren_count)/e;
			$paren_start = $i;
			$paren_start_char = $char_array[$i];
		    }
		}
		elsif ($paren_start >= 0) {
		    my $paren_type = &CheckParenType([@char_array[$paren_start + 1 .. $i - 2]]);
		    print "# S-ID:$current_sid 括弧タイプ:$paren_type 括弧位置:$paren_start 括弧始:$paren_start_char 括弧終:$char_array[$i - 1]\n";
		    print join('', @char_array[$paren_start + 1 .. $i - 2]), "\n";
		    $paren_start = -1;
		    $paren_count++;
		}
	    }

	    # 最後のひとつ
	    if ($paren_start >= 0) {
		my $paren_type = &CheckParenType([@char_array[$paren_start + 1 .. $i - 2]]);
		print "# S-ID:$sid 括弧タイプ:$paren_type 括弧位置:$paren_start 括弧始:$paren_start_char 括弧終:$char_array[$i - 1]\n";
		print join('', @char_array[$paren_start + 1 .. $i - 2]), "\n";
	    }
	}
    }
}

# すべて漢字なら1
sub CheckKanji {
    my ($list) = @_;

    for my $str (@$list) {
	if ($str =~ /^[\x00-\xaf]/) {
	    return 0;
	}
    }

    return 1;
}

# すべてひらがななら1
sub CheckHiragana {
    my ($list) = @_;

    for my $str (@$list) {
	if ($str !~ /^\xa4/) {
	    return 0;
	}
    }

    return 1;
}

# すべて数字なら1
sub CheckNum {
    my ($list) = @_;

    for my $str (@$list) {
	if ($str !~ /^\xa3[\xb0-\xb9]$/) {
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
