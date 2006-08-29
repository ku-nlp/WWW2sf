#!/usr/local/bin/zsh

# $Id$

usage() {
    echo "$0 [-j] [-k] input.html"
    exit 1
}

opts=()
jmn=0
knp=0
i=1

while getopts jkh OPT
do  
    case $OPT in
	j)  opts[i]="--jmn"
            i=`expr $i + 1`
	    jmn=1
	    ;;
	k)  opts[i]="--knp"
            i=`expr $i + 1`
	    knp=1
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
xmlfile1=$f:r.xml1

perl -I perl scripts/extract-sentences.perl --checkzyoshi --checkjapanese --xml $1 > $xmlfile1

# 助詞のチェックで日本語ページとは判定されなかったもの
if [ ! -s $xmlfile1 ]; then
    rm -f $xmlfile1
    exit
fi

cat $xmlfile1 | perl -I perl scripts/format-www-xml.perl > $rawfile

# 文の抽出
cat $rawfile | perl -I perl scripts/extract-rawstring.perl > $sentencesfile

# Juman/Knp
if [ $jmn -eq 1 ]; then
    cat $sentencesfile | nkf -e -d | juman -e2 -B -i \# > $jmnfile
elif [ $knp -eq 1 ]; then
    cat $sentencesfile | nkf -e -d | juman -e2 -B -i \# | knp -tab > $jmnfile
fi

# merge
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $rawfile | perl -I perl scripts/add-knp-result.perl $opts[*] $jmnfile
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

