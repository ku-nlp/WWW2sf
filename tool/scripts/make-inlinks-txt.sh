#!/bin/sh

# $Id$

# �����󥯤��Ƥ���ʸ��ID�˽��äƥ�󥯾���ʥƥ����ȥǡ����ˤ�ޡ�������h00000.inlinks �ե�������������

outlinkdir=$1
outdir=$2

outf=$outdir/outlinks.merged.acc.inlink-dids.gz
perldir=$HOME/cvs/WWW2sf/tool/scripts
inlink_text_dir=$outdir/inlink-texts

GZIPPED=-z


mkdir -p $outdir 2> /dev/null
mkdir -p $inlink_text_dir 2> /dev/null

perl $perldir/merge-linkdata.perl -n 2 $GZIPPED $outlinkdir/* | gzip > $outf
perl $perldir/split-inlink-text.perl -compress -file $outf -outdir $inlink_text_dir
