#!/usr/bin/env perl

# htmlを文リストに変換

# $Id$

use strict;
# use TextExtor2;
use TextExtractor;
use Encode qw(encode decode);
use Encode::Guess;
use XML::Writer;
use File::stat;
use POSIX qw(strftime);
use HtmlGuessEncoding;
use SentenceFilter;
use ConvertCode qw(convert_code);
use Getopt::Long;
use utf8;
use File::Basename;
use HTTP::Date qw(parse_date);
use URI;
use URI::Split qw(uri_split uri_join);
use URI::Escape;
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

sub usage {
    $0 =~ /([^\/]+)$/;
    print "Usage: $1 [--language english|japanese] [--xml] [--url string] [--checkjapanese] [--checkzyoshi] [--checkencoding] file.html\n";
    exit 1;
}


our (%opt, $writer, $filter);
&GetOptions(\%opt, 'language=s', 'url=s', 'xml', 'checkjapanese', 'checkzyoshi', 'zyoshi_threshold=f', 'checkencoding', 'ignore_br', 'blog=s', 'cndbfile=s', 'uniq_br_and_linebreak', 'make_urldb', 'verbose');
$opt{language} = 'japanese' unless $opt{language}; # デフォルト言語: japanese
$opt{blog} = 'none' unless $opt{blog};

# --checkencoding: encodingをチェックして、日本語ではないエンコーディングなら何も出力せず終了する
# --checkjapanese: 日本語(ひらがな、カタカナ、漢字)含有率をチェックする
# --checkzyoshi:   助詞含有率をチェックする

my ($VERSION, $CRAWL_DATE, $buf, $crawlTime, $url);

# 変換スクリプトのバージョンを読み込み
my $version_file = sprintf("%s/../data/VERSION", dirname($INC{'TextExtractor.pm'}));
if (-e $version_file) {
    open F, "< $version_file" or die $!;
    $VERSION = <F>;
    chomp $VERSION;
    close F;
} else {
    print STDERR "[WARNING] data/VERSION file was not found.\n";
}


# Date: がない場合用にクロール日をあらかじめ記述したファイルをロード
my $crawldate_file = sprintf("%s/../data/CRAWL_DATE", dirname($INC{'TextExtractor.pm'}));
if (-e $crawldate_file) {
    open F, "< $crawldate_file" or die $!;
    $CRAWL_DATE = <F>;
    chomp $CRAWL_DATE;
    close F;
} else {
    print STDERR "[WARNING] data/CRAWL_DATE file was not found.\n";
}



############################################################
#                      処理開始
############################################################

our $HtmlGuessEncoding = new HtmlGuessEncoding(\%opt);
our $Filter = new SentenceFilter if $opt{checkjapanese};

our $Threshold_Filter = 0.6;
our $Threshold_Zyoshi = $opt{zyoshi_threshold} ? $opt{zyoshi_threshold} : 0.005;

our $textextractor_option = {language => $opt{language}};
$textextractor_option->{uniq_br_and_linebreak} = $opt{uniq_br_and_linebreak} if $opt{uniq_br_and_linebreak};
$textextractor_option->{cndbfile} = $opt{cndbfile} if $opt{cndbfile};
$textextractor_option->{verbose} = $opt{verbose} if $opt{verbose};
our $ext = new TextExtractor($textextractor_option);

our $crawler_html = 0;
my $flag = -1;
my $htmlfile = $ARGV[-1];
my ($id) = ($htmlfile =~ /(\d+)(\.\d+)(\.utf8)?\.html?/);
my $dir = `dirname $htmlfile`; chop $dir;

