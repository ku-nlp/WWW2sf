#!/bin/sh

# $Id$

# usage: embed-annotation.sh [-j|-k|-s] host:/anywhere/x000.tgz


# 素の標準フォーマットにJUMAN/KNP/SYNGRAPHの解析結果を埋め込むスクリプト


# ★以下の環境変数を変更すること★

workspace=/tmp
perlhome=$HOME/cvs/WWW2sf/tool/perl
scripthome=$HOME/cvs/WWW2sf/tool/scripts
syngraph_pm=$HOME/cvs/SynGraph/perl
syndb_path=$HOME/cvs/SynGraph/syndb/x86_64

tool=
while getopts jks OPT
do
    case $OPT in
	j)  tool="-jmn"
	    ;;
	k)  tool="-knp"
	    ;;
	s)  tool="-syngraph"
	    ;;
    esac
done
shift `expr $OPTIND - 1`


mkdir $workspace 2> /dev/null

filepath=$1
id=`basename $filepath | cut -f 2 -d 'x' | cut -f 1 -d '.'`
xdir=x$id
outdir=s$id
logfile=$id.log

cd $workspace
echo scp $filepath ./
scp $filepath ./

echo tar xzf x$id.tgz
tar xzf x$id.tgz
rm -r x$id.tgz

mkdir $outdir 2> /dev/null

echo perl -I $perlhome -I $syngraph_pm  $scripthome/add-knp-result-dir.perl $tool -syndbdir $syndb_path -antonymy -r -indir $xdir -outdir $outdir -sentence_length_max 130 -all
perl -I $perlhome -I $syngraph_pm  $scripthome/add-knp-result-dir.perl $tool -syndbdir $syndb_path -antonymy -r -indir $xdir -outdir $outdir -sentence_length_max 130 -all

echo tar czf $outdir.tgz $outdir
tar czf $outdir.tgz $outdir

echo rm -r $outdir
rm -r $outdir
rm -r $xdir
