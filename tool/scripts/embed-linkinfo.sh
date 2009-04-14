#!/bin/sh

# $Id$

# ��󥯾����ɸ��ե����ޥåȤ������ॹ����ץ�

# Usage: sh embed-linkinfo.sh somewhere/url2did.cdb.keymap somehost:/somewhere/xXXXXX.tgz


workspace=/tmp/skeiji
cdblist=/share09/home/skeiji/sample-dat/cdblist
perldir=/share09/home/skeiji/cvs/WWW2sf/tool/scripts
utildir=/share09/home/skeiji/cvs/Utils/perl


url2did_keymap=$1
fp=$2

id=`basename $fp | cut -f 1 -d '.' | cut -f 2 -d 'x'`
indir=x$id
outdir=xx$id


incdb_keymap=$workspace/$id.inlinks.cdb.keymap
# outcdb_keymap=$workspace/$id.outlinks.cdb.keymap

# command="perl -I $utildir $perldir/embed-linkinfo.perl -in $incdb_keymap -out $outcdb_keymap -indir $indir -outdir $outdir"
command="perl -I $utildir $perldir/embed-linkinfo.perl -in $incdb_keymap -url2did $url2did_keymap -indir $indir -outdir $outdir"

# ���ϤȤʤ��Ǥ�ɸ��ե����ޥåȥǡ����� gzip ���̤���Ƥ���
command="$command -z"

# ���ϤȤʤ��Ǥ�ɸ��ե����ޥåȥǡ���(��󥯾�����)�� gzip ���̤���
command="$command -compress"





##########################################################
#                     ��������
##########################################################

mkdir $workspace 2> /dev/null
cd $workspace

# ɸ��ե����ޥåȥǡ����Υ��ԡ�
scp -r $fp ./

# �����󥯤˴ط�����ǡ����Υ��ԡ�
for f in `grep $id.inlink $cdblist`
do
    scp $f ./
done

# # �����ȥ�󥯤˴ط�����ǡ����Υ��ԡ�
# for f in `grep $id.outlink $cdblist`
# do
#     scp $f ./
# done



echo tar xzf $indir.tgz
tar xzf $indir.tgz
rm $indir.tgz


# �����߽����μ¹�
echo $command
$command



# �����
rm -r $id.inlink*
# rm -r $id.outlink*
rm -r $indir


mv $outdir $indir
outdir=$indir
outf=$outdir.tgz
echo tar czf $outdir.tgz $outdir
tar czf $outf $outdir
rm -r $outdir

# ���������ǡ����ΰ�ư
mkdir finish 2> /dev/null
mv $outf finish/
