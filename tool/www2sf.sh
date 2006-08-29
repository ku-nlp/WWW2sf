#!/usr/local/bin/zsh

# html��ɸ��ե����ޥåȤ��Ѵ�

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
    echo $f
    ./html2sf.sh $opts[*] $f > $xdir/$f:r:t.xml

    # ���Ϥ�0�ξ�硢���                                                       
    if [ ! -s $xdir/$f:r:t.xml ]; then
        rm -f $xdir/$f:r:t.xml
    fi

done
