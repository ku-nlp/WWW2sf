#!/usr/bin/env perl

use FileHandle;
use Encode;
use strict;

our $FILEBASE = ''; # w201102-
our $MAXLEN = 200;
our (@fh);

while (<STDIN>) {
    eval {
	$_ = decode('utf8', $_, Encode::FB_QUIET);
    };
    if ($@) {
	warn "$@\n";
	next;
    }
    my ($str) = (/^([^ ]+)/);
    &store_str(length($str), $_);
}

for my $i (0 .. @fh - 1) {
    $fh[$i]->close if $fh[$i];
}


sub store_str {
    my ($len, $line) = @_;

    $len = $MAXLEN if $len > $MAXLEN;

    unless ($fh[$len]) {
	$fh[$len] = new FileHandle("$FILEBASE$len", '>:utf8');
    }

    $fh[$len]->print($line);
}
