package HankakuZenkaku;

# È¾³Ñ<=>Á´³ÑÊÑ´¹¥â¥¸¥å¡¼¥ë
# from Encode::JP::Util

# $Id$

use strict;
use base qw(Exporter);
use Encode qw(encode decode);
use Encode::CJKConstants qw(:all);
use Encode::JP::H2Z;

our @EXPORT_OK = qw(ascii_h2z ascii_z2h h2z4japanese_utf8);

our %ASCII_Z2H = (
"\xa1\xa1" => "\x20", #¡¡
"\xa1\xaa" => "\!", #¡ª
"\xa1\xc9" => "\"", #¡É
"\xa1\xf4" => "\#", #¡ô
"\xa1\xf0" => "\$", #¡ð
"\xa1\xf3" => "\%", #¡ó
"\xa1\xf5" => "\&", #¡õ
"\xa1\xc7" => "\'", #¡Ç
"\xa1\xca" => "\(", #¡Ê
"\xa1\xcb" => "\)", #¡Ë
"\xa1\xf6" => "\*", #¡ö
"\xa1\xdc" => "\+", #¡Ü
"\xa1\xa4" => "\,", #¡¤
"\xa1\xdd" => "\-", #¡Ý
"\xa1\xbd" => "\-", #¡½
"\xa1\xa5" => "\.", #¡¥
"\xa1\xbf" => "\/", #¡¿
"\xa3\xb0" => "0", #£°
"\xa3\xb1" => "1", #£±
"\xa3\xb2" => "2", #£²
"\xa3\xb3" => "3", #£³
"\xa3\xb4" => "4", #£´
"\xa3\xb5" => "5", #£µ
"\xa3\xb6" => "6", #£¶
"\xa3\xb7" => "7", #£·
"\xa3\xb8" => "8", #£¸
"\xa3\xb9" => "9", #£¹
"\xa1\xa7" => "\:", #¡§
"\xa1\xa8" => "\;", #¡¨
"\xa1\xe3" => "\<", #¡ã
"\xa1\xe1" => "\=", #¡á
"\xa1\xe4" => "\>", #¡ä
"\xa1\xa9" => "\?", #¡©
"\xa1\xf7" => "\@", #¡÷
"\xa3\xc1" => "A", #£Á
"\xa3\xc2" => "B", #£Â
"\xa3\xc3" => "C", #£Ã
"\xa3\xc4" => "D", #£Ä
"\xa3\xc5" => "E", #£Å
"\xa3\xc6" => "F", #£Æ
"\xa3\xc7" => "G", #£Ç
"\xa3\xc8" => "H", #£È
"\xa3\xc9" => "I", #£É
"\xa3\xca" => "J", #£Ê
"\xa3\xcb" => "K", #£Ë
"\xa3\xcc" => "L", #£Ì
"\xa3\xcd" => "M", #£Í
"\xa3\xce" => "N", #£Î
"\xa3\xcf" => "O", #£Ï
"\xa3\xd0" => "P", #£Ð
"\xa3\xd1" => "Q", #£Ñ
"\xa3\xd2" => "R", #£Ò
"\xa3\xd3" => "S", #£Ó
"\xa3\xd4" => "T", #£Ô
"\xa3\xd5" => "U", #£Õ
"\xa3\xd6" => "V", #£Ö
"\xa3\xd7" => "W", #£×
"\xa3\xd8" => "X", #£Ø
"\xa3\xd9" => "Y", #£Ù
"\xa3\xda" => "Z", #£Ú
"\xa1\xce" => "\[", #¡Î
"\xa1\xef" => "\\", #¡ï
"\xa1\xc0" => "\\", #¡À
"\xa1\xcf" => "\]", #¡Ï
"\xa1\xb0" => "\^", #¡°
"\xa1\xb2" => "_", #¡²
"\xa1\xae" => "\`", #¡®
"\xa1\xc6" => "\`", #¡Æ
"\xa3\xe1" => "a", #£á
"\xa3\xe2" => "b", #£â
"\xa3\xe3" => "c", #£ã
"\xa3\xe4" => "d", #£ä
"\xa3\xe5" => "e", #£å
"\xa3\xe6" => "f", #£æ
"\xa3\xe7" => "g", #£ç
"\xa3\xe8" => "h", #£è
"\xa3\xe9" => "i", #£é
"\xa3\xea" => "j", #£ê
"\xa3\xeb" => "k", #£ë
"\xa3\xec" => "l", #£ì
"\xa3\xed" => "m", #£í
"\xa3\xee" => "n", #£î
"\xa3\xef" => "o", #£ï
"\xa3\xf0" => "p", #£ð
"\xa3\xf1" => "q", #£ñ
"\xa3\xf2" => "r", #£ò
"\xa3\xf3" => "s", #£ó
"\xa3\xf4" => "t", #£ô
"\xa3\xf5" => "u", #£õ
"\xa3\xf6" => "v", #£ö
"\xa3\xf7" => "w", #£÷
"\xa3\xf8" => "x", #£ø
"\xa3\xf9" => "y", #£ù
"\xa3\xfa" => "z", #£ú
"\xa1\xd0" => "\{", #¡Ð
"\xa1\xc3" => "\|", #¡Ã
"\xa1\xd1" => "\}", #¡Ñ
"\xa1\xc1" => "\~", #¡Á
"\xa1\xb1" => "\~", #¡±
);
our %ASCII_H2Z = reverse(%ASCII_Z2H);



