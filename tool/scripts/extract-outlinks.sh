#!/bin/sh

# $Id$

# �����ȥ�󥯾���ʥƥ����ȡ�cdb�ˤ�������륹����ץ�
#
# Usage:
# sh extract-outlinks.sh hdir1 hdir2 ...
#
# ���ϡ�gzip���̤��줿�����֥ڡ�����Ǽ���줿�ǥ��쥯�ȥ�
# ���ϡ�hdir.outlinks�ʥƥ����ȷ�����
#     ��hdir.outlinks.cdb��cdb������


# �Ķ��ˤ��碌�ưʲ����ѿ����ѹ�
# �����������
utildir=$HOME/cvs/Utils/perl
tooldir=$HOME/cvs/WWW2sf/tool
perldir=$tooldir/perl
scriptdir=$tooldir/scripts

# �����֥ڡ�����gzip���̤���Ƥʤ����϶�ʸ���ˤ���
GZIPPED=-z

# url����ʸ��ID���Ҥ���ǡ����١�����keymap�ե�����
dbmap=/data/home/skeiji/cdbs/url2did.cdb.keymap
# �������ޤǡ�



for hdir in $@
do
    # ��󥯾�������
    perl -I $utildir -I $perldir $scriptdir/extract-anchor.perl $GZIPPED -dir $hdir -dbmap $dbmap > $hdir.outlinks
    # cdb��
    perl -I $utildir -I $perldir $scriptdir/make-anchor-db.perl -outlink -file $hdir.outlinks
done
