#!/bin/sh

# x????以下のファイルの番号をつめる

usage() {
    echo "$0 x????"
    exit 1
}

if [ ! -d "$1" ]; then
    usage
fi

dir=$1
dir_n=`expr $dir : "x\(.*\)"`

count=0
for f in $dir/*
do
    old_n=`expr $f : "$dir/$dir_n\([0-9]*\)"`
    ext=`expr $f : "$dir/$dir_n$old_n\.\([^\.]*\)$"`
    if [ -n "$old_n" ]; then
	new_n=`printf %04d $count`
	if [ "$old_n" = "$new_n" ]; then
	    echo "$f -> $dir/$dir_n$new_n.$ext (unchanged)"
	else
	    echo "$f -> $dir/$dir_n$new_n.$ext"
	    mv $f $dir/$dir_n$new_n.$ext
	fi
	count=`expr $count + 1`
    fi
done
