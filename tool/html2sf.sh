#!/bin/sh

# $Id$

usage() {
    echo "$0 [-j|-k] [-b] [-p] [-f] input.html"
    exit 1
}

jmn=0
knp=0
extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=
formatwww_args=
addknp_args=
rawstring_args=
save_utf8file=0

while getopts abfjkpPhBsc:u OPT
do  
    case $OPT in
	a)  rawstring_args="--all"
	    ;;
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	c)  extract_args="--cndbfile $OPTARG $extract_args"
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
        u)  save_utf8file=1
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
utf8file="$base_f.$$.utf8.xml"
sentencesfile="$base_f.sentences"
rawfile="$base_f.$$.raw"
jmnfile="$base_f.$$.jmn"
knpfile="$base_f.$$.knp"
xmlfile0="$base_f.$$.xml0"
xmlfile1="$base_f.$$.xml1"

clean_tmpfiles() {
    rm -f $sentencesfile $rawfile $xmlfile0 $xmlfile1 $jmnfile
    if [ ! $save_utf8file -eq 1 ]; then
	rm -f $utf8file
    fi
}

trap 'clean_tmpfiles; exit 1' 1 2 3 15
base_dir=`dirname $0`

# utf8���Ѵ�
perl -I $base_dir/perl $base_dir/scripts/to_utf8.perl $f > $utf8file
# ʸ�������ɤ�����Ǥ��ʤ��ʤɤ���ͳ��utf8�����줿�ڡ����������ʤ����Ͻ�λ
if [ $? -ne 0 ]; then
    rm -f $utf8file
    exit
fi

# ���Ǥ�ɸ��ե����ޥåȤ�����
perl -I $base_dir/perl $base_dir/scripts/extract-sentences.perl $extract_std_args $extract_args --xml $utf8file > $xmlfile0

# Offset��Length��������
perl -I $base_dir/perl $base_dir/scripts/set-offset-and-length.perl -html $utf8file -xml $xmlfile0 > $xmlfile1


# ����Υ����å������ܸ�ڡ����Ȥ�Ƚ�ꤵ��ʤ��ä����
if [ ! -s $xmlfile1 ]; then
    rm -f $xmlfile1
    exit
fi

cat $xmlfile1 | perl -I $base_dir/perl $base_dir/scripts/format-www-xml.perl $formatwww_args > $rawfile

# ʸ�����
cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/extract-rawstring.perl $rawstring_args > $sentencesfile

# Juman/Knp
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $sentencesfile | nkf -e -d | juman -e2 -B -i \# > $jmnfile
fi
if [ $knp -eq 1 ]; then
    $base_dir/scripts/parse-comp.sh $jmnfile > /dev/null
    mv -f $knpfile $jmnfile
fi

# merge
if [ $jmn -eq 1 -o $knp -eq 1 ]; then
    cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/add-knp-result.perl $addknp_args $jmnfile
else
    cat $rawfile
fi

clean_tmpfiles
exit 0
