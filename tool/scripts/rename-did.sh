#!/bin/sh

# ɸ��ե����ޥåȤ�ID��Ĥ�륹����ץ�


# �� �ʲ����ͤ��ѹ����뤳��
# �� ������Υǥ��쥯�ȥ�
distdir=/tmp
# �� ��ȥǥ��쥯�ȥ�
workdir=/tmp



# �� �ǥ��쥯�ȥ�γ����ֹ楪�ե��å�
offset=$1 ; shift

find $@ -type f | sort > $workdir/find.files.$$

for d in `cat $workdir/find.files.$$ | awk '{printf("'$distdir'/x%05d\n", ('$offset' + NR - 1)/ 10000)}' | sort -u`
do
    echo mkdir $d >> move.$$
done

find $@ -type f | sort | awk '{printf("mv %s '$distdir'/x%05d/%09d.xml.gz\n", $1, ('$offset' + NR - 1)/ 10000, NR -1 + '$offset')}' >> move.$$

sh move.$$
rm move.$$
rm $workdir/find.files.$$
