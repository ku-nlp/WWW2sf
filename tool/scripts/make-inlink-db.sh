#!/bin/sh

# $Id$

# �����󥯤�-���١��ǡ�cdb�ˤ�������륹����ץ�
#
# Usage:
# sh make-inlink-db.sh file1 file2 ...
#
# ���ϡ������󥯤��Ƥ���ʸ��ID�˽��äƥ����Ȥ��줿��󥯾���
# ���ϡ�hdir.inlinks.cdb��cdb������


# �� �Ķ��ˤ��碌�ưʲ����ѿ����ѹ�
utildir=$HOME/cvs/Utils/perl
tooldir=$HOME/cvs/WWW2sf/tool
perldir=$tooldir/perl
scriptdir=$tooldir/scripts

for file in $@
do
     perl -I $utildir -I $perldir $scriptdir/make-anchor-db.perl -inlink -file $file
done
