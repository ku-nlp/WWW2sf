package EnjuWrapper;

# $Id$

# A wrapper of Enju
# http://www-tsujii.is.s.u-tokyo.ac.jp/enju/

use strict;
use IPC::Open3;
use FileHandle;

our $ParserDir = "$ENV{HOME}/share/tool/SearchEngine/enju2tsubaki";
our $ParserFile = 'run-pipe.sh';
our $ParserCommand;

sub new {
    my ($this, $opt) = @_;

    $opt = {} unless defined($opt);
    $this = {opt => $opt};

    # パス等の設定があれば上書きする
    $ParserDir = $this->{opt}{parser_dir} if exists($this->{opt}{parser_dir});
    $ParserCommand = "$ParserDir/$ParserFile";

    bless $this;
}

sub DESTROY {
    my ($this) = @_;
}

sub open_enju {
    my ($this, $str) = @_;

    my $input_file = "/tmp/enjuwrapper-tmp-input-$$.txt";
    open(INPUT, "> $input_file") or die;
    print INPUT $str;
    close(INPUT);
    $this->{input_file} = $input_file;

    my $pid = open3(\*WTR, \*RDR, \*ERR, "$ParserCommand $input_file");
    $this->{pid} = $pid;

    $this->{WTR} = \*WTR;
    $this->{WTR}->autoflush(1);
    $this->{RDR} = \*RDR;
    $this->{RDR}->autoflush(1);
    $this->{ERR} = \*ERR;
}

sub close_enju {
    my ($this) = @_;

    unlink $this->{input_file};
    $this->{WTR}->close;
    $this->{RDR}->close;
    $this->{ERR}->close;
}

# parse a raw sentence
sub analyze {
    my ($this, $str) = @_;

    $this->open_enju($str);
    # $this->{WTR}->print($str);

    my ($buf);
    while (1) {
	my $line = $this->{RDR}->getline; # read one line
	$buf .= $line;
	last if $line =~ m|</S>$|; # the end of sentence
    }

    $this->close_enju();
    return $buf;
}

1;
