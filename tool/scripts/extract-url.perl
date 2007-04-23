#!/usr/bin/env perl

# 標準フォーマットからURLを抽出するプログラム

use strict;
use utf8;
use CDB_File;

&main();

sub main{
    foreach my $dir (@ARGV){
	my $url_cdb = new CDB_File ("$dir.url.cdb", "$dir.mkcdb_url_temp.$$") or die;
	open(WRITER, "> $dir.url.txt") or die;
	opendir(DIR, $dir) or die;
	foreach my $subdir (sort {$a <=> $b} readdir(DIR)) {
	    next unless($subdir =~ /^x\d\d\d\d$/);

	    my $cnt = 0;
	    opendir(SUBDIR, "$dir/$subdir") or die;
	    foreach my $xfile (sort {$a <=> $b} readdir(SUBDIR)) {
		my $READER;
		if($xfile =~ /^(\d+)\.xml\.gz$/){
		    open($READER, "zcat $dir/$subdir/$xfile |") or die;
		}elsif($xfile =~ /^(\d+)\.xml$/){
		    open($READER, "$subdir/$xfile") or die;
		}else{
		    next;
		}

		print STDERR "\r$subdir ($cnt)" if($cnt%113 == 0);
		$cnt++;
		my $fid = $1;
		my $xml_tag = <$READER>;
		my $sf_tag = <$READER>;

		while(<$READER>){};
		close($READER);

		unless($sf_tag =~ /Url=\"([^"]+)"/){
		    print STDERR "error\n";
		}else{
		    my $url = $1;
		    $url_cdb->insert($fid, $url);
		    print WRITER "$fid $url\n";
		}
	    }
	    closedir(SUBDIR);
	    print STDERR "\r$subdir ($cnt) done\n";
	}
	close(WRITER);
	closedir(DIR);
	$url_cdb->finish(); 
    }
}
