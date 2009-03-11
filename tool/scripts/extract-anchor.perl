#!/usr/bin/env perl

# $Id$

# utf8エンコードされたウェブページからリンク情報を抽出するプログラム
#
#
# 入力
# perl extract-anchor.perl -dir utf8化されたウェブページが収められたディレクトリ -dbmap CDB_Writerが出力した url2did.cdb の keymapファイル [-z]
#
#
# 出力フォーマット
#
# リンク元文書ID リンク元URL リンク先文書ID リンク先URL アンカーテキスト（全角化）
# 037615272 http://www.syasen.com/bk/2006/08/post_39.html www.syasen.com/bk/2006/08/post_233.html 守矢クリニック
#

use strict;
use utf8;
use Encode;
use Getopt::Long;
use HTML::Entities;
use Unicode::Normalize;
use Unicode::Japanese;
use ModifiedTokeParser;
use CDB_Reader;
use URI;

my (%opt);
GetOptions(\%opt, 'dir=s', 'dbmap=s', 'z', 'verbose');

binmode(STDOUT, ':utf8');

&main();

sub main {
    my $url2did = new CDB_Reader($opt{dbmap});

    opendir(DIR, $opt{dir});
    foreach my $file (sort {$a <=> $b} readdir(DIR)) {
	next unless ($file =~ /(\d+)\.html/);

	my $did = $1;
	my $fp = "$opt{dir}/$file";

	if ($opt{z}) {
	    open(READER, "zcat $fp |");
	} else {
	    open(READER, $fp);
	}
	binmode(READER, ':utf8');

	my $line = <READER>;
	my $htmltext = $line;
	my ($dumy, $baseurl, $size) = split(' ', $line);

	# URL 中の「//」に対処
	$baseurl =~ s!//!/!g;
	$baseurl =~ s!:/!://!g;
	my $baseurl_wo_protocol = $baseurl;
	$baseurl_wo_protocol =~ s!^https?://!!;

	while (<READER>) {
	    $htmltext .= $_;
	}
	close(READER);

	my $in_anchor = 0;
	my $outlink = '';
	my $anchor_text = '';
	my $anchor_offset;
	my $parser = ModifiedTokeParser->new(\$htmltext) or die $!;
	while (my $token = $parser->get_token()) {
	    my $offset = $token->[3];
	    my $length = $token->[4];
	    if ($token->[0] eq 'S'){
		if ($token->[1] eq 'a') {
		    my $href = $token->[2]{href};
		    if (defined $href && $href !~ /^mail|javascript|\#/ && $href !~ /\.(jpg|jpeg|gif|png)$/) {
			$in_anchor = 1;
			if ($href =~ /^http.?:\/\//) {
			    $outlink = $href;
			} else {
			    $outlink = &soutai2zettai($baseurl, $href);
			    $outlink =~ s!/\./!/!g;
			    $outlink = "http://" . $outlink unless ($outlink =~ /^http/);
			}

			$anchor_offset = $offset;
			$outlink =~ s/\n|\r//g;
			$outlink =~ s/ //g;
		    }
		}
	    }
	    elsif ($token->[0] eq 'T'){
		if ($in_anchor > 0) {
		    $anchor_text .= $token->[1];
		}
	    }
	    elsif ($token->[0] eq 'E') {
		if ($token->[1] eq 'a') {
		    # アンカーテキストの整形
 		    $anchor_text =~ s/&nbsp;/ /g; # &nbsp; はスペースに変換 (\xa0に変換させない)
#  		    $anchor_text =~ s/&lt;/</g;
#  		    $anchor_text =~ s/&gt;/>/g;
#  		    $anchor_text =~ s/&amp;/&/g;
#  		    $anchor_text =~ s/&apos;/'/g;
#  		    $anchor_text =~ s/&quot;/"/g;
#  		    $anchor_text =~ s/&lsquo;/`/g;
#  		    $anchor_text =~ s/&rsquo;/'/g;
#  		    $anchor_text =~ s/&ldquo;/``/g;
#  		    $anchor_text =~ s/&rsaquo;/</g;
#  		    $anchor_text =~ s/&lsaquo;/>/g;
#  		    $anchor_text =~ s/&raquo;/<</g;
#  		    $anchor_text =~ s/&laquo;/>>/g;
#  		    $anchor_text =~ s/&.{2,5};//g;

#		    $anchor_text = decode_entities($anchor_text);
# 		    $anchor_text = NFKC($anchor_text);
		    $anchor_text =~ s/(\n|\r)/ /g;
		    $anchor_text =~ s/\t/ /g;

		    # 空でなければ
		    if ($anchor_text ne '') {
			# URL中に2byte文字があるため
			# 006181925.html.gz のはんたばる
			# http://ww21.tiki.ne.jp/%7Ezyusei/distiller/okinawa/taikoku.htm
			# $outlink = encode('utf8', $outlink) if (utf8::is_utf8($outlink));

			$anchor_text = Unicode::Japanese->new($anchor_text)->h2z->getu();
			$anchor_text =~ s/ /　/g;
			$anchor_text =~ s/(　){2,}/　/g;
			$anchor_text =~ s/^　//;
			$anchor_text =~ s/　$//;
			# my $len = $offset + $length - $anchor_offset;

			my $can_outlink = &CanonicalizeURL($outlink);
			my $outlink_did = $url2did->get($can_outlink);
			print "$did $baseurl $outlink_did $can_outlink $anchor_text\n" if (defined $outlink_did && $anchor_text ne '');
		    }
		    $in_anchor = 0;
		    $anchor_text = '';
		    $anchor_offset = 0;
		}
	    }
	}
    }
}


