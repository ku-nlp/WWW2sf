package StandardFormatLib;

# Common settings for StandardFormat

use strict;

our %pf_order = (id => 0, head => 1, category => 2, feature => 3, type => 4); # print order of phrase attributes
our %wf_order = (id => 0, surf => 1, orig => 2, read => 3, pos1 => 4, repname => 5, conj => 6, feature => 99); # print order of word attributes
our %synnodesf_order = (head => 0, phraseid => 1);
our %synnodef_order = (wordid => 0, synid => 1, score => 2);

1;
