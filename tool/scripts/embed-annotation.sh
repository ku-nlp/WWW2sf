#!/bin/sh

# $Id$

# usage: embed-annotation.sh [-j|-k|-s] [-R] host:/anywhere/x000.tgz


# 素の標準フォーマットにJUMAN/KNP/SYNGRAPHの解析結果を埋め込むスクリプト


source $HOME/.zshrc

# 設定ファイルの読み込み
confdir=`echo $0 | xargs dirname`/../conf
configfile=$confdir/configure


# 解析に用いるツールの指定
command_opt="-jmncmd $jmncmd -knpcmd $knpcmd -jmnrc $jmnrc -knprc $knprc"



tool=
recycle=0

# -regist_exclude_semi_contentwordオプションを有効にするかどうかを指定する
# 旧バージョンとの調整用オプション。有効にすると名詞的形容詞語幹（「多量摂
# 取」の多量）に対してSYNノードを付与しなくなる。通常はオフ。
#
no_regist_adjective_stem=
distflg=0

while getopts C:jksRNTOIDKSw:d: OPT
do
    case $OPT in
	C)  configfile=$OPTARG
	    ;;
	j)  tool="-jmn"
	    ;;
	k)  tool="-knp"
	    ;;
	s)  tool="-syngraph"
	    ;;
	R)  recycle=1
	    ;;
	N)  no_regist_adjective_stem="-no_regist_adjective_stem"
	    ;;
	T)  command_opt="$command_opt -title"
	    ;;
	O)  command_opt="$command_opt -outlink"
	    ;;
	I)  command_opt="$command_opt -inlink"
	    ;;
	D)  command_opt="$command_opt -description"
	    ;;
	K)  command_opt="$command_opt -keywords"
	    ;;
	S)  command_opt="$command_opt -sentence"
	    ;;
	w)  sleep `expr $RANDOM \% $OPTARG`
	    ;;
	d)  distdir=$OPTARG
	    distflg=1
    esac
done
shift `expr $OPTIND - 1`

. $configfile

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

workspace=$workspace4embed
LOGFILE=$workspace/$id.log
command="perl -I $perldir -I $syngraph_pm  $scriptdir/add-knp-result-dir.perl $recycle_opt $tool -syndbdir $syndb_path -antonymy -indir $sfdir -outdir $outdir -sentence_length_max 130 -all -syndb_on_memory $no_regist_adjective_stem $command_opt -logfile $LOGFILE"


mkdir -p $workspace 2> /dev/null
mkdir -p $workspace/finish 2> /dev/null
cd $workspace
touch $LOGFILE


echo scp $filepath ./
scp -o "BatchMode yes" -o "StrictHostKeyChecking no" $filepath ./

echo tar xzf $sfdir.tgz
tar xzf $sfdir.tgz
rm -rf $sfdir.tgz

mkdir -p $outdir 2> /dev/null



# スワップしないように使用するメモリサイズを制限する(max 2GB)
ulimit -m 2097152
ulimit -v 2097152

echo $command
until [ `tail -1 $LOGFILE | grep finish` ] ;
do
    $command
done




rm -rf $sfdir

if [ $recycle -eq 1 ]
then
    mv $outdir $sfdir
    outdir=$sfdir
fi


echo "cd $outdir ; for f in ls ; do gzip -f $f ; done ; cd .."
cd $outdir ; for f in `ls | grep -v gz` ; do gzip -f $f ; done ; cd ..


echo tar czf $outdir.tgz $outdir
tar czf $outdir.tgz $outdir

echo rm -rf $outdir
rm -rf $outdir


mv $outdir.tgz $workspace/finish/
mv $LOGFILE $workspace/finish/

if [ $distflg -eq 1 ]
then
    scp -o "BatchMode yes" -o "StrictHostKeyChecking no" $workspace/finish/$outdir.tgz $distdir
    rm -f $workspace/finish/$outdir.tgz
fi
