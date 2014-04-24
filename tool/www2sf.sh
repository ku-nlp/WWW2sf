#!/bin/sh

# htmlを標準フォーマットに変換

# $Id$

usage() {
    cat `dirname $0`"/"usage
    exit 1
}

html2sf_extra_args=
ext=
verbose=0

# ファイルサイズの閾値(default 5M)
fsize_threshold=5242880

# ある日時より新しいファイルだけ処理するための基準epoch time (-nで指定)
ref_time=0

base_dir=`dirname $0`

flag_of_make_urldb=0
while getopts ajkshS:c:uUzOTFt:C:eExn:d:D:vfr OPT
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
	d)  html2sf_extra_args="-d $OPTARG $html2sf_extra_args"
	    ;;
	D)  html2sf_extra_args="-D $OPTARG $html2sf_extra_args"
	    ;;
	f)  html2sf_extra_args="-f $html2sf_extra_args"
	    ;;
	r)  html2sf_extra_args="-r $html2sf_extra_args"
	    ;;
	v)  verbose=1
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

    # -z(gzip圧縮)オプションが指定されたとき
    if [ "$ext" = ".gz" ]; then
	gzip -dc $f > $xdir/$base_f.html
	f=$xdir/$base_f.html
    fi

    # ファイルの最終修正時刻を得る
    mtime=`$base_dir/scripts/print-epoch-time.perl $in_f`

    fsize=`wc -c $f | awk '{print $1}'`
    # ファイルサイズが$fsize_threshold以下、最終修正時刻が基準epoch timeより後(default: 全てOK)なら
    if [ $fsize -lt $fsize_threshold -a $mtime -gt $ref_time ]; then
	if [ $verbose -eq 1 ]; then
	    echo $f
	fi
	# 各htmlに対するinfoファイル(URL encoding)があれば
	if [ -f $hdir/$base_f.info ]; then
	    html2sf_info_args="-i $hdir/$base_f.info"
	else
	    html2sf_info_args=
	fi
	$base_dir/html2sf.sh $html2sf_extra_args $html2sf_info_args -p -f $f > $xdir/$base_f.xml

	# 出力が0の場合、削除
	if [ ! -s $xdir/$base_f.xml ]; then
            rm -f $xdir/$base_f.xml
	fi
    else
	# 空ファイルを作る
	: > $xdir/$base_f.xml
    fi
    if [ "$ext" = ".gz" -a -f $xdir/$base_f.xml ]; then
		gzip $xdir/$base_f.xml 
	fi

    if [ "$ext" = ".gz" ]; then
	rm -f $f
    fi
done

############################
# アウトリンク情報をまとめる
############################

if [ $flag_of_make_urldb -eq 1 ]; then
    for f in `ls $xdir | grep outlinks | sort` ; do cat $xdir/$f ; done > $hdir.outlinks
    for f in `ls $xdir | grep outlinks | sort` ; do rm  $xdir/$f ; done
    gzip $hdir.outlinks
fi
