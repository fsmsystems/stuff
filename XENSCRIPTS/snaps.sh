#!/bin/bash

SNAP_LIST=$(xe snapshot-list --minimal| sed "s/\\,/\\ /g")
for SNAP in  $SNAP_LIST; do
	DESC=$(xe snapshot-list uuid=$SNAP params=name-label --minimal)
	echo snapshot = $SNAP - $DESC
	SNAP_OF=$(xe snapshot-list uuid=$SNAP params=snapshot-of --minimal)
	NAME_LABEL=$(xe vm-list uuid=$SNAP_OF params=name-label --minimal)
	echo -en ' + [ \E[0;32m'"\033[1msnapshot of = $SNAP_OF \033[0m] - VM.name-label = $NAME_LABEL\n"
	
done
