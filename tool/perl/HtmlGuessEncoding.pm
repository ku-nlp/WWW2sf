package HtmlGuessEncoding;

# HTML��Encoding��Guess

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
    my ($this, $buf_ref, $option) = @_;
    my ($language, $encoding);

    # ���ꤷ������ȥڡ����θ��줬���פ��뤫Ƚ��

    # meta����Υ����å�
    if ($$buf_ref =~ /<meta [^>]*content=[" ]*text\/html[; ]*charset=([^" >]+)/) { 
        my $charset = lc($1);
	# �Ѹ�/��������
	if ($charset =~ /^iso-8859-1|iso-8859-15|windows-1252|macintosh|x-mac-roman$/) {
	    $language = 'english';
	}
	# ���ܸ�EUC
	elsif ($charset =~ /^euc-jp|x-euc-jp$/) {
	    $language = 'japanese';
	    $encoding = 'euc-jp';
	}
	# ���ܸ�JIS
	elsif ($charset =~ /^iso-2022-jp$/) {
	    $language = 'japanese';
	    $encoding = '7bit-jis';
	}
	# ���ܸ�SJIS
	elsif ($charset =~ /^shift_jis|windows-932|x-sjis|shift-jp|shift-jis$/) {
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
    # meta���ʤ����Ͽ���
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

    # ���ܸ����
    if ($this->{opt}{language} eq 'japanese') {
	if ($language ne 'japanese') {
	    return undef;
	}
	else {
	    if ($encoding ne 'utf8') {
		# utf-8�ǰ���
		$$buf_ref = &convert_code($$buf_ref, $encoding, 'utf8') if $option->{change_to_utf8};
	    }
	}
    }
    # �Ѹ����
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

