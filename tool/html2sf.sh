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
origfile=$f:r.orig
rawfile=$f:r.raw
jmnfile=$f:r.jmn


perl -I perl scripts/extract-sentences.perl --xml $1 | perl -I perl scripts/sentence-filter-xml.perl | perl -I perl scripts/format-www-xml.perl > $origfile
# Ê¸¤ÎÃê½Ð
cat $origfile | perl -I perl scripts/extract-rawstring.perl > $rawfile

# Juman/Knp
if [ $jmn -eq 1 ]; then
    cat $rawfile | nkf -e -d | juman -e2 -B -i \# > $jmnfile
elif [ $knp -eq 1 ]; then
    cat $rawfile | nkf -e -d | juman -e2 -B -i \# | knp -tab> $jmnfile
fi

# merge
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $origfile | perl -I perl scripts/add-knp-result.perl $opts[*] $jmnfile
else
    cat $origfile
fi

rm $origfile
rm $rawfile
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    rm $jmnfile
fi

