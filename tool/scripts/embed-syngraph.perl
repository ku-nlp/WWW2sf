#!/usr/bin/env perl

# $Id$

use strict;
use utf8;
use Encode;
use SynGraph;
use KNP;
use Getopt::Long;

# Attention!
use Error qw(:try);




my (%opt); GetOptions(\%opt, 'dir=s', 'z', 'syndbdir=s', 'hyponymy', 'antonymy');
my $SynGraph = new SynGraph($opt{syndbdir});

if (!$opt{dir} || !$opt{syndbdir}) {
    print "Usage $0 -dir x0000 -syndbdir SYNDB_DIR_PATH [-z]\n";
    exit;
}


my $cnt = 0;
opendir(DIR, $opt{dir});
foreach my $file (sort readdir(DIR)){
    next if ($file eq '.' || $file eq '..');

    print STDERR "\rln: $cnt" if ($cnt%13 == 0);
    $cnt++;

    my $regnode_option;
    $regnode_option->{relation} = ($opt{hyponymy}) ? 1 : 0;
    $regnode_option->{antonym} = ($opt{antonymy}) ? 1 : 0;
    
    my $fp = "$opt{dir}/$file";
    if ($opt{z}) {
	open(READER, "zcat $fp |");
    } else {
	open(READER, $fp);
    }

    my $sid = 0;
    my $syn_doc;
    my $knp_result;
    my $knp_flag = 0;
    my $TAG_NAME = "Knp";
    while (<READER>) {
	if($_ =~ /^\]\]\><\/Annotation>/){
	    $knp_result = decode('utf8', $knp_result) unless (utf8::is_utf8($knp_result));
	    
	    try {
		my $result = new KNP::Result($knp_result);
		$result->set_id($sid++);
		my $syn_result = $SynGraph->OutputSynFormat($result, $regnode_option);
		$syn_doc .= "      <Annotation Scheme=\"SynGraph\"><![CDATA[";
		$syn_doc .= encode('utf8', $syn_result);
		$syn_doc .= "]]></Annotation>\n";
	    } catch Error with {
		my $e = shift;
		print STDERR "Exception at line $e->{-line} in $e->{-file} file=$fp\n";
		print STDERR encode('euc-jp', $knp_result) . "\n";
	    } finally {
		$knp_result = undef;
		$knp_flag = 0;
	    };
	}elsif($_ =~ /.*\<Annotation Scheme=\"$TAG_NAME\"\>\<\!\[CDATA\[/){
	    $knp_result = "$'";
	    $knp_flag = 1;
	}elsif($knp_flag > 0){
	    $knp_result .= "$_";
	}else{
	    $syn_doc .= $_;
	}
    }
    close(READER);

    $fp =~ s/.gz$// if ($opt{z});

    open(WRITER, "> $fp.syn");
    print WRITER $syn_doc;
    close(WRITER)
}

print STDERR "\rln: $cnt done.\n";
