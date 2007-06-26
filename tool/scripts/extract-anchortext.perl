#!/usr/bin/env perl

# html文書からアンカーテキストとそのリンク先のペアを抽出するプログラム

use Getopt::Long;
use strict;
use utf8;
use HtmlGuessEncoding;
use Encode;
use Encode::Guess;


my $encoding = new HtmlGuessEncoding({language => 'japanese'});

&main();

sub main {
    foreach my $f (@ARGV) {
	open(READER, "zcat $f |");
	while (<READER>) {
	    if ($_ =~ /^<<<0*(\d+) (\d+)>>>$/) {
		my $dat_size = $1;
		my $url_size = $2;
		
		my $url;
		my $output;
		
		read(READER, $url, $url_size);
		chop($url);
		
		read(READER, $output, $dat_size - $url_size);
		
		my $encode = $encoding->ProcessEncoding(\$output, {change_to_utf8 => 1});
		if ($encode) {
		    
		    $output =~ s/<script[^>]*?>(.|[\n\r])*?<\/script>//img;
		    $output =~ s/<style[^>]*?>(.|[\n\r])*?<\/style>//img;
		    $output =~ s/<!(?:\-\-[^\-]*(?:(?!\-\-)-[^\-]*)*\-\-(?:(?!\-\-)[^>])*)*(?:>|(?!\n)$|\-\-.*$)//mg;
		    
		    my $anchors = &extract_anchors($output);
		    foreach my $anchor (@{$anchors}) {
			my $text = $anchor->{text};
			my $href_org = $anchor->{href};
			my $href = &soutai2zettai($url, $anchor->{href});
			
#			print "url=[$url] href=[$href] org=[$href_org]\n";
			print "$url $href $text\n"; # to from text
		    }
		}
	    }
	}
    }
}

sub main2 {
    foreach my $f (@ARGV) {
	open(READER, $f);
	my $output;
	my $meta = <READER>;
	my($type, $url, $size) = split(' ', $meta);
	while (<READER>) {
	    $output .= $_;
	}
	close(READER);

	my $encode = $encoding->ProcessEncoding(\$output, {change_to_utf8 => 1});
	if ($encode) {
	    $output =~ s/<script[^>]*?>(.|[\n\r])*?<\/script>//img;
	    $output =~ s/<style[^>]*?>(.|[\n\r])*?<\/style>//img;
	    $output =~ s/<!(?:\-\-[^\-]*(?:(?!\-\-)-[^\-]*)*\-\-(?:(?!\-\-)[^>])*)*(?:>|(?!\n)$|\-\-.*$)//mg;

	    my $anchors = &extract_anchors($output);
	    foreach my $anchor (@{$anchors}) {
		my $text = $anchor->{text};
		my $href_org = $anchor->{href};
		my $href = &soutai2zettai($url, $anchor->{href});
		
#		print "url=[$url] href=[$href] org=[$href_org]\n";
		print "$url $href $text\n"; # to from text
	    }
	}
    }
}

# 相対パスから絶対パスへ変換
sub soutai2zettai {
    my ($url, $href) = @_;

    return "$'" if ($href =~ m!^https?://!);

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

# アンカーテキストとそのリンク先を抽出
sub extract_anchors {
    my ($htmltext) = @_;

    my @anchors = ();
    while ($htmltext =~ /<\/A>/i) {
	my $fwd = "$`";
	my $bck = "$'";
	my $end_tag = "$&";
	if ($fwd =~ /^((?:.|\n|\r)+)(<A[^>]+>)/i) {
	    my $fwd = $1;
	    my $start_tag = $2;
	    my $anchor_text = "$'";

	    $anchor_text =~ s/<[^>]+>//g;
	    $anchor_text =~ s/(\n|\r)//g;
	    $anchor_text =~ s/^\s+//g;
	    $anchor_text =~ s/\s+$//g;

	    my $href = &extract_href($start_tag);

	    # メールは削除
	    $href = undef if ($href =~ /^mailto:/i);
	    if (defined($href) && $anchor_text ne '') {
		push(@anchors, {text => $anchor_text, href => $href});
	    }
	    $htmltext = $fwd . $bck;
	} else {
	    last;
	}
    }

    return \@anchors;
}

# <A>タグのhrefの値を抽出
sub extract_href {
    my ($anchor_tag) = @_;

    return undef unless ($anchor_tag =~ /href/i);

    $anchor_tag =~ s/ *?= *?/=/g;
    $anchor_tag =~ s/(\n|\r)//g;
    $anchor_tag =~ s/^<//;
    $anchor_tag =~ s/>$//;

    my $href;
    foreach my $attr_val (split(/ /, $anchor_tag)) {
	if ($attr_val =~ /href=/i) {
	    $href = "$'";
	    $href =~ s/^"//;
	    $href =~ s/"$//;
	    $href =~ s/^'//;
	    $href =~ s/'$//;
	    last;
	}
    }

    return $href;
}
    
