#!/bin/sh

# $Id$

usage() {
    echo "$0 [-j|-k] [-b] [-p] [-f] input.html"
    exit 1
}

juman_path=/share09/home/skeiji/local/080216/bin

jmn=0
knp=0
extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=
formatwww_args=
addknp_args=
rawstring_args=

while getopts abfjkpPhBs OPT
do  
    case $OPT in
	a)  rawstring_args="--all"
	    ;;
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	B)  extract_args="--blog mt $extract_args"
	    ;;
	f)  extract_std_args=""
	    rawstring_args="--all"
	    ;;
	j)  addknp_args="--jmn"
	    jmn=1
	    ;;
	k)  addknp_args="--knp"
	    knp=1
	    ;;
        p)  formatwww_args="--include_paren $formatwww_args"
            ;;
        P)  formatwww_args="--divide_paren $formatwww_args"
            ;;
        s)  formatwww_args="--save_all $formatwww_args"
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
base_f=`expr $f : "\(.*\)\.[^\.]*$"`
sentencesfile="$base_f.sentences"
rawfile="$base_f.$$.raw"
jmnfile="$base_f.$$.jmn"
knpfile="$base_f.$$.knp"

clean_tmpfiles() {
    rm -f $sentencesfile $rawfile $xmlfile1 $jmnfile
}

trap 'clean_tmpfiles; exit 1' 1 2 3 15
base_dir=`dirname $0`

cat $f | perl -I $base_dir/perl $base_dir/scripts/format-www-xml.perl $formatwww_args > $rawfile

# Ê¸¤ÎÃê½Ð
cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/extract-rawstring.perl $rawstring_args > $sentencesfile

# Juman/Knp
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $sentencesfile | nkf -e -d | $juman_path/juman -e2 -B -i \# > $jmnfile
fi
if [ $knp -eq 1 ]; then
    $base_dir/scripts/parse-comp.sh $jmnfile > /dev/null
    mv -f $knpfile $jmnfile
fi

# merge
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/add-knp-result.perl $addknp_args -replace $jmnfile
else
    cat $rawfile
fi

clean_tmpfiles
exit 0
