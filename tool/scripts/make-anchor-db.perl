#!/usr/bin/env perl

# $Id$

#################################################
# InLink/OutLink データベースを作成するプログラム
#################################################

# キー：文書ID
# 値：リンク情報(\t\tリンク情報)*
#
# リンク情報：リンク元文書ID\tリンク元URL\tリンク先文書ID\tリンク先URL\tオフセット\tバイト長\tアンカーテキスト\tアンカーテキストの解析結果
#
# ※：オフセット、バイト長、アンカーテキストの解析結果はダミー（それぞれ、0, 0, undef）を出力


use strict;
use CDB_Writer;
use utf8;
use Getopt::Long;
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;




my (%opt);
GetOptions(\%opt, 'inlink', 'outlink', 'file=s');

my $N;
my $cdbfp;

my ($fid) = ($opt{file} =~ /(?:h|u)(\d+)\.(in|out)links/);
if ($opt{inlink}) {
    $N = 2;
    $cdbfp = $fid . ".inlinks.cdb";
}
elsif ($opt{outlink}) {
    $N = 0;
    $cdbfp = $fid . ".outlinks.cdb";
}
else {
    print STDERR "-inlink/-outlink のいずれかを指定して下さい.\n";
    exit 1;
}

&main();

sub main {
    if ($opt{file} =~ /gz$/) {
	open(FILE, "zcat $opt{file} |") or die;
    } else {
	open(FILE, $opt{file}) or die;
    }
    binmode(FILE, 'utf8');


    my @buf = ();
    my $prev_id = -1;
    my $cdb = new CDB_Writer($cdbfp, $cdbfp . ".keymap", 2.5 * 1024 * 1024 * 1024, 1000000);
    while (<FILE>) {
	chop;
	my ($from_id, $from_url, $to_id, $to_url, @text) = split(/ /, $_);
	my $key = ($opt{outlink}) ? $from_id : $to_id;
	if ($key ne $prev_id && $prev_id > -1) {
	    my $value = join("\t\t", @buf);
	    $cdb->add($prev_id, $value);
	    @buf = ();
	}
	push(@buf, sprintf qq(%09d\t%s\t%09d\t%s\t0\t0\t%s\tundef), $from_id, $from_url, $to_id, $to_url, join(' ', @text));
	$prev_id = $key;
    }
    close(FILE);

    if (scalar(@buf) > 0) {
	my $value = join("\t\t", @buf);
	$cdb->add($prev_id, $value);
    }

    $cdb->close();
}
