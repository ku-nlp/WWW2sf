#!/usr/bin/env perl

use TsuruokaTagger;
use strict;
use Getopt::Long;

our (%opt);
&GetOptions(\%opt, 'tagger_dir=s', 'tagger_command=s');

my $tagger = new TsuruokaTagger(\%opt);
while (<STDIN>) {
    my $result = $tagger->analyze($_);
    print $result;
}
