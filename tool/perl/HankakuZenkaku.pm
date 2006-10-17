package HankakuZenkaku;

# Ⱦ��<=>�����Ѵ��⥸�塼��
# from Encode::JP::Util

# $Id$

use strict;
use base qw(Exporter);
use Encode qw(encode decode);
use Encode::CJKConstants qw(:all);
use Encode::JP::H2Z;

our @EXPORT_OK = qw(ascii_h2z ascii_z2h h2z4japanese_utf8);

our %ASCII_Z2H = (
"\xa1\xa1" => "\x20", #��
"\xa1\xaa" => "\!", #��
"\xa1\xc9" => "\"", #��
"\xa1\xf4" => "\#", #��
"\xa1\xf0" => "\$", #��
"\xa1\xf3" => "\%", #��
"\xa1\xf5" => "\&", #��
"\xa1\xc7" => "\'", #��
"\xa1\xca" => "\(", #��
"\xa1\xcb" => "\)", #��
"\xa1\xf6" => "\*", #��
"\xa1\xdc" => "\+", #��
"\xa1\xa4" => "\,", #��
"\xa1\xdd" => "\-", #��
"\xa1\xbd" => "\-", #��
"\xa1\xa5" => "\.", #��
"\xa1\xbf" => "\/", #��
"\xa3\xb0" => "0", #��
"\xa3\xb1" => "1", #��
"\xa3\xb2" => "2", #��
"\xa3\xb3" => "3", #��
"\xa3\xb4" => "4", #��
"\xa3\xb5" => "5", #��
"\xa3\xb6" => "6", #��
"\xa3\xb7" => "7", #��
"\xa3\xb8" => "8", #��
"\xa3\xb9" => "9", #��
"\xa1\xa7" => "\:", #��
"\xa1\xa8" => "\;", #��
"\xa1\xe3" => "\<", #��
"\xa1\xe1" => "\=", #��
"\xa1\xe4" => "\>", #��
"\xa1\xa9" => "\?", #��
"\xa1\xf7" => "\@", #��
"\xa3\xc1" => "A", #��
"\xa3\xc2" => "B", #��
"\xa3\xc3" => "C", #��
"\xa3\xc4" => "D", #��
"\xa3\xc5" => "E", #��
"\xa3\xc6" => "F", #��
"\xa3\xc7" => "G", #��
"\xa3\xc8" => "H", #��
"\xa3\xc9" => "I", #��
"\xa3\xca" => "J", #��
"\xa3\xcb" => "K", #��
"\xa3\xcc" => "L", #��
"\xa3\xcd" => "M", #��
"\xa3\xce" => "N", #��
"\xa3\xcf" => "O", #��
"\xa3\xd0" => "P", #��
"\xa3\xd1" => "Q", #��
"\xa3\xd2" => "R", #��
"\xa3\xd3" => "S", #��
"\xa3\xd4" => "T", #��
"\xa3\xd5" => "U", #��
"\xa3\xd6" => "V", #��
"\xa3\xd7" => "W", #��
"\xa3\xd8" => "X", #��
"\xa3\xd9" => "Y", #��
"\xa3\xda" => "Z", #��
"\xa1\xce" => "\[", #��
"\xa1\xef" => "\\", #��
"\xa1\xc0" => "\\", #��
"\xa1\xcf" => "\]", #��
"\xa1\xb0" => "\^", #��
"\xa1\xb2" => "_", #��
"\xa1\xae" => "\`", #��
"\xa1\xc6" => "\`", #��
"\xa3\xe1" => "a", #��
"\xa3\xe2" => "b", #��
"\xa3\xe3" => "c", #��
"\xa3\xe4" => "d", #��
"\xa3\xe5" => "e", #��
"\xa3\xe6" => "f", #��
"\xa3\xe7" => "g", #��
"\xa3\xe8" => "h", #��
"\xa3\xe9" => "i", #��
"\xa3\xea" => "j", #��
"\xa3\xeb" => "k", #��
"\xa3\xec" => "l", #��
"\xa3\xed" => "m", #��
"\xa3\xee" => "n", #��
"\xa3\xef" => "o", #��
"\xa3\xf0" => "p", #��
"\xa3\xf1" => "q", #��
"\xa3\xf2" => "r", #��
"\xa3\xf3" => "s", #��
"\xa3\xf4" => "t", #��
"\xa3\xf5" => "u", #��
"\xa3\xf6" => "v", #��
"\xa3\xf7" => "w", #��
"\xa3\xf8" => "x", #��
"\xa3\xf9" => "y", #��
"\xa3\xfa" => "z", #��
"\xa1\xd0" => "\{", #��
"\xa1\xc3" => "\|", #��
"\xa1\xd1" => "\}", #��
"\xa1\xc1" => "\~", #��
"\xa1\xb1" => "\~", #��
);
our %ASCII_H2Z = reverse(%ASCII_Z2H);



