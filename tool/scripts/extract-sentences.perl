#!/usr/bin/env perl

# html��ʸ�ꥹ�Ȥ��Ѵ�

# $Id$

use strict;
use TextExtor2;
use Encode::Guess;
use XML::Writer;
use File::stat;
use POSIX qw(strftime);
use HtmlGuessEncoding;
use SentenceFilter;
use ConvertCode qw(convert_code);
use Getopt::Long;

sub usage {
    $0 =~ /([^\/]+)$/;
    print "Usage: $1 [--language english|japanese] [--xml] [--url string] [--checkjapanese] [--checkzyoshi] [--checkencoding] file.html\n";
    exit 1;
}

our (%opt, $writer, $filter);
&GetOptions(\%opt, 'language=s', 'url=s', 'xml', 'checkjapanese', 'checkzyoshi', 'zyoshi_threshold=f', 'checkencoding', 'ignore_br', 'blog=s', 'cndbfile=s');
$opt{language} = 'japanese' unless $opt{language};
$opt{blog} = 'none' unless $opt{blog};

# --checkencoding: encoding������å����ơ����ܸ�ǤϤʤ����󥳡��ǥ��󥰤ʤ鲿����Ϥ�����λ����
# --checkjapanese: ���ܸ�(�Ҥ餬�ʡ��������ʡ�����)��ͭΨ������å�����
# --checkzyoshi:   �����ͭΨ������å�����

my ($buf, $timestamp, $url);

my $HtmlGuessEncoding = new HtmlGuessEncoding(\%opt);
my $Filter = new SentenceFilter if $opt{checkjapanese};

our $Threshold_Filter = 0.6;
our $Threshold_Zyoshi = $opt{zyoshi_threshold} ? $opt{zyoshi_threshold} : 0.005;

# �ե�����̾��Ϳ�����Ƥ���Х����ॹ����פ����
if ($ARGV[0] and -f $ARGV[0]) {
    my $st = stat($ARGV[0]);
    $timestamp = strftime("%Y-%m-%d %T", localtime($st->mtime));
}

my $flag = -1;
my $crawler_html = 0;
while (<>) {
    if (!$buf and /^HTML (\S+)/) { # 1���ܤ���URL�����(read-zaodata�����Ϥ��Ƥ���)
	$url = $1;
	$crawler_html = 1;
    }

    # �إå������ɤ߽����ޤǥХåե���󥰤��ʤ�
    if (!$crawler_html || $flag > 0) {
	$buf .= $_;
    } else {
	if ($_ =~ /^\r$/) {
	    $flag = 1;
	}
    }
}
exit 0 unless $buf;

my $encoding = $HtmlGuessEncoding->ProcessEncoding(\$buf, {change_to_utf8 => 1});
exit if $opt{checkencoding} and !$encoding;

# �ȥ�å��Хå��������ȡ���˥塼��ʬ������Movable Type�ѡ�
if($opt{blog} eq 'mt'){
    # <head>���
    if ($buf =~ m!^((?:.|\n|\r)+)<head>(?:.|\n|\r)+?</head>((?:.|\n|\r)+)$!) {
	$buf = $1 . $2;
    }

    # banner-inner, content-nav, entry-footer����
    if ($buf =~ m!^((?:.|\n|\r)+)<div id="banner-inner" class="pkg">(?:.|\n|\r)+?</div>((?:.|\n|\r)+)$!) {
	$buf = $1 . $2;
    }
    if ($buf =~ m!^((?:.|\n|\r)+)<p class="content-nav">(?:.|\n|\r)+?</p>((?:.|\n|\r)+)$!) {
	$buf = $1 . $2;
    }
    if ($buf =~ m!^((?:.|\n|\r)+)<p class="entry-footer">(?:.|\n|\r)+?</p>((?:.|\n|\r)+)$!) {
	$buf = $1 . $2;
    }

    if($buf =~ /<div class=\"trackbacks\">/){
	my $before_menu = "$`";
	my $menu_part = "$&$'";
	while(1){
	    if($menu_part =~ m!</div>!){
		my $fwd = "$`";
		my $bck = "$'";
		if($fwd =~ m!(( |.|\n|\r)*)<div !){
		    $menu_part = $1 . $bck;
		}else{
		    last;
		}
	    }else{
		print "nothing.\n";
	    }
	}
	$buf = $before_menu . $menu_part;
    }

    if($buf =~ /<div id=\"comments\" class=\"comments\">/){
	my $before_menu = "$`";
	my $menu_part = "$&$'";
	while(1){
	    if($menu_part =~ m!</div>!){
		my $fwd = "$`";
		my $bck = "$'";
		if($fwd =~ m!(( |.|\n|\r)*)<div !){
		    $menu_part = $1 . $bck;
		}else{
		    last;
		}
	    }else{
		print "nothing.\n";
	    }
	}
	$buf = $before_menu . $menu_part;
    }

    if($buf =~ /<div id=\"beta-inner\" class=\"pkg\">/){
	my $before_menu = "$`";
	my $menu_part = "$&$'";
	while(1){
	    if($menu_part =~ m!</div>!){
		my $fwd = "$`";
		my $bck = "$'";
		if($fwd =~ m!(( |.|\n|\r)*)<div !){
		    $menu_part = $1 . $bck;
		}else{
		    last;
		}
	    }else{
		print "nothing.\n";
	    }
	}
	$buf = $before_menu . $menu_part;
    }
}

