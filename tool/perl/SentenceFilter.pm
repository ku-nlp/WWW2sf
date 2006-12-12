package SentenceFilter;

# Mark Japanese sentences that are judged as Japanese

# $Id$

use utf8;
use strict;

sub new {
    my ($this) = @_;

    $this = {};

    bless $this;
    return $this;
}

sub JapaneseCheck {
    my ($this, $buf) = @_;
    my ($acount, $count);

    unless (utf8::is_utf8($buf)) {
	require Encode;
	$buf = Encode::decode('utf8', $buf)
    }

    for my $str (split(//, $buf)) {
	# count Hiragana, Katakana or Kanji
	if ($str =~ /^\p{Hiragana}|\p{Katakana}|ー|\p{Han}|\p{Punctuation}$/) {
	    $count++;
	}
	$acount++;
    }
    return 0 unless $acount;
    return $count / $acount;
}

1;
