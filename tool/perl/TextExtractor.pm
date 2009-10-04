### HTMLから文単位でテキストを抽出するモジュール
# $Id$

package TextExtractor;
use ModifiedTokeParser;
use HTML::Entities qq(decode_entities);
use SentenceExtractor;
use HankakuZenkaku qw(ascii_h2z h2z4japanese_utf8);
use ConvertCode qw(convert_code);
use Encode qw(encode decode);
use vars qw($VERSION %DELIMITER_TAGS %PREMODE_TAGS %HEADING_TAGS %LIST_TAGS $CONNECT_A_TH);
use strict;
use utf8;
use Unicode::Normalize;
use Unicode::Japanese;
use CharacterRange;
use Annotator;
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

$VERSION = sprintf("%d.%d", q$Revision$ =~ /(\d+)\.(\d+)/);

# 文区切りとみなすタグ
%DELIMITER_TAGS = (
		   address => 1,
		   blockquote => 1,
#		   br => 1,
		   caption => 1,
		   center => 1,
		   dd => 1,
		   dir => 1,
		   div => 1,
		   dl => 1,
		   dt => 1,
		   fieldset => 1,
		   form => 1,
		   h1 => 1,
		   h2 => 1,
		   h3 => 1,
		   h4 => 1,
		   h5 => 1,
		   h6 => 1,
		   hr => 1,
		   isindex => 1,
		   li => 1,
		   listing => 1,
		   menu => 1,
		   multicol => 1,
		   noframes => 1,
		   noscript => 1,
		   ol => 1,
		   option => 1,
		   p => 1,
		   plaintext => 1,
		   pre => 1,
		   select => 1,
		   table => 1,
		   tbody => 1,
		   td => 1,
		   tfoot => 1,
		   th => 1,
		   thead => 1,
		   tr => 1,
		   ul => 1,
		   xmp => 1
		   );

# 改行を文区切りとみなすタグ
%PREMODE_TAGS = 
    ( pre        => 1,
      xmp        => 1,
      listing    => 1,
      plaintext  => 1,
    );

# 見出し
%HEADING_TAGS = 
    ( h1         => 1,
      h2         => 2,
      h3         => 3,
      h4         => 4,
      h5         => 5,
      h6         => 6,
    );

# リスト
%LIST_TAGS =
    ( ul         => 1,
      ol         => 1,
      dir        => 1,
      menu       => 1,
      dl         => 1,
    );

my $ITEMIZE__HEADER = qr/\p{alphabet_or_number}．/;
my $CHARS_OF_BEGINNING_OF_ITEMIZATION = qr/、|，|：/;

my $NUMBER = qr/\xa3(?:[\xa0-\xb9])/;

my $CONNECT_A_TH = 1000; # aタグを連結するときの複合名詞（最長）の頻度の閾値

sub new {
    my ($this, $opt) = @_;  # 対象となるHTMLファイルを引数として渡す

    $this = {opt => $opt};
    # 改行を無視する場合
    if ($opt->{'ignore_br'}) {
	delete($DELIMITER_TAGS{br});
	delete($DELIMITER_TAGS{p});
    }

    # 複合名詞データベース
    if ($this->{opt}{cndbfile}) {
	require CDB_File;
	my $cndb = tie %{$this->{CN2DF}}, 'CDB_File', $this->{opt}{cndbfile} or die;
    }

    $this->{annotator} = new Annotator();
    bless $this;
}

sub DESTROY {
    my ($this) = @_;

    if ($this->{opt}{cndbfile}) {
	untie %{$this->{CN2DF}};
    }
}

sub is_unseparate_property {
    my ($property) = @_;

    if (defined $property->{title} ||
	defined $property->{keywords} ||
	defined $property->{description}) {
	return 1;
    } else {
	return 0;
    }
}

