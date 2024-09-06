#!/bin/bash

# Check if a filename is provided
if [ "$#" -ne 1 ]; then
	echo "Usage: $0 executable"
	exit 1
fi

filename=$1.log
binname=$1
binary=./build/$1
MONITOR_DIR=/home/kleftog/sidecfi/pt_monitor 

if [ ! -f "$binary" ]; then
	echo "Binary file $binary does not exist."
	exit 1
fi

if [ ! -f "$filename" ]; then
	echo "Filename file $filename does not exist."
	exit 1
fi

rm $MONITOR_DIR/sidecfi.$binname.typemap
declare -A funcMap

# Process the file
while IFS= read -r line
do
	# Check if the line starts with "***create func"
	if [[ $line == ***create\ func* ]]; then
		# Extract the symbol, hashed_typeID
		read funcName funcNumber <<< $(echo $line | sed -n 's/.*create func md \([^ ]*\) .* (\([^)]*\))/\1 \2/p')
		symbolAddress=$(nm -a "$binary" | awk -v key="$funcName" '$3 == key {print $1}')
		if [[ $symbolAddress != "" ]]; then
			echo "$funcName  $funcNumber  $symbolAddress" >> $MONITOR_DIR/sidecfi.$binname.typemap
		fi
	elif [[ $line == ***create\ vtable* ]]; then
		# Extract the symbol, hashed_typeID
		read funcName funcNumber <<< $(echo $line | sed -n 's/.*create vtable md \([^ ]*\) .* (\([^)]*\))/\1 \2/p')
		symbolAddress=$(nm -a "$binary" | awk -v key="$funcName" '$3 == key {print $1}')
		if [[ $symbolAddress != "" ]]; then
			echo "$funcName  $funcNumber  $symbolAddress" >> $MONITOR_DIR/sidecfi.$binname.typemap
		fi
	fi
done < "$filename"

