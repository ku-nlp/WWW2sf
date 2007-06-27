#!/usr/bin/env zsh

# htmlを標準フォーマットに変換

# $Id$

usage() {
    echo "$0 [-j] [-k] h0001 x0001"
    exit 1
}

opts=()
i=1

while getopts jkh OPT
do  
    case $OPT in
	j)  opts[i]="-j"
            i=`expr $i + 1`
	    ;;
	k)  opts[i]="-k"
            i=`expr $i + 1`
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

for f in $hdir/*.html; do
    fsize=`wc -c $f | awk '{print $1}'`
    # ファイルサイズが10M以下なら
    if [ $fsize -lt 10000000 ];
    then
	echo $f
	./html2sf.sh $opts[*] -a -p -f $f > $xdir/$f:r:t.xml
	
	# 出力が0の場合、削除
	if [ ! -s $xdir/$f:r:t.xml ]; then
            rm -f $xdir/$f:r:t.xml
	fi
    fi
done
