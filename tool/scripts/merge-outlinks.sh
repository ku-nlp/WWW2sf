#!/bin/sh

# $Id$

# sort���ޥ�ɤ����Ѥ���temp�ΰ�
tmpdir=/data2/$USER/inlink-gene-tmp.$$
tmpf=$tmpdir/outlinks.$$
outf=$tmpdir/`hostname --long | cut -f 1 -d .`.inlinks


# �����ȥ�󥯥ǡ���(.outlinks)������ǥ��쥯�ȥ�
datadir=$1
# �ޡ���������󥯥ǡ�������Ϥ�����
# distdir=$2

# tmp�ǥ��쥯�ȥ������
mkdir -p $tmpdir

cat $datadir/*outlinks > $tmpf
sort -T $tmpdir -n +2 $tmpf > $outf
mv $outf $datadir/

# gzip $outf
# scp $outf.gz $distdir

rm -r $tmpdir
