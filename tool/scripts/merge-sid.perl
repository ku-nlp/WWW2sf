#!/usr/bin/env perl

# # S-ID:ntcir000-3-4 URL:http://0.tecmo.jp/contents.html
# ���������ΰ������Ԥ��ƣϣͣ��������饷�꡼��������̣�廊�륪�ꥸ�ʥ륳��ƥ�ĤǤ���
#
# ��
# ���������ΰ������Ԥ��ƣϣͣ��������饷�꡼��������̣�廊�륪�ꥸ�ʥ륳��ƥ�ĤǤ��� # S-ID:ntcir000-3-4 URL:http://0.tecmo.jp/contents.html
#

use strict;

my ($comment);
while (<>) {
    if (/^\#/) {
	$comment = $_;
    }
    else {
	chomp;
	print;
	print " $comment";
    }
}
