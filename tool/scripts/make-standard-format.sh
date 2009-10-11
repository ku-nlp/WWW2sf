#!/bin/sh

# $Id$

# ディレクトリ中のHTML文書を標準フォーマットに変換するスクリプト

# ★以下の変数の値を変更すること
workspace=/data/skeiji/mksf
# このスクリプトの一つ上
# scriptdir=`echo $PWD/$0 | xargs dirname | xargs dirname`
scriptdir=/home/skeiji/ipsj/WWW2sf/tool
# オプション
CNDB=/home/skeiji/public_html/data/cns.cdb
OPTION="-U -c $CNDB"


. $HOME/.zshrc

fp=$1;
distdir=$2
fname=`basename $fp`
fid=`echo $fname | cut -f 1 -d . | cut -f 2 -d 'h'`

hdir=h$fid
xdir=x$fid

if [ ! -e $workspace ]; then
    mkdir -p $workspace
fi

cd $workspace
scp $fp ./
tar xzf $fname
rm $fname

echo mkdir $workspace/$xdir
mkdir $workspace/$xdir

cd $workspace
echo sh $scriptdir/www2sf.sh $hdir $xdir
sh $scriptdir/www2sf.sh $OPTION $hdir $xdir

echo rm -r $hdir
rm -r $hdir

cd $xdir
ls | xargs gzip
cd ..

echo tar czf $xdir.tgz $xdir
tar czf $xdir.tgz $xdir

echo rm -r $xdir
rm -r $xdir

scp $xdir.tgz $distdir
rm $xdir.tgz
