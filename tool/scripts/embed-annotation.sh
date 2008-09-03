#!/bin/sh

# $Id$

# usage: embed-annotation.sh [-j|-k|-s] [-R] host:/anywhere/x000.tgz


# 素の標準フォーマットにJUMAN/KNP/SYNGRAPHの解析結果を埋め込むスクリプト


source $HOME/.bashrc


# ★以下の環境変数を変更すること★

workspace=/tmp
perldir=$HOME/cvs/WWW2sf/tool/perl
scriptdir=$HOME/cvs/WWW2sf/tool/scripts
syngraph_pm=$HOME/cvs/SynGraph/perl
syndb_path=$HOME/cvs/SynGraph/syndb/`uname -p`

# 解析に用いるJUMAN/KNPのインストール先
tooldir=$HOME/local/080813/bin
# jumanrc/knprcが置いてあるディレクトリの設定
rcdir=$HOME/local/080813/etc

jmncmd=$tooldir/juman
knpcmd=$tooldir/knp
jmnrc=$rcdir/jumanrc
knprc=$rcdir/knprc

# 解析に用いるツールの指定
command_opt="-jmncmd $jmncmd -knpcmd $knpcmd -jmnrc $jmnrc -knprc $knprc"



tool=
recycle=0

# -regist_exclude_semi_contentwordオプションを有効にするかどうかを指定する
# 旧バージョンとの調整用オプション。有効にすると名詞的形容詞語幹（「多量摂
# 取」の多量）に対してSYNノードを付与しなくなる。通常はオフ。
# 
no_regist_adjective_stem=
while getopts jksRN OPT
do
    case $OPT in
	j)  tool="-jmn"
	    ;;
	k)  tool="-knp"
	    ;;
	s)  tool="-syngraph"
	    ;;
	R)  recycle=1
	    ;;
	N)  no_regist_adjective_stem="-no_regist_adjective_stem"
    esac
done
shift `expr $OPTIND - 1`



clean_tmpfiles() {
    if [ -e $outdir ]; then
	rm -fr $outdir
    fi

    if [ -e $outdir.tgz ]; then
	rm -fr $outdir.tgz
    fi

    if [ -e $sfdir ]; then
	rm -fr $sfdir
    fi

    if [ -e $sfdir.tgz ]; then
	rm -fr $sfdir.tgz
    fi
}

trap 'clean_tmpfiles; exit 1' 1 2 3 9 15


filepath=$1


if [ $recycle -eq 1 ]
then
    id=`basename $filepath | cut -f 2 -d 's' | cut -f 1 -d '.'`
    sfdir=s$id
    outdir=t$id
    recycle_opt="-recycle_knp"

else
    id=`basename $filepath | cut -f 2 -d 'x' | cut -f 1 -d '.'`
    sfdir=x$id
    outdir=s$id
    recycle_opt=
fi

LOGFILE=$workspace/$id.log
touch $LOGFILE
command="perl -I $perldir -I $syngraph_pm  $scriptdir/add-knp-result-dir.perl $recycle_opt $tool -syndbdir $syndb_path -antonymy -indir $sfdir -outdir $outdir -sentence_length_max 130 -all -syndb_on_memory $no_regist_adjective_stem $command_opt -logfile $LOGFILE"



mkdir $workspace 2> /dev/null
mkdir $workspace/finish 2> /dev/null
cd $workspace



echo scp $filepath ./
scp $filepath ./

echo tar xzf $sfdir.tgz
tar xzf $sfdir.tgz
rm -r $sfdir.tgz

mkdir $outdir 2> /dev/null



# スワップしないように仕様するメモリサイズを制限する(max 2GB)
ulimit -m 2097152
ulimit -v 2097152

echo $command
until [ `tail -1 $LOGFILE | grep finish` ] ;
do
    $command
done




rm -r $sfdir

if [ $recycle -eq 1 ]
then
    mv $outdir $sfdir
    outdir=$sfdir
fi


echo "cd $outdir ; for f in ls ; do gzip -f $f ; done ; cd .."
cd $outdir ; for f in `ls | grep -v gz` ; do gzip -f $f ; done ; cd ..


echo tar czf $outdir.tgz $outdir
tar czf $outdir.tgz $outdir

echo rm -r $outdir
rm -r $outdir


mv $outdir.tgz $workspace/finish/
