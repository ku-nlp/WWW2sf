#!/bin/sh

# 論文ファイル（.txt）からHTMLファイルを作成する

# $Id$

# 設定ファイルの読み込み
confdir=`echo $0 | xargs dirname`/../conf
configfile=$confdir/configure

option=-ipsj
tmpdir=.
distdir=
fnum=10000
flist='none'
while getopts C:f:D:w: OPT
do
    case $OPT in
	C) configfile=$OPTARG
	    ;;
	f) file=$OPTARG
	    ;;
	D) distdir=$OPTARG
	    ;;
	w) sleep `expr $RANDOM \% $OPTARG`
	    ;;
    esac
done
shift `expr $OPTIND - 1`


. $configfile


mkdir -p $workspace4mkhtml 2> /dev/null
cd $workspace4mkhtml

fname=`basename $file`
id=`echo $fname | cut -f 1 -d . | cut -f 2 -d t`
tdir=t$id
hdir=h$id
scp -o "BatchMode yes" -o "StrictHostKeyChecking no" $file ./
tar xzf $fname

sh $scriptdir/make-htmlfile.sh $option4mkhtmls -T $tdir $tdir
mv $tdir/htmls $hdir
tar czf $hdir.tgz $hdir
rm -r $tdir $hdir

scp -o "BatchMode yes" -o "StrictHostKeyChecking no" $hdir.tgz $distdir
rm $hdir.tgz