open (HTML, $htmlfile) or die "$!";
while (<HTML>) {
  ## added by ynaga, following kaji-san's modifications
  &process_one_html($_, $url);
=uncommented by ynaga, following kaji-san's modifications #'
    if (/^HTML (\S+)/ && $flag < 0) { # 1行目からURLを取得(read-zaodataが出力している)
	my $next_url = $1;
	$crawler_html = 1;

	if ($buf) {
	    &process_one_html($buf, $url);
	    $buf = '';
	}
	$flag = -1;
	$url = $next_url;
    }

    # ヘッダーが読み終わるまでバッファリングしない
    if (!$crawler_html || $flag > 0) {
	$buf .= $_;
    }
    else {
	# ウェブサーバーが応答した日時を取得
	if ($_ =~ /^Date: (.+)$/) {
	    $crawlTime = &convertTimeFormat($1);
	}

	if ($_ =~ /^(\x0D\x0A|\x0D|\x0A)$/) {
	    $flag = 1;
	}
    }
=cut
}
close (HTML);
exit 0 unless $buf;
# uncommented by ynaga, following kaji-san's modification
# &process_one_html($buf, $url);

# ひとつのHTMLを処理
sub process_one_html {
    my ($buf, $url) = @_;

    my $encoding = $HtmlGuessEncoding->ProcessEncoding(\$buf, {force_change_to_utf8_with_flag => 1});
    return 1 if $opt{checkencoding} and !$encoding;

    # トラックバック、コメント、メニュー部分を削除（Movable Type用）
    if ($opt{blog} eq 'mt') {
	# <head>削除
	if ($buf =~ m!^((?:.|\n|\r)+)<head>(?:.|\n|\r)+?</head>((?:.|\n|\r)+)$!) {
	    $buf = $1 . $2;
	}

	# banner-inner, content-nav, entry-footerを削除
	if ($buf =~ m!^((?:.|\n|\r)+)<div id="banner-inner" class="pkg">(?:.|\n|\r)+?</div>((?:.|\n|\r)+)$!) {
	    $buf = $1 . $2;
	}
	if ($buf =~ m!^((?:.|\n|\r)+)<p class="content-nav">(?:.|\n|\r)+?</p>((?:.|\n|\r)+)$!) {
	    $buf = $1 . $2;
	}
	if ($buf =~ m!^((?:.|\n|\r)+)<p class="entry-footer">(?:.|\n|\r)+?</p>((?:.|\n|\r)+)$!) {
	    $buf = $1 . $2;
	}

	if ($buf =~ /<div class=\"trackbacks\">/) {
	    my $before_menu = "$`";
	    my $menu_part = "$&$'";
	    while (1) {
		if ($menu_part =~ m!</div>!) {
		    my $fwd = "$`";
		    my $bck = "$'";
		    if ($fwd =~ m!(( |.|\n|\r)*)<div !) {
			$menu_part = $1 . $bck;
		    }
		    else {
			last;
		    }
		}
		else {
		    print "nothing.\n";
		}
	    }
	    $buf = $before_menu . $menu_part;
	}

	if ($buf =~ /<div id=\"comments\" class=\"comments\">/) {
	    my $before_menu = "$`";
	    my $menu_part = "$&$'";
	    while (1) {
		if ($menu_part =~ m!</div>!) {
		    my $fwd = "$`";
		    my $bck = "$'";
		    if ($fwd =~ m!(( |.|\n|\r)*)<div !) {
			$menu_part = $1 . $bck;
		    }
		    else {
			last;
		    }
		}
		else {
		    print "nothing.\n";
		}
	    }
	    $buf = $before_menu . $menu_part;
	}

	if ($buf =~ /<div id=\"beta-inner\" class=\"pkg\">/) {
	    my $before_menu = "$`";
	    my $menu_part = "$&$'";
	    while (1) {
		if ($menu_part =~ m!</div>!) {
		    my $fwd = "$`";
		    my $bck = "$'";
		    if ($fwd =~ m!(( |.|\n|\r)*)<div !) {
			$menu_part = $1 . $bck;
		    }
		    else {
			last;
		    }
		}
		else {
		    print "nothing.\n";
		}
	    }
	    $buf = $before_menu . $menu_part;
	}
    }

    # クローラのヘッダを削除
    $buf =~ s/^(?:\d|.|\n|\r)*?(<html)/\1/i if $crawler_html;

    # クローラのフッタを削除
    $buf =~ s/(<\/html>)(([^>]|\n)*?)?(\d|\r|\n)+$/\1\n/i if ($crawler_html);

    # HTMLを文のリストに変換
    my $parsed = $ext->extract_text(\$buf);

    # 助詞含有率をチェック
    if ($opt{checkzyoshi}) {
      
	my $allbuf;
=heaby computation
	for my $i (0 .. $#{$parsed->{TEXT}}) {
	    $allbuf .= $parsed->{TEXT}[$i];
	}
=cut
        $allbuf = join('', @{$parsed->{TEXT}});

	my $ratio = &postp_check($allbuf);
	if ($ratio <= $Threshold_Zyoshi) {
	    print STDERR "$ratio is less than the threshold($Threshold_Zyoshi)\n";
	    return 1;
	}
    }

    # XML出力の準備
    if ($opt{xml}) {
	require XML::Writer;
	$writer = new XML::Writer(OUTPUT => *STDOUT, DATA_MODE => 'true', DATA_INDENT => 2);
	$writer->xmlDecl('utf-8');
    }

    # 文に分割して出力
    # uncommented by ynaga, following kaji-san's modification
    # &print_page_header($parsed, $opt{url} ? $opt{url} : $url, $encoding, $crawlTime);
    &print_extract_sentences($parsed, $buf);
    # uncommented by ynaga, following kaji-san's modification
    # &print_page_footer();
}

