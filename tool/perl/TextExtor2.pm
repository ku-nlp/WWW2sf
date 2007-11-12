### HTMLから文単位でテキストを抽出するモジュール (Original: TextExtor.pm by Yoji Kiyota)
# $Id$

package TextExtor2;
use ModifiedTokeParser;
use HTML::Entities;
use SentenceExtractor2;
use HankakuZenkaku qw(ascii_h2z h2z4japanese_utf8);
use ConvertCode qw(convert_code);
use Encode qw(encode decode);
use vars qw($VERSION %TAG_DELIMITER %TAG_PREMODE %TAG_HEADING %TAG_LIST);
use strict;

$VERSION = sprintf("%d.%d", q$Revision$ =~ /(\d+)\.(\d+)/);

# 文区切りとみなすタグ
%TAG_DELIMITER = 
    ( hr         => 3,
      p          => 2,
      br         => 1,
      h1         => 2,
      h2         => 2,
      h3         => 2,
      h4         => 2,
      h5         => 2,
      h6         => 2,
      center     => 2,
      div        => 2,
      blockquote => 3,
      pre        => 3,
      xmp        => 3,
      listing    => 3,
      plaintext  => 3,
      ul         => 3,
      ol         => 3,
      dir        => 3,
      menu       => 3,
      li         => 1,
      dl         => 1,
      dt         => 1,
      dd         => 1,
      table      => 3,
      caption    => 1,
      tr         => 1,
      th         => 1,
      td         => 1,
      thead      => 1,
      tbody      => 1,
      tfoot      => 1,
    );

# 改行を文区切りとみなすタグ
%TAG_PREMODE = 
    ( pre        => 1,
      xmp        => 1,
      listing    => 1,
      plaintext  => 1,
    );

# 見出し
%TAG_HEADING = 
    ( h1         => 1,
      h2         => 2,
      h3         => 3,
      h4         => 4,
      h5         => 5,
      h6         => 6,
    );

# リスト
%TAG_LIST =
    ( ul         => 1,
      ol         => 1,
      dir        => 1,
      menu       => 1,
      dl         => 1,
    );

my $ALPHABET_OR_NUMBER = qr/\xa3(?:[\xc1-\xda]|[\xe1-\xfa]|[\xb0-\xb9])/;
my $ITEMIZE__HEADER = qr/$ALPHABET_OR_NUMBER．/;
my $CHARS_OF_BEGINNING_OF_ITEMIZATION = qr/、|，|：/;