# Ⱦ�ѥ������� -> ���ѥ�������
sub _h2z4japanese_utf8(){
    my($ch_code,$next_ch_code) = @_;
    my $shift = 0;
    if(0xff71 <= $ch_code && $ch_code <= 0xff75){
	# ������
	$shift = (0xff71 - 0x30a2) - ($ch_code - 0xff71);
    }elsif(0xff76 <= $ch_code && $ch_code <= 0xff81){
	# ������
	$shift = 0xff76 - 0x30ab - ($ch_code - 0xff76);
    }elsif(0xff82 <= $ch_code && $ch_code <= 0xff84){
	# �ġ���
	$shift = 0xff82 - 0x30c4 - ($ch_code - 0xff82);
    }elsif(0xff85 <= $ch_code && $ch_code <= 0xff89){
	# �ʡ���
	$shift = 0xcebb;
    }elsif(0xff8a <= $ch_code && $ch_code <= 0xff8e){
	# �ϡ���
	$shift = 0xcebb - 2*($ch_code - 0xff8a);
    }elsif(0xff8f <= $ch_code && $ch_code <= 0xff93){
	# �ޡ���
	$shift = 0xceb1;
    }elsif(0xff94 <= $ch_code && $ch_code <= 0xff96){
	# �����
	$shift = 0xceb0 - ($ch_code - 0xff94);
    }elsif(0xff97 <= $ch_code && $ch_code <= 0xff9b){
	# �����
	$shift = 0xceae;
    }elsif(0xff67 <= $ch_code && $ch_code <= 0xff6b){
	# ������
	$shift = (0xff67 - 0x30a1) - ($ch_code - 0xff67);
    }elsif(0xff6c <= $ch_code && $ch_code <= 0xff6e){
	# �����
	$shift = (0xff6c - 0x30e3 ) - ($ch_code - 0xff6c);
    }else{
      SWITCH: {
	  $shift = 0xff9c - 0x30ef, last SWITCH if($ch_code == 0xff9c); # ��
	  $shift = 0xff66 - 0x30f2, last SWITCH if($ch_code == 0xff66); # ��
	  $shift = 0xff9d - 0x30f3, last SWITCH if($ch_code == 0xff9d); # ��
	  $shift = 0xff6f - 0x30c3, last SWITCH if($ch_code == 0xff6f); # ��

	  $shift = 0xff61 - 0x3002, last SWITCH if($ch_code == 0xff61); # ��
	  $shift = 0xff62 - 0x300c, last SWITCH if($ch_code == 0xff62); # ��
	  $shift = 0xff63 - 0x300d, last SWITCH if($ch_code == 0xff63); # ��
	  $shift = 0xff64 - 0x3001, last SWITCH if($ch_code == 0xff64); # ��
	  $shift = 0xff65 - 0x30fb, last SWITCH if($ch_code == 0xff65); # ��
	  $shift = 0xff70 - 0x30fc, last SWITCH if($ch_code == 0xff70); # -
      } # end of switch
    } # end of else

    ## �����ν���
    if($next_ch_code == 0xff9e){
	# ��
	if($ch_code == 0xff73){
	    # ��
	    $shift = 0xff73 - 0x30f4;
	}else{
	    $shift -= 1;
	}
    }

    ## Ⱦ�����ν���
    if($next_ch_code == 0xff9f){
	# ��
	$shift -= 2;
    }

    return ($ch_code - $shift);
}

sub h2z4japanese_utf8{
    my($text) = @_;
    my @cbuff = ();
    my @ch_codes = unpack("U0U*", $$text);
    for(my $i = 0; $i < scalar(@ch_codes); $i++){
	my $ch_code = $ch_codes[$i];
	unless(0xff60 < $ch_code && $ch_code < 0xffa0){
	    push(@cbuff, $ch_code);
	}else{
	    my $next_ch_code = ($i + 1 < scalar(@ch_codes))?$ch_codes[$i+1]:0;
	    my $zenkaku_code = &_h2z4japanese_utf8($ch_code, $next_ch_code);
	    push(@cbuff, $zenkaku_code);
	    if($next_ch_code == 0xff9e || $next_ch_code == 0xff9f){
		$i++;
	    }
	}
    }
    my $stemp = encode('utf8', pack("U0U*",@cbuff));
    return \$stemp;
}

sub _ascii_z2h {
    my $r = $ASCII_Z2H{$_[0]};

    return defined($r) ? $r : $_[0];
}

sub _ascii_h2z {
    my $r = $ASCII_H2Z{$_[0]};

    return defined($r) ? $r : $_[0];
}

sub ascii_h2z {
    my ($arg) = @_;

    my $r_str = ref $arg ? $arg : \$arg;
    my $n = $$r_str =~ s/($RE{ASCII})/&_ascii_h2z($1)/eog;
    return ref $arg ? $n : $arg;
}

sub ascii_z2h {
    my ($arg) = @_;

    my $r_str = ref $arg ? $arg : \$arg;
    my $n = $$r_str =~ s/($RE{EUC_C}|$RE{EUC_0212}|$RE{EUC_KANA})/&_ascii_z2h($1)/eog;
    return ref $arg ? $n : $arg;
}

1;
