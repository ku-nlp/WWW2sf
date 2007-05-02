#!/usr/bin/env perl

# encoding��Ƚ�ꤹ�륹����ץ�

# meta��charset�����ܸ�Τ�Τʤ�OK
# charset�ε��Ҥ��ʤ��ʤ�guess_encoding�ǿ��ꤷ�����ܸ�Τ�Τʤ�OK
# utf-8�����ܸ줫�ɤ�����Ƚ�ꤻ�����Ȥꤢ����OK�ˤ��Ƥ���

# --with-header: ���Ϥ�HTTP�إå����Ĥ��Ƥ���Ȥ��˻���

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

our $RequireContentType = 'text/html'; # HTTP�إå��դ��ξ���html�Τߤ򰷤�
our $HtmlGuessEncoding = new HtmlGuessEncoding(\%opt);

my ($buf, $header);
my $in_header_flag = 1;
while (<>) {
    if ($opt{'with-header'} and $in_header_flag) {
	$header .= $_;
	if (/^\r?$/) { # HTTP�إå��ν����
	    $in_header_flag = 0;
	}
    }
    else {
	$buf .= $_;
    }
}

# HTTP�إå����������html���ɤ���������å�
# HTTP�إå����charset�ϸ��ߥ����å����Ƥ��ʤ�
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

# ����Ƚ��
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
