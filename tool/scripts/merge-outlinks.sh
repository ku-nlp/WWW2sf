#!/bin/sh

# $Id$

# sortコマンドが利用するtemp領域
tmpdir=/data2/$USER/inlink-gene-tmp.$$
tmpf=$tmpdir/outlinks.$$
outf=$tmpdir/`hostname --long | cut -f 1 -d .`.inlinks


# アウトリンクデータ(.outlinks)があるディレクトリ
datadir=$1
# マージしたリンクデータを出力する先
# distdir=$2

# tmpディレクトリの生成
mkdir -p $tmpdir

cat $datadir/*outlinks > $tmpf
sort -T $tmpdir -n +2 $tmpf > $outf
mv $outf $datadir/

# gzip $outf
# scp $outf.gz $distdir

rm -r $tmpdir
