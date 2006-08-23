package HankakuZenkaku;

# È¾³Ñ<=>Á´³ÑÊÑ´¹¥â¥¸¥å¡¼¥ë
# from Encode::JP::Util

# $Id$

use strict;
use base qw(Exporter);
use Encode::CJKConstants qw(:all);
use Encode::JP::H2Z;

our @EXPORT_OK = qw(ascii_h2z ascii_z2h);

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
