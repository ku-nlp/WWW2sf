#!/bin/sh

# htmlを標準フォーマットに変換

# $Id$

usage() {
    cat `dirname $0`"/"usage
    exit 1
}

html2sf_extra_args=

# ファイルサイズの閾値(default 5M)
fsize_threshold=5242880

base_dir=`dirname $0`

while getopts jkshS:c:u OPT
do  
    case $OPT in
	j)  html2sf_extra_args="-j"
	    ;;
	k)  html2sf_extra_args="-k"
	    ;;
	s)  html2sf_extra_args="-s"
	    ;;
	S)  fsize_threshold=$OPTARG
	    ;;
	c)  html2sf_extra_args="-c $OPTARG $html2sf_extra_args"
	    ;;
	u)  html2sf_extra_args="-u $html2sf_extra_args"
	    ;;
        h)  usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

hdir=$1
xdir=$2

if [ ! -d $xdir ]; then
    mkdir -p $xdir
fi

for f in $hdir/*.html
do
    base_f=`basename $f .html`
    fsize=`wc -c $f | awk '{print $1}'`
    # ファイルサイズが$fsize_threshold以下なら
    if [ $fsize -lt $fsize_threshold ]; then
	echo $f
	$base_dir/html2sf.sh $html2sf_extra_args -p -f $f > $xdir/$base_f.xml
	
	# 出力が0の場合、削除
	if [ ! -s $xdir/$base_f.xml ]; then
            rm -f $xdir/$base_f.xml
	fi
    fi
done
