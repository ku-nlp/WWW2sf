#!/bin/sh

# $Id$

usage() {
    echo "$0 [-j|-k|-s] [-b] [-B] [-f] [-c cns.cdb] [-p|-P] [-w] [-M] [-u] input.html"
    exit 1
}

# -j: JUMAN�β��Ϸ�̤�������
# -k: KNP�β��Ϸ�̤�������
# -s: SynGraph�β��Ϸ�̤�������
# -b: <br>��<p>��̵�� (extract-sentences.perl --ignore_br)
# -B: Movable Type�ѥ��ץ���� (extract-sentences.perl --blog mt)
# -f: ���ܸ�����å��򤷤ʤ� (extract-sentences.perl)
# -c cns.cdb: ���󥫡��ƥ����Ȥ�Ϣ³��ʣ��̾��ñ�̤Ƕ��ڤ� (extract-sentences.perl --cndbfile cns.cdb)
# -p: ��̤�ʸ��˴ޤ�� (format-www-xml.perl --inclue_paren)
# -P: ��̤�ʸ�Ȥ���ʬ���� (format-www-xml.perl --divide_paren)
# -w: ���κ�����ʤ� (format-www-xml.perl --save_all)
# -M: ���Ϸ�̤������ि��ˡ�AddKNPResult.pm���Ѥ��ʤ�
# -u: utf8���Ѵ�����HTMLʸ�����¸����

# Change this for SynGraph annotation
syndb_path=$HOME/cvs/SynGraph/syndb/x86_64

extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=
formatwww_args=
addknp_args="--sentence_length_max 130 --all"
rawstring_args="--all"
syngraph_args="--syndbdir $syndb_path --antonymy --syndb_on_memory"
save_utf8file=0
use_module=1
annotation=

while getopts bfjkspPhBwc:umM OPT
do  
    case $OPT in
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	c)  extract_args="--cndbfile $OPTARG $extract_args"
	    ;;
	B)  extract_args="--blog mt $extract_args"
	    ;;
	f)  extract_std_args=""
	    ;;
	j)  addknp_args="--jmn $addknp_args"
	    annotation=jmn
	    ;;
	k)  addknp_args="--knp $addknp_args"
	    annotation=knp
	    ;;
	s)  addknp_args="--syngraph $syngraph_args $addknp_args"
	    annotation=syngraph
	    ;;
        p)  formatwww_args="--include_paren $formatwww_args"
            ;;
        P)  formatwww_args="--divide_paren $formatwww_args"
            ;;
        w)  formatwww_args="--save_all $formatwww_args"
            ;;
        u)  save_utf8file=1
            ;;
        m)  use_module=1
            ;;
        M)  use_module=0
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
utf8file="$base_f.$$.utf8.html"
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

if [ -n "$annotation" ]; then

    if [ $use_module -eq 1 ]; then
	cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/add-knp-result.perl $addknp_args --usemodule
    else
	# ʸ�����
	cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/extract-rawstring.perl $rawstring_args > $sentencesfile

	# Juman/Knp
	cat $sentencesfile | nkf -e -d | juman -e2 -B -i \# > $jmnfile

	if [ $knp -eq 1 ]; then
	    $base_dir/scripts/parse-comp.sh $jmnfile > /dev/null
	    mv -f $knpfile $jmnfile
	fi

	# merge
	cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/add-knp-result.perl $addknp_args $jmnfile
    fi
else
    cat $rawfile
fi

clean_tmpfiles
exit 0
