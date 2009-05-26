#!/bin/sh

# html��ɸ��ե����ޥåȤ��Ѵ�

# $Id$

usage() {
    cat `dirname $0`"/"usage
    exit 1
}

html2sf_extra_args=
ext=

# �ե����륵����������(default 5M)
fsize_threshold=5242880

base_dir=`dirname $0`

flag_of_make_urldb=0
while getopts jkshS:c:uUzO OPT
do
    case $OPT in
	j)  html2sf_extra_args="-j $html2sf_extra_args"
	    ;;
	k)  html2sf_extra_args="-k $html2sf_extra_args"
	    ;;
	s)  html2sf_extra_args="-s $html2sf_extra_args"
	    ;;
	S)  fsize_threshold=$OPTARG
	    ;;
	c)  html2sf_extra_args="-c $OPTARG $html2sf_extra_args"
	    ;;
	u)  html2sf_extra_args="-u $html2sf_extra_args"
	    ;;
	U)  html2sf_extra_args="-U $html2sf_extra_args"
	    ;;
	z)  ext=".gz"
	    ;;
	O)  html2sf_extra_args="-O $html2sf_extra_args"
	    flag_of_make_urldb=1
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

for in_f in $hdir/*.html$ext
do
    f=$in_f
    base_f=`basename $in_f .html$ext`

    # -z(gzip����)���ץ���󤬻��ꤵ�줿�Ȥ�
    if [ "$ext" = ".gz" ]; then
	gzip -dc $f > $xdir/$base_f.html
	f=$xdir/$base_f.html
    fi

    fsize=`wc -c $f | awk '{print $1}'`
    # �ե����륵������$fsize_threshold�ʲ��ʤ�
    if [ $fsize -lt $fsize_threshold ]; then
	echo $f
	$base_dir/html2sf.sh $html2sf_extra_args -p -f $f > $xdir/$base_f.xml

	# ���Ϥ�0�ξ�硢���
	if [ ! -s $xdir/$base_f.xml ]; then
            rm -f $xdir/$base_f.xml
	fi
    fi

    if [ "$ext" = ".gz" ]; then
	rm -f $f
    fi
done

############################
# �����ȥ�󥯾����ޤȤ��
############################

if [ $flag_of_make_urldb -eq 1 ]; then
    for f in `ls $xdir | grep outlinks | sort` ; do cat $xdir/$f ; done > $hdir.outlinks
    for f in `ls $xdir | grep outlinks | sort` ; do rm  $xdir/$f ; done
    gzip $hdir.outlinks
fi