sub print_page_header {
    my ($parsed, $url, $encoding, $crawlTime) = @_;

    my $formatTime = strftime("%Y-%m-%d %T %Z", localtime(time));

    if ($opt{xml}) {
	$writer->startTag('StandardFormat',
			  Url => $url,
			  OriginalEncoding => $encoding,
			  CrawlTime => ($crawlTime) ? $crawlTime : $CRAWL_DATE,
			  FormatTime => $formatTime,
			  FormatProgVersion => $VERSION
	    );

	$writer->startTag('Header');
	for my $i (0 .. $#{$parsed->{TEXT}}) {
	    my $line = $parsed->{TEXT}[$i];
	    if ($opt{xml}) {
		my $tagname;
		if (defined($parsed->{PROPERTY}[$i]{title})) {
		    $tagname = 'Title';
		}
		elsif (defined($parsed->{PROPERTY}[$i]{keywords})) {
		    $tagname = 'Keywords';
		}
		elsif (defined($parsed->{PROPERTY}[$i]{description})) {
		    $tagname = 'Description';
		} else {
		    next;
		}

		if ($opt{checkjapanese}) {
		    my $score = sprintf("%.5f", $Filter->JapaneseCheck($line));
		    my $is_Japanese = $score > $Threshold_Filter ? '1' : '0';
		}

		$writer->startTag($tagname);
		$writer->startTag('RawString');
		$writer->characters($line);
		$writer->endTag('RawString');
		$writer->endTag($tagname);

		last if ($i > 2); # title, keywords, description は3番目までに全て入っている
	    }
	}

	# アウトリンク情報を出力
	&print_outlinks($url, $parsed->{OUTLINKS});

	$writer->endTag('Header');
	$writer->startTag('Text', Type => 'default');
    }
    else {
	if ($url) {
	    printf qq(<PAGE URL="%s">\n), $url;
	}
	else {
	    print "<PAGE>\n";
	}
    }
}

