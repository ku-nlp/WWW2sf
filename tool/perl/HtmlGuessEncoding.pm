package HtmlGuessEncoding;

# HTMLのEncodingをGuess

# $Id$

use ConvertCode qw(convert_code);
use Encode qw(decode);
use Encode::Guess;
use strict;
use utf8;

sub new {
    my ($this, $opt) = @_;

    $this = {
	opt => $opt
	};

    bless $this;
    return $this;
}

sub ProcessEncoding {
    my ($this, $buf_ref, $option) = @_;
    my ($language, $encoding);

    # 指定した言語とページの言語が一致するか判定

    # meta情報のチェック
    if ($$buf_ref =~ /<meta [^>]*content=[" ]*text\/html[; ]*charset=([^" >]+)/i) { 
        my $charset = lc($1);
	# 英語/西欧言語
	if ($charset =~ /^iso-8859-1|iso-8859-15|windows-1252|macintosh|x-mac-roman$/i) {
	    $language = 'english';
	}
	# 日本語EUC
	elsif ($charset =~ /^euc-jp|x-euc-jp$/i) {
	    $language = 'japanese';
	    $encoding = 'euc-jp';
	}
	# 日本語JIS
	elsif ($charset =~ /^iso-2022-jp$/i) {
	    $language = 'japanese';
	    $encoding = '7bit-jis';
	}
	# 日本語SJIS
	elsif ($charset =~ /^sjis|shift_jis|windows-932|x-sjis|shift-jp|shift-jis$/i) {
	    $language = 'japanese';
	    $encoding = 'shiftjis';
	}
	# UTF-8
	elsif ($charset =~ /^utf-8$/i) {
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
		if ($option->{change_to_utf8}) {
		    $$buf_ref = &convert_code($$buf_ref, $encoding, 'utf8');
		}
		elsif ($option->{change_to_utf8_with_flag}) {
		    $$buf_ref = &convert_code($$buf_ref, $encoding, 'utf8');
		    $$buf_ref = decode('utf8', $$buf_ref);
		}
	    } else {
		$$buf_ref = decode('utf8', $$buf_ref) if ($option->{change_to_utf8_with_flag});
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

1;