sub new {
    my ($this, $text, $encoding, $opt) = @_;  # 対象となるHTMLファイルを引数として渡す

    ## 半角平仮名、記号を全角に変換
    $text = &h2z4japanese_utf8($text);

    # 改行を無視する場合
    if ($opt->{'ignore_br'}) {
	delete($TAG_DELIMITER{br});
	delete($TAG_DELIMITER{p});
    }

    my $title = '';        # <TITLE>
    my $title_offset;      # titleのoffset(バイト単位)
    my $title_length;      # titleのバイト長
    my $keywords = '';     # <META NAME="keywords">
    my $keywords_offset;   # keywordsのoffset(バイト単位)
    my $keywords_length;   # keywordsのバイト長
    my $description = '';  # <META NAME="description">
    my $description_offset;# descriptionのoffset(バイト単位)
    my $description_length;# descriptionのバイト長

    my $count = 3;         # 配列 @text, @property における番号
                           # 0:title, 1:keywords, 2:description
    my $num = 4;           # 文番号(仮)
                           # 1:title, 2:keywords, 3:description
    my $body = 1;          # <BODY> 内での先頭からの距離
    my $fontsize = 0;      # <FONT SIZE=n>
    my $basefontsize = 0;  # 
    my $mode_title = 0;    # <TITLE>
    my $mode_heading = 0;  # <Hn>
    my $mode_center = 0;   # <CENTER>, <DIV ALIGN=center>
    my $mode_list = 0;     # リスト
    my $mode_table = 0;    # テーブル
    my $mode_pre = 0;      # 改行を文区切りとみなす
    my $mode_script = 0;   # スクリプト
    my $mode_form = 0;     # フォーム
    my $mode_style = 0;    # スタイルシート

    my @text;              # テキスト
    my @property;          # テキストの属性(連想配列へのリファレンス)

    # HTML::TokeParserでparseする
    # HTML::TokeParserを、offsetとlengthを返させるように修正したModifiedTokeParserを使う
    my $parser = ModifiedTokeParser->new($text);

    # トークンを処理する
    while (my $token = $parser->get_token) {
        my $type = $token->[0];
	my $offset = $token->[3];
	my $length = $token->[4];

	# 開始タグ
        if ($type eq 'S') {
            my $tag = $token->[1];

            if (defined $TAG_DELIMITER{$tag}) {
                $count++;
		$num++;
		$body += $TAG_DELIMITER{$tag};
            }

	    if ($tag eq 'title') {
		$mode_title = 1;
	    } elsif (defined $TAG_HEADING{$tag}) {
		$mode_heading = $TAG_HEADING{$tag};
	    } elsif ($tag eq 'center') {
		$mode_center = 1;
	    } elsif ($tag eq 'div') {
		my $align = $token->[2]->{align};
		if ($align =~ /^center/i) {
		    $mode_center = 1;
		}
	    } elsif (defined $TAG_LIST{$tag}) {
		$mode_list = 1;
	    } elsif ($tag eq 'table') {
		$mode_table = 1;
	    } elsif (defined $TAG_PREMODE{$tag}) {
		$mode_pre = 1;
	    } elsif ($tag eq 'meta') {
		my $name = $token->[2]->{name};
		if ($name =~ /^keyword/i) {
		    $keywords = &convert_code($token->[2]->{content}, $encoding, 'euc-jp', 1); # with normalization
		    $keywords_offset = $offset;
		    $keywords_length = $length;
		} elsif ($name =~ /^description/i) {
		    $description = &convert_code($token->[2]->{content}, $encoding, 'euc-jp', 1); # with normalization
		    $description_offset = $offset;
		    $description_length = $length;
		}
	    } elsif ($tag eq 'font') {
		my $size = $token->[2]->{size};
		if ($size =~ /^\+(\d)/) {
		    $fontsize = $basefontsize + $1;
		} elsif ($size =~ /^\-(\d)/) {
		    $fontsize = $basefontsize - $1;
		} elsif ($size =~ /^(\d)/) {
		    $fontsize = $1 - 3;
		}
		$count++;
	    } elsif ($tag eq 'basefont') {
		my $size = $token->[2]->{size};
		if ($size =~ /^(\d)/) {
		    $basefontsize = $1 - 3;
		    $fontsize = $basefontsize;
		}
		$count++;
	    } elsif ($tag eq 'big') {
		$fontsize = $basefontsize + 2;
		$count++;
	    } elsif ($tag eq 'small') {
		$fontsize = $basefontsize - 2;
		$count++;
	    } elsif ($tag eq 'script') {
		$mode_script = 1;
	    } elsif ($tag eq 'form') {
		$mode_form = 1;
	    } elsif ($tag eq 'style') {
		$mode_style = 1;
	    }

	# 終了タグ
        } elsif ($type eq 'E') {
            my $tag = $token->[1];

            if (defined $TAG_DELIMITER{$tag}) {
                $count++;
		$num++;
            }

	    if ($mode_title) {
		$mode_title = 0;
	    }

	    if (defined $TAG_HEADING{$tag}) {
		$mode_heading = 0;
	    } elsif ($tag eq 'center') {
		$mode_center = 0;
	    } elsif ($tag eq 'div') {
		$mode_center = 0;
	    } elsif (defined $TAG_LIST{$tag}) {
		$mode_list = 0;
	    } elsif ($tag eq 'table') {
		$mode_table = 0;
	    } elsif (defined $TAG_PREMODE{$tag}) {
		$mode_pre = 0;
	    } elsif ($tag eq 'font') {
		$fontsize = $basefontsize;
		$count++;
	    } elsif ($tag eq 'big') {
		$fontsize = $basefontsize;
		$count++;
	    } elsif ($tag eq 'small') {
		$fontsize = $basefontsize;
		$count++;
	    } elsif ($tag eq 'script') {
		$mode_script = 0;
	    } elsif ($tag eq 'form') {
		$mode_form = 0;
	    } elsif ($tag eq 'style') {
		$mode_style = 0;
	    }

	# テキスト
        } elsif ($type eq 'T') {
            my $text = &convert_code($token->[1], $encoding, 'euc-jp', 1); # with normalization

	    if ($mode_title) {
		$title = $text;
		$title_offset = $offset;
		$title_length = $length;
	    } elsif ($mode_script or $mode_style) {
	    } else {
		$text[$count] .= $text;
		$property[$count]->{num} = $num;
		$property[$count]->{body} = $body;
		if (defined($property[$count]->{offset})) {
		    $property[$count]->{length} = $offset - $property[$count]->{offset} + $length;
		}
		else {
		    $property[$count]->{offset} = $offset;
		    $property[$count]->{length} = $length;
		}
		if ($fontsize) {
		    $property[$count]->{fontsize} = $fontsize;
		}
		if ($mode_heading) {
		    $property[$count]->{heading} = $mode_heading;
		}
		if ($mode_center) {
		    $property[$count]->{center} = 0;
		}
		if ($mode_list) {
		    $property[$count]->{list} = 0;
		}
		if ($mode_table) {
		    $property[$count]->{table} = 0;
		}
		if ($mode_pre) {
		    $property[$count]->{pre} = 0;
		}
	    }

        } elsif ($type eq 'C') {
        } elsif ($type eq 'D') {
        }
    }

    if ($title) {
        $text[0] = $title;
	$property[0]->{title} = 0;
	$property[0]->{num} = 1;
	$property[0]->{offset} = $title_offset;
	$property[0]->{length} = $title_length;
    }
    if ($keywords) {
	$text[1] = $keywords;
	$property[1]->{keywords} = 0;
	$property[1]->{num} = 2;
	$property[1]->{offset} = $keywords_offset;
	$property[1]->{length} = $keywords_length;
    }
    if ($description) {
	$text[2] = $description;
	$property[2]->{description} = 0;
	$property[2]->{num} = 3;
	$property[2]->{offset} = $description_offset;
	$property[2]->{length} = $description_length;
    }

    my @s_text;
    my @s_property;
    my $s_count = 0;
    my $s_num = 1;
    my $num_before = 0;

    for (my $i = 0; $i <= $#text; $i++) {
	next unless $text[$i];
	next if $text[$i] =~ /^(?:　|\s)*$/;   # 空白は無視する

	### テキストへの前処理

	# HTML 中の特殊文字をデコードする
	my $buf = $text[$i];
	$buf =~ s/&nbsp;/ /g; # &nbsp; はスペースに変換 (\xa0に変換させない)
	$buf = encode('euc-jp', decode_entities(decode('euc-jp', $buf))); # utf-8で処理しeuc-jpに戻す

	# \n(\x0a) 以外のコントロールコードは削除する
	$buf =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;

	# 改行の処理
 	$buf =~ s/([^\x0a])\x0a+$/$1/; # 最後の改行を削除
 	$buf =~ s/^\x0a+([^\x0a])/$1/; # 頭の改行を削除
	$buf =~ s/([^\x0a])\x0a([^\x0a])/$1 $2/g; # 単独の改行をスペースに (後でまわりをみて処理)

	# 整形処理
	my @buf;
	for my $str (split(/\n+/, $buf)) { # 2個以上の改行で文を切る
	    if ($opt->{language} eq 'japanese') {
		push(@buf, &ProcessJapanese($str, $property[$i]));
	    }
	    elsif ($opt->{language} eq 'english') {
		# $buf = &ProcessEnglish($buf);
		push(@buf, $str);
	    }
	    else {
		die "Unknown language: $opt->{language}\n";
	    }
	}

	my @buf2;
	foreach my $x (@buf) {
	    if (defined($property[$i]->{title})) {
		# タイトルに関しては句読点区切りをしない
		push(@buf2, $x);
	    } else {
		# 句読点で区切る
		push(@buf2, SentenceExtractor2->new($x, $opt->{language})->GetSentences());
	    }
	}

	if ($property[$i]->{num} == $num_before) {
	    $s_num--;
	}

	my $x = 0;
	foreach my $y (@buf2) {
	    unless ($y =~ /^(?:　|\s)*$/) {
	        # 先頭、末尾の空白を削除
		$y =~ s/^\s+//;
		$y =~ s/\s+$//;
		$y =~ s/^(?:　)+//;
		$y =~ s/(?:　)+$//;

		$s_text[$s_count] = $y;
 		for my $key (keys %{$property[$i]}) {
		    if ($key ne 'num') {
		        $s_property[$s_count]->{$key} = $property[$i]->{$key};
		    }
		}
		$s_property[$s_count]->{num} = $s_num;
		$s_count++;
		$s_num++;
                $x++;
            }
	}
        if ($x == 0) {
            $s_num++;
        }
	$num_before = $property[$i]->{num};
    }

    my @buff2 = ();
    my $start_itemization = 0;
    for (my $i = 0; $i < scalar(@s_text); $i++) {
	# 箇条書きかどうか
	if ($s_text[$i] =~ /^$ITEMIZE__HEADER/) {
	    if ($start_itemization > 0) {
		# 以下のお店、
		# ・さえずり
		# ・のら酒房
		# ・串カツ屋
		# は美味しいです。
		#
		# 型箇条書きの場合
		#     ↓
		# S1 次のお店＿・さえずり＿・のら酒房＿・串カツ屋＿は美味しいです。（＿は全角空白に読み替えてください）
		$buff2[-1] .= ('　' . $s_text[$i]);
	    } else {
		# 以下にお店を列挙します。
		# ・さえずり
		# ・のら酒房
		# ・串カツ屋
		# これらのお店は ...
		#
		# 型箇条書きの場合
		#     ↓
		# S1 以下にお店を列挙します。
		# S2 ・さえずり
		# S3 ・のら酒房
		# S4 ・串カツ屋
		# S5 これらのお店は ...
		push(@buff2, $s_text[$i]);
	    }
	} else {
	    if ($start_itemization > 0) {
		# は美味しいです。を連結
		if (scalar(@buff2) < 1) {
		    $buff2[0] = $s_text[$i];
		} else {
		    $buff2[-1] .= ('　' . $s_text[$i]);
		}
	    } else {
		push(@buff2, $s_text[$i]);
	    }
	    $start_itemization = ($s_text[$i] =~ /$CHARS_OF_BEGINNING_OF_ITEMIZATION$/) ? 1 : 0;
	}
    }

    @s_text = @buff2;

    if ($opt->{debug} == 1) {
	for (my $i = 0; $i <= $#s_text; $i++) {
	    my @p;
	    for my $key (sort keys %{$s_property[$i]}) {
		if ($s_property[$i]->{$key}) {
		    push @p, $key . '=' . $s_property[$i]->{$key};
		} else {
		    push @p, $key;
		}
	    }
	    print "$i " . join(',', @p) . " $s_text[$i]\n";
	}
    } elsif ($opt->{debug} == 2) {
	for (my $i = 0; $i <= $#text; $i++) {
	    my @p;
	    for my $key (sort keys %{$property[$i]}) {
		if ($property[$i]->{$key}) {
		    push @p, $key . '=' . $property[$i]->{$key};
		} else {
		    push @p, $key;
		}
	    }
	    print "$i " . join(',', @p) . " $text[$i]\n";
	}
    }

    bless $this = {
		   TEXT => \@s_text,
		   PROPERTY => \@s_property,
		  };

    return $this;
}