sub detag {
    my ($this, $raw_html, $opt) = @_;
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
    my $fontsize = 0;      # <FONT SIZE=n>
    my $basefontsize = 0;  # 
    my %mode;
    $mode{title} = 0;      # <TITLE>
    $mode{heading} = 0;    # <Hn>
    $mode{center} = 0;     # <CENTER>, <DIV ALIGN=center>
    $mode{list} = 0;       # リスト
    $mode{table} = 0;      # テーブル
    $mode{pre} = 0;        # 改行を文区切りとみなす
    $mode{script} = 0;     # スクリプト
    $mode{form} = 0;       # フォーム
    $mode{style} = 0;      # スタイルシート
    $mode{link} = 0;       # <a>

    my @text;              # テキスト
    my @property;          # テキストの属性(連想配列へのリファレンス)

    my $link_buf;          # <a>タグの中身すべて
    my $link_buf2;         # <a>タグの途中を保持

    my @outlinks;          # outlink DB作成用データ

    # テキスト要素直前のタグ
    my $immediately_before_tag = '';

    # 領域のタイプ
    my $blockType;

    # HTML::TokeParserでparseする
    # HTML::TokeParserを、offsetとlengthを返させるように修正したModifiedTokeParserを使う
    my $parser = ModifiedTokeParser->new($raw_html) or die $!;

    # トークンを処理する
    while (my $token = $parser->get_token) {
        my $type = $token->[0];
	my $offset = $token->[3] + $this->{opt}{offset};
	my $length = $token->[4];
	# 開始タグ
	if ($type eq 'S') {
            my $tag = $token->[1];
	    $immediately_before_tag = $tag;
	    $blockType = ($token->[2]->{myblocktype}) ? $token->[2]->{myblocktype} : 'unknown_block';
            if (defined $DELIMITER_TAGS{$tag}) {
		# link_bufがある場合、直前に連結
		if ($link_buf) {
		    $text[$count] .= $link_buf;
		    $link_buf = '';
		}

                $count++;
		$num++;
            }
	    # <br>は単なる改行と見なす
	    elsif ($tag eq 'br') {
		# link_bufがある場合、直前に連結
		if ($link_buf) {
		    $text[$count] .= $link_buf;
		    $link_buf = '';
		}

		$text[$count] .= "\n";
	    }

	    if ($tag eq 'title' && $title eq '') {
		$mode{title} = 1;
	    } elsif (defined $HEADING_TAGS{$tag}) {
		$mode{heading} = $HEADING_TAGS{$tag};
	    } elsif ($tag eq 'center') {
		$mode{center} = 1;
	    } elsif ($tag eq 'div') {
		my $align = $token->[2]->{align};
		if ($align =~ /^center/i) {
		    $mode{center} = 1;
		}
	    } elsif (defined $LIST_TAGS{$tag}) {
		$mode{list} = 1;
	    } elsif ($tag eq 'table') {
		$mode{table} = 1;
	    } elsif (defined $PREMODE_TAGS{$tag}) {
		$mode{pre} = 1;
	    } elsif ($tag eq 'meta') {
		my $name = $token->[2]->{name};
		if ($name =~ /^keyword/i) {
#		    $keywords = NFKC($token->[2]->{content});
		    $keywords = $token->[2]->{content};
		    $keywords_offset = $offset;
		    $keywords_length = $length;
		} elsif ($name =~ /^description/i) {
#		    $description = NFKC($token->[2]->{content});
		    $description = $token->[2]->{content};
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
	    } elsif ($tag eq 'basefont') {
		my $size = $token->[2]->{size};
		if ($size =~ /^(\d)/) {
		    $basefontsize = $1 - 3;
		    $fontsize = $basefontsize;
		}
	    } elsif ($tag eq 'big') {
		$fontsize = $basefontsize + 2;
	    } elsif ($tag eq 'small') {
		$fontsize = $basefontsize - 2;
	    } elsif ($tag eq 'script') {
		$mode{script} = 1;
	    } elsif ($tag eq 'form') {
		$mode{form} = 1;
	    } elsif ($tag eq 'style') {
		$mode{style} = 1;
	    } elsif ($tag eq 'a') {
		$mode{link} = 1;

		push(@outlinks, {text => '', url => $token->[2]{href}});
	    }
        }
	# 終了タグ
	elsif ($type eq 'E') {
            my $tag = $token->[1];

            if (defined $DELIMITER_TAGS{$tag}) {
		# link_bufがある場合、直前に連結
		if ($link_buf) {
		    $text[$count] .= $link_buf;
		    $link_buf = '';
		}

                $count++;
		$num++;
            }

	    if ($mode{title}) {
		$mode{title} = 0;
	    }

	    if (defined $HEADING_TAGS{$tag}) {
		$mode{heading} = 0;
	    } elsif ($tag eq 'center') {
		$mode{center} = 0;
	    } elsif ($tag eq 'div') {
		$mode{center} = 0;
	    } elsif (defined $LIST_TAGS{$tag}) {
		$mode{list} = 0;
	    } elsif ($tag eq 'table') {
		$mode{table} = 0;
	    } elsif (defined $PREMODE_TAGS{$tag}) {
		$mode{pre} = 0;
	    } elsif ($tag eq 'font') {
		$fontsize = $basefontsize;
	    } elsif ($tag eq 'big') {
		$fontsize = $basefontsize;
	    } elsif ($tag eq 'small') {
		$fontsize = $basefontsize;
	    } elsif ($tag eq 'script') {
		$mode{script} = 0;
	    } elsif ($tag eq 'form') {
		$mode{form} = 0;
	    } elsif ($tag eq 'style') {
		$mode{style} = 0;
	    } elsif ($tag eq 'a') {
		$this->Process_a_Tag(\$link_buf, \$link_buf2, \@text, \$count);
		$mode{link} = 0;
	    }

	    # テキスト
        } elsif ($type eq 'T') {
	    # インラインタグで囲まれたテキストのオフセットを取得したいので
	    # 全てのテキストを@textの別要素とする
	    $count++ if ($opt->{always_countup});

#           my $text = NFKC($token->[1]);
            my $text = $token->[1];

	    # "<BR>\n", "<P>\n" を一つの改行と思う
	    if ($immediately_before_tag =~ /br|p/ && $this->{opt}{uniq_br_and_linebreak}) {
		$text =~ s/^\n//;
	    }
	    $immediately_before_tag = '';

	    if ($mode{title}) {
		$title = $text;
		$title_offset = $offset;
		$title_length = $length;
	    } elsif ($mode{script} or $mode{style}) {
		# nothing to do
	    } else {
		if ($mode{link}) {
		    $outlinks[-1]->{text} .= $text;
		}

		# 複合名詞データベースが指定されている場合
		if ($this->{opt}{cndbfile}) {
		    # <a>タグの中
		    if ($mode{link}) {
			$link_buf2 .= $text;
		    }
		    else {
			if ($link_buf) {
			    $text[$count] .= $link_buf;
			    $link_buf = '';
			}
			$text[$count] .= $text;
		    }
		}
		else {
		    $text[$count] .= $text;
		}

		$property[$count]->{num} = $num;
		if (defined($property[$count]->{offset})) {
		    $property[$count]->{length} = $offset - $property[$count]->{offset} + $length; # 後で考える
		}
		else {
		    $property[$count]->{offset} = $offset;
		    $property[$count]->{length} = $length;
		}

		if ($fontsize) {
		    $property[$count]->{fontsize} = $fontsize;
		}

		$property[$count]->{heading} = $mode{heading};
		$property[$count]->{center} = $mode{center};
		$property[$count]->{list} = $mode{list};
		$property[$count]->{table} = $mode{table};
		$property[$count]->{pre} = $mode{pre};
		$property[$count]->{blockType} = $blockType;
	    }
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

    return (\@text, \@property, \@outlinks);
}


sub extract_text {
    my($this, $raw_html) = @_;  # 対象となるHTMLファイルを引数として渡す

    my ($text, $property, $outlinks) = $this->detag($raw_html);

    my @s_text;
    my @s_property;
    my $s_count = 0;
    my $s_num = 1;
    my $paraID = 1;
    my $num_before = 0;

    for (my $i = 0; $i < scalar(@$text); $i++) {
	next if (!defined $text->[$i] || $text->[$i] eq '');
	next if ($text->[$i] =~ /^(?:　|\s)*$/);   # 空白は無視する

	### テキストへの前処理

	# HTML 中の特殊文字をデコードする
	my $buf = $text->[$i];
	$text->[$i] = decode('utf8', $text->[$i]) unless (utf8::is_utf8($text->[$i]));
	$buf =~ s/(?:&\#160|&nbsp);/ /g; # &nbsp; はスペースに変換 (\xa0に変換させない)
	$buf = decode_entities($buf);

	# \n(\x0a) 以外のコントロールコードは削除する
	$buf =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;

	# 改行の処理
 	$buf =~ s/([^\x0a])\x0a+$/$1/; # 最後の改行を削除
 	$buf =~ s/^\x0a+([^\x0a])/$1/; # 頭の改行を削除
	$buf =~ s/([^\x0a])\x0a([^\x0a])/$1 $2/g; # 単独の改行をスペースに (後でまわりをみて処理)

	# 整形処理
	my @buf;
	my $j = 0;
	for my $str (split(/\n{2,}/, $buf)) { # 2個以上の改行で文を切る
	    if ($this->{opt}{language} eq 'japanese') {
		my $tmp = $this->ProcessJapanese($str, $property->[$i]);
		push(@{$buf[$j]}, $tmp);
	    }
	    elsif ($this->{opt}{language} eq 'english') {
		# $buf = &ProcessEnglish($buf);
		push(@{$buf[$j]}, $str);
	    }
	    else {
		die "Unknown language: $this->{opt}{language}\n";
	    }

	    # 段落ごとに格納する配列をかえる
	    $j++;
	}

	my @buf2;
	my $j = 0;
	foreach my $paragraph (@buf) {
	    foreach my $sent (@$paragraph) {
		if (&is_unseparate_property($property->[$i])) {
		    # <title>, <meta keywords=>, <meta description=> に関しては句読点区切りをしない
		    push(@{$buf2[$j]}, $sent);
		} else {
		    # 句読点で区切る
		    push(@{$buf2[$j]}, SentenceExtractor->new($sent, $this->{opt}{language})->GetSentences());
		}
	    }
	    $j++;
	}

	# 顔文字、（笑）等で文を区切る
	foreach my $paragraph (@buf2) {
	    @{$paragraph} = $this->SplitByEmoticon($paragraph) unless (&is_unseparate_property($property->[$i]));
	}


	if ($property->[$i]->{num} == $num_before) {
	    $s_num--;
	}

	my $x = 0;
	foreach my $paragraph (@buf2) {
	    foreach my $y (@$paragraph) {
		unless ($y =~ /^(?:　|\s)*$/o) { # added o by ynaga
		    # 先頭、末尾の空白を削除
		    # modified by ynaga.
                    $y =~ s/^(?:　|\s)+//o;
                    $y = reverse ($y); $y =~ s/^(?:　|\s)+//o; $y = reverse ($y);

		    $s_text[$s_count] = $y;
		    for my $key (keys %{$property->[$i]}) {
			if ($key ne 'num') {
			    $s_property[$s_count]->{$key} = $property->[$i]->{$key};
			}
		    }
		    $s_property[$s_count]->{num} = $s_num;
		    $s_property[$s_count]->{paragraph} = $paraID;
		    $s_count++;
		    $s_num++;
		    $x++;
		}
	    }
	    $paraID++;
	}

        if ($x == 0) {
            $s_num++;
        }
	$num_before = $property->[$i]->{num};
    }

    my @buff2 = ();
    my $start_itemization = 0;
    for (my $i = 0; $i < scalar(@s_text); $i++) {
	# 箇条書きかどうか
	if ($s_text[$i] =~ /^$ITEMIZE__HEADER/o) { # added o by ynaga
	    if ($start_itemization > 0) {
		# 以下のお店、
		# ・さえずり
		# ・のら酒房
		# ・串カツ屋
		# は美味しいです。
		#
		# ↑型箇条書きの場合
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
		# ↑型箇条書きの場合
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
	    $start_itemization = ($s_text[$i] =~ /$CHARS_OF_BEGINNING_OF_ITEMIZATION$/o && # added o by ynaga
				  !&is_unseparate_property($s_property[$i]) &&
				  !defined $s_property[$i]->{description} &&
				  !defined $s_property[$i]->{keywords}) ? 1 : 0;
	}
    }

    @s_text = @buff2;

    if ($this->{opt}{debug} == 1) {
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
    } elsif ($this->{opt}{debug} == 2) {
	for (my $i = 0; $i < scalar(@$text); $i++) {
	    my @p;
	    for my $key (sort keys %{$property->[$i]}) {
		if ($property->[$i]->{$key}) {
		    push @p, $key . '=' . $property->[$i]->{$key};
		} else {
		    push @p, $key;
		}
	    }
	    print "$i " . join(',', @p) . " $text->[$i]\n";
	}
    }

    my %outlinks = ();
    foreach my $e (@$outlinks) {
	next if ($e->{text} eq '');

	my $T = $e->{text};

	$T = decode('utf8', $T) unless (utf8::is_utf8($T));
	$T =~ s/[&\#160|&nbsp];/ /g; # &nbsp; はスペースに変換 (\xa0に変換させない)
	$T = decode_entities($T);

	# \n(\x0a) 以外のコントロールコードは削除する
	$T =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;
	# 改行の処理
 	$T =~ s/([^\x0a])\x0a+$/$1/; # 最後の改行を削除
 	$T =~ s/^\x0a+([^\x0a])/$1/; # 頭の改行を削除
	$T =~ s/([^\x0a])\x0a([^\x0a])/$1 $2/g; # 単独の改行をスペースに (後でまわりをみて処理)

	$T = $this->ProcessJapanese($T);

	$T =~ s/^(?:　|\s)+//o;
	$T = reverse ($T); $T =~ s/^(?:　|\s)+//o; $T = reverse ($T);

	push (@{$outlinks{$T}}, $e->{url});
    }

    my $ret = {
	TEXT => \@s_text,
	PROPERTY => \@s_property,
	OUTLINKS => \%outlinks
    };

    return $ret;
}

sub ProcessJapanese {
    my ($this, $buf, $property) = @_;

    $buf =~ s/\n/ /g;    # 改行コードは半角の空白に変換
    # ynaga; +? is meaningless, here.
    $buf =~ s/([　-。・-；゛-龠])\s+([　-。・-；゛-龠])/$1$2/g; 
    $buf =~ s/([!-~])\s+([　-。・-；゛-龠])/$1$2/g;
    $buf =~ s/([　-。・-；゛-龠])\s+([!-~])/$1$2/g;
    # $buf =~ s/((\p{Han}|\p{Hiragana}|\p{Katakana})+?)\s+((\p{Han}|\p{Hiragana}|\p{Katakana})+?)/$1$3/g;

    if (defined($property->{pre})) {
	# <PRE>の中で連続する空白は削除
	$buf =~ s/([a-zA-Z0-9])(?:　| |\t){2,}([a-zA-Z0-9])/$1 $2/g; # 英数字で囲まれている場合は空白1つ残す
	$buf =~ s/(?:　| |\t){2,}//g; # それ以外の空白2個以上は削除
    }
    else {
	# 連続する空白は詰める
	$buf =~ s/(?:　| |\t){2,}/ /g;
    }

    # 1バイト文字を2バイトに変換する
#   $buf =~ tr/ !""#\$%&''\(\)\*\+,\-\.\/:;<=>\?@\[\\\]\^_`\{\|\}~0-9A-Za-z/　！””＃＄％＆’’（）＊＋，−．／：；＜＝＞？＠［¥］＾＿｀｛｜｝‾０-９Ａ-Ｚａ-ｚ/;
    $buf = Unicode::Japanese->new($buf)->h2z->getu();

    # カタカナの後についているハイフンを「ー」に正規化
    $buf =~ s!(\p{Katakana})((?:ー|―|−|─|━|‐)+)!sprintf("%s%s", $1, 'ー' x (length($2)))!ge;

    # euc-jpにないコードを変換
    $buf =~ s/－/−/g; # FULLWIDTH HYPHEN-MINUS (U+ff0d) -> MINUS SIGN (U+2212)
    $buf =~ s/～/〜/g; # FULLWIDTH TILDE (U+ff5e) -> WAVE DASH (U+301c)
    $buf =~ s/∥/‖/g; # PARALLEL TO (U+2225) -> DOUBLE VERTICAL LINE (U+2016)
    $buf =~ s/￠/¢/g;  # FULLWIDTH CENT SIGN (U+ffe0) -> CENT SIGN (U+00a2)
    $buf =~ s/￡/£/g;  # FULLWIDTH POUND SIGN (U+ffe1) -> POUND SIGN (U+00a3)
    $buf =~ s/￢/¬/g;  # FULLWIDTH NOT SIGN (U+ffe2) -> NOT SIGN (U+00ac)
    $buf =~ s/—/―/g; # EM DASH (U+2014) -> HORIZONTAL BAR (U+2015)
    $buf =~ s/¥/￥/g;  # YEN SIGN (U+00a5) -> FULLWIDTH YEN SIGN (U+ffe5)
    # ※ これ以外の特殊な文字は解析時に「〓」に変換 (Juman.pm)

    # Unicode変換のバグ

    # 数字￣数字 → 数字〜数字
    $buf =~ s/(\p{number}+)￣(\p{number}+)/\1〜\2/g;

    # 数字(単位)￣数字(単位) → 数字(単位)〜数字(単位)
    $buf =~ s/(\p{number}+)(.{1,2})￣(\p{number}+)(\2)/\1\2〜\3\2/g;

    return $buf;
}

# 顔文字、（笑）等で文を区切る
sub SplitByEmoticon {
    my ($this, $buf) = @_;

    my @retbuf;
    foreach my $x (@{$buf}) {
	# darts の置換メソッドを利用
	my $newstr = decode("utf8", $this->{annotator}->{da}->gsub($x, sub{ "$_[0]\n" }));
	# デリミタ, 顔文字が文末に連続している場合はまとめる
	while ($newstr =~ /\n(?:(?:$this->{annotator}->{pat})\n)*/o) {
	    $newstr = $'; # perl mode で適切にハイライトさせるための「'」
	    my $sent = $` . $&;
	    $sent =~ s/\n//g;
	    push (@retbuf, $sent);
	}
	push (@retbuf, $newstr);
    }
    return @retbuf;
}

# <a>タグを処理する
sub Process_a_Tag {
    my ($this, $link_buf, $link_buf2, $ar_text, $count) = @_;

    # 直前も<a>タグの場合、連結した文字列で複合名詞データベースをひく
    # 複合名詞であれば、連結し、そうでなければ、別の文にする
    if ($$link_buf) {
	my $cn_candidate = $$link_buf . $$link_buf2;

	my $df_longest = $this->{CN2DF}{"$cn_candidate@"};

	# 最長で出現する頻度が閾値以上
	# どちらもひらがな一文字は除く(<a>あ</a><a>い</a>)
	if ($$link_buf && $link_buf2 && 
	    $$link_buf !~ /^\p{Hiragana}$/ && $$link_buf2 !~ /^\p{Hiragana}$/ && 
	    defined $df_longest && $df_longest >= $CONNECT_A_TH) {
	    print STDERR '★CN ', $$link_buf . ':' . $$link_buf2, " $df_longest\n" if $this->{opt}{verbose};

	    # 今の$$link_buf2と、次の<a>タグが複合名詞関係にあるかどうかもチェックするので、
	    # ここでは、$$link_bufだけを$ar_text[$$count]に入れて、$$link_buf2は$$link_bufに保持する
	    $ar_text->[$$count] .= $$link_buf;
	    $$link_buf = $$link_buf2;
	}
	else {
	    print STDERR 'Not CN', " $$link_buf:$$link_buf2 ", $cn_candidate, " $df_longest\n" if $this->{opt}{verbose};
	    $ar_text->[$$count++] .= $$link_buf;
	    $$link_buf = $$link_buf2;
	}
    }
    # 直前が<a>タグでない場合、bufに入れておく
    else {
	$$link_buf = $$link_buf2;
    }
    $$link_buf2 = '';
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
