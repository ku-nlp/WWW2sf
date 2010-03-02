#!/bin/sh

# parse English sentences using a POS tagger and a dependency parser

TMPDir=/data/kawahara/parse-english-$$
JdkDir=$HOME/share/tool/jdk1.6.0_17
TaggerDir=$HOME/share/tool/postagger-1.0
ParserDir=$HOME/share/tool/malt-1.3.1
ModelFile=$HOME/share/tool/malt-1.3.1/engmalt.mco
OrigDir=`pwd`
ScriptsDir=`dirname $0`
JavaHeapMem=1024m
export PATH=$JdkDir/bin:$PATH

usage() {
    echo "$0 test.txt > test.conll"
    exit 1
}

if [ -f "$OrigDir/$1" ]; then
    InputFile="$OrigDir/$1"
elif [ -f "$1" ]; then
    InputFile=$1
else
    usage
fi
InputFileName=`basename $InputFile`
ModelFileName=`basename $ModelFile`

if [ ! -d "$TMPDir" ]; then
    mkdir -p $TMPDir
    if [ ! -d "$TMPDir" ]; then
	echo "Cannot create TMPDir ($TMPDir)!"
	exit 1
    fi
fi

cd $TaggerDir
if [ ! -d "$ScriptsDir" ]; then
    ScriptsDir=$OrigDir/$ScriptsDir
    if [ ! -d "$ScriptsDir" ]; then
	echo "Cannot detect current dir!"
	exit 1
    fi
fi

grep -v '^#' $InputFile > $TMPDir/$InputFileName.$$.raw.txt
./tagger < $TMPDir/$InputFileName.$$.raw.txt 2> /dev/null | perl $ScriptsDir/tagger-out2conll.perl > $TMPDir/$InputFileName.$$.tagged.conll

cd $TMPDir

cp $ModelFile .
java -Xmx$JavaHeapMem -jar $ParserDir/malt.jar -c engmalt -m parse < $TMPDir/$InputFileName.$$.tagged.conll > $TMPDir/$InputFileName.$$.parsed.conll 2> /dev/null
perl $ScriptsDir/lemmatize-conll.perl $TMPDir/$InputFileName.$$.parsed.conll > $TMPDir/$InputFileName.$$.parsed.lem.conll
perl $ScriptsDir/add-sid-conll.perl $InputFile $TMPDir/$InputFileName.$$.parsed.lem.conll > $TMPDir/$InputFileName.$$.parsed.sid.conll
cat $TMPDir/$InputFileName.$$.parsed.sid.conll

rm -f $TMPDir/$ModelFileName $TMPDir/$InputFileName.$$.raw.txt $TMPDir/$InputFileName.$$.tagged.conll $TMPDir/$InputFileName.$$.parsed.conll $TMPDir/$InputFileName.$$.parsed.lem.conll $TMPDir/$InputFileName.$$.parsed.sid.conll
rm -rf $TMPDir
