#!/usr/bin/env perl

# # S-ID:ntcir000-3-4 URL:http://0.tecmo.jp/contents.html
# ケータイの一歩先を行くＦＯＭＡ９００ｉシリーズだから味わえるオリジナルコンテンツです。
#
# ↓
# ケータイの一歩先を行くＦＯＭＡ９００ｉシリーズだから味わえるオリジナルコンテンツです。 # S-ID:ntcir000-3-4 URL:http://0.tecmo.jp/contents.html
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
