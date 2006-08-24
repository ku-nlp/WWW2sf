package HtmlGuessEncoding;

# HTMLのEncodingをGuess

# $Id$

use Encode qw(from_to);
use Encode::Guess;
use strict;

sub new {
    my ($this, $opt) = @_;

    $this = {
	opt => $opt
	};

    bless $this;
    return $this;
}

sub ProcessEncoding {
    my ($this, $buf_ref) = @_;
    my ($language, $encoding);

    # 指定した言語とページの言語が一致するか判定

    # meta情報のチェック
    if ($$buf_ref =~ /<meta [^>]*content=[" ]*text\/html[; ]*charset=([^" >]+)/) { 
        my $charset = lc($1);
	# 英語/西欧言語
	if ($charset =~ /^iso-8859-1|iso-8859-15|windows-1252|macintosh|x-mac-roman$/) {
	    $language = 'english';
	}
	# 日本語EUC
	elsif ($charset =~ /^euc-jp|x-euc-jp$/) {
	    $language = 'japanese';
	    $encoding = 'euc-jp';
	}
	# 日本語JIS
	elsif ($charset =~ /^iso-2022-jp$/) {
	    $language = 'japanese';
	    $encoding = '7bit-jis';
	}
	# 日本語SJIS
	elsif ($charset =~ /^shift_jis|windows-932|x-sjis|shift-jp$/) {
	    $language = 'japanese';
	    $encoding = 'shiftjis';
	}
	# UTF-8
	elsif ($charset =~ /^utf-8$/) {
	    $language = 'japanese'; # ?????
	    $encoding = 'utf8';
	}
	else {
	    return undef;
	}
    }
    # metaがない場合は推定
    else {
	my $enc = guess_encoding($$buf_ref, qw/ascii euc-jp shiftjis 7bit-jis utf8/); # range
	return unless ref($enc);
	if ($enc->name eq 'ascii') {
	    $language = 'english';
	}
	else {
	    $language = 'japanese';
	    $encoding = $enc->name;
	}
    }

    # 日本語指定
    if ($this->{opt}{language} eq 'japanese') {
	if ($language ne 'japanese') {
	    return undef;
	}
	else {
	    if ($encoding ne 'utf8') {
		# utf-8で扱う
		$$buf_ref = &convert_code($$buf_ref, $encoding, 'utf8');
	    }
	}
    }
    # 英語指定
    elsif ($this->{opt}{language} eq 'english') {
	if ($language ne 'english') {
	    return undef;
	}
    }
    else {
	return undef;
    }

    return $language eq 'english' ? 'ascii' : $encoding;	
}

sub convert_code {
    my ($buf, $from_enc, $to_enc) = @_;

    eval {from_to($buf, $from_enc, $to_enc)};
    if ($@) {
	print STDERR $@;
	return undef;
    }

    return $buf;
}

1;

