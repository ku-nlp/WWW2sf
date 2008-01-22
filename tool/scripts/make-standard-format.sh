#!/bin/sh

# �ǥ��쥯�ȥ����HTMLʸ���ɸ��ե����ޥåȤ��Ѵ����륹����ץ�

# ���ʲ����ѿ����ͤ��ѹ����뤳��
workspace=/data/home/skeiji/mksf_test
scriptdir=/share19/work/skeiji/test/WWW2sf/tool



fp=$1;
fname=`basename $fp`
fid=`echo $fname | cut -f 2 -d 'h'`

hdir=h$fid
xdir=x$fid

if [ ! -e $workspace ]; then
    mkdir $workspace
fi

cd $workspace
echo cp -r $fp ./
cp -r $fp ./

echo mkdir $workspace/$xdir
mkdir $workspace/$xdir

echo sh $scriptdir/www2sf.sh -k $hdir $xdir
sh $scriptdir/www2sf.sh -k $hdir $xdir

echo rm -r $hdir
rm -r $hdir

cd $xdir
ls | xargs gzip
cd ..

echo tar czf $xdir.tgz $xdir
tar czf $xdir.tgz $xdir

echo rm -r $xdir
rm -r $xdir
