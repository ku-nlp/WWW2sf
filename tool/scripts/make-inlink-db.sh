#!/bin/sh

# $Id$

# インリンクで-食べー素（cdb）を作成するスクリプト
#
# Usage:
# sh make-inlink-db.sh file1 file2 ...
#
# 入力：インリンクしている文書IDに従ってソートされたリンク情報
# 出力：hdir.inlinks.cdb（cdb形式）


# ★ 環境にあわせて以下の変数を変更
utildir=$HOME/cvs/Utils/perl
tooldir=$HOME/cvs/WWW2sf/tool
perldir=$tooldir/perl
scriptdir=$tooldir/scripts

for file in $@
do
     perl -I $utildir -I $perldir $scriptdir/make-anchor-db.perl -inlink -file $file
done
