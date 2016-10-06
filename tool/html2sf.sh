#!/bin/sh

# $Id$

usage() {
    echo "$0 [-j|-k|-s] [-b] [-B] [-f] [-c cns.cdb] [-p|-P] [-w] [-M] [-u] [-U] [-e] [-x] [-a|-N] [-d SynGraphPath] [-D DetectBlocksPath] [-l URL] input.html > output.xml"
    exit 1
}

# -j: JUMANの解析結果を埋め込む
# -J: JUMAN++の解析結果を埋め込む
# -k: KNPの解析結果を埋め込む
# -N: KNP にassignf オプションを渡し，係り受け解析をしない
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
# -O: アウトリンク情報を抽出する
# -T: 領域のタイプを判定する
# -e: 英語モード
# -C: 設定ファイルの指定
# -x: 解析結果をXMLとして埋め込む
# -a: KNPにおいて省略解析を行う
# -d: SynGraphのパスを指定する
# -D: DetectBlocksのパスを指定する
# -t: tmp_dirを指定する
# -r: 入力ファイルを厳しくチェックする (fileコマンドでテキスト、5000行以下)
# -l: URLを指定する
# -W:  (extract-sentences.perl --wget)

# Change this for SynGraph annotation
syngraph_home=$HOME/cvs/SynGraph
syndb_path=$syngraph_home/syndb/`uname -m`
detectblocks_home=$HOME/cvs/DetectBlocks

base_dir=`dirname $0`
tmp_dir=/tmp/$USER/html2sf_tmp.$$

extract_std_args="--checkzyoshi --checkjapanese --checkencoding"
extract_args=
formatwww_args=
addknp_args="--sentence_length_max 130 --all"
rawstring_args="--all"
save_utf8file=0
use_module=1
annotation=
input_utf8html=0
annotate_blocktype=0
file_cmd_filter=0
language=japanese
ipsj_metadb=
configfile=$base_dir/conf/configure
infofile=
strict_check_flag=0

while getopts abfjJkspPhBwc:umMNUOTFt:C:eExi:d:l:D:r OPT
do
    case $OPT in
	a)  addknp_args="--anaphora $addknp_args"
	    ;;
	b)  extract_args="--ignore_br $extract_args"
	    ;;
	c)  extract_args="--cndbfile $OPTARG $extract_args"
	    ;;
	B)  extract_args="--blog mt $extract_args"
	    ;;
	e)  language=english
	    addknp_args="--english --all"
	    annotation=conll
	    extract_std_args=""
	    extract_args="--language english $extract_args"
	    ;;
	E)  language=english
	    extract_std_args=""
	    extract_args="--language english $extract_args"
	    ;;
	f)  extract_std_args=""
	    ;;
	j)  addknp_args="--jmn $addknp_args"
	    annotation=jmn
	    ;;
	J)  addknp_args="--jmn --use_jmnpp $addknp_args"
	    annotation=jmn
	    ;;
	k)  addknp_args="--knp $addknp_args"
	    annotation=knp
	    ;;
    N)  addknp_args="--assignf $addknp_args"
        annotation=knp
        ;;
	s)  annotation=syngraph
	    ;;
	x)  addknp_args="--embed_result_in_xml $addknp_args"
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
	t)  tmp_dir=$OPTARG
	    ;;
	F)  file_cmd_filter=1
	    ;;
	C)  configfile=$OPTARG
	    ;;
	i)  infofile=$OPTARG
	    ;;
	d)  syngraph_home=$OPTARG
	    syndb_path=$syngraph_home/syndb/`uname -m`
	    ;;
	D)  detectblocks_home=$OPTARG
	    ;;
	r)  strict_check_flag=1
	    file_cmd_filter=1
	    ;;
        h)  usage
            ;;
	l)  extract_args="--url ${OPTARG} $extract_args"
	    ;;
	W)  extract_args="--wget $extract_args"
	    ;;
    esac
done
shift `expr $OPTIND - 1`

if [ "$annotation" = "syngraph" ]; then
    syngraph_args="--syndbdir $syndb_path --antonymy --syndb_on_memory"
    addknp_args="--syngraph $syngraph_args $addknp_args"
