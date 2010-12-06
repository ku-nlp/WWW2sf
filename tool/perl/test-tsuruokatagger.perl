#!/usr/bin/env perl

use TsuruokaTagger;
use strict;

my $tagger = new TsuruokaTagger;
while (<STDIN>) {
    my $result = $tagger->analyze($_);
    print $result;
}
