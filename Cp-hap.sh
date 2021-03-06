#!/bin/bash

#if this script has every error, exit
set -e

SOURCE=$(dirname $0})/scripts/

usage()
{
echo '''
[Cp-hap, chloroplast genome haplotype Dection, detect chloroplast genome structural heteroplasmy using long-reads]
Usage: bash Cp-hap.sh -r reads -g chloroplastGenome.fa -o outputDir [options]
Required:
    -r      the path of long-read file in fa/fq format, can be compressed(.gz).
    -g      the path of chloroplast genome, chloroplast genome should be in fa format, not gzip. The chloroplast genome file should only have three sequences, named as 'lsc', 'ssc' and 'ir' (see testData/Epau.format.fa as an example). It does not matter which oritentation is for lsc, ssc and ir.
    -o      the path of outputDir.
Options:
    -t      number of threads. Default is 1.
    -x      readType, only can be map-pb (PacBio reads) or map-ont (Nanopore reads). Default is map-pb.
    -d      minimun distance of exceeding the first and last conjunctions (such as lsc/ir and ir/ssc). 1 means 1 bp, 1000 means 1 kb. Default is 1000.
'''
}

#set default
threads=1
readType='map-pb'
minDistance=1000

#regular expression, test whether some arguments are integer of float
intRe='^[0-9]+$'

#get arguments
while getopts ":hr:g:o:t:d:x:" opt
do
  case $opt in
    g)
      chloroplastGenome=$OPTARG
      if [ ! -f "$chloroplastGenome" ]
      then
          echo "ERROR: $chloroplastGenome is not a file"
          exit 1
      fi
      ;;
    r)
      reads=$OPTARG
      if [ ! -f "$reads" ]
      then
          echo "ERROR: $reads is not a file"
          exit 1
      fi
      ;;
    o)
      outputDir=$OPTARG
      ;;
    t)
      threads=$OPTARG
      if ! [[ $threads =~ $intRe ]]
      then
          echo "ERROR: threads should be an integer, $threads is not an integer"
          exit 1
      fi
      ;;
    d)
      minDistance=$OPTARG
      if ! [[ $minDistance =~ $intRe ]]
      then
          echo "ERROR: minDistance should be an integer, $minDistance is not an integer"
          exit 1
      fi
      ;;
    x)
      readType=$OPTARG
      if [ $readType != 'map-pb' -a $readType != 'map-ont' ]   
      then
          echo "ERROR: readType must be map-pb or map-ont."
          exit 1
      fi
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1

      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done


#test whether minimap2 is in the path
if ! [ -x "$(command -v minimap2)" ]
then
    echo 'ERROR: minimap2 did not be found, please add it into the path (e.g "export PATH=/path/of/script/:$PATH") before running this script'
    exit 1
fi

#check whether set the required arguments
if [ -z "$chloroplastGenome" ] || [ -z "$reads" ] || [ -z "$outputDir" ]
then
    echo "ERROR: -g or -r or -o has not been set"
    usage
    exit 1
fi

mkdir -p $outputDir

echo 'Parameters:'
echo 'ChloroplastGenome:'           $chloroplastGenome
echo 'Input long-read:'             $reads
echo 'Read type:'                   $readType
echo 'OutputDir:'                   $outputDir
echo 'Threads'                      $threads
echo 'MinDistance'                  $minDistance


#minimap2 output
minimapOutput=$outputDir/$(basename ${reads%.*}).paf
#combinations of different directions of single copy
reference=$outputDir/dir_directions_$(basename ${chloroplastGenome%.*})
#final output result
outputFile=$outputDir/result_$(basename ${reads%.*})_$(basename ${chloroplastGenome%.*})

#get combinations of different direction of single copy
echo "creating different references"
python $SOURCE/getDifferentDirectionCombine.py \
    $chloroplastGenome \
    $reference 

#run minimap2
echo "mapping long-reads to reference using minimap2"
minimap2 \
    -x $readType \
    --secondary=no \
    -t $threads \
    -L \
    -c \
    $reference \
    $reads > $minimapOutput

#check orientation ratio
echo "parsing result"
python $SOURCE/parse.py \
    $chloroplastGenome \
    $outputFile \
    $minimapOutput \
    $minDistance




