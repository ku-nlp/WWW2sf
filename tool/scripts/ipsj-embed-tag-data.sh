#!/bin/sh

# $Id$

source $HOME/.zshrc

# 設定ファイルの読み込み
confdir=`echo $0 | xargs dirname`/../conf
. $confdir/configure



filepath=$1
file2id=$2
tagdata=$3
distdir=$4

id=`basename $filepath | cut -f 1 -d . | cut -f 2 -d s`
sdir=s$id
outdir=ss$id


workspace=$workspace4tag

mkdir -p $workspace 2> /dev/null
cd $workspace

echo scp $filepath ./
scp $filepath ./

echo tar xzf $sdir.tgz
tar xzf $sdir.tgz
rm -rf $sdir.tgz


mkdir -p $outdir 2> /dev/null
find $sdir -type f | perl $scriptdir/ipsj-embed-tag-data.perl $file2id $tagdata -outdir $outdir -z

rm -r $sdir
mv $outdir $sdir
tar czf $sdir.tgz $sdir

scp $workspace/$sdir.tgz $distdir
rm -f $workspace/$sdir.tgz
rm -r $sdir
