#!/bin/sh

# $Id$

# usage: embed-annotation.sh [-j|-k|-s] [-R] host:/anywhere/x000.tgz


# �Ǥ�ɸ��ե����ޥåȤ�JUMAN/KNP/SYNGRAPH�β��Ϸ�̤������ॹ����ץ�


source $HOME/.bashrc


# ���ʲ��δĶ��ѿ����ѹ����뤳�ȡ�

workspace=/tmp
perldir=$HOME/cvs/WWW2sf/tool/perl
scriptdir=$HOME/cvs/WWW2sf/tool/scripts
syngraph_pm=$HOME/cvs/SynGraph/perl
syndb_path=$HOME/cvs/SynGraph/syndb/`uname -p`

# ���Ϥ��Ѥ���JUMAN/KNP�Υ��󥹥ȡ�����
tooldir=$HOME/local/080813/bin
# jumanrc/knprc���֤��Ƥ���ǥ��쥯�ȥ������
rcdir=$HOME/local/080813/etc

jmncmd=$tooldir/juman
knpcmd=$tooldir/knp
jmnrc=$rcdir/jumanrc
knprc=$rcdir/knprc

# ���Ϥ��Ѥ���ġ���λ���
command_opt="-jmncmd $jmncmd -knpcmd $knpcmd -jmnrc $jmnrc -knprc $knprc"



tool=
recycle=0

# -regist_exclude_semi_contentword���ץ�����ͭ���ˤ��뤫�ɤ�������ꤹ��
# ��С������Ȥ�Ĵ���ѥ��ץ����ͭ���ˤ����̾��Ū���ƻ�촴�ʡ�¿����
# ��פ�¿�̡ˤ��Ф���SYN�Ρ��ɤ���Ϳ���ʤ��ʤ롣�̾�ϥ��ա�
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



# ����åפ��ʤ��褦�˻��ͤ�����ꥵ���������¤���(max 2GB)
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
