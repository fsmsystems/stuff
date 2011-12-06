#!/bin/bash

fault=`sudo /sbin/multipath -ll | grep faulty | wc -l`
if [ $fault -gt 0 ]; then
	echo "Algun cami cap a CX4120 caigut!!!!"
	exit 1
else	
	echo "Tots els camins OK"	
	exit 0
fi
