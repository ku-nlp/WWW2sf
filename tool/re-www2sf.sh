#!/bin/sh

# htmlを標準フォーマットに変換

# $Id$

usage() {
    echo "$0 [-j] [-k] h0001 x0001"
    exit 1
}

html2sf_extra_args=

# ファイルサイズの閾値(default 5M)
fsize_threshold=5242880

base_dir=`dirname $0`

while getopts jkhS: OPT
do  
    case $OPT in
	j)  html2sf_extra_args="-j"
	    ;;
	k)  html2sf_extra_args="-k"
	    ;;
	S)  fsize_threshold=$OPTARG
	    ;;
        h)  usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

xdir1=$1
xdir2=$2

if [ ! -d $xdir2 ]; then
    mkdir -p $xdir2
fi

for f in `ls $xdir1`
do
    base_f=`basename $xdir1/$f .xml`
    echo $f
    $base_dir/re-html2sf.sh $html2sf_extra_args -a -p -f $xdir1/$f > $xdir2/$base_f.xml
	
    # 出力が0の場合、削除
    if [ ! -s $xdir2/$base_f.xml ]; then
        rm -f $xdir2/$base_f.xml
    fi
done