sub ProcessJapanese {
    my ($buf, $property) = @_;

    # 全角文字同士、全角文字と半角文字の間の空白は詰める
    $buf =~ s/([\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])\s+([\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/$1$2/g;
    $buf =~ s/([^\s\x80-\xfe])\s+([\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/$1$2/g;
    $buf =~ s/([\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])\s+([^\s\x80-\xfe])/$1$2/g;

    if (defined($property->{pre})) {
	# <PRE>の中で連続する空白は削除
	$buf =~ s/(?:　| |\t){2,}//g;
    }
    else {
	# 連続する空白は詰める
	$buf =~ s/(?:　| |\t){2,}/ /g;
    }

    # 1バイト文字を2バイトに変換する
    &ascii_h2z(\$buf);

    # カタカナの後についているハイフンを「ー」に正規化
    $buf =~ s!(\xa5.)((?:ー|―|−|─|━|‐)+)!sprintf("%s%s", $1, 'ー' x (length($2) / 2))!ge;

    return $buf;
}

sub z2h{
    my $string = shift;
    if(utf8::is_utf8($string)){
	$string = Encode::encode("euc-jp", $string);
	Encode::JP::H2Z::h2z(\$string);
	return Encode::decode("euc-jp", $string);
    }else{
	Encode::JP::H2Z::h2z(\$string);
	  return $string;
      }
}

1;
