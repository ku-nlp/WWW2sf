package TsuruokaTagger;

# $Id$

# A wrapper of tsuruoka-san's tagger
# http://www-tsujii.is.s.u-tokyo.ac.jp/~tsuruoka/postagger/

use strict;
use warnings;
use IPC::Open3;
use FileHandle;

our $TaggerDir = "$ENV{HOME}/share/tool/postagger-1.0";
our $TaggerCommand = "$TaggerDir/tagger";

sub new {
    my ($this, $opt) = @_;

    # Tagger がインストールされているディレクトリの変更
    $TaggerDir = $opt->{tagger_dir} if ($opt->{tagger_dir});
    $TaggerCommand = "$TaggerDir/tagger";

    chdir($TaggerDir);
    my $pid = open3(\*WTR, \*RDR, \*ERR, $TaggerCommand);
    $this = {opt => $opt, WTR => \*WTR, RDR => \*RDR, ERR => \*ERR, pid => $pid, lemmatizer => undef};
    $this->{RDR}->autoflush(1);
    $this->{WTR}->autoflush(1);

    bless $this;
}

sub DESTROY {
    my ($this) = @_;

    $this->{WTR}->close;
    $this->{RDR}->close;
    $this->{ERR}->close;

    undef $this->{lemmatizer} if defined($this->{lemmatizer});
}

sub analyze {
    my ($this, $str) = @_;

    return undef if !$str or $str =~ /^\s*$/;
    $str .= "\n" unless $str =~ /\n$/;

    $this->{WTR}->print($str);

    my $buf = $this->{RDR}->getline; # read one line

    if (exists($this->{opt}{format}) and lc($this->{opt}{format}) eq 'conll') { # CoNLL format
	return $this->tagged2conll($buf);
    }
    else {
	return $buf;
    }
}

# from tagger's output to conll format
sub tagged2conll {
    my ($this, $str) = @_;

    my $buf;
    my $i = 1;
    for my $pair (split(' ', $str)) {
	my ($word, $pos) = split('/', $pair, 2);
	$pos = &change_parenthesis_pos($pos);
	my $h = 0;
	my $rel = '_';
	my $lemma = $this->{opt}{lemmatize} ? $this->lemmatize($word, $pos) : '_';
	$buf .= sprintf("%d\t%s\t%s\t%s\t%s\t\_\t%d\t%s\t\_\t\_\n", $i, $word, $lemma, $pos, $pos, $h, $rel);
	$i++;
    }
    $buf .= "\n";

    return $buf;
}

sub change_parenthesis_pos {
    my ($pos) = @_;

    $pos =~ s/\(/-LRB-/;
    $pos =~ s/\)/-RRB-/;
    $pos =~ s/\[/-LSB-/;
    $pos =~ s/\]/-RSB-/;
    $pos =~ s/\{/-LCB-/;
    $pos =~ s/\}/-RCB-/;

    return $pos;
}

sub lemmatize {
    my ($this, $word, $pos) = @_;

    require Lemmatize;
    $this->{lemmatizer} = new Lemmatize unless defined($this->{lemmatizer});

    my @lemmas = $this->{lemmatizer}->lemmatize(lc($word), $pos);
    if (@lemmas) {
	return $lemmas[0];
    }
    else {
	return $word;
    }
}

1;
