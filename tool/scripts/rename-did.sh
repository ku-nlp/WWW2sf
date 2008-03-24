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

for d in `cat $workdir/find.files.$$ | awk '{printf("%05d\n", ('$offset' + NR - 1)/ 10000)}' | sort -u`
do
   mkdir $distdir/h$d
   mkdir $distdir/x$d
   mkdir $distdir/u$d
done

find $@ -type f | sort | perl -pe 's/\.[^\.]+$/\n/' | perl -pe 's/^x//' | awk '{printf("%s %05d/%09d\n", $1, ('$offset' + NR - 1)/ 10000, NR -1 + '$offset')}' > ids.map.$$

cat ids.map.$$ | awk '{printf("mv h%s.html '$distdir'/h%s.html\n", $1, $2)}' > move.h.$$
cat ids.map.$$ | awk '{printf("mv x%s.xml  '$distdir'/x%s.xml\n",  $1, $2)}' > move.x.$$
cat ids.map.$$ | awk '{printf("mv h%s.*utf8.html '$distdir'/u%s.utf8.html\n", $1, $2)}' > move.u.$$

sh move.h.$$
sh move.x.$$
sh move.u.$$
rm move.h.$$
rm move.x.$$
rm move.u.$$

rm ids.map.$$
rm $workdir/find.files.$$
