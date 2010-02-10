#$Id$

# 入力された論文から参考文献、謝辞等を分割するプログラム
# Mainの関数はDividePaper($input, $keys)
# $inputを$keysで指定されたキーで分割する(複数マッチした場合は最後尾のマッチで分割)

# $keysの書式は以下のとおり
#   KEY1 => [],  # 先頭4文字までの間にNEGLが挿入されていても良いキー (e.g. ["参考文献", "文献＋pp"])
#   KEY2 => [],  # NEGLの挿入を認めないキー (e.g. "[Rr]eferences? 1", "[Rr]eference＋pp\\\.")
#   NEGL => "",  # KEY1の間に挿入を許す文字列 (e.g. "[ .,\'　]")
#   MISC => ""}; # KEYの前方に出現した場合に分割の後方に含める雑多な文字列 (e.g. "[ <\[〔【]")
# "＋"が含まれているKEYは"＋"以下(sub_key)が離れていも良いが後方に出現していることが必要

package DividePaper;

use strict;
use utf8;

sub new {
    my ($this) = @_;

    $this = {};

    bless $this;
    return $this;
}

sub DividePaper {

    my ($this, $input, $keys) = @_;   
    my ($flag, $output, $mem);

    # 入力された$keysから正規表現を生成
    my $regs = &MakeKey($keys);

    for my $line (split('\n', $input)) {

	# 入力行が$keysを含む場合
	if (my ($front, $rear) = &CheckKey($line, $regs)) {

	    # すでに$flagが立っている場合は$memを$outputに追加
	    $output .= $mem if ($flag);
	    
	    # $frontを$outputに追加、$rearは$memに保存
	    $output .= $front . "\n";
	    $mem = $rear . "\n";
	    
	    # flagを立てる
	    $flag = 1;
	}
	elsif ($flag) {
	    # flagが立っている場合は$memに追加
	    $mem .= $line . "\n";
	}
	else {
	    # flagが立っていない場合は$ouputに追加
	    $output .= $line . "\n";
	}
    }
    return ($output, $mem);
}

# マッチ用の正規表現を生成する関数
sub MakeKey {
    
    my ($keys) = @_;
    my ($negl, $misc) = ($keys->{NEGL}, $keys->{MISC});   
    my ($regs) = [];

    # 先頭4文字までの間に$neglが挿入されていても可
    for my $key (@{$keys->{KEY1}}) {
	my ($main_key, $sub_key) = split(/[＋]/, $key, 2);
	my @keys = split(//, $main_key, 4);

	# 段階的な絞り込みを行うために複数生成
	push(@{$regs}, {
	    full => "$misc*$keys[0]$negl*$keys[1]$negl*$keys[2]$negl*$keys[3].+$sub_key.*",
	    main => "$keys[0]$negl*$keys[1]$negl*$keys[2]$negl*$keys[3].+$sub_key",
	    sub1 => "$keys[0]",
	    sub2 => "$keys[1]"});
    }
    
    # $neglの挿入不可
    for my $key (@{$keys->{KEY2}}) {
	my ($main_key, $sub_key) = split(/[＋]/, $key, 2);

	# 段階的な絞り込みを行うために複数生成
	push(@{$regs}, {	    	    
	    full => "$misc*$main_key.+$sub_key.*",
	    main => "$main_key.+$sub_key",
	    sub1 => "$main_key", 
	    sub2 => "$sub_key"});
    }

    return $regs;
}

# $line中に$keysが含まれているかどうかをチェックする関数
sub CheckKey {
    my ($line, $regs) = @_;

    for my $reg (@{$regs}) {
	
	# 高速化のため段階的に絞り込み
	if ($line =~ /$reg->{sub1}/ && $line =~ /$reg->{sub2}/ &&
	    $line =~ /$reg->{main}/) {

	    # マッチした場合は、KEYより前の文字列と、KEY以降の文字列を返す
	    return ($`, $&) if ($line =~ /$reg->{full}/);
	}
    }
    
    # マッチしなかった場合は何も返さない
    return;
}

1;
