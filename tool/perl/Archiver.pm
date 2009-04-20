package Archiver;

# $id:$

use strict;
use utf8;
use FileHandle;

sub new {
    my ($class, $files, $opt) = @_;

    my $this = {opt => $opt};

    $this->{workspace} =($opt->{workspace}) ? $opt->{workspace} : "/tmp";
    $this->{archive_file} = sprintf ("%s/archive.%d", $this->{workspace}, $$);

    open (WRITER, "> ". $this->{archive_file}) or die $!;
    foreach my $file (@$files) {
	if ($opt->{z}) {
	    open (FILE, "zcat $file |") or die $!;
	} else {
	    open (FILE, $file) or die $!;
	}

	# 入力がテキストファイルかどうかのチェック
	if ($opt->{skip_binary_file} && !-T FILE) {
	    my $result = `file $file`;
	    unless ($result =~ /text/) {
		my ($ftype) = ($result =~ /: (.+)$/);
		printf STDERR ("[SKIP] %s is * NOT * a text file. (%s)\n", $file, $ftype);
		next;
	    }
	}

	my $buf;
	while (<FILE>) {
	    $buf .= $_;
	}
	close (FILE);
	$buf .= "\n";

	my $bytesize = length ($buf);
	printf WRITER "%d %s\n%s", $bytesize, $file, $buf;
    }
    close (WRITER);

    bless $this;
}

sub DESTROY {}

sub nextFile {
    my ($this) = @_;

    unless ($this->{handler}) {
	$this->{handler} = new FileHandle();
	open ($this->{handler}, $this->{archive_file}) or die $!;
    }

    if (my $header = $this->{handler}->getline()) {
	my ($size, $name) = split (/ /, $header); chop ($name);

	my $content;
	read ($this->{handler}, $content, $size);

	my $linenum = scalar(split(/\n|\r/, $content));
	return {
	    name => $name,
	    size => $size,
	    linenum => $linenum,
	    content => $content
	    };
    } else {
	return 0;
    }
}


sub close {
    my ($this) = @_;

    if (unlink ($this->{archive_file})) {
	# the archive file was succucessfully removed.
    } else {
	printf STDERR "[WARNNING] the archive file (%s) was * NOT * succucessfully removed.\n", $this->{archive_file};
    }
}

1;