# È¾³Ñ¥«¥¿¥«¥Ê -> Á´³Ñ¥«¥¿¥«¥Ê
sub _h2z4japanese_utf8(){
    my($ch_code,$next_ch_code) = @_;
    my $shift = 0;
    if(0xff71 <= $ch_code && $ch_code <= 0xff75){
	# ¥¢¡Á¥ª
	$shift = (0xff71 - 0x30a2) - ($ch_code - 0xff71);
    }elsif(0xff76 <= $ch_code && $ch_code <= 0xff81){
	# ¥«¡Á¥Á
	$shift = 0xff76 - 0x30ab - ($ch_code - 0xff76);
    }elsif(0xff82 <= $ch_code && $ch_code <= 0xff84){
	# ¥Ä¡Á¥È
	$shift = 0xff82 - 0x30c4 - ($ch_code - 0xff82);
    }elsif(0xff85 <= $ch_code && $ch_code <= 0xff89){
	# ¥Ê¡Á¥Î
	$shift = 0xcebb;
    }elsif(0xff8a <= $ch_code && $ch_code <= 0xff8e){
	# ¥Ï¡Á¥Û
	$shift = 0xcebb - 2*($ch_code - 0xff8a);
    }elsif(0xff8f <= $ch_code && $ch_code <= 0xff93){
	# ¥Þ¡Á¥â
	$shift = 0xceb1;
    }elsif(0xff94 <= $ch_code && $ch_code <= 0xff96){
	# ¥ä¡Á¥è
	$shift = 0xceb0 - ($ch_code - 0xff94);
    }elsif(0xff97 <= $ch_code && $ch_code <= 0xff9b){
	# ¥é¡Á¥í
	$shift = 0xceae;
    }elsif(0xff67 <= $ch_code && $ch_code <= 0xff6b){
	# ¥¡¡Á¥©
	$shift = (0xff67 - 0x30a1) - ($ch_code - 0xff67);
    }elsif(0xff6c <= $ch_code && $ch_code <= 0xff6e){
	# ¥ã¡Á¥ç
	$shift = (0xff6c - 0x30e3 ) - ($ch_code - 0xff6c);
    }else{
      SWITCH: {
	  $shift = 0xff9c - 0x30ef, last SWITCH if($ch_code == 0xff9c); # ¥ï
	  $shift = 0xff66 - 0x30f2, last SWITCH if($ch_code == 0xff66); # ¥ò
	  $shift = 0xff9d - 0x30f3, last SWITCH if($ch_code == 0xff9d); # ¥ó
	  $shift = 0xff6f - 0x30c3, last SWITCH if($ch_code == 0xff6f); # ¥Ã

	  $shift = 0xff61 - 0x3002, last SWITCH if($ch_code == 0xff61); # Ž¡
	  $shift = 0xff62 - 0x300c, last SWITCH if($ch_code == 0xff62); # Ž¢
	  $shift = 0xff63 - 0x300d, last SWITCH if($ch_code == 0xff63); # Ž£
	  $shift = 0xff64 - 0x3001, last SWITCH if($ch_code == 0xff64); # Ž¤
	  $shift = 0xff65 - 0x30fb, last SWITCH if($ch_code == 0xff65); # Ž¥
	  $shift = 0xff70 - 0x30fc, last SWITCH if($ch_code == 0xff70); # -
      } # end of switch
    } # end of else

    ## Âù²»¤Î½èÍý
    if($next_ch_code == 0xff9e){
	# ¡«
	if($ch_code == 0xff73){
	    # ¥ô
	    $shift = 0xff73 - 0x30f4;
	}else{
	    $shift -= 1;
	}
    }

    ## È¾Âù²»¤Î½èÍý
    if($next_ch_code == 0xff9f){
	# ¡¬
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
