#!/bin/bash

names=$1
dir=$2

for i in `cat $names`; do
	echo $i
	mv $2${i}*.fna $2${i}.fna
done
