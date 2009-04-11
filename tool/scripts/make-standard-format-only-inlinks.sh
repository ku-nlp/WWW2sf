#!/bin/sh

# $Id;$

# inlink情報のみが埋め込まれた標準フォーマット（解析結果付）を作成するスクリプト

# ★以下の変数の値を変更すること
WORKSPACE=/data2/work/$USER/mksf-inlink
SCRIPT_DIR=$HOME/cvs/WWW2sf/tool/scripts
UTILS_DIR=$HOME/cvs/Utils/perl

INLINK_CDB=$1
id=`basename $INLINK_CDB | cut -f 1 -d .`
DIST_DIR=x$id

mkdir -p $WORKSPACE 2> /dev/null
cd $WORKSPACE

COMMAND=$SCRIPT_DIR/embed-linkinfo.perl
OPTION="-in $INLINK_CDB -inlink_sf -outdir $DIST_DIR"

perl -I $UTILS_DIR $COMMAND $OPTION

tar czf $DIST_DIR.tgz $DIST_DIR
rm -r $DIST_DIR
