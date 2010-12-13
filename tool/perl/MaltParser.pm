package MaltParser;

# $Id$

# A wrapper of MaltParser
# http://maltparser.org/

use strict;
use warnings;
use File::Path;
use IPC::Open3;
use FileHandle;
use TsuruokaTagger;

our $MEMsize = '1024m';
our $ParserDir = "$ENV{HOME}/share/tool/malt-1.3.1";
our $JavaCommand = "$ENV{HOME}/share/tool/jdk1.6.0_17/bin/java";
our $ParserCommand = "$JavaCommand -Xmx$MEMsize -jar $ParserDir/malt.jar -w $ParserDir -c engmalt -m parse";

sub new {
    my ($this, $opt) = @_;

    # delete the directory generated when an error occurred
    if (-d "$ParserDir/engmalt") {
	rmtree "$ParserDir/engmalt";
    }

    $opt = {} unless defined($opt);
    $opt->{lemmatize} = 1 unless exists($opt->{lemmatize}); # default: turn on lemmatization

    my $pid = open3(\*WTR, \*RDR, \*ERR, $ParserCommand);
    $this = {opt => $opt, WTR => \*WTR, RDR => \*RDR, ERR => \*ERR, pid => $pid, tagger => undef};
    $this->{RDR}->autoflush(1);
    $this->{WTR}->autoflush(1);

    bless $this;
}

sub DESTROY {
    my ($this) = @_;

    $this->{WTR}->close;
    $this->{RDR}->close;
    $this->{ERR}->close;

    undef $this->{tagger} if defined($this->{tagger});
}

# parse a tagged sentence in conll format
sub analyze_from_conll {
    my ($this, $str) = @_;

    $this->{WTR}->print($str);

    my ($buf);
    while (1) {
	my $line = $this->{RDR}->getline; # read one line
	$buf .= $line;
	last if $line =~ /^\s*$/;
    }
    return $buf;
}

# parse a raw sentence
sub analyze {
    my ($this, $str) = @_;

    $this->{tagger} = new TsuruokaTagger({format => 'conll', lemmatize => $this->{opt}{lemmatize}}) unless defined($this->{tagger});

    my $tagged_result = $this->{tagger}->analyze($str);
    return undef unless $tagged_result;

    return $this->analyze_from_conll($tagged_result);
}

1;
