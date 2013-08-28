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
our $ParserDir = "$ENV{HOME}/share/tool/maltparser-1.7.2";
our $JavaCommand = "$ENV{HOME}/share/tool/jdk1.6.0_29/bin/java";
our $ParserJarFile = 'maltparser-1.7.2.jar';
our $ParserModelFile = 'engmalt.linear-1.7.mco';
our $ParserCommand;
our $ParserOptions;

sub new {
    my ($this, $opt) = @_;

    # パス等の設定があれば上書きする
    $MEMsize     = $opt->{mem_size}     if ($opt->{mem_size});
    $ParserDir   = $opt->{parser_dir}   if ($opt->{parser_dir});
    $JavaCommand = $opt->{java_command} if ($opt->{java_command});
    $ParserJarFile = $opt->{parser_jar_file} if ($opt->{parser_jar_file});
    $ParserModelFile = $opt->{parser_model_file} if ($opt->{parser_model_file});
    if ($opt->{parser_options}) {
	$ParserOptions = $opt->{parser_options};
    }
    else {
	if (! -f "$ParserDir/$ParserJarFile") {
	    die("Cannot find: $ParserDir/$ParserJarFile\n");
	}
	if (! -f "$ParserDir/$ParserModelFile") {
	    die("Cannot find: $ParserDir/$ParserModelFile\n");
	}
	$ParserOptions = "-jar $ParserDir/$ParserJarFile -w $ParserDir -c $ParserModelFile -m parse";
    }
    $ParserCommand = "$JavaCommand -Xmx$MEMsize $ParserOptions";

    if (! -x $JavaCommand) {
	die("Cannot execute: $JavaCommand\n");
    }

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

    if ($this->{opt}{output_sf}) { # 解析結果を標準フォーマットにする場合
	require StandardFormatLib;
    }

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

    if ($this->{opt}{output_sf}) {
	return &StandardFormatLib::conll2sf($buf);
    }
    else {
	return $buf;
    }
}

# parse a raw sentence
sub analyze {
    my ($this, $str) = @_;

    $this->{tagger} = new TsuruokaTagger({format => 'conll', lemmatize => $this->{opt}{lemmatize}, tagger_dir => $this->{opt}{tagger_dir}}) unless defined($this->{tagger});

    my $tagged_result = $this->{tagger}->analyze($str);
    return undef unless $tagged_result;

    return $this->analyze_from_conll($tagged_result);
}

1;
