#!/bin/sh

# zaodataを読み込むシェルスクリプト
# ./read-zaodata.sh tsubame00 doc0000000000
# -o num: offsetの指定
# -t: tar.gzで固める

usage() {
    echo "$0 [-o num] [-t] tsubame00 doc0000000000"
    echo "In case of tsubame01: $0 -o 628 tsubame01 doc0000000000"
    exit 1
}

read_zaodata_args=
offset=0
targz_flag=0

while getopts o:th OPT
do
    case $OPT in
        o)  read_zaodata_args="--offset $OPTARG $read_zaodata_args"
	    offset=$OPTARG
            ;;
	t)  targz_flag=1
	    ;;
        h)  usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

block=$1
head=$2

# ★ここを変える必要がある★
localdir=/data/shibate
sourcedir=$HOME
destdir=$sourcedir/${block}h
# localdir=/data/nlp/kawahara
# sourcedir=/export/home/nlp/text/WWW/orig
# destdir=$HOME/work/WWW/${block}h


if [ ! -d $localdir/$block/ ] ; then
    mkdir -p $localdir/$block/
fi

if [ ! -d $destdir ] ; then
    mkdir -p $destdir
fi

# copy
cp $sourcedir/$block/$head.idx $localdir/$block/
cp $sourcedir/$block/$head.zl $localdir/$block/

perl -I ../perl read-zaodata.perl $read_zaodata_args --splithtml --language japanese $localdir/$block/$head.idx

rm -f $localdir/$block/$head.idx
rm -f $localdir/$block/$head.zl

cd $localdir/$block

h=`echo $head | sed 's/^doc000000//'`
h=`expr $h + $offset`
h=`printf "h%04d" $h`

if [ $targz_flag -eq 1 ]; then
    tar zcvf $h.tar.gz ./$h
    mv $h.tar.gz $destdir
    rm -fr $h
else
    mv $h $destdir
fi
