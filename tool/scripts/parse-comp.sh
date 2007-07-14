#!/bin/sh

# $Id$

usage() {
    echo "Usage: $0 jmnfile"
    exit 1
}

if [ ! -f "$1" ]; then
    usage
fi

base_dir=`dirname $0`

# please change these variables
ScriptsDIR=$base_dir
PERL=perl
ParseCMD=knp
KNParg="-dpnd -tab -postprocess"
RCarg=

jmn=$1
prejmn=$jmn
n=0

head=`expr $jmn : "\(.*\)\.jmn"`

if [ -z "$head" ]; then
    usage
fi

: > $head.knp
: > $head.log

while true
do
    $ParseCMD $KNParg $RCarg < $prejmn > $head.knp$n 2> $head.log$n
    $PERL $ScriptsDIR/check-article.perl --data $head.rst$n $prejmn $head.knp$n > /dev/null
    cat $head.knp$n >> $head.knp
    cat $head.log$n >> $head.log
    rm -f $head.knp$n
    rm -f $head.log$n

    # non-existent or size == 0
    if [ ! -s $head.rst$n ]; then
	echo "succeeded."
	rm -f $head.rst*
	exit 0
    else
	size_pre=`wc -c $prejmn`
	size_pre=`expr "$size_pre" : "\(.*\) $prejmn"`
	size_now=`wc -c $head.rst$n`
	size_now=`expr "$size_now" : "\(.*\) $head.rst$n"`

	# no change!: error
	if [ $size_pre -eq $size_now ]; then
	    echo -n "error occurred: cutting the first sentence ... "
	    $PERL $ScriptsDIR/cut-one-sentence.perl $prejmn > $head.rst$n
	    echo "done."
	fi
    fi

    if [ $n -ne 0 ]; then
	rm -f $prejmn
    fi

    prejmn=$head.rst$n
    n=`expr $n + 1`
done
