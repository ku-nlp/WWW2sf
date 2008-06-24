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
recycle=0
while getopts jksR OPT
do
    case $OPT in
	j)  tool="-jmn"
	    ;;
	k)  tool="-knp"
	    ;;
	s)  tool="-syngraph"
	    ;;
	R)  recycle=1
	    ;;
    esac
done
shift `expr $OPTIND - 1`



clean_tmpfiles() {
    if [ -e $outdir ]; then
	rm -fr $outdir
    fi

    if [ -e $outdir.tgz ]; then
	rm -fr $outdir.tgz
    fi

    if [ -e $sfdir ]; then
	rm -fr $sfdir
    fi

    if [ -e $sfdir.tgz ]; then
	rm -fr $sfdir.tgz
    fi
}

trap 'clean_tmpfiles; exit 1' 1 2 3 9 15


filepath=$1


if [ $recycle -eq 1 ]
then
    id=`basename $filepath | cut -f 2 -d 's' | cut -f 1 -d '.'`
    sfdir=s$id
    outdir=t$id
    recycle_opt="-recycle_knp"

else
    id=`basename $filepath | cut -f 2 -d 'x' | cut -f 1 -d '.'`
    sfdir=x$id
    outdir=s$id
    recycle_opt=
fi
logfile=$id.log

command="perl -I $perlhome -I $syngraph_pm  $scripthome/add-knp-result-dir.perl $recycle_opt $tool -syndbdir $syndb_path -antonymy -hyponymy -indir $sfdir -outdir $outdir -sentence_length_max 130 -all -syndb_on_memory"



mkdir $workspace 2> /dev/null
mkdir $workspace/finish 2> /dev/null
cd $workspace



echo scp $filepath ./
scp $filepath ./

echo tar xzf $sfdir.tgz
tar xzf $sfdir.tgz
rm -r $sfdir.tgz

mkdir $outdir 2> /dev/null



echo $command
$command



rm -r $sfdir

if [ $recycle -eq 1 ]
then
    mv $outdir $sfdir
    outdir=$sfdir
fi

echo "cd $outdir ; for f in `ls` ; do gzip $f ; done ; cd .."
cd $outdir ; for f in `ls` ; do gzip $f ; done ; cd ..


echo tar czf $outdir.tgz $outdir
tar czf $outdir.tgz $outdir

echo rm -r $outdir
rm -r $outdir


mv $outdir.tgz $workspace/finish/
