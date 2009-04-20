#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
use Getopt::Long;
use Error qw(:try);
use Archiver;
use File::Path;
use HtmlGuessEncoding;
use File::Basename;
use TextExtractor;
use HTTP::Date qw(parse_date);
use URI;
use URI::Split qw(uri_split uri_join);
use URI::Escape;
use Encode qw(encode decode);
use Encode::Guess;
use XML::Writer;
use File::stat;
use POSIX qw(strftime);
use HtmlGuessEncoding;
use SentenceFilter;
use ConvertCode qw(convert_code);
use HTML::Entities;
use XML::LibXML;
use SentenceFormatter;
use Error qw(:try);

binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my (%opt);
&GetOptions(\%opt,
# Not Supported
#	    'jmn',
#	    'knp',
#	    'syn',
#	    'case',
	    'htmldir=s',
	    'outdir=s',
	    'z',
	    'save_utf8html=s',
#	    'ignore_encoding',
	    'filesize',
	    'linenum=s',
	    'workspace=s',
	    'cndb',

	    'include_paren',
	    'divide_paren',
	    'save_all',

	    'language=s',
	    'url=s',
	    'xml',
	    'checkjapanese',
	    'checkzyoshi',
	    'zyoshi_threshold=f',
	    'checkencoding',
	    'ignore_br',
	    'blog=s',
	    'cndbfile=s',
	    'uniq_br_and_linebreak',
	    'make_urldb',
	    'verbose',
	    'help'
	    );


mkdir $opt{save_utf8html} if (!-e $opt{save_utf8html} && $opt{save_utf8html});

# ファイルサイズの閾値(default 5M)
$opt{filesize} = 5242880 unless ($opt{filesize});
$opt{linenum} = 5000 unless ($opt{linenum});

$opt{checkencoding} = 1;
$opt{checkjapanese} = 1;
# $opt{checkzyoshi} = 1;

$opt{language} = 'japanese' unless $opt{language}; # デフォルト言語: japanese
$opt{blog} = 'none' unless $opt{blog};

my $MAX_LENGTH_OF_HTML_ENTITY = ($opt{max_length_of_html_entity}) ? $opt{max_length_of_html_entity} : 10;
$opt{html_encoding} = 'utf8' unless ($opt{html_encoding});
$opt{max_num_of_discardable_chars_for_rawstring} = 5;
$opt{max_num_of_discardable_chars_for_html} = 10;

my $Filter = new SentenceFilter if $opt{checkjapanese};

# --checkencoding: encodingをチェックして、日本語ではないエンコーディングなら何も出力せず終了する
# --checkjapanese: 日本語(ひらがな、カタカナ、漢字)含有率をチェックする
# --checkzyoshi:   助詞含有率をチェックする

open (OUT_LINK_WRITER, '>:utf8', sprintf ("%s.outlinks", $opt{htmldir})) or die "$!" if ($opt{make_urldb});

&main();

close (OUT_LINK_WRITER) if ($opt{make_urldb});



