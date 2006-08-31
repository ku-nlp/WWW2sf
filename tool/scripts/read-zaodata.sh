#!/usr/local/bin/zsh

# zaodataを読み込むシェルスクリプト
# ./read-zaodata.sh tsubame00 doc0000000000

block=$1
head=$2

if [ ! -d /data/shibate/$block/ ] ; then
    mkdir -p /data/shibate/$block/
fi

# copy
cp /home/shibate/$block/$head.idx /data/shibate/$block/
cp /home/shibate/$block/$head.zl /data/shibate/$block/

perl -I ../perl read-zaodata.perl -splithtml --language japanese /data/shibate/$block/$head.idx

rm -f /data/shibate/$block/$head.idx
rm -f /data/shibate/$block/$head.zl

cd /data/shibate/$block/

h=`echo $head | sed 's/^doc000000/h/'`
exe="tar zcvf $h.tar.gz ./$h"
eval $exe
mv $h.tar.gz /home/shibate/tsubame00h/
rm -fr $h

