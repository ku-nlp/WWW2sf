package StanfordPOSTagger;

# $Id$

# A wrapper for Stanford POS Tagger
# http://nlp.stanford.edu/software/tagger.shtml
# Original command line usage: java -mx300m -cp 'stanford-postagger.jar:' edu.stanford.nlp.tagger.maxent.MaxentTagger -model models/wsj-0-18-left3words-distsim.tagger

use strict;
use warnings;
use IPC::Open3;
use FileHandle;
use Cwd;
use Tokenize;

our $MEMsize = '300m';
our $TaggerDir = "$ENV{HOME}/share/tool/stanford-postagger-full-2013-04-04";
# our $JavaCommand = "$ENV{HOME}/share/tool/jdk1.6.0_29/bin/java";
our $JavaCommand = "/usr/bin/java";
our $TaggerJarFile = 'stanford-postagger.jar';
our $TaggerModelFile = 'models/wsj-0-18-left3words-distsim.tagger';
our $TaggerCommand;
our $TaggerOptions;

sub new {
    my ($this, $opt) = @_;

    # overwrite dynamic settings of path etc.
    $MEMsize = $opt->{mem_size} if ($opt->{mem_size});
    $TaggerDir = $opt->{tagger_dir} if ($opt->{tagger_dir});
    $JavaCommand = $opt->{java_command} if ($opt->{java_command});
    $TaggerJarFile = $opt->{tagger_jar_file} if ($opt->{tagger_jar_file});
    $TaggerModelFile = $opt->{tagger_model_file} if ($opt->{tagger_model_file});
    if ($opt->{tagger_options}) {
	$TaggerOptions = $opt->{tagger_options};
    }
    else {
	if (! -f "$TaggerDir/$TaggerJarFile") {
	    die("Cannot find: $TaggerDir/$TaggerJarFile\n");
	}
	if (! -f "$TaggerDir/$TaggerModelFile") {
	    die("Cannot find: $TaggerDir/$TaggerModelFile\n");
	}
	$TaggerOptions = "-cp $TaggerDir/$TaggerJarFile edu.stanford.nlp.tagger.maxent.MaxentTagger -model $TaggerDir/$TaggerModelFile -sentenceDelimiter newline -tokenize false";
    }
    $TaggerCommand = "$JavaCommand -Xmx$MEMsize $TaggerOptions";

    my $pid = open3(\*WTR, \*RDR, \*ERR, $TaggerCommand);
    $this = {opt => $opt, WTR => \*WTR, RDR => \*RDR, ERR => \*ERR, pid => $pid, lemmatizer => undef, 
	     tokenizer => new Tokenize};
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

    my $buf;
    if ($str) {
	$str = $this->{tokenizer}->tokenize($str); # do tokenize by myself
	$str .= "\n" unless $str =~ /\n$/;
	$this->{WTR}->print($str);

	$buf = $this->{RDR}->getline;
	$this->{RDR}->getline; # discard the newline (it is output for the STDIN input)
    }
    else {
	$buf = "\n";
    }

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
	if ($pair =~ m|^(.+)_([^_]+)$|) {
	    my ($word, $pos) = ($1, $2);
	    my $h = 0;
	    my $rel = '_';
	    my $lemma = $this->{opt}{lemmatize} ? $this->lemmatize($word, $pos) : '_';
	    $buf .= sprintf("%d\t%s\t%s\t%s\t%s\t\_\t%d\t%s\t\_\t\_\n", $i, $word, $lemma, $pos, $pos, $h, $rel);
	    $i++;
	}
	else {
	    warn("Invalid pair: $pair\n");
	}
    }
    $buf .= "\n";

    return $buf;
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