# 相対パスから絶対パスへ変換
sub soutai2zettai {
    my ($url, $href) = @_;

    my ($domain, $dir, $file) = &decompose_url($url);

    if ($href =~ /^\//) {
	# href="/hoge.html"
	return $domain . $href;
    } elsif ($href =~ /^\.\.\//) {
	# href="../../hoge.html"

	my ($cds) = ($href =~ /((?:\.\.\/)+)/);
	# ../ の後に続くファイルパス
	my $following = "$'";
	# ../ の計数
	my $dir_num = scalar(split('/', $cds));

	my @dlist = split('/', $dir);
	my $dpath;
	for (my $i = 0; $i < scalar(@dlist) - $dir_num; $i++) {
	    $dpath .= ($dlist[$i] . "/");
	}
	return $domain . "/" . $dpath . $following;
    } else {
	# href="./hoge.html"
	$href = "$'" if ($href =~ /^\.\//);
	if ($dir ne  '') {
	    return $domain . "/" . $dir . "/" . $href;
	} else {
	    return $domain . "/" . $href;
	}	    
    }
}

# URLをドメイン名、ディレクトリ名、ファイル名に分割する関数
sub decompose_url {
    my ($url) = @_;

    my ($domain) = ($url =~ m!^https?://([^/]+)!);
    my ($filepath) = ($url =~ m!^https?://$domain/(.+)$!);
    my ($dir, $file);
    if (index($filepath, '/') > 0) {
        ($dir, $file) = ($filepath =~ m!^(.+?)/?([^/]+)$!);
    } else {
        $dir = '';
        $file = $filepath;
    }

    return ($domain, $dir, $file);
}

# ~t-morii/development/crawling/lib/urlcan.pm より
sub CanonicalizeURL($)
{
	my ($uri) = @_;

	my $uri_obj = URI->new($uri);

	return undef if ( $uri_obj->scheme !~ /http(s)?/ );
	return undef unless ( $uri_obj->host );

	my $path = CanonicalizePath($uri_obj->path);

	my $uri_after = $uri_obj->scheme.'://'.$uri_obj->host.CanonicalizePath($uri_obj->path);
	$uri_after .= "?".$uri_obj->query if ( defined($uri_obj->query) );

	return URI->new($uri_after)->canonical;
}

# パス名の正規化
# http://www.ipa.go.jp/security/awareness/vendor/programming/b07_07_main.html
sub CanonicalizePath($)
{
	my $path = shift;

	$path = "/$path" if ( $path !~ m|^/| );				# 先頭に / が無い場合は、/ を付加する

	# 正規化パス名の作成
	my @components = ();						# 正規化パス名中間データを初期化
	foreach my $component ( split('/', $path) )
	{
		next if ( $component eq "" );				# // は無視
		next if ( $component eq "." );				# /./ は無視
		if ( $component eq ".." )				# /../ なら
		{
			pop(@components);				# 1 つ前の構成要素も無視
			next;
		}
		push(@components, $component);				# 構成要素を追加
	}

	my $result = '/'.join('/', @components);			# パス名文字列を生成
	$result .= '/' if ( $path =~ /\/$/ && $result !~ /\/$/ );	# / が抜けた場合は付加する

	return $result;
}
