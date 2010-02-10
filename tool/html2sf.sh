#!/bin/sh

# $Id$

usage() {
    echo "$0 [-j|-k|-s] [-b] [-B] [-f] [-c cns.cdb] [-p|-P] [-w] [-M] [-u] [-U] [-e] input.html > output.xml"
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
# -U: ���Ϥ����Ǥ�utf8���Ѵ��Ѥߤξ��
# -O: �����ȥ�󥯾������Ф���
# -T: �ΰ�Υ����פ�Ƚ�ꤹ��
# -e: �Ѹ�⡼��

# Change this for SynGraph annotation
CVS_DIR=$HOME/cvs
syngraph_home=$HOME/cvs/SynGraph
syndb_path=$syngraph_home/syndb/`uname -m`

extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=
formatwww_args=
addknp_args="--sentence_length_max 130 --all"
rawstring_args="--all"
syngraph_args="--syndbdir $syndb_path --antonymy --syndb_on_memory"
save_utf8file=0
use_module=1
annotation=
input_utf8html=0
annotate_blocktype=0
file_cmd_filter=0
language=japanese
ipsj_metadb=

while getopts bfejkspPhBwc:umMUOTFt: OPT
do
    case $OPT in
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	c)  extract_args="--cndbfile $OPTARG $extract_args"
	    ;;
	B)  extract_args="--blog mt $extract_args"
	    ;;
	e)  language=english
	    addknp_args="--conll --all"
	    annotation=conll
	    use_module=0
	    extract_std_args=""
	    extract_args="--language english $extract_args"
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
        U)  input_utf8html=1
            ;;
	O)  extract_args="-make_urldb $extract_args"
	    ;;
	T)  annotate_blocktype=1
	    ;;
	t)  ipsj_metadb=$OPTARG
	    ;;
	F)  file_cmd_filter=1
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
utf8file_w_annotate_blocktype="$utf8file.w.block"
sentencesfile="$base_f.sentences"
rawfile="$base_f.$$.raw"
jmnfile="$base_f.$$.jmn"
knpfile="$base_f.$$.knp"
xmlfile0="$base_f.$$.xml0"
xmlfile1="$base_f.$$.xml1"

clean_tmpfiles() {
    rm -f $sentencesfile $rawfile $xmlfile0 $xmlfile1 $jmnfile $utf8file_w_annotate_blocktype
    if [ ! $save_utf8file -eq 1 ]; then
	rm -f $utf8file
    fi
}

trap 'clean_tmpfiles; exit 1' 1 2 3 15
base_dir=`dirname $0`

# ���Ϥ��ƥ����ȥե����뤫�ɤ����Υ����å�
if [ $file_cmd_filter -eq 1 ]; then
    file $f | grep text > /dev/null
    if [ $? -eq 1 ]; then
	echo "ERROR: $f is *NOT* a text file." 1>&2
	exit
    fi
fi


# ���ϥե�����ιԿ���5000�Ԥ�Ķ������ϲ������ե�����ȸ��ʤ�
lnum=`wc -l $f | awk '{print $1}'`
if [ $lnum -gt 5000 ]; then
    echo "ERROR: $f has too much lines ($lnum)." 1>&2
    exit
fi


# utf8���Ѵ�(crawl�ǡ������Ѵ��ѤߤΤ��ᡢ����Ū�� utf8 ��Ƚ�Ǥ�����)
if [ $input_utf8html -eq 1 ]
then
    perl -CIOE -I $base_dir/perl $base_dir/scripts/to_utf8.perl -force $f > $utf8file
else
    perl -I $base_dir/perl $base_dir/scripts/to_utf8.perl $f > $utf8file
fi
# ʸ�������ɤ�����Ǥ��ʤ��ʤɤ���ͳ��utf8�����줿�ڡ����������ʤ����Ͻ�λ
if [ $? -ne 0 ]; then
    echo "$f - UTF-8 �Ѵ��Ǽ��Ԥ��ޤ���" 1>&2
    rm -f $utf8file
    exit
fi

# �ΰ�Υ����פ�Ƚ�ꤷ�����η�̤�������
if [ $annotate_blocktype -eq 1 ]
then
    OPTION="-add_class2html -add_blockname2alltag -without_juman"
    perl -I $CVS_DIR/DetectBlocks/perl $base_dir/scripts/embed-region-info.perl $OPTION < $utf8file > $utf8file_w_annotate_blocktype
else
    cat $utf8file > $utf8file_w_annotate_blocktype
fi

# ���Ǥ�ɸ��ե����ޥåȤ�����
perl -I $base_dir/perl $base_dir/scripts/extract-sentences.perl $extract_std_args $extract_args --xml $utf8file_w_annotate_blocktype > $xmlfile0


# Offset��Length��������
perl -I $base_dir/perl $base_dir/scripts/set-offset-and-length.perl -html $utf8file -xml $xmlfile0 > $xmlfile1


# ����Υ����å������ܸ�ڡ����Ȥ�Ƚ�ꤵ��ʤ��ä����
if [ ! -s $xmlfile1 ]; then
    echo "$f - ���ܸ�ڡ����ǤϤ���ޤ���" 1>&2
    rm -f $utf8file
    rm -f $xmlfile0
    rm -f $xmlfile1
    exit
fi

if [ ! -s $ipsj_metadb ]; then
    cat $xmlfile1 | perl -I $base_dir/perl $base_dir/scripts/format-www-xml.perl $formatwww_args > $rawfile
else
    perl $base_dir/scripts/ipsj-embed-metadata.perl -cdb $ipsj_metadb -file $xmlfile1 -file2id $HOME/ipsj/istvan/file2id | perl -I $base_dir/perl $base_dir/scripts/format-www-xml.perl $formatwww_args > $rawfile
fi

if [ -n "$annotation" ]; then

    if [ $use_module -eq 1 ]; then
	cat $rawfile | perl -I $base_dir/perl -I $syngraph_home/perl $base_dir/scripts/add-knp-result.perl $addknp_args --usemodule
    else
	# ʸ�����
	cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/extract-rawstring.perl $rawstring_args > $sentencesfile

	if [ $annotation = "conll" ]; then # currently English only
	    $base_dir/scripts/parse-english.sh $sentencesfile > $jmnfile 2> /dev/null
	else
	    # Juman/Knp
	    cat $sentencesfile | nkf -e -d | juman -e2 -B -i \# > $jmnfile

	    if [ $annotation = "knp" ]; then
		$base_dir/scripts/parse-comp.sh $jmnfile > /dev/null
		mv -f $knpfile $jmnfile
	    fi
	fi

	# merge
	cat $rawfile | perl -I $base_dir/perl -I $syngraph_home/perl $base_dir/scripts/add-knp-result.perl $addknp_args $jmnfile
    fi
else
    cat $rawfile
fi

clean_tmpfiles
exit 0
