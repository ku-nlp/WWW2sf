#!/usr/bin/env perl

use strict;
use utf8;
use TextExtractor;
use Unicode::Normalize;
use HTML::Entities;
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

binmode(STDIN, ':encoding(utf8)');
# binmode(STDOUT, ':encoding(euc-jp)');

my $text;
while (<STDIN>) {
    $text .= $_;
}

$text =~ s/\&.aquo;//g;
$text = decode_entities($text);

my $ext = new TextExtractor({language => 'japanese'});
$ext->extract_text(\$text);

print Dumper($ext->{TEXT}) . "\n";