sub main {
    # load parameters.
    my ($VERSION, $CRAWL_DATE) = &loadParameters();


    my @files;
    if ($opt{htmldir}) {
	opendir (DIR, $opt{htmldir}) or die $!;
	@files = map {$_ = sprintf ("%s/%s", $opt{htmldir}, $_) } grep { $_ ne '.' && $_ ne '..'} readdir (DIR);
	close (DIR);
    } else {
	@files = @ARGV;
    }


    my $makeWorkspace = 0;
    unless (-e $opt{workspace}) {
	mkpath $opt{workspace};
	$makeWorkspace = 1;
    }

    # cat files in the directory.
    $opt{skip_binary_file} = 1;
    my $archiver = new Archiver(\@files, \%opt);



    my $HtmlGuessEncoding = new HtmlGuessEncoding({language => 'japanese'});


    $opt{Threshold_Filter} = 0.6;
    $opt{Threshold_Zyoshi} = $opt{zyoshi_threshold} ? $opt{zyoshi_threshold} : 0.005;

    my $textextractor_option = {language => $opt{language}};
    $textextractor_option->{uniq_br_and_linebreak} = $opt{uniq_br_and_linebreak} if $opt{uniq_br_and_linebreak};
    $textextractor_option->{cndbfile} = $opt{cndbfile} if $opt{cndbfile};
    $textextractor_option->{verbose} = $opt{verbose} if $opt{verbose};

    while (my $file = $archiver->nextFile()) {
	# ファイルサイズを調べる
	if ($file->{size} > $opt{filesize}) {
	    printf STDERR "[SKIP] %s is over file size.\n", $file->{name};
	    next;
	}

	# 入力ファイルの行数が5000行を超える場合は怪しいファイルと見なす
	if ($file->{linenum} > $opt{linenum}) {
	    printf STDERR "[SKIP] %s is over lines.\n", $file->{name};
	    next;
	}

	# utf8に変換(crawlデータは変換済みのため、強制的に utf8 と判断させる)
	unless ($HtmlGuessEncoding->ProcessEncoding(\$file->{content}, {force_change_to_utf8_with_flag => $opt{force}, change_to_utf8 => !$opt{utf8}})) {
	    next;
	}



	############################################################
	#                      処理開始
	############################################################

	my $ext = new TextExtractor($textextractor_option);
	my $htmlrawdat = $file->{content};
	my ($url, $crawlTime, $buf, $isCrawlerHtml) = &getParameterFromHtmlheader($file->{content});

	my $htmlfile = $file->{name};
	my ($id) = ($htmlfile =~ /(\d+)\.html?/);
	my $dir = `dirname $htmlfile`; chop $dir;

	my $encoding = $HtmlGuessEncoding->ProcessEncoding(\$buf, {force_change_to_utf8_with_flag => 1});
	next if $opt{checkencoding} and !$encoding;


	if ($opt{save_utf8html}) {
	    open (HTMLFILE, sprintf ("> %s/%s.html", $opt{save_utf8html}, $id)) or die $!;
	    print HTMLFILE $htmlrawdat;
	    close (HTMLFILE)
	}

	my $xmldat = &process_one_html($buf, $url, $encoding, $isCrawlerHtml, $ext, $crawlTime, $VERSION, $CRAWL_DATE, $htmlrawdat, $id);

	if ($xmldat) {
	    open (WRITER, '>:utf8', sprintf ("%s/%09d.xml", $opt{outdir}, $id));
	    print WRITER $xmldat;
	    close (WRITER);
	}
    }
    $archiver->close();
}

