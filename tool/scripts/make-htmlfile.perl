#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
use Getopt::Long;
use PerlIO::gzip;
use Error qw(:try);

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');

my (%opt);
GetOptions(\%opt, 'outdir=s', 'kuhp', 'ipsj', 'z', 'timeout=s');

$opt{outdir} = './htmls' unless (defined $opt{outdir});
$opt{timeout} = 60 unless (defined $opt{timeout});

&main();

sub main {

    `mkdir -p $opt{outdir}` unless (-d $opt{outdir});
    if ($opt{kuhp}) {
	&make_htmlfile_kuhp(\@ARGV);
    }
    elsif ($opt{ipsj}) {
	&make_htmlfile_ipsj(\@ARGV);
    }
}


sub make_htmlfile_kuhp {
    my ($files) = @_;

    my %VERSION = ();
    foreach my $file (@$files) {
	open (F, '<:utf8', $file) or die $!;
	# skip attribute names
	my $dumy = <F>;
	while (<F>) {
	    chop;
	    my @data = split (/\t/, $_);
	    my $fid = $data[0];
	    $fid =~ s/ /_/g;
	    my $findings = $data[5];
	    my $imp = $data[6];
	    my ($order) = ($data[7] =~ /●依頼コメント：(.+?)●/);

	    # 特殊文字を削除
	    $findings =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;
	    $imp =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;
	    $order =~ tr/\x00-\x09\x0b-\x1f\x7f-\x9f//d;

	    # save
	    my $version = '';
	    if (exists $VERSION{$fid}) {
		$version = '-' . $VERSION{$fid};
	    } else {
		$VERSION{$fid} = 0;
	    }
	    $VERSION{$fid}++;

	    if ($opt{z}) {
		open (OUTF, '>:gzip', sprintf ("%s/%s%s.html.gz", $opt{outdir}, $fid, $version)) or die $!;
		binmode (OUTF, ':utf8');
	    } else {
		open (OUTF, '>:utf8', sprintf ("%s/%s%s.html", $opt{outdir}, $fid, $version)) or die $!;
	    }

	    print  OUTF "<HTML>\n";
	    print  OUTF "<BODY>\n";
	    printf OUTF (qq(<DIV myblocktype="findings">%s</DIV>\n), $findings);
	    printf OUTF (qq(<DIV myblocktype="imp">%s</DIV>\n), $imp);
	    printf OUTF (qq(<DIV myblocktype="order">%s</DIV>\n), $order);
	    print  OUTF "</BODY>\n";
	    print  OUTF "</HTML>\n";
	    close (OUTF);
	}
	close (F);
    }
}

sub make_htmlfile_ipsj {
    my ($dirs) = @_;

    require DividePaper;

    my $cite_keys = {
	KEY1 => ["参考文献", "引用文献", "文献＋pp", "文献＋pages", "文献＋Proc"],
	KEY2 => ["[Rr]eferences? 1", "[Rr]eferences? \\\[ 1", "[Rr]eference＋pp\\\.", "[Rr]eference＋Vol\\\.",
		 "REFERENCES? 1", "REFERENCES? \\\[ 1", "REFERENCE＋pp\\\.", "REFERENCE＋Vol\\\."],
	NEGL => "[ .,\'　]",
	MISC => "[ <\[〔【]"};

    my $ack_keys = {
	KEY1 => [],
	KEY2 => ["謝辞＋感謝", "謝辞＋謝意", "謝辞＋深謝", "謝辞＋本論文", "謝辞＋本研究", "謝辞＋援助", "謝辞＋協力",
		 "[Aa]cknowledgement＋[Tt]hank", "[Aa]cknowledgement＋acknowledge", "[Aa]cknowledgement＋grateful",
		 "ACKNOWLEDGEMENT＋[Tt]hank", "ACKNOWLEDGEMENT＋acknowledge", "ACKNOWLEDGEMENT＋grateful"],
	NEGL => "",
	MISC => "[ <\[〔【]"};

    my $TIMEOUT = $opt{timeout};
    foreach my $dir (@$dirs) {
	opendir (DIR, $dir) or die "$!";
	foreach my $file (readdir(DIR)) {
	    next if ($file eq '.' || $file eq '..');
	    next if ($file =~ /html$/);

	    my $filepath = $dir . "/" . $file;
	    my $outfile = $file;
	    $outfile =~ s/txt$/html/;

	    open (FILE, '<:utf8', $filepath) or die "$!";
	    my $buf;
	    while (<FILE>) {
		$buf .= $_;
	    }
	    close (FILE);

	    $buf =~ s/>/&gt;/g;
	    $buf =~ s/</&lt;/g;

	    try {
		local $SIG{ALRM} = sub {die sprintf (qq([WARNING] Time out occured! (time=%d [sec], file=%s)), $TIMEOUT, $filepath)};
		alarm $TIMEOUT;

		my $dp = new DividePaper;
		my ($main, $cite) = $dp->DividePaper($buf, $cite_keys);
		my ($main, $ack) = $dp->DividePaper($main, $ack_keys);

		my $_main = $main;
		# OCRの読み取り誤りに対処
		$main =~ s/([^\p{Hiragana}|\p{Katakana}|\p{Han}]{10,})([\p{Hiragana}|\p{Katakana}|\p{Han}])([^\p{Hiragana}|\p{Katakana}|\p{Han}]{10,})/\1\3/g;

		# ひらがな、カタカナ、漢字以外の文字が100字以上続いていれば、そこを英語のアブストラクトと思う
		my ($buf2, $eabst) = ($main =~ /^((?:.|\n)+?)([^\p{Hiragana}|\p{Katakana}|\p{Han}]{100,})/);
		my $content = "$'";
		$content = $_main if (length($buf2) > 1000);



		$content =~ s/(　)+//g;
		$content =~ s/([a-z|A-Z|0-9|\,|\.|\-]) +([a-z|A-Z|0-9|\,|\.|\-])/$1&nbsp;$3/g;
		$content =~ s/ +//g;
		alarm 0;


		if ($opt{z}) {
		    open (WRITER, '>:gzip', sprintf ("%s/%s%s.gz", $opt{outdir}, $outfile)) or die $!;
		    binmode (WRITER, ':utf8');
		} else {
		    open (WRITER, '>:utf8', sprintf ("%s/%s", $opt{outdir}, $outfile)) or die $!;
		}

		print WRITER "<HTML>\n";
		print WRITER "<BODY>\n";
		print WRITER qq(<DIV myblocktype="maintext">$content</DIV>\n);
		print WRITER qq(<DIV myblocktype="acknowledgement">$ack</DIV>\n) if ($ack);
		print WRITER qq(<DIV myblocktype="reference">$cite</DIV>\n) if ($cite);
		print WRITER "</BODY>\n";
		print WRITER "</HTML>\n";
		close WRITER;
 	    } catch Error with {
 		print STDERR "[TIMEOUT] " . $filepath . "\n";
 	    };
	}
    }
}
