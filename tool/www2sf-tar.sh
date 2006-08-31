#!/usr/local/bin/zsh

# www2sf.shを走らせるシェルスクリプト
# 解析終了後、圧縮してmvする
# ./www2sf-tar.sh tsubame00 h0001 x0001

block=$1
h=$2
x=$3

if [ ! -d /data/shibate/$block/ ] ; then
    mkdir -p /data/shibate/$block/
fi

# copy
cp /home/shibate/${block}h/$h.tar.gz /data/shibate/$block/

cd /data/shibate/$block/

tar zxvf $h.tar.gz

cd /home/shibate/work/WWW2sf/tool/

# 変換
./www2sf.sh -j /data/shibate/$block/$h /data/shibate/$block/$x 

cd /data/shibate/$block/

tar zcvf $x.tar.gz ./$x

mv $x.tar.gz /home/shibate/${block}x/

rm -f /data/shibate/$block/$h.tar.gz
rm -fr /data/shibate/$block/$h
rm -fr /data/shibate/$block/$x
