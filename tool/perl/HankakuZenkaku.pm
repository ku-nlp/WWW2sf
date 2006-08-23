package HankakuZenkaku;

# Ⱦ��<=>�����Ѵ��⥸�塼��
# from Encode::JP::Util

# $Id$

use strict;
use base qw(Exporter);
use Encode::CJKConstants qw(:all);
use Encode::JP::H2Z;

our @EXPORT_OK = qw(ascii_h2z ascii_z2h);

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
