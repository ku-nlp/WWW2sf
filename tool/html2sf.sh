#!/bin/sh

# $Id$

usage() {
    echo "$0 [-j|-k] [-b] [-p] [-f] input.html"
    exit 1
}

opts=()
jmn=0
knp=0
extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=""
formatwww_args=
addknp_args=

while getopts bfjkph OPT
do  
    case $OPT in
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	f)  extract_std_args=""
	    ;;
	j)  addknp_args="--jmn"
	    jmn=1
	    ;;
	k)  addknp_args="--knp"
	    knp=1
	    ;;
        p)  formatwww_args="--include_paren $formatwww_args"
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
sentencesfile=$f:r.sentences
rawfile=$f:r.raw
jmnfile=$f:r.jmn
knpfile=$f:r.knp
xmlfile1=$f:r.xml1

perl -I perl scripts/extract-sentences.perl $extract_std_args $extract_args --xml $1 > $xmlfile1

# 助詞のチェックで日本語ページとは判定されなかったもの
if [ ! -s $xmlfile1 ]; then
    rm -f $xmlfile1
    exit
fi

cat $xmlfile1 | perl -I perl scripts/format-www-xml.perl $formatwww_args > $rawfile

# 文の抽出
cat $rawfile | perl -I perl scripts/extract-rawstring.perl > $sentencesfile

# Juman/Knp
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $sentencesfile | nkf -e -d | juman -e2 -B -i \# > $jmnfile
fi
if [ $knp -eq 1 ]; then
    scripts/parse-comp.sh $jmnfile
    mv -f $knpfile $jmnfile
fi

# merge
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $rawfile | perl -I perl scripts/add-knp-result.perl $addknp_args $jmnfile
else
    cat $rawfile
fi

# clean
if [ -e $sentencesfile ]; then
    rm -f $sentencesfile
fi

if [ -e $rawfile ]; then
    rm -f $rawfile
fi

if [ -e $xmlfile1 ]; then
    rm -f $xmlfile1
fi

if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    if [ -e $jmnfile ]; then
	rm -f $jmnfile
    fi
fi
