#!/bin/sh

# $Id$

usage() {
    echo "$0 [-j|-k|-s] [-b] [-B] [-f] [-c cns.cdb] [-p|-P] [-w] [-M] [-u] [-U] input.html > output.xml"
    exit 1
}

# -j: JUMANの解析結果を埋め込む
# -k: KNPの解析結果を埋め込む
# -s: SynGraphの解析結果を埋め込む
# -b: <br>と<p>を無視 (extract-sentences.perl --ignore_br)
# -B: Movable Type用オプション (extract-sentences.perl --blog mt)
# -f: 日本語チェックをしない (extract-sentences.perl)
# -c cns.cdb: アンカーテキストの連続を複合名詞単位で区切る (extract-sentences.perl --cndbfile cns.cdb)
# -p: 括弧を文内に含める (format-www-xml.perl --inclue_paren)
# -P: 括弧を文として分ける (format-www-xml.perl --divide_paren)
# -w: 全体削除しない (format-www-xml.perl --save_all)
# -M: 解析結果を埋め込むために、AddKNPResult.pmを用いない
# -u: utf8に変換したHTML文書を保存する
# -U: 入力がすでにutf8に変換済みの場合

# Change this for SynGraph annotation
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

while getopts bfjkspPhBwc:umMU OPT
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
        U)  input_utf8html=1
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

# utf8に変換(crawlデータは変換済みのため、強制的に utf8 と判断させる)
if [ $input_utf8html -eq 1 ]
then
    perl -CIOE -I $base_dir/perl $base_dir/scripts/to_utf8.perl -force $f > $utf8file
else
    perl -I $base_dir/perl $base_dir/scripts/to_utf8.perl $f > $utf8file
fi
# 文字コードが推定できないなどの理由でutf8化されたページが得られない場合は終了
if [ $? -ne 0 ]; then
    echo "$f - UTF-8 変換で失敗しました" 1>&2
    rm -f $utf8file
    exit
fi

# 簡素な標準フォーマットを生成
perl -I $base_dir/perl $base_dir/scripts/extract-sentences.perl $extract_std_args $extract_args --xml $utf8file > $xmlfile0

# OffsetとLengthを埋め込み
perl -I $base_dir/perl $base_dir/scripts/set-offset-and-length.perl -html $utf8file -xml $xmlfile0 > $xmlfile1


# 助詞のチェックで日本語ページとは判定されなかったもの
if [ ! -s $xmlfile1 ]; then
    echo "$f - 日本語ページではありません" 1>&2
    rm -f $utf8file
    rm -f $xmlfile0
    rm -f $xmlfile1
    exit
fi

cat $xmlfile1 | perl -I $base_dir/perl $base_dir/scripts/format-www-xml.perl $formatwww_args > $rawfile

if [ -n "$annotation" ]; then

    if [ $use_module -eq 1 ]; then
	cat $rawfile | perl -I $base_dir/perl -I $syngraph_home/perl $base_dir/scripts/add-knp-result.perl $addknp_args --usemodule
    else
	# 文の抽出
	cat $rawfile | perl -I $base_dir/perl $base_dir/scripts/extract-rawstring.perl $rawstring_args > $sentencesfile

	# Juman/Knp
	cat $sentencesfile | nkf -e -d | juman -e2 -B -i \# > $jmnfile

	if [ $annotation = "knp" ]; then
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
