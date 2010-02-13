#!/bin/sh

# $Id$

# ディレクトリ中のHTML文書を標準フォーマットに変換するスクリプト

# ★以下の変数の値を変更すること

# 設定ファイルの読み込み
confdir=`echo $0 | xargs dirname`/../conf
configfile=$confdir/configure

source $HOME/.zshrc

fp=
distdir=
while getopts C:f:D:w: OPT
do
    case $OPT in
	C) configfile=$OPTARG
	    ;;
	f) fp=$OPTARG
	    ;;
	D) distdir=$OPTARG
	    ;;
	w)  sleep `expr $RANDOM \% $OPTARG`
	    ;;
    esac
done
shift `expr $OPTIND - 1`

. $configfile


workspace=$workspace4mksfs

# オプションの設定
CNDB=$cndb_path
OPTION=$option4mksfs


. $HOME/.zshrc

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
echo sh $www2sfdir/tool/www2sf.sh $OPTION $hdir $xdir
sh $www2sfdir/tool/www2sf.sh $OPTION -C $configfile $hdir $xdir

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
