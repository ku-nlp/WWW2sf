#!/bin/sh

usage () {
    echo "$0 hoge.txt.gz"
    exit 1
}

file=$1
com=$HOME/scripts/split-rawstring-by-length-with-error-handling.perl
dir=`pwd`

if [ ! -f "$file" ]; then
    usage
fi

filebase=`basename $file`
base=`echo $filebase | cut -f1 -d.`

if [ -z "$base" ]; then
    usage
fi

if [ ! -d $base ]; then
    mkdir $base
fi

cd $base

if [ ! -f $file ]; then
    file="$dir/$file"
fi

gzip -dc $file | $com

for i in *
do
    if [ -f "$i" ]; then
	LANG=C sort -T . $i | gzip -c > $i.gz
	rm -f $i
    fi
done
