#!/bin/sh

# 各種ファイルからHTMLファイルを作成する

# $Id$

base_dir=`dirname $0`
source $HOME/.zshrc

option=
tmpdir=.
fnum=10000
flist='none'
while getopts hiT:zN:F: OPT
do
    case $OPT in
	h)  option="-kuhp $option"
	    ;;
	i)  option="-ipsj $option"
	    ;;
	z)  option="-z $option"
	    ;;
	T)  tmpdir=$OPTARG
	    option="-outdir $tmpdir/htmls $option"
	    ;;
	N)  fnum=$OPTARG
	    ;;
	F)  flist=$OPTARG
	    ;;
    esac
done
shift `expr $OPTIND - 1`

mkdir -p $tmpdir 2> /dev/null
perl -I$base_dir/../perl $base_dir/make-htmlfile.perl $option $@

find $tmpdir/htmls -type f | awk '{printf "mv %s h%04d\n", $1, int(NR/'$fnum')}' > $tmpdir/mv.sh

cd $tmpdir
cut -f 3 -d ' ' mv.sh | sort -u | xargs mkdir 2> /dev/null
sh mv.sh
rmdir htmls
for d in `cut -f 3 -d ' ' mv.sh | sort -u`
do
  tar czf $d.tgz $d
  rm -r $d
done

rm mv.sh

if [ $flist != 'none' ]; then
    for tgzf in `ls`
    do
      echo $HOSTNAME:`pwd`/$tgzf
    done > $flist
fi
