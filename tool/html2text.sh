#!/bin/sh

# $Id$

usage() {
    echo "$0 input.html"
    exit 1
}

extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=
formatwww_args=

while getopts bfpPhB OPT
do  
    case $OPT in
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	B)  extract_args="--blog mt $extract_args"
	    ;;
	f)  extract_std_args=""
	    ;;
        p)  formatwww_args="--include_paren $formatwww_args"
            ;;
        P)  formatwww_args="--divide_paren $formatwww_args"
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
tmpfile=$base_f.$$
trap 'rm -f $tmpfile; exit 1' 1 2 3 15

perl -I $base_dir/perl $base_dir/scripts/extract-sentences.perl $extract_std_args $extract_args $f | perl -I $base_dir/perl $base_dir/scripts/sentence-filter.perl > $tmpfile
perl -I $base_dir/perl $base_dir/scripts/format-www.perl $formatwww_args $tmpfile
rm -f $tmpfile
