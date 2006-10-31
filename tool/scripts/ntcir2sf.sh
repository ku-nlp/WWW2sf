#!/bin/sh

# ★ここを変える必要がある★
www2sf_dir=$HOME/work/WWW/WWW2sf/tool
scripts_dir=$www2sf_dir/scripts
perl_dir=$www2sf_dir/perl

usage() {
    echo "Usage: $0 [-j|-k] dir"
    echo "e.g., $0 -j /export/home/nlp/text/NTCIR/NTCIR-5-WEB/NW1000G-04/data/raw/000"
    exit 1
}

jmn=0
knp=0
auto_args=
knp_command="parse-comp.sh"
while getopts jkh OPT
do
    case $OPT in
	j)  auto_args="--jmn"
	    jmn=1
	    ;;
	k)  auto_args="--knp"
	    knp=1
	    ;;
	h)  usage
	    ;;
    esac
done
shift `expr $OPTIND - 1`

if [ ! -d "$1" ]; then
    usage
    exit 1
fi

given_dir=$1

file_count=0
ok_count=0

dirhead=`basename $given_dir`
mkdir "x$dirhead"
mkdir "h$dirhead"

IFS='
'

for list in `find $given_dir -type f -name "*.filelist" -print`
do
    echo "LIST $list"
    dir=`dirname $list`
    site_num=`basename $list .filelist`

    for line in `cat $list`
    do
        part_path=`echo $line | cut -f2 -d' '`
        url=`echo $line | cut -f3 -d' '`
	sub_dir=`echo $part_path | cut -b1-3`
	subsub_dir=`echo $part_path | cut -b4,5`
	f="$dir/$sub_dir/${subsub_dir}xx/${site_num}_$part_path.dat"
	filehead="${site_num}_$part_path"

	if [ ! -f $f ]; then
	    echo "ERROR $f: Not found"
	    continue
	fi

	file_count=`expr $file_count + 1`
	echo -n "$f "

	# check filetype (text is OK)
	filetype=`file $f`
	filetype_ok=`echo $filetype | grep text`
	if [ -z "$filetype_ok" ]; then
	    echo "NG (filetype: $filetype)"
	    continue
	fi

	tmp_file=`mktemp ntcir2sf.XXXXXXXX`
	perl -I $perl_dir $scripts_dir/extract-sentences.perl --checkencoding --checkjapanese --checkzyoshi --xml --url $url $f > $tmp_file
	if [ ! -s $tmp_file ]; then
	    rm -f $tmp_file
	    echo "NG"
	    continue
	fi

	echo "OK"

	pathhead="x$dirhead/$filehead"

	cp $f h$dirhead/$filehead.html
	cat $tmp_file | perl -I $perl_dir $scripts_dir/format-www-xml.perl > $pathhead.xml

	# 文の抽出
	if [ $jmn -eq 1 -o $knp -eq 1 ]; then
	    cat $pathhead.xml | perl -I $perl_dir $scripts_dir/extract-rawstring.perl > $pathhead.sentences
	fi

	# Juman/Knp
	if [ $jmn -eq 1 ]; then
	    cat $pathhead.sentences | nkf -e -d | juman -i \# > $pathhead.auto
	elif [ $knp -eq 1 ]; then
	    cat $pathhead.sentences | nkf -e -d | juman -i \# > $pathhead.jmn
	    $knp_command $pathhead.jmn
	    mv -f $pathhead.knp $pathhead.auto
	    rm -f $pathhead.jmn $pathhead.log
	fi

	# merge
	if [ $jmn -eq 1 -o $knp -eq 1 ]; then
	    cat $pathhead.xml | perl -I $perl_dir $scripts_dir/add-knp-result.perl $auto_args $pathhead.auto > $tmp_file
	    mv -f $tmp_file $pathhead.xml
	    rm -f $pathhead.sentences $pathhead.auto
	else
	    rm -f $tmp_file
	fi

	ok_count=`expr $ok_count + 1`
    done
done

echo "$ok_count / $file_count"
