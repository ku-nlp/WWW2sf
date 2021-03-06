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

    # 強制的にutf8と判断させる場合 (crawlデータなど)
    if ($option->{force_change_to_utf8_with_flag}) {
	$language = $this->{opt}{language};
	$encoding = 'utf8';
    }
    # エンコーディングを指定する場合
    elsif ($option->{given_encoding}) {
	$language = $this->{opt}{language};
	$encoding = $option->{given_encoding};
    }
    # meta情報のチェック
    elsif ($$buf_ref =~ /<meta [^>]*content=[" ]*text\/html[; ]*charset=([^" >]+)/i) { 
        my $charset = lc($1);
	# 英語/西欧言語
	if ($charset =~ /^iso-8859-1|iso-8859-15|windows-1252|macintosh|x-mac-roman|iso8859-1$/i) {
	    $language = 'english';
	}
	# 日本語EUC
	elsif ($charset =~ /^euc-jp|x-euc-jp|x-euc-japan|euc_jp$/i) {
	    $language = 'japanese';
	    $encoding = 'euc-jp';
	}
	# 日本語JIS
	elsif ($charset =~ /^iso-2022-jp|iso2022-jp$/i) {
	    $language = 'japanese';
	    $encoding = '7bit-jis';
	}
	# 日本語SJIS
	elsif ($charset =~ /^sjis|shift_jis|windows-932|windows-31j|x-sjis|shift-jp|shift-jis|x_sjis|shift_sjis|shiftjis|sift_jis|x\(sjis$/i) {
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
	unless (ref($enc)) {
	    # 推定できなかった場合
	    return if ($enc =~ /No appropriate encodings found!/);

	    $language = 'japanese';
	    if ($enc =~ /euc/) {
		$encoding = 'euc-jp';
	    } elsif ($enc =~ /shiftjis/) {
		$encoding = 'shiftjis';
	    } else {
		$encoding = 'utf8';
	    }
	} else {
	    if ($enc->name eq 'ascii') {
		$language = 'english';
	    }
	    else {
		$language = 'japanese';
		$encoding = $enc->name;
	    }
	}
    }

    # 日本語指定
    if ($this->{opt}{language} eq 'japanese') {
	if ($language ne 'japanese') {
	    return undef;
	}
	else {
	    # $encodingが何であってもutf8コードのbufをdecodeする
	    # 例: $encodingがshift-jisであっても、to_utf8.perlでutf8に変換されている場合
	    if ($option->{force_change_to_utf8_with_flag}) {
		$$buf_ref = decode('utf8', $$buf_ref);
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
    }
    # 英語指定
    elsif ($this->{opt}{language} eq 'english') {
	if ($language ne 'english') {
	    return undef;
	}
	elsif ($option->{force_change_to_utf8_with_flag}) {
	    $$buf_ref = decode('utf8', $$buf_ref);
	}
    }
    else {
	return undef;
    }

    return $language eq 'english' ? 'ascii' : $encoding;
}

1;

