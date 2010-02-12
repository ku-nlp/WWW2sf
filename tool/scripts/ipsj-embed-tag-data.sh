#!/bin/sh

# $Id$

source $HOME/.zshrc


# 設定ファイルの読み込み
confdir=`echo $0 | xargs dirname`/../conf
configfile=$confdir/configure

filepath=
file2id=
tagdata=
distdir=
while getopts C:f:t:D:m:w: OPT
do
    case $OPT in
	C) configfile=$OPTARG
	    ;;
	f) filepath=$OPTARG
	    ;;
	t) tagdata=$OPTARG
	    ;;
	D) distdir=$OPTARG
	    ;;
	m) file2id=$OPTARG
	    ;;
	w) sleep `expr $RANDOM \% $OPTARG`
    esac
done
shift `expr $OPTIND - 1`


. $configfile


id=`basename $filepath | cut -f 1 -d . | cut -f 2 -d s`
sdir=s$id
outdir=ss$id


workspace=$workspace4tag

mkdir -p $workspace 2> /dev/null
cd $workspace

scp -o "BatchMode yes" -o "StrictHostKeyChecking no" $filepath ./

echo tar xzf $sdir.tgz
tar xzf $sdir.tgz
rm -rf $sdir.tgz


mkdir -p $outdir 2> /dev/null
find $sdir -type f | perl $scriptdir/ipsj-embed-tag-data.perl $file2id $tagdata -outdir $outdir -z

rm -r $sdir
mv $outdir $sdir
tar czf $sdir.tgz $sdir

scp -o "BatchMode yes" -o "StrictHostKeyChecking no" $workspace/$sdir.tgz $distdir
rm -f $workspace/$sdir.tgz
rm -r $sdir
