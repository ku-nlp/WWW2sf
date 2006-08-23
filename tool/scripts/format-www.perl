#!/usr/local/bin/perl

# WWW�����������ʸ������, ���, S-ID��Ϳ

# $Id$

use Getopt::Long;
use strict;
use vars qw(%opt @enu);

@enu = ("��", "��", "��", "��", "��", "��", "��", "��", "��", "��");

GetOptions(\%opt, 'head');

my ($head, $site, $file, $fileflag, $count, $url, $comment);
my ($sid, $sentence) = @_;
my (@char_array, @check_array, $i, $j, $flag);
my ($enu_num, $paren_start, $paren_level, $paren_str);

if ($opt{head}) {
    my ($tmp_filename);
    if ($ARGV[0] =~ /([^\/]+)\/([^\/]+)$/) {
	($head, $tmp_filename) = ($1, $2);
	$head = (split(/\./, $head))[0]; # tsubame00.kototoi.org => tsubame00
	($site) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
    }
    else {
	($tmp_filename) = ($ARGV[0] =~ /([^\/]+)$/);
	($head) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
    }
}
else {
    my ($tmp_filename) = ($ARGV[0] =~ /([^\/]+)$/);
    ($head) = ($tmp_filename =~ /^(?:doc)?([^.]+)/);
}

