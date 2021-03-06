#!/bin/bash

EXIT_WARNING=1
WARNING_TRESHOLD=95

let total_alloc=`sudo /usr/bin/xe sr-param-get uuid=84ca4fbd-f150-1f62-c9e4-ee4a656558d5 param-name=physical-utilisation`
let total_bytes=`sudo /usr/bin/xe sr-param-get uuid=84ca4fbd-f150-1f62-c9e4-ee4a656558d5 param-name=physical-size`

let factor=1073741824

total_alloc_Gb=`expr $total_alloc \/ $factor`
total_bytes_Gb=`expr $total_bytes \/ $factor`
let free_space=`expr $total_bytes_Gb - $total_alloc_Gb`
total_percentage=`expr 100 \* $total_alloc_Gb  \/ $total_bytes_Gb`
#echo $free_space
#echo $total_percentage
if [ $total_percentage -ge "90" ] ; then
	echo "CRITICAL: Disc al $total_percentage%"
        EXIT=2
else 
	if [ $total_percentage -ge "80" ] ; then
		echo "WARNING: Disc al $total_percentage"
		EXIT=1
	else
		echo "OK: Disc al $total_percentage%"
		EXIT=0
	fi	
fi

