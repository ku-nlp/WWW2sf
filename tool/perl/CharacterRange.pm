package CharacterRange;

# $Id$

use strict;
use base qw(Exporter);
use utf8;

our @EXPORT = qw(alphabet_or_number number);

sub alphabet_or_number {
    return <<END;
FF10\tFF19
FF21\tFF3A
FF41\tFF5A
END
}

sub number {
    return <<END;
FF10\tFF19
END
}

1;
