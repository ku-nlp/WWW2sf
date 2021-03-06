#!/usr/bin/env zsh

# www2sf.shを走らせるシェルスクリプト
# 解析終了後、圧縮してmvする
# ./www2sf-tar.sh tsubame00 h0001 x0001

block=$1
h=$2
x=$3

# ★ここを変える必要がある★
localdir=/data/shibate
sourcedir=$HOME/${block}h
destdir=$HOME/${block}x
# localdir=/data/nlp/kawahara
# sourcedir=$HOME/work/WWW/${block}h
# destdir=$HOME/work/WWW/${block}x

if [ ! -d $localdir/$block/ ] ; then
    mkdir -p $localdir/$block/
fi

if [ ! -d $destdir ] ; then
    mkdir -p $destdir
fi

# copy
if [ -f $sourcedir/$h.tar.gz ]; then
    cp $sourcedir/$h.tar.gz $localdir/$block/
    tar -C $localdir/$block -zxvf $localdir/$block/$h.tar.gz
elif [ -d $sourcedir/$h ]; then
    tar -C $sourcedir -cf - $h | tar -xvf - -C $localdir/$block
else
    echo "Not found: $h"
    exit 1
fi

# 変換
./www2sf.sh -j $localdir/$block/$h $localdir/$block/$x 

scripts/rename-continuously.sh $localdir/$block/$h $localdir/$block/$x 
tar -C $localdir/$block -zcvf $destdir/$h.tar.gz ./$h
tar -C $localdir/$block -zcvf $destdir/$x.tar.gz ./$x

rm -f $localdir/$block/$h.tar.gz
rm -fr $localdir/$block/$h
rm -fr $localdir/$block/$x
