#!/bin/sh

# $Id$

usage() {
    echo "$0 [-b] [-B] [-f] [-p|-P] [-w] input.html"
    exit 1
}

# -b: <br>��<p>��̵�� (extract-sentences.perl --ignore_br)
# -B: Movable Type�ѥ��ץ���� (extract-sentences.perl --blog mt)
# -f: ���ܸ�����å��򤷤ʤ� (extract-sentences.perl)�����󥳡��ǥ��󥰤�UTF-8�Ȥ��ƽ���
# -p: ��̤�ʸ��˴ޤ�� (format-www.perl --inclue_paren)
# -P: ��̤�ʸ�Ȥ���ʬ���� (format-www.perl --divide_paren)
# -w: ���κ�����ʤ� (format-www.perl --save_all)

extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=
formatwww_args=

while getopts bfpPhBsw OPT
do  
    case $OPT in
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	B)  extract_args="--blog mt $extract_args"
	    ;;
	f)  extract_std_args=""
	    formatwww_args="--encoding utf8 $formatwww_args"
	    ;;
        p)  formatwww_args="--include_paren $formatwww_args"
            ;;
        P)  formatwww_args="--divide_paren $formatwww_args"
            ;;
        s)  echo "please use -w option instead of -s."
	    usage
            ;;
        w)  formatwww_args="--save_all $formatwww_args"
            ;;
        h)  usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

if [ ! -f "$1" ]; then
    usage
fi

f=$1
base_dir=`dirname $0`
base_f=`expr $f : "\(.*\)\.[^\.]*$"`
formatwww_args="--head $base_f $formatwww_args"
tmpfile=$base_f.$$
tmpfile2=${base_f}_2.$$
trap 'rm -f $tmpfile; exit 1' 1 2 3 15

perl -I $base_dir/perl $base_dir/scripts/extract-sentences.perl $extract_std_args $extract_args $f > $tmpfile

if [ -n "$extract_std_args" ]; then
    nkf -We $tmpfile | perl -I $base_dir/perl $base_dir/scripts/sentence-filter.perl > $tmpfile2
    mv -f $tmpfile2 $tmpfile
fi

perl -I $base_dir/perl $base_dir/scripts/format-www.perl $formatwww_args < $tmpfile
rm -f $tmpfile
