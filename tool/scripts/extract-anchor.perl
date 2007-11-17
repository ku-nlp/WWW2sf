#!/usr/bin/env perl

# #Id:$

# utf8エンコードされたウェブページからアウトリンクをオフセット、長さ付きで
# 出力するプログラム
#
# 入力
# perl extract-anchor.perl -dir ウェブページが収められたディレクトリ [-z]
#
#
# 出力フォーマット
# 
# 037615272 http://www.syasen.com/bk/2006/08/post_39.html www.syasen.com/bk/2006/08/post_233.html 15793 188 守矢クリニック
#
# did 元URL リンク先URL offset length アンカーテキスト
#

use strict;
use utf8;
use Encode;
use Getopt::Long;
use HTML::Entities;
use Unicode::Normalize;
use Unicode::Japanese;
use ModifiedTokeParser;

my (%opt);
GetOptions(\%opt, 'dir=s', 'z', 'verbose');

# binmode(STDOUT, ':encoding(euc-jp)');
# binmode(STDOUT, ':utf8');

&main();

sub main {
    opendir(DIR, $opt{dir});
    foreach my $file (readdir(DIR)) {
	next unless ($file =~ /(\d+)\.html/);

	my $did = $1;
	my $fp = "$opt{dir}/$file";

	if ($opt{z}) {
	    open(READER, "zcat $fp |");
	} else {
	    open(READER, $fp);
	}
#	binmode(READER, ':utf8');

	my $line = <READER>;
	my $htmltext = $line;
	my ($dumy, $baseurl, $size) = split(' ', $line);
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
			    $outlink = "$'";
			} else {
			    $outlink = &soutai2zettai($baseurl, $href);
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
		    $anchor_text =~ s/\n|\r/ /g;
		    $anchor_text =~ s/^[　| |\t]+//;
		    $anchor_text =~ s/[　| |\t]+$//;

		    # 空でなければ
		    if ($anchor_text ne '') {
			# URL中に2byte文字があるため
			# 006181925.html.gz のはんたばる
			# http://ww21.tiki.ne.jp/%7Ezyusei/distiller/okinawa/taikoku.htm
			$outlink = encode('utf8', $outlink) if (utf8::is_utf8($outlink));

#			$anchor_text = Unicode::Japanese->new($anchor_text)->h2z->get();
			my $len = $offset + $length - $anchor_offset;
			print "$did $baseurl $outlink $anchor_offset $len $anchor_text\n";
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
