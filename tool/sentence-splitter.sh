#!/bin/sh

# テキストを文に切って、括弧処理とID付与を行う

# $Id$

usage() {
    echo "$0 [-p|-P] [-w] input.txt"
    exit 1
}

# -p: 括弧を文内に含める (format-www.perl --inclue_paren)
# -P: 括弧を文として分ける (format-www.perl --divide_paren)
# -w: 全体削除しない (format-www.perl --save_all)

formatwww_args=

while getopts bfpPhBsw OPT
do  
    case $OPT in
        p)  formatwww_args="--include_paren $formatwww_args"
            ;;
        P)  formatwww_args="--divide_paren $formatwww_args"
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
filename=`basename $f`
head_f=`expr $filename : "\(.*\)\.[^\.]*$"`

perl -I $base_dir/perl $base_dir/scripts/sentence-splitter.perl < $f | perl -I $base_dir/perl $base_dir/scripts/format-www.perl $formatwww_args --head $head_f
