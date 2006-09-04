#!/bin/sh

# x????以下のファイルの番号をつめる
# x????にないh????のファイルを削除し、番号をつめる

usage() {
    echo "Usage: $0 h???? x????"
    exit 1
}

if [ ! -d "$1" -o ! -d "$2" ]; then
    usage
fi

hdir=$1
xdir=$2
base=`basename $xdir`
dir_n=`expr $base : "x\(.*\)"`

hext=html
xext=xml

count=0
for f in $xdir/*
do
    old_n=`expr $f : "$xdir/$dir_n\([0-9]*\)"`
    # xext=`expr $f : "$xdir/$dir_n$old_n\.\([^\.]*\)$"`
    if [ -n "$old_n" ]; then
	new_n=`printf %04d $count`
	if [ "$old_n" = "$new_n" ]; then
	    echo "$f -> $xdir/$dir_n$new_n.$xext (unchanged)"
	else
	    echo "$f -> $xdir/$dir_n$new_n.$xext, $hdir/$dir_n$old_n.$hext -> $hdir/$dir_n$new_n.$hext"
	    mv $f $xdir/$dir_n$new_n.$xext
	    mv -f $hdir/$dir_n$old_n.$hext $hdir/$dir_n$new_n.$hext
	fi
	count=`expr $count + 1`
    fi
done

# h????以下の残りのファイルを削除
rm_flag=0
for f in $hdir/*
do
    if [ $rm_flag -eq 1 ]; then
	echo "removed $f"
	rm -f $f
    else
	n=`expr $f : "$hdir/$dir_n\([0-9]*\)"`
	if [ -n "$n" ]; then
	    raw_n=`expr $n : "0*\(.*\)"`
	    if [ -z "$raw_n" ]; then
		raw_n=0
	    fi

	    if [ $raw_n -ge $count ]; then
		echo "removed $hdir/$dir_n$n.$hext"
		rm -f $hdir/$dir_n$n.$hext
		rm_flag=1
	    fi
	fi
    fi
done
