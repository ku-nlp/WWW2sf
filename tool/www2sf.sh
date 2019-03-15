#!/bin/sh

# htmlを標準フォーマットに変換

# $Id$

usage() {
    cat `dirname $0`"/"usage
    exit 1
}

html2sf_extra_args=
add_knp_result_dir_extra_args="--sentence_length_max 130 --all"
ext=
verbose=0

# ファイルサイズの閾値(default 5M)
fsize_threshold=5242880

# ある日時より新しいファイルだけ処理するための基準epoch time (-nで指定)
ref_time=0

# Change this for SynGraph annotation
syngraph_home=$HOME/cvs/SynGraph
syndb_path=$syngraph_home/syndb/`uname -m`

jumanpp_cmd=

base_dir=`dirname $0`

flag_of_make_urldb=0
annotation=

while getopts aANjJkshS:c:uUzOTFt:C:eExn:d:D:ovfrm:M:p:P: OPT
do
    case $OPT in
	a)  add_knp_result_dir_extra_args="--anaphora $add_knp_result_dir_extra_args"
	    ;;
	A)  add_knp_result_dir_extra_args="--case $add_knp_result_dir_extra_args"
	    ;;
	N)  html2sf_extra_args="-N $html2sf_extra_args"
        ;;
	j)  annotation=-jmn
	    ;;
	J)  add_knp_result_dir_extra_args="-use_jmnpp $add_knp_result_dir_extra_args"
	    if [ -z "$annotation" ]; then
		annotation=-jmn
	    fi
	    if [ -z "$jumanpp_cmd" ]; then
		jumanpp_cmd=`which jumanpp`
	    fi
	    ;;
	m)  jumanpp_cmd=$OPTARG
	    ;;
	M)  add_knp_result_dir_extra_args="-jmnrc $OPTARG $add_knp_result_dir_extra_args"
	    ;;
	p)  add_knp_result_dir_extra_args="-knpcmd $OPTARG $add_knp_result_dir_extra_args"
	    ;;
	P)  add_knp_result_dir_extra_args="-knprc $OPTARG $add_knp_result_dir_extra_args"
	    ;;
	k)  annotation=-knp
	    ;;
	s)  annotation=-syngraph
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
	d)  syngraph_home=$OPTARG
	    syndb_path=$syngraph_home/syndb/`uname -m`
	    ;;
	D)  html2sf_extra_args="-D $OPTARG $html2sf_extra_args"
	    ;;
	o)  html2sf_extra_args="-o $html2sf_extra_args"
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

if [ -n "$annotation" ]; then
    xdir_orig=$xdir
    xdir_tmp=$xdir.$$
    mkdir -p $xdir_tmp
    
    xdir=$xdir_tmp
fi

clean_tmpdir() {
if [ -n "$annotation" ]; then
    rm -fr $xdir_tmp
fi
}

trap 'clean_tmpdir; exit 1' 1 2 3 15

if [ -n "$annotation" ]; then
    add_knp_result_dir_extra_args="$annotation $add_knp_result_dir_extra_args"
fi    

if [ -n "$jumanpp_cmd" ]; then
    add_knp_result_dir_extra_args="-jmncmd $jumanpp_cmd $add_knp_result_dir_extra_args"
fi

if [ "$annotation" = "-syngraph" ]; then
    syngraph_args="--syndbdir $syndb_path --antonymy --syndb_on_memory"
    add_knp_result_dir_extra_args="$syngraph_args $add_knp_result_dir_extra_args"
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

############
# 言語解析 #
############

if [ -n "$annotation" ]; then
    perl -I$base_dir/perl -I$syngraph_home/perl $base_dir/scripts/add-knp-result-dir.perl -nologfile -indir $xdir -outdir $xdir_orig $add_knp_result_dir_extra_args
fi

############################
# アウトリンク情報をまとめる
############################

if [ $flag_of_make_urldb -eq 1 ]; then
    for f in `ls $xdir | grep outlinks | sort` ; do cat $xdir/$f ; done > $hdir.outlinks
    for f in `ls $xdir | grep outlinks | sort` ; do rm  $xdir/$f ; done
    gzip $hdir.outlinks
fi

clean_tmpdir
exit 0
