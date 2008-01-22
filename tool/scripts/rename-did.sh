#!/bin/sh

# 標準フォーマットのIDをつめるスクリプト


# ★ 以下の値を変更すること
# ★ 出力先のディレクトリ
distdir=/tmp
# ★ 作業ディレクトリ
workdir=/tmp



# ★ ディレクトリの開始番号オフセット
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
