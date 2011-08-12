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

# ����������꿷�����ե���������������뤿��δ��epoch time (-n�ǻ���)
ref_time=0

base_dir=`dirname $0`

flag_of_make_urldb=0
while getopts ajkshS:c:uUzOTFt:C:eExn: OPT
do
    case $OPT in
	a)  html2sf_extra_args="-a $html2sf_extra_args"
	    ;;
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
	T)  html2sf_extra_args="-T $html2sf_extra_args"
	    ;;
	t)  html2sf_extra_args="-t $OPTARG $html2sf_extra_args"
	    ;;
	F)  html2sf_extra_args="-F $html2sf_extra_args"
	    ;;
	C)  html2sf_extra_args="-C $OPTARG $html2sf_extra_args"
	    ;;
	e)  html2sf_extra_args="-e $html2sf_extra_args"
	    ;;
	E)  html2sf_extra_args="-E $html2sf_extra_args"
	    ;;
	x)  html2sf_extra_args="-x $html2sf_extra_args"
	    ;;
	n)  ref_time=$OPTARG
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

    # �ե�����κǽ��������������
    mtime=`$base_dir/scripts/print-epoch-time.perl $in_f`

    fsize=`wc -c $f | awk '{print $1}'`
    # �ե����륵������$fsize_threshold�ʲ����ǽ��������郎���epoch time����(default: ����OK)�ʤ�
    if [ $fsize -lt $fsize_threshold -a $mtime -gt $ref_time ]; then
	echo $f
	# ��html���Ф���info�ե�����(URL encoding)�������
	if [ -f $hdir/$base_f.info ]; then
	    html2sf_info_args="-i $hdir/$base_f.info"
	else
	    html2sf_info_args=
	fi
	$base_dir/html2sf.sh $html2sf_extra_args $html2sf_info_args -p -f $f > $xdir/$base_f.xml

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
