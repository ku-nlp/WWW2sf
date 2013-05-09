package StanfordParser;

# $Id$

# A wrapper for Stanford Parser
# http://nlp.stanford.edu/software/lex-parser.shtml
# Original command line usage: java -mx600m -cp ~/share/tool/stanford-parser-2013-04-05/\* edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat typedDependencies -sentences newline edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz -

use strict;
use warnings;
use utf8;
use File::Path;
use IPC::Open3;
use FileHandle;
use Encode;
use Tokenize;

our $MEMsize = '600m';
our $ParserDir = "$ENV{HOME}/share/tool/stanford-parser-2013-04-05";
# our $JavaCommand = "$ENV{HOME}/share/tool/jdk1.6.0_29/bin/java";
our $JavaCommand = '/usr/bin/java';
our $ParserJarFile = '\\*';
our $ParserModel = 'edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz'; # edu/stanford/nlp/models/lexparser/englishFactored.ser.gz
our $ParserCommand;
our $ParserOptions;

sub new {
    my ($this, $opt) = @_;

    # overwrite dynamic settings of path etc.
    $MEMsize     = $opt->{mem_size}     if ($opt->{mem_size});
    $ParserDir   = $opt->{parser_dir}   if ($opt->{parser_dir});
    $JavaCommand = $opt->{java_command} if ($opt->{java_command});
    $ParserJarFile = $opt->{parser_jar_file} if ($opt->{parser_jar_file});
    if ($opt->{parser_options}) {
	$ParserOptions = $opt->{parser_options};
    }
    else {
	if (! -d $ParserDir) {
	    die("Cannot find: ParserDir\n");
	}
	$ParserOptions = "-cp $ParserDir/$ParserJarFile edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat typedDependencies -sentences newline -tokenized -escaper edu.stanford.nlp.process.PTBEscapingProcessor $ParserModel -";

    }
    $ParserCommand = "$JavaCommand -Xmx$MEMsize $ParserOptions";

    if (! -x $JavaCommand) {
	die("Cannot execute: $JavaCommand\n");
    }

    $opt = {} unless defined($opt);
    $opt->{lemmatize} = 1 unless exists($opt->{lemmatize}); # default: turn on lemmatization

    my $pid = open3(\*WTR, \*RDR, \*ERR, $ParserCommand);
    $this = {opt => $opt, WTR => \*WTR, RDR => \*RDR, ERR => \*ERR, pid => $pid, lemmatizer => undef, 
	     tokenizer => new Tokenize};
    $this->{RDR}->autoflush(1);
    $this->{WTR}->autoflush(1);

    if ($this->{opt}{output_sf}) { # output format is standard format
	require XML::LibXML;
	require StandardFormatLib;
    }

    bless $this;
}

sub DESTROY {
    my ($this) = @_;

    $this->{WTR}->close;
    $this->{RDR}->close;
    $this->{ERR}->close;
}

# parse a raw sentence
sub analyze {
    my ($this, $str) = @_;

    return undef if !$str or $str =~ /^\s*$/;

    my $buf;
    if ($str) {
	$str = $this->{tokenizer}->tokenize($str); # do tokenize by myself
	$str .= "\n" unless $str =~ /\n$/;
	$str = encode_utf8($str) if Encode::is_utf8($str);
	$this->{WTR}->print($str);

	while (1) {
	    my $tmp_buf = $this->{RDR}->getline;
	    last if $tmp_buf =~ /^$/;
	    $buf .= $tmp_buf;
	}
    }
    else {
	$buf = "\n";
    }

    if ($this->{opt}{output_sf}) {
	return $this->dependencies2sf($buf);
    }
    else {
	return $buf;
    }
}

# convert Stanford dependencies format to standard format
sub dependencies2sf {
    my ($this, $result) = @_;

    # decode_utf8 if a wide character is contained
    # $result = decode_utf8($result, Encode::FB_CROAK) if $result; # && $result =~ /[^\x00-\x7f]/;

    my $doc = XML::LibXML::Document->new('1.0');
    my $sf_node = $doc->createElement('StandardFormat');
    my $sentence_node = $doc->createElement('S');
    $sf_node->appendChild($sentence_node);
    my $annotation_node = $doc->createElement('Annotation');
    $sentence_node->appendChild($annotation_node);

    if ($result) {
	my (%words, %arguments);
	my $count = 1;
	for my $line (split("\n", $result)) {
	    # decode_utf8 if a wide character is contained
	    eval {
		$line = decode_utf8($line, Encode::FB_QUIET);
	    };
	    if ($@) {
		print STDERR "$@\n";
		next;
	    }

	    if ($line =~ /^(.+)\((.+)-(\d+), ([^ ]+)-(\d+)\)$/) {
		my ($rel, $head_str, $head_id, $mod_str, $mod_id) = ($1, $2, $3, $4, $5);
		$words{$mod_id} = {id => $count, origid => $mod_id, str => $mod_str, rel => $rel, head_origid => $head_id};
		$arguments{$head_id}{$rel} = $count; # new id
		$count++;
	    }
	}

	for my $word_hr (sort {$a->{origid} <=> $b->{origid}} values %words) {
	    if ($word_hr->{head_origid} != 0 && !exists($words{$word_hr->{head_origid}})) {
		# printf STDERR "Error: Head of %s cannot be found.\n", $word_hr->{head_origid};
		# print STDERR $result;
		next;
	    }
	    my $head = $word_hr->{head_origid} == 0 ? 'c-1' : 'c' . $words{$word_hr->{head_origid}}{id};
	    my %pf = (id => 'c' . $word_hr->{id}, head => $head, type => $word_hr->{rel});
	    my %wf = (id => 't' . $word_hr->{id}, surf => $word_hr->{str}, 
		      orig => $this->{opt}{lemmatize} ? $this->lemmatize($word_hr->{str}) : '_'); # pos1 => $word_hr->{pos}

	    my $phrase_node = $doc->createElement('Chunk');
	    for my $key (sort {$StandardFormatLib::pf_order{$a} <=> $StandardFormatLib::pf_order{$b}} keys %pf) {
		$phrase_node->setAttribute($key, $pf{$key});
	    }

	    my $word_node = $doc->createElement('Token');
	    for my $key (sort {$StandardFormatLib::wf_order{$a} <=> $StandardFormatLib::wf_order{$b}} keys %wf) {
		$word_node->setAttribute($key, $wf{$key});
	    }

	    # predicate-argument structure
	    if (exists($arguments{$word_hr->{origid}})) {
		my $predicate_node = $doc->createElement('Predicate');
		for my $rel (keys %{$arguments{$word_hr->{origid}}}) {
		    $predicate_node->setAttribute($rel, 't' . $arguments{$word_hr->{origid}}{$rel});
		}
		$word_node->appendChild($predicate_node);
	    }

	    $phrase_node->appendChild($word_node);
	    $annotation_node->appendChild($phrase_node);
	}
    }

    $doc->setDocumentElement($sf_node);
    return $doc->toString();
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
