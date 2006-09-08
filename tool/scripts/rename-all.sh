#!/bin/sh

# ★ここを変える必要がある★
localdir=/data/nlp/kawahara
www2sf_dir=$HOME/work/WWW/WWW2sf/tool/scripts

usage() {
    echo "Usage: $0 -h tsubame00h/h0627.tar.gz -x tsubame00x/x0627.tar.gz tsubame01h tsubame01x"
    exit 1
}

# -h, -x: 指定したところに足していく (前回の最後を指定)


rename_all() {
    tmp_hgoal_dir=$1
    tmp_xgoal_dir=$2
    tmp_hdir=$3
    tmp_xdir=$4

    base=`basename $tmp_xgoal_dir`
    n=`expr $base : "x\(.*\)"`

    count=0
    for tmp_f in $tmp_xgoal_dir/*
    do
	# count=`expr $tmp_f : "$tmp_xgoal_dir/$n\([0-9]*\)"`
	count=`expr $count + 1`
    done

    for tmp_f in $tmp_xdir/*
    do
	base_tmp_f=`expr $tmp_f : "$tmp_xdir/\([0-9]*\)\.$xext"`

	# 10000個になり一杯になったので、次の受け皿を作る
	if [ $count -ge 10000 ]; then
	    tar -C $tmp_dst_dir -zcf $hbase.tar.gz $hbase
	    tar -C $tmp_dst_dir -zcf $xbase.tar.gz $xbase
	    rm -rf $tmp_dst_dir/$hbase
	    rm -rf $tmp_dst_dir/$xbase

	    raw_n=`expr $n : "0*\(.*\)"`
	    raw_n=`expr $raw_n + 1`
	    new_n=`printf %04d $raw_n`
	    hbase="h$new_n"
	    xbase="x$new_n"
	    tmp_hgoal_dir="$tmp_dst_dir/$hbase"
	    tmp_xgoal_dir="$tmp_dst_dir/$xbase"
	    mkdir $tmp_hgoal_dir
	    mkdir $tmp_xgoal_dir
	    count=0
	fi

	# ここで移動
	new_count=`printf %04d $count`
	mv -v $tmp_f $tmp_xgoal_dir/$n$new_count.$xext
	mv -v $tmp_hdir/$base_tmp_f.$hext $tmp_hgoal_dir/$n$new_count.$hext
	count=`expr $count + 1`
    done
}

xfile=
hfile=
hext=html
xext=xml

while getopts h:x: OPT
do
    case $OPT in
        h)  if [ ! -f "$OPTARG" ]; then
		usage
	    fi
	    hfile=$OPTARG
	    hbase=`basename $hfile .tar.gz`
	    if [ -z "$hbase" ]; then
		usage
	    fi
            ;;
	x)  if [ ! -f "$OPTARG" ]; then
		usage
	    fi
	    xfile=$OPTARG
	    xbase=`basename $xfile .tar.gz`
	    if [ -z "$xbase" ]; then
		usage
	    fi
	    ;;
    esac
done
shift `expr $OPTIND - 1`

if [ ! -d "$1" -o ! -d "$2" ]; then
    usage
fi

hdir=$1
xdir=$2
tmp_src_dir=`mktemp -d $localdir/rename_src.XXXXXXXX`
tmp_dst_dir=`mktemp -d $localdir/rename_dst.XXXXXXXX`
trap 'rm -rf $tmp_src_dir $tmp_dst_dir; exit 1' 1 2 3 15

if [ -n "$xfile" -a -n "$hfile" ]; then
    # 受け皿
    tar zxf $xfile -C $tmp_dst_dir
    tar zxf $hfile -C $tmp_dst_dir
    $www2sf_dir/rename-continuously.sh $tmp_dst_dir/$hbase $tmp_dst_dir/$xbase
elif [ -n "$xfile" -o -n "$hfile" ]; then
    usage
fi

for f in $xdir/*.tar.gz
do
    base=`basename $f .tar.gz`
    if [ -z "$xfile" ]; then
	# 受け皿
	xfile=$f
	xbase=`basename $xfile .tar.gz`
	tar zxf $xfile -C $tmp_dst_dir

	hbase=`echo $xbase | sed 's/^x/h/'`
	hfile=$hdir/$hbase.tar.gz
	tar zxf $hfile -C $tmp_dst_dir

	$www2sf_dir/rename-continuously.sh $tmp_dst_dir/$hbase $tmp_dst_dir/$xbase
	continue
    elif [ $f = $xfile ]; then
	echo "skipped $f in $xdir"
	continue
    fi

    tar zxf $f -C $tmp_src_dir
    xcur_base=`basename $f .tar.gz`
    hcur_base=`echo $xcur_base | sed 's/^x/h/'`
    tar zxf $hdir/$hcur_base.tar.gz -C $tmp_src_dir
    $www2sf_dir/rename-continuously.sh $tmp_src_dir/$hcur_base $tmp_src_dir/$xcur_base

    # 移動関数
    rename_all $tmp_dst_dir/$hbase $tmp_dst_dir/$xbase $tmp_src_dir/$hcur_base $tmp_src_dir/$xcur_base

    rm -rf $tmp_src_dir/$hcur_base
    rm -rf $tmp_src_dir/$xcur_base
done

tar -C $tmp_dst_dir -zcf $hbase.tar.gz $hbase
tar -C $tmp_dst_dir -zcf $xbase.tar.gz $xbase
rm -rf $tmp_dst_dir/$hbase
rm -rf $tmp_dst_dir/$xbase

rm -rf $tmp_src_dir
rm -rf $tmp_dst_dir
