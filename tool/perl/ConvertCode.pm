package ConvertCode;

# 文字コード変換
# method: convert_code(バイト列, 入力コード名, 出力コード名, NFKC正規化の有無)

# $Id$

use strict;
use base qw(Exporter);
use Encode qw(from_to encode decode);
use Unicode::Normalize;

our @EXPORT_OK = qw(convert_code);

sub convert_code {
    my ($buf, $from_enc, $to_enc, $normalization_flag) = @_;

    if ($from_enc =~ /shiftjis/i and $to_enc =~ /utf8/i) {
	require ShiftJIS::CP932::MapUTF;
	ShiftJIS::CP932::MapUTF->import(qw(cp932_to_utf8));
	eval {$buf = cp932_to_utf8($buf)};
    }
    else {
	# eval {from_to($buf, $from_enc, $to_enc)};
	eval {$buf = decode($from_enc, $buf)};
	$buf = NFKC($buf) if $normalization_flag; # NFKC normalization
	eval {$buf = encode($to_enc, $buf)}; # for debug, add "sub { sprintf "<U+%04X>", shift }" to the argument
    }

    if ($@) {
	print STDERR $@;
	return undef;
    }

    return $buf;
}

1;