while (<>) {
    chomp;

    if (/^\<PAGE(?:\s*URL=\"([^\"]+)\")?\>/) {
	$comment .= "URL:$1" if $1;
	$file++;
	$fileflag = 0;
	$count = 0;
	next;
    }
    elsif (/^\<\/PAGE\>/) {
	$file-- if $fileflag == 0;
	$comment = undef;
	next;
    }
    else {
	$fileflag = 1;
    }

    $count++;
    $sid = defined($site) ? "$head-$site-$file-$count" : "$head-$file-$count";
    $sentence = $_;
    @char_array = ();

    # ��ñ�̤�ʬ�� (EUC)
    while (/([^\x80-\xfe]|[\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/g) {
	push(@char_array, $1);
    }

     # "��"��"��"��"��"��"��"��"��"��"��"�ǻϤޤ�ʸ�����Τ���
    if ($sentence =~ /^(��)*(��|��|��|��|��|��|��|��|��|��|��|��|��|��|��|��|��|��|��|��)/) {
	print "# S-ID:$sid ���κ��:$sentence\n";
	next;
    }

    # "��"��������5��ʾ�ޤ���Ĺ��512�Х��Ȱʾ�(¿���ϰ���ʸ)�����Τ���
    if ($sentence =~ /^.+��.+��.+��.+��.+��.+/ ||
	length($sentence) >= 512) {
	print "# S-ID:$sid ���κ��:$sentence\n";
	next;
    }

    # "�ġġ�"������ʸ�����Τ���
    if ($sentence =~ /^(��)+$/) {
	print "# S-ID:$sid ���κ��:$sentence\n";
	next;
    }

    # "��"��ޤ�ʸ�����Τ��� (��˥塼�ʤ�)
    if (&CheckChar(\@char_array, '��|��')) {
	print "# S-ID:$sid ���κ��:$sentence\n";
	next;
    }

    # ���٤ƴ����ʤ����Τ���
    if (&CheckKanji(\@char_array)) {
	print "# S-ID:$sid ���κ��:$sentence\n";
	next;
    }


    for ($i = 0; $i < @char_array; $i++) {
	$check_array[$i] = 1;
    }

    # ʸƬ��"��"�Ϻ��
    $check_array[0] = 0 if ($char_array[0] eq "��");

    # ʸƬ��"������"�Ϻ��
    if ($sentence =~ "^������") {
	$check_array[1] = 0;
	$check_array[2] = 0;
    }

    # "�ʡġ�"�κ������������"�ʣ���"��"�ʣ���"�ξ��ϻĤ�
    $enu_num = 1;
    $paren_start = -1;
    $paren_level = 0;
    $paren_str = "";
    for ($i = 0; $i < @char_array; $i++) {
	if ($char_array[$i] eq "��") {
	    $paren_start = $i if ($paren_level == 0);
	    $paren_level++;
	} 
	elsif ($char_array[$i] eq "��") {
	    $paren_level--;
	    if ($paren_level == 0) {
		if ($paren_str eq $enu[$enu_num]) {
		    $enu_num++;
		}
		else {
		    for ($j = $paren_start; $j <= $i; $j++) {
			$check_array[$j] = 0;
		    }
		}
	    $paren_start = -1;
	    $paren_str = "";
	    }
	}
	else {
	    $paren_str .= $char_array[$i] if ($paren_level != 0);
	}
    }
    # print STDERR "enu_num(+1) = $enu_num\n" if ($enu_num > 1);

    # "��ġ�"�κ�����������֤�"��"�������RESET

    $paren_start = -1;
    $paren_level = 0;
    $paren_str = "";
    for ($i = 0; $i < @char_array; $i++) {
	if ($check_array[$i] == 0) {
	    ; # "�ʡġ�"����ϥ����å�
	} elsif ($char_array[$i] eq "��") {
	    if ($paren_level == 0) {
		$paren_start = $i; 
		$paren_level++;
	    } 
	    elsif ($paren_level == 1) {
		for ($j = $paren_start; $j <= $i; $j++) {
		    $check_array[$j] = 0;
		}
		$paren_start = -1;
		$paren_level = 0;
		$paren_str = "";
	    }
	}
	elsif ($char_array[$i] eq "��") {
	    if ($paren_level == 1) {

		# "���"�ȤʤäƤ��Ƥ⡤"��"�������RESET
		# �� "�����ǯ�����ס���Ĺ�ȡ��㤭ŷ�͡ᱩ��"
		# print STDERR "��ġ��ġ�RESET:$paren_str:$sentence\n";

		$paren_start = -1;
		$paren_level = 0;
		$paren_str = "";
	    }
	}
	else {
	    $paren_str .= $char_array[$i] if ($paren_level == 1);
	}
    }

    # "���(ʸ��)"�ǡ�ʸ����"��"���ʤ�����"��"��"�̿���"�Ǥ���н���
    if ($paren_level == 1) {
	if ($paren_str =~ /^�̿�/ || $paren_str !~ /��$/) {
	    for ($j = $paren_start; $j < $i; $j++) {
		$check_array[$j] = 0;
	    }
	    # print STDERR "���DELETE:$paren_str:$sentence\n";
	} else {
	    # print STDERR "���KEEP:$paren_str:$sentence\n";
	}
    }

    $flag = 0;
    for ($i = 0; $i < @char_array; $i++) {
	if ($check_array[$i] == 1) {
	    $flag = 1;
	    last;
	}			# ͭ����ʬ���ʤ�������κ��
    }
    if ($enu_num > 2) {		# �ʣ��ˡʣ��ˤȤ�������κ��
	# print STDERR "# S-ID:$sid ���κ��:$sentence\n";
	$flag = 0;
    }

    if ($flag == 0) {
	print "# S-ID:$sid ���κ��:$sentence\n";
    } else {
	print "# S-ID:$sid $comment";

	for ($i = 0; $i < @char_array; $i++) {
	    if ($check_array[$i] == 0) {
		print " ��ʬ���:$i:" 
		    if ($i == 0 || $check_array[$i-1] == 1);
		print $char_array[$i];
	    }
	}
	print "\n";

	for ($i = 0; $i < @char_array; $i++) {
	    print $char_array[$i] if ($check_array[$i] == 1);
	}
	print "\n";
    }
}

# ���٤ƴ����ʤ�1
sub CheckKanji {
    my ($list) = @_;

    for my $str (@$list) {
	if ($str =~ /^[\x00-\xaf]/) {
	    return 0;
	}
    }

    return 1;
}

# ���ꤵ�줿ʸ���ѥ�����˥ޥå�����ʤ�1
sub CheckChar {
    my ($list, $pat) = @_;

    for my $str (@$list) {
	if ($str =~ /^(?:$pat)$/) {
	    return 1;
	}
    }
    return 0;
}
