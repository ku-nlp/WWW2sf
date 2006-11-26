#!/bin/sh

# $Id$

usage() {
    echo "$0 input.html"
    exit 1
}

if [ ! -f "$1" ]; then
    usage
fi

head=`basename $1 .html`
tmpfile=$head.$$

perl -I perl scripts/extract-sentences.perl --checkzyoshi --checkjapanese --checkencoding $1 | perl -I perl scripts/sentence-filter.perl > $tmpfile
perl -I perl scripts/format-www.perl $tmpfile
rm -f $tmpfile
