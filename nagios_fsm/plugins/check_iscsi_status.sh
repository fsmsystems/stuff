#!/bin/bash

sessions=`sudo /sbin/iscsiadm -m session | wc -l`

case $sessions in
        4)
		echo "Logging a tots els ports de les SP's OK"
                exit 0
                ;;

	[2-3])
		echo "S'ha perdut la connectivitat amb algun port de les SP's"
		exit 1
		;;

	1)
		echo "Nomes tenim connectivitat amb un port de les SP's!!!!!"
                exit 2
                ;;
esac
		
 