fi

if [ ! -f "$1" ]; then
    usage
fi

f=$1
base_f_w_org_path=`expr $f : "\(.*\)\.[^\.]*$"`
base_f=$tmp_dir/`basename $base_f_w_org_path`
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
    rm -rf $tmp_dir
}

trap 'clean_tmpfiles; exit 1' 1 2 3 15

# 入力がテキストファイルかどうかのチェック
if [ $file_cmd_filter -eq 1 ]; then
    file $f | grep text > /dev/null
    if [ $? -eq 1 ]; then
	echo "ERROR: $f is *NOT* a text file." 1>&2
	exit 1
    fi
fi

# URLとエンコーディングを指定したinfoファイル(スペース区切り)がある場合
url=
encoding=
if [ -n "$infofile" -a -f "$infofile" ]; then
    url=`head -1 $infofile | cut -f1 -d' '`
    encoding=`head -1 $infofile | cut -f2 -d' '`
    if [ $encoding = "utf-8" -o $encoding = "utf8" ]; then
	input_utf8html=1
    fi
    if [ -n "$url" ]; then
	extract_args="--url $url $extract_args"
    fi
fi

# 入力ファイルの行数が5000行を超える場合は怪しいファイルと見なす
if [ $strict_check_flag -eq 1 ]; then
    lnum=`wc -l $f | awk '{print $1}'`
    if [ $lnum -gt 5000 ]; then
	echo "ERROR: $f has too many lines ($lnum)." 1>&2
	exit 1
    fi
fi

if [ ! -d $tmp_dir ]; then
    mkdir -p $tmp_dir
fi

# 英語以外はutf8変換
if [ $language = english ]
then
    cp -f $f $utf8file
else
    # utf8に変換(crawlデータは変換済みのため、強制的に utf8 と判断させる)
    if [ $input_utf8html -eq 1 ]
    then
	perl -CIOE -I $base_dir/perl $base_dir/scripts/to_utf8.perl -force $f > $utf8file
    elif [ -n "$encoding" ]
    then
	perl -I $base_dir/perl $base_dir/scripts/to_utf8.perl --encoding $encoding $f > $utf8file
    else
	perl -I $base_dir/perl $base_dir/scripts/to_utf8.perl $f > $utf8file
    fi
    # 文字コードが推定できないなどの理由でutf8化されたページが得られない場合は終了
    if [ $? -ne 0 ]; then
	echo "$f - UTF-8 変換で失敗しました (強制的にUTF-8と判断しました)" 1>&2
	# 強制的にutf8と判断する
	perl -CIOE -I $base_dir/perl $base_dir/scripts/to_utf8.perl -force $f > $utf8file
    fi
fi

# 領域のタイプを判定し、その結果を埋め込む
if [ $annotate_blocktype -eq 1 ]
then
    OPTION="-add_class2html -add_blockname2alltag -without_juman"
    perl -I $detectblocks_home/perl $base_dir/scripts/embed-region-info.perl $OPTION < $utf8file > $utf8file_w_annotate_blocktype
else
    cat $utf8file > $utf8file_w_annotate_blocktype
fi

# 簡素な標準フォーマットを生成
perl -I $base_dir/perl $base_dir/scripts/extract-sentences.perl $extract_std_args $extract_args --xml $utf8file_w_annotate_blocktype > $xmlfile0


# OffsetとLengthを埋め込み
perl -I $base_dir/perl $base_dir/scripts/set-offset-and-length.perl -html $utf8file -xml $xmlfile0 > $xmlfile1


# 助詞のチェックで日本語ページとは判定されなかったもの
if [ ! -s $xmlfile1 ]; then
    echo "$f - 日本語ページではありません" 1>&2
    clean_tmpfiles
    exit 1
fi

cat $xmlfile1 | perl -I $base_dir/perl $base_dir/scripts/format-www-xml.perl $formatwww_args > $rawfile

if [ -n "$annotation" ]; then

    if [ $use_module -eq 1 ]; then
	cat $rawfile | perl -I $base_dir/perl -I $syngraph_home/perl $base_dir/scripts/add-knp-result.perl $addknp_args --usemodule
    else
	# 文の抽出
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