# トラックバック、コメント、メニュー部分を削除（Movable Type用）
sub removeTemplate4MovableType {
    my ($buf) = @_;

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

# ひとつのHTMLを処理
sub process_one_html {
    my ($buf, $url, $encoding, $crawler_html, $ext, $crawlTime, $VERSION, $CRAWL_DATE, $htmldat, $id) = @_;

    # トラックバック、コメント、メニュー部分を削除（Movable Type用）
    &removeTemplate4MovableType($buf) if ($opt{blog} eq 'mt');

    if ($crawler_html) {
	# クローラのヘッダを削除
	$buf =~ s/^(?:\d|.|\n|\r)*?(<html)/\1/i;
	# クローラのフッタを削除
	$buf =~ s/(<\/html>)(([^>]|\n)*?)?(\d|\r|\n)+$/\1\n/i if ($crawler_html);
    }

    # HTMLを文のリストに変換
    my $parsed = $ext->extract_text(\$buf);

    # 助詞含有率をチェック
    if ($opt{checkzyoshi}) {
	my $allbuf;
	for my $i (0 .. $#{$parsed->{TEXT}}) {
	    $allbuf .= $parsed->{TEXT}[$i];
	}

	my $ratio = &postp_check($allbuf);
	if ($ratio <= $opt{Threshold_Zyoshi}) {
	    print STDERR "[SKIP] $id is * NOT * a Japanese web page. (joshi ratio $ratio (< $opt{Threshold_Zyoshi}))\n";
	    return 0;
	}
    }


    my $writer;
    my $xmldat;
    # XML出力の準備
    if ($opt{xml}) {
	require XML::Writer;
	$writer = new XML::Writer(OUTPUT => \$xmldat, DATA_MODE => 'true', DATA_INDENT => 2);
	$writer->xmlDecl('utf-8');
    }

    # 文に分割して出力
    &print_page_header($writer, $parsed, $opt{url} ? $opt{url} : $url, $encoding, $crawlTime, $VERSION, $CRAWL_DATE, $id);
    &print_extract_sentences($writer, $parsed, $buf);
    &print_page_footer($writer);

    $xmldat = &embedOffsetAndLength($htmldat, $xmldat, $crawler_html);


    return $xmldat;
}

sub embedOffsetAndLength {
    my ($htmldat, $xmldat, $crawler_html) = @_;

    # クローラのヘッダはアライメントの対象としない
    my $ignored_chars;
    if ($crawler_html) {
	if ($htmldat =~ /^((\d|.|\n)*?)(<html(.|\n|\r)+)$/i) {
	    $ignored_chars .= $1;
	    $htmldat = $3;
	}
    }

    # HTML文書からテキストを取得
    $htmldat = encode ('utf8', $htmldat) if (utf8::is_utf8($htmldat));
    $ignored_chars = encode ('utf8', $ignored_chars) if (utf8::is_utf8($ignored_chars));

    my $ext = new TextExtractor({language => 'japanese', offset => length($ignored_chars)});
    my ($text, $property) = $ext->detag(\$htmldat, {always_countup => 1});

    for (my $i = 0; $i < scalar(@$text); $i++) {
	$text->[$i] = decode('utf8', $text->[$i]) unless (utf8::is_utf8($text->[$i]));
	$text->[$i] =~ s/&nbsp;/      /g;

	# HTMLエンティティを変換し、差分の文字数を半角空白でつめる
	# &lt; -> '<___'
	my $buf;
	while ($text->[$i] =~ /(&.+?;)/g) {
	    $buf .= "$`";
	    $text->[$i] = "$'";

	    my $entity = $1;
	    my $length = length($entity);
	    my $decodedEntity = decode_entities($entity);

	    # 置換後のエンティティの置換前の文字列の差分を計算
	    my $decodedEntityByte = length(encode('utf8', $decodedEntity));
	    my $diff = $length - $decodedEntityByte;

	    $buf .= $decodedEntity;
	    # print STDERR "$entity $decodedEntity $diff\n";
	    # 差分の文だけ半角空白をつける
	    for (my $j = 0; $j < $diff; $j++) {
		$buf .= ' ';
	    }
	}

	$buf .= $text->[$i];
	$text->[$i] = $buf;
	# print "[ " . $text->[$i] . "]\n";
	# $text->[$i] = decode_entities($text->[$i]);
    }

    # 標準フォーマットから文情報を取得
    my $parser = new XML::LibXML;
    my $doc = $parser->parse_string($xmldat);
    my $sentences = &get_sentence_nodes($doc);


    # HTML文書、標準フォーマット間 のアライメントをとる
    foreach my $s (@$sentences) {
	my $rawstring = &get_rawstring($s);
	my ($offset, $length, $is_successful) = &get_offset_and_length($rawstring, $text, $property);
	$s->setAttribute('Offset', $offset);
	$s->setAttribute('Length', $length);

	unless ($is_successful) {
	    # print STDERR "Fail to set offset alignment: " . $opt{xml} . "\n";
	    # &seek_common_char();
	}
    }

    foreach my $tagName (('Title', 'Description', 'Keywords', 'S')) {
	my %option = (
		      setLogAttribute => 0,
		      setIdAttribute  => (($tagName eq 'S') ? 1 : 0)
		      );

	&xml_check_sentence($doc, $tagName, \%option);
    }

    my $string = $doc->toString();
    return utf8::is_utf8($string) ? $string : decode($doc->actualEncoding(), $string);
}

sub print_page_header {
    my ($writer, $parsed, $url, $encoding, $crawlTime, $VERSION, $CRAWL_DATE, $id) = @_;

    my $formatTime = strftime("%Y-%m-%d %T %Z", localtime(time));

    if ($opt{xml}) {
	$writer->startTag('StandardFormat',
			  Url => $url,
			  OriginalEncoding => $encoding,
			  CrawlTime => (($crawlTime) ? $crawlTime : $CRAWL_DATE),
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
		    my $is_Japanese = $score > $opt{Threshold_Filter} ? '1' : '0';
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
	&print_outlinks($writer, $url, $parsed->{OUTLINKS}, $id, $url);

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
    my ($writer, $baseurl, $outlinks, $id, $url) = @_;

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

		try {
		    $writer->startTag('DocID', Url => $URL);
		    $writer->endTag('DocID');
		} catch Error with {
		    my $err = shift;
		    print STDERR "Exception at line ",$err->{-line}," in ",$err->{-file},"(",$err->{-text} ,")\n";
		    next;
		};

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
 	foreach my $e (@buff) {
 	    printf OUT_LINK_WRITER ("%s\t%s\t%s\t%s\n"), $id, $url, $e->{url}, $e->{text};
 	}
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
    my ($writer, $parsed, $buf) = @_;
    my ($prev_offset, $prev_length);

    my $para = 0;
    my $sid = 1;
    my $prev_para = -1;
    for my $i (0 .. $#{$parsed->{TEXT}}) {
	my $line = $parsed->{TEXT}[$i];


	if ($opt{xml}) {
	    next if (defined $parsed->{PROPERTY}[$i]{title} ||
		     defined $parsed->{PROPERTY}[$i]{keywords} ||
		     defined $parsed->{PROPERTY}[$i]{description});

	    if (length($line) > 200) {
#		print STDERR "The following sentence has too much chars: $line\n";
		next;
	    }

	    $prev_offset = $parsed->{PROPERTY}[$i]{offset};
	    $prev_length = $parsed->{PROPERTY}[$i]{length};

	    my $is_Japanese = 0;
	    if ($opt{checkjapanese}) {
		my $score = sprintf("%.5f", $Filter->JapaneseCheck($line));
		$is_Japanese = $score > $opt{Threshold_Filter} ? '1' : '0';

		# $writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length}, is_Japanese => $is_Japanese, JapaneseScore => $score);
	    }

#	    $writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length});
	    $para++ if ($prev_para < -1 || $prev_para != $parsed->{PROPERTY}[$i]{paragraph});
	    $prev_para = $parsed->{PROPERTY}[$i]{paragraph};

	    $writer->startTag('S', Paragraph => $para, Offset => '', Length=> '');
	    $writer->startTag('RawString');
	    $writer->characters($line);
	    $writer->endTag('RawString');
	    $writer->endTag('S');
	    $sid++;
	}
	else {
	    print $line, "\n";
	}
    }
}

sub xml_check_sentence {
    my ($doc, $tagName, $opt) = @_;
    my $count = 1;

    my $formatter = new SentenceFormatter(\%opt);
    for my $sentence ($doc->getElementsByTagName($tagName)) { # for each $tagName
	my $is_japanese_flag = $sentence->getAttribute('is_Japanese');
	if (defined($is_japanese_flag) and $is_japanese_flag == 0) { # do not process non-Japanese
	    $sentence->setAttribute('is_Japanese_Sentence', '0');
	    $sentence->setAttribute('Id', $count++) if ($opt->{setIdAttribute});
	    next;
	}

	my (@parens);
	for my $raw_string_node ($sentence->getChildNodes) {
	    if ($raw_string_node->nodeName eq 'RawString') {
		my $raw_string_element = $raw_string_node->getFirstChild; # text content node
		my ($main);

		# 全文削除や括弧の処理
		($main, @parens) = $formatter->FormatSentence($raw_string_element->string_value, $count);
		if ($main->{sentence}) {
		    $sentence->setAttribute('is_Japanese_Sentence', '1');
		    $raw_string_node->removeChild($raw_string_element);
		    $raw_string_node->appendChild(XML::LibXML::Text->new($main->{sentence}));
		}
		else { # 全文削除されても、RawStringには残す
		    $sentence->setAttribute('is_Japanese_Sentence', '0');
		    # $raw_string_node->removeChild($raw_string_element);
		    # $raw_string_node->appendChild(XML::LibXML::Text->new(''));
		}
		$sentence->setAttribute('Id', $main->{sid}) if ($opt->{setIdAttribute});
		$sentence->setAttribute('Log', $main->{comment}) if ($main->{comment} && $opt->{setLogAttribute});
		$count++;
		last;
	    }
	}

	# 括弧文の処理 (--divide_paren時)
	if (@parens) {
	    my $paren_node = $doc->createElement('Parenthesis');
	    for my $paren (@parens) {
		my $new_sentence_node = $doc->createElement('S');
		$new_sentence_node->setAttribute('Id', $paren->{sid});
		$new_sentence_node->setAttribute('Log', $paren->{comment}) if $paren->{comment};

		my $string_node = $doc->createElement('RawString');
		$string_node->appendChild(XML::LibXML::Text->new($paren->{sentence}));

		$new_sentence_node->appendChild($string_node);
		$paren_node->appendChild($new_sentence_node);
	    }

	    $sentence->appendChild($paren_node);
	    @parens = ();
	}
    }
}

sub print_extract_sentences_bak {
    my ($writer, $parsed, $buf) = @_;
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
		my $is_Japanese = $score > $opt{Threshold_Filter} ? '1' : '0';

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
    my ($writer) = @_;
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

    # modified by ynaga.
    $pp_count = ($buf =~ s/(が|を|に|は|の|で)/\1/g);
    $count = length($buf);

    return eval {$pp_count/$count};
}

sub convertTimeFormat {
    my ($timestr) = @_;

    my ($YYYY,$MM,$DD,$hh,$mm,$ss,$TZ) = parse_date($timestr);
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d %s", $YYYY, $MM, $DD, $hh, $mm, $ss, $TZ);
}

sub getParameterFromHtmlheader {
    my ($doc) = @_;

    my ($url, $crawlTime, $buf);

    my $crawler_html = 0;
    my $flag = -1;
    foreach (split /(?:\n)/, $doc) {
	$_ .= "\n";
	if (/^HTML (\S+)/ && $flag < 0) { # 1行目からURLを取得(read-zaodataが出力している)
	    $crawler_html = 1;
	    $url = $1;
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
    }

    return ($url, $crawlTime, $buf, $crawler_html);
}


sub loadParameters {
    my ($VERSION, $CRAWL_DATE);

    # 変換スクリプトのバージョンを読み込み
    my $version_file = sprintf("%s/data/VERSION", dirname($0));
    if (-e $version_file) {
	open F, "< $version_file" or die $!;
	$VERSION = <F>;
	chomp $VERSION;
	close F;
    } else {
	print STDERR "[WARNING] data/VERSION file was not found.\n";
    }


    # Date: がない場合用にクロール日をあらかじめ記述したファイルをロード
    my $crawldate_file = sprintf("%s/data/CRAWL_DATE", dirname($0));
    if (-e $crawldate_file) {
	open F, "< $crawldate_file" or die $!;
	$CRAWL_DATE = <F>;
	chomp $CRAWL_DATE;
	close F;
    } else {
	print STDERR "[WARNING] data/CRAWL_DATE file was not found.\n";
    }

    return ($VERSION, $CRAWL_DATE);
}

sub get_offset_and_length {
    my ($rawstring, $text, $property) = @_;

    my @chars_r = split(//, $rawstring);
    my @chars_h = split(//, $text->[0]);

    if ($opt{verbose}) {
	print "\n";
	print "--------------------------------------------------\n";
	print "rawstring: [$rawstring]\n";
	print "html_text: [" . $text->[0] . "]\n";
	print "--------------------------------------------------\n";
    }

    my $i = 0; # @chars_rの添字
    my $j = 0; # @chars_hの添字

    my $offset = -1;
    my $miss = -1;
    my $prev_ch_h = undef;
    while ($i < scalar(@chars_r)) {

	# @chars_hを読みきった時の処理 length(@chars_r) > length(@chars_h)
	if ($j >= scalar(@chars_h)) {
	    # 使い切った分を削除
	    shift(@$text);
	    shift(@$property);

	    print "-----\n" if ($opt{verbose});
	    print "[" . $text->[0] . "]\n" if ($opt{verbose});
	    @chars_h = split(//, $text->[0]);
	    $j = 0;
	}

	($i, $j, $offset, $miss, $prev_ch_h) = &alignment(\@chars_r, \@chars_h, $i, $j, $offset, $property, $prev_ch_h);

	last if ($miss > 0);
    }

    # アライメント失敗
    if ($miss > 0) {
	return (-1, -1, 0);
    } else {
	# アライメントに使用した分を除去
	my @removed = splice(@chars_h, 0, $j);
	my $removed_string = join('', @removed);

	my $length = length(encode($opt{html_encoding}, $removed_string));

	if ($property->[0]{offset} - $offset > 0) {
	    $length += ($property->[0]{offset} - $offset);
	}

	# 未使用部分を文字列に戻す
	my $substring_unused = join('', @chars_h);
	$text->[0] = $substring_unused;

	if ($opt{verbose}) {
	    print "----------\n";
	    print $removed_string . " is removed. ($length bytes)\n";
	    print "property->[0]{offset}: " . $property->[0]{offset} . " -> " . ($property->[0]{offset} + $length) . "\n";
	    print "----------\n";
	}

	# 使用した分だけオフセットをずらす
	$property->[0]{offset} = $offset + $length;

	return ($offset, $length, 1);
    }
}


# アライメントをとる関数
sub alignment {
    my ($chars_r, $chars_h, $r, $h, $offset, $property, $prev_ch_h) = @_;

    my $ch_r = $chars_r->[$r];
    my $next_ch_h = $chars_h->[$h + 1];
    my $ch_h = &normalized($chars_h->[$h], $prev_ch_h);

    print "r:[$ch_r] cmp h:[$ch_h] next_h:[$next_ch_h] off=$offset ord:r=" . ord($ch_r) . " ord:h=" . ord($ch_h) . "\n" if ($opt{verbose});

    # マッチ
    if ($ch_r eq $ch_h) {
	if ($offset < 0) {
	    $offset = $property->[0]{offset};
	}
	$r++;
	$h++;
    }
    # HTML側が空文字の時はスキップ
    elsif ($ch_h eq '' || $ch_h eq "\x{00A0}") {
	$h++;
    }
    # HTML側が空白の時はスキップ
    elsif ($ch_h eq '　') {
	$h++;
    }
    # 標準フォーマット側で文字化けを起こしてる時はスキップ
    elsif ($ch_r eq '?') {
	$r++;
	$h++;
    }
    # 標準フォーマット側で箇条書き処理により挿入された空白はスキップ
    elsif ($ch_r eq '　') {
	$r++;
    }
    # ウェブ文書側の次の文字が半角の濁音、半濁音であれば現在の文字は半角カタカナと見なしスキップ
    # $ch_r = デ, $ch_h ﾃ, $next_ch_h ﾞ
    elsif ($next_ch_h eq 'ﾟ' || $next_ch_h eq 'ﾞ') {
	$r++;
	$h += 2;
    }
    # マッチ失敗
    # 適当に一文字ずつずらして、共通する文字を求める
    else {
	my $flag = -1;
	for (my $i = 0 ; $i  < $opt{max_num_of_discardable_chars_for_rawstring}; $i++) {
	    my $next_char_r = $chars_r->[$i + $r + 1];
	    for (my $j = 0; $j < $opt{max_num_of_discardable_chars_for_html}; $j++) {
		my $next_char_h = &normalized($chars_h->[$j + $h + 1], $chars_h->[$j + $h]);

		print "r:[$next_char_r] cmp h:[$next_char_h] off=$offset miss\n" if ($opt{verbose});

		# ズレの吸収
		if ($next_char_r eq $next_char_h) {
		    $r += ($i + 2);
		    $h += ($j + 2);
		    $flag = 1;
		    last;
		}
	    }
	    last if ($flag > 0);

	    return (-1, -1, $offset, 1, $ch_h) if ($flag < 0);
	}
    }

    return ($r, $h, $offset, -1, $ch_h);
}


# HTML文書側の文字に対して標準フォーマット生成時の変換処理を適用
sub normalized {
    my ($ch, $prev_ch) = @_;

    # 制御コードを空白に変換
    $ch = '　' if ($ch =~ /[\x00-\x1f\x7f-\x9f]/);

    # 半角文字を全角に変換
    $ch = Unicode::Japanese->new($ch)->h2z->getu();

    # `ー'は汎化
    $ch =~ s/(?:ー|―|−|─|━|‐)/ー/ if ($prev_ch =~ /^(\p{Katakana}|ー)$/);

    # euc-jpにないコードを変換
    $ch =~ s/－/−/g; # FULLWIDTH HYPHEN-MINUS (U+ff0d) -> MINUS SIGN (U+2212)
    $ch =~ s/～/〜/g; # FULLWIDTH TILDE (U+ff5e) -> WAVE DASH (U+301c)
    $ch =~ s/∥/‖/g; # PARALLEL TO (U+2225) -> DOUBLE VERTICAL LINE (U+2016)
    $ch =~ s/￠/¢/g;  # FULLWIDTH CENT SIGN (U+ffe0) -> CENT SIGN (U+00a2)
    $ch =~ s/￡/£/g;  # FULLWIDTH POUND SIGN (U+ffe1) -> POUND SIGN (U+00a3)
    $ch =~ s/￢/¬/g;  # FULLWIDTH NOT SIGN (U+ffe2) -> NOT SIGN (U+00ac)
    $ch =~ s/—/―/g; # EM DASH (U+2014) -> HORIZONTAL BAR (U+2015)
    $ch =~ s/¥/￥/g;  # YEN SIGN (U+00a5) -> FULLWIDTH YEN SIGN (U+ffe5)
    # ※ これ以外の特殊な文字は解析時に「〓」に変換 (Juman.pm)

    return $ch;
}


sub get_sentence_nodes {
    my ($doc) = @_;
    my @sentences = ();

    foreach my $tagname ('Title', 'Keywords', 'Description') {
	my $node = $doc->getElementsByTagName($tagname)->[0];
	push(@sentences, $node) if (defined $node);
    }

    foreach my $sentence ($doc->getElementsByTagName('S')) { # for each S
	push(@sentences, $sentence);
    }

    return \@sentences;
}

sub get_rawstring {
    my ($sentence) = @_;
    for my $s_child_node ($sentence->getChildNodes) {
	if ($s_child_node->nodeName eq 'RawString') { # one of the children of S is Text
	    for my $node ($s_child_node->getChildNodes) {
		return $node->string_value;
	    }
	}
    }
}
