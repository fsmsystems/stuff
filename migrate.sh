#!/bin/bash
#COMMANDS & CONSTANTS
S_OR="ripolles"
S_DE="arizona"
FS_MOUNT="/migration"
S_LIST="$S_OR $S_DE"
mounted=0
DISC_OR="/dev/mapper/36006016091e02200a6a3fb4449a9e011"
DISC_DE="/dev/mapper/36006016091e02200a6a3fb4449a9e011"
#Check if LUN is mounted on any server
for i in  `echo $S_LIST` ; do 
	ssh root@$i -C "mount -l | grep $FS_MOUNT"
	if [ $? -eq "0" ] ; then
		echo "mounted in $i"
		mounted=1
		ssh root@$i -C "umount /migration"
	fi
done

if [ $mounted -eq "0" ] ; then
	echo "+$FS_MOUNT is not mounted anywhere -> OK"
	echo "=========================================="
	echo " Source Operations"
	echo "=========================================="
	echo -n "+mounting migration disc on source server: $S_OR ->"
	ssh root@$S_OR -C "mount $DISC_OR $FS_MOUNT"
 	ssh root@$S_OR -C "mount -l | grep $FS_MOUNT"	
	echo "+selected VM to migrate: $1"
	ssh root@$S_OR -C "xe vm-list name-label=$1"
	echo "+perform shutdown to VM $1"
        ssh root@$S_OR -C "xe vm-shutdown name-label=$1"
	echo "+Exporting $1 to migration disc $FS_MOUNT/$1.xva"
        ssh root@$S_OR -C "xe vm-export name-label=$1 filename=$FS_MOUNT/$1.xva"
	echo "+umounting migration disc on source server: $S_OR ->"
	ssh root@$S_OR -C "umount $FS_MOUNT" 
	ssh root@$S_OR -C "mount -l | grep $FS_MOUNT"
	echo
        echo "=========================================="
        echo " Destination Operations"
        echo "=========================================="
 	echo "+mounting migration disc on destination server: $S_DE ->"
	ssh root@$S_DE -C "mount $DISC_DE $FS_MOUNT"
	ssh root@$S_DE -C "mount -l | grep $FS_MOUNT"			
	echo "+exporting /FS_MOUNT/$1.xva to POOL"
	ssh root@$S_DE -C "xe vm-import filename=$FS_MOUNT/$1.xva"
	ssh root@$S_DE -C "umount $FS_MOUNT"
fi

ssh root@$S_OR -C "umount $FS_MOUNT"
ssh root@$S_DE -C "umount $FS_MOUNT"
