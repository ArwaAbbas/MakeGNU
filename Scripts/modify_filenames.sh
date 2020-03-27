#!/bin/bash
names=$1
dir=$2

for i in `cat ../TestData/genome_list.txt`;do
	echo $i
	#cp $2${i}*.fna $2${i}.fna
done
