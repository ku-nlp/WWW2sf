#!/bin/sh

# $Id$

# アウトリンク情報（テキスト、cdb）を作成するスクリプト
#
# Usage:
# sh extract-outlinks.sh hdir1 hdir2 ...
#
# 入力：gzip圧縮されたウェブページが納められたディレクトリ
# 出力：hdir.outlinks（テキスト形式）
#     ：hdir.outlinks.cdb（cdb形式）


# 環境にあわせて以下の変数を変更
# ★ここから★
utildir=$HOME/cvs/Utils/perl
tooldir=$HOME/cvs/WWW2sf/tool
perldir=$tooldir/perl
scriptdir=$tooldir/scripts

# ウェブページがgzip圧縮されてない場合は空文字にする
GZIPPED=-z

# urlから文書IDがひけるデータベースのkeymapファイル
dbmap=/data/home/skeiji/cdbs/url2did.cdb.keymap
# ★ここまで★



for hdir in $@
do
    # リンク情報の抽出
    perl -I $utildir -I $perldir $scriptdir/extract-anchor.perl $GZIPPED -dir $hdir -dbmap $dbmap > $hdir.outlinks
    # cdb化
    perl -I $utildir -I $perldir $scriptdir/make-anchor-db.perl -outlink -file $hdir.outlinks
done
