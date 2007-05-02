#!/usr/bin/env perl

# encodingを判定するスクリプト

# metaのcharsetが日本語のものならOK
# charsetの記述がないならguess_encodingで推定し、日本語のものならOK
# utf-8は日本語かどうかは判定せず、とりあえずOKにしている

# --with-header: 入力にHTTPヘッダがついているときに指定

use Getopt::Long;
use HtmlGuessEncoding;
use strict;

sub usage {
    $0 =~ /([^\/]+)$/;
    print "Usage: [--with-header] [--language lang] $0 input.html\n";
    exit 255;
}

our (%opt);
&GetOptions(\%opt, 'with-header', 'language=s', 'help', 'debug');
&usage if $opt{help};
$opt{language} = 'japanese' unless $opt{language};

our $RequireContentType = 'text/html'; # HTTPヘッダ付きの場合はhtmlのみを扱う
our $HtmlGuessEncoding = new HtmlGuessEncoding(\%opt);

my ($buf, $header);
my $in_header_flag = 1;
while (<>) {
    if ($opt{'with-header'} and $in_header_flag) {
	$header .= $_;
	if (/^\r?$/) { # HTTPヘッダの終わり
	    $in_header_flag = 0;
	}
    }
    else {
	$buf .= $_;
    }
}

# HTTPヘッダがある場合はhtmlかどうかをチェック
# HTTPヘッダ中のcharsetは現在チェックしていない
if ($header) {
    if ($header =~ /\ncontent-type:\s*$RequireContentType([^\n]*)/i) {
	;
    }
    else {
	print STDERR "Content-Type error\n" if $opt{debug};
	print "NG\n";
	exit 1;
    }
}

# 言語判定
if (my $enc = $HtmlGuessEncoding->ProcessEncoding(\$buf)) {
    print STDERR "Encoding: $enc\n" if $opt{debug};
    print "OK\n";
    exit 0;
}
else {
    print STDERR "Encoding error\n" if $opt{debug};
    print "NG\n";
    exit 1;
}