# ������Υإå�����
$buf =~ s/^(?:\d|.|\n)*?(<html)/\1/i if $crawler_html;

# ������Υեå�����
$buf =~ s/^((?:.|\n)+<\/html>)(.|\n)*?(\d|\r|\n)+$/\1\n/i if $crawler_html;

# HTML��ʸ�Υꥹ�Ȥ��Ѵ�
my $parsed = new TextExtor2(\$buf, 'utf8', \%opt);

# �����ͭΨ������å�
if ($opt{checkzyoshi}) {
    my $allbuf;
    for my $i (0 .. $#{$parsed->{TEXT}}) {
	$allbuf .= $parsed->{TEXT}[$i];
    }

    my $ratio = &postp_check($allbuf);
    exit if $ratio <= $Threshold_Zyoshi;
}

# XML���Ϥν���
if ($opt{xml}) {
    require XML::Writer;
    $writer = new XML::Writer(OUTPUT => *STDOUT, DATA_MODE => 'true', DATA_INDENT => 2);
    $writer->xmlDecl('utf-8');
}

# ʸ��ʬ�䤷�ƽ���
&print_page_header($opt{url} ? $opt{url} : $url, $encoding, $timestamp);
&print_extract_sentences($buf);
&print_page_footer();

sub print_page_header {
    my ($url, $encoding, $timestamp) = @_;

    if ($opt{xml}) {
	$writer->startTag('StandardFormat', Url => $url, OriginalEncoding => $encoding, Time => $timestamp);

	$writer->startTag('Header');
	for my $i (0 .. $#{$parsed->{TEXT}}) {
	    my $line = $parsed->{TEXT}[$i];
	    if ($opt{xml}) {
		if(defined($parsed->{PROPERTY}[$i]{title})){
		    $line = &convert_code($line, 'euc-jp', 'utf8');

		    if ($opt{checkjapanese}) {
			my $score = sprintf("%.5f", $Filter->JapaneseCheck($line));
			my $is_Japanese = $score > $Threshold_Filter ? '1' : '0';
			
			$writer->startTag('Title', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length}, is_Japanese => $is_Japanese, JapaneseScore => $score);
		    } else {
			$writer->startTag('Title', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length});
		    }

		    $writer->startTag('RawString');
		    $writer->characters($line);
		    $writer->endTag('RawString');
		    $writer->endTag('Title');

		    last;
		}
	    }
	}
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

sub print_extract_sentences {
    my ($buf) = @_;
    my ($prev_offset, $prev_length);

    for my $i (0 .. $#{$parsed->{TEXT}}) {
	my $line = $parsed->{TEXT}[$i];

	if ($opt{xml}) {
	    next if (defined($parsed->{PROPERTY}[$i]{title}));

	    $prev_offset = $parsed->{PROPERTY}[$i]{offset};
	    $prev_length = $parsed->{PROPERTY}[$i]{length};

 	    $line = &convert_code($line, 'euc-jp', 'utf8');

	    if ($opt{checkjapanese}) {
		my $score = sprintf("%.5f", $Filter->JapaneseCheck($line));
		my $is_Japanese = $score > $Threshold_Filter ? '1' : '0';

		$writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length}, is_Japanese => $is_Japanese, JapaneseScore => $score);
	    }
	    else {
		$writer->startTag('S', Offset => $parsed->{PROPERTY}[$i]{offset}, Length => $parsed->{PROPERTY}[$i]{length});
	    }
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

#    $buf = &convert_code($buf, 'utf8', 'euc-jp');

    while ($buf =~ /([^\x80-\xfe]|[\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/g) {
	my $chr = $1;
	next if $chr eq "\n";
	if ($chr =~ /^��|��|��|��|��|��$/) {
	    $pp_count++;
	}
	$count++;
    }

    return eval {$pp_count/$count};
}
