#!/bin/sh

# parse English sentences using tagger and MSTParser

JdkDir=$HOME/share/tool/jdk1.6.0_04
TaggerDir=$HOME/share/tool/postagger-1.0
ParserDir=$HOME/share/tool/mstparser
OrigDir=`pwd`
ScriptsDir=`dirname $0`

JavaHeapMem=3600m
export PATH=$JdkDir/bin:$PATH

usage() {
    echo "$0 test.txt > test.conll"
    exit 1
}

cd $TaggerDir

if [ ! -d "$ScriptsDir" ]; then
    ScriptsDir=$OrigDir/$ScriptsDir
    if [ ! -d "$ScriptsDir" ]; then
	echo "Cannot detect current dir!"
	exit 1
    fi
fi

grep -v '^#' $OrigDir/$1 > $1.$$.raw.txt
./tagger < $1.$$.raw.txt 2> /dev/null | perl $ScriptsDir/tagger-out2conll.perl > $1.$$.tagged.conll
java -classpath "$ParserDir:$ParserDir/lib/trove.jar" -Xmx$JavaHeapMem mstparser.DependencyParser test test-file:$1.$$.tagged.conll model-name:$ParserDir/model/ptb-o2.model order:2 output-file:$1.$$.parsed.conll > /dev/null
perl $ScriptsDir/lemmatize-conll.perl $1.$$.parsed.conll > $1.$$.parsed.lem.conll
perl $ScriptsDir/add-sid-conll.perl $OrigDir/$1 $1.$$.parsed.lem.conll > $1.$$.parsed.sid.conll
cat $1.$$.parsed.sid.conll

rm -f $1.$$.raw.txt $1.$$.tagged.conll $1.$$.parsed.conll $1.$$.parsed.lem.conll $1.$$.parsed.sid.conll