sub print_outlinks {
    my ($baseurl, $outlinks) = @_;

    my @buff;
    if ($opt{xml}) {
	$writer->startTag('OutLinks');
	foreach my $rawstring (keys %$outlinks) {
	    my $urls = $outlinks->{$rawstring};

	    $writer->startTag('OutLink');

	    $writer->startTag('RawString');
	    $writer->characters($rawstring);
	    $writer->endTag('RawString');

	    $writer->startTag('DocIDs');
	    foreach my $_url (@$urls) {
		my $URL = &convertURL($baseurl, $_url);

		$writer->startTag('DocID', Url => $URL);
		$writer->endTag('DocID');

		if ($opt{make_urldb}) {
		    push (@buff, {url => $URL, text => $rawstring});
		}
	    }
	    $writer->endTag('DocIDs');

	    $writer->endTag('OutLink');
	}
	$writer->endTag('OutLinks');
    }
    else {
	# 何もしない
    }

    if ($opt{make_urldb}) {
	open (WRITER, '>:utf8', sprintf ("%s/h%s.outlinks", $dir, $id)) or die "$!";
	foreach my $e (@buff) {
	    printf WRITER ("%s\t%s\t%s\t%s\n"), $id, $url, $e->{url}, $e->{text};
	}
	close (WRITER);
    }
}

# 相対パスから絶対パスへ変換
sub convertURL {
    my ($url, $fpath) = @_;

    my $returl = (defined $url) ? URI->new($fpath)->abs($url) : $fpath;

    # プロトコル削除
    # $returl =~ s/^.+?:\/\///;

    return $returl;
}

sub print_extract_sentences {
    my ($parsed, $buf) = @_;
    my ($prev_offset, $prev_length);

    my $para = 0;
    my $prev_para = -1;
    for my $i (0 .. $#{$parsed->{TEXT}}) {
	my $line = $parsed->{TEXT}[$i];

	if ($opt{xml}) {
	    next if (defined $parsed->{PROPERTY}[$i]{title} ||
		     defined $parsed->{PROPERTY}[$i]{keywords} ||
		     defined $parsed->{PROPERTY}[$i]{description});

	    if (length($line) > 200) {
		print STDERR "The following sentence has too much chars: $line\n";
		next;
	    }

	    $prev_offset = $parsed->{PROPERTY}[$i]{offset};
	    $prev_length = $parsed->{PROPERTY}[$i]{length};

	    if ($opt{checkjapanese}) {
		my $score = sprintf("%.5f", $Filter->JapaneseCheck($line));
		my $is_Japanese = $score > $Threshold_Filter ? '1' : '0';

		# $writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length}, is_Japanese => $is_Japanese, JapaneseScore => $score);
	    }

#	    $writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length});
	    $para++ if ($prev_para < -1 || $prev_para != $parsed->{PROPERTY}[$i]{paragraph});
	    $prev_para = $parsed->{PROPERTY}[$i]{paragraph};

	    $writer->startTag('S', Paragraph => $para);
	    $writer->startTag('RawString');
	    $writer->characters($line);
	    $writer->endTag('RawString');
	    $writer->endTag('S');
	}
	else {
	    print $line, "\n";
	}
    }
}

sub print_page_footer {
    if ($opt{xml}) {
	$writer->endTag('Text');
	$writer->endTag('StandardFormat');
	$writer->end();
    }
    else {
	print "</PAGE>\n";
    }
}

sub postp_check {
    my ($buf) = @_;
    my ($pp_count, $count);

    $count = length ($buf);
#    $pp_count = ($buf =~ s/が|を|に|は|の|で/$&/g); # not optimal
=begin
    my $min = $count * $Threshold_Zyoshi;
    while ($pp_count <= $min && $buf =~ /が|を|に|は|の|で/o) { # min search
      $pp_count++;
      $buf = $';
    }
=cut
#=heavy computation
    foreach my $chr (split(//, $buf)) {
	next if $chr eq "\n";
	if ($chr =~ /^が|を|に|は|の|で$/) {
	    $pp_count++;
	}
	$count++;
    }
#=cut
    return eval {$pp_count/$count};
}

sub convertTimeFormat {
    my ($timestr) = @_;

    my ($YYYY,$MM,$DD,$hh,$mm,$ss,$TZ) = parse_date($timestr);
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d %s", $YYYY, $MM, $DD, $hh, $mm, $ss, $TZ);
}
