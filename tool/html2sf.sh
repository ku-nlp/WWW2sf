#!/bin/sh

# $Id$

usage() {
    echo "$0 input.html"
    exit 1
}

if [ ! -f "$1" ]; then
    usage
fi

head=`expr $1 : "\(.*\)\.[^\.]*$"`

perl -I perl scripts/extract-sentences.perl --xml $1 | perl -I perl scripts/sentence-filter-xml.perl | perl -I perl scripts/format-www-xml.perl | perl -I perl scripts/add-knp-result.perl

