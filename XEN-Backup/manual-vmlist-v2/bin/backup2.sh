#!/bin/bash
WORKSPACE=/opt/sistemes/XEN-Backup
. $WORKSPACE/bin/backup2.cfg

mount $DEVICE $BACKUP
#rm $BACKUP/vms/* 
find /backup/vms -mtime +7 -exec rm {} \; 
 
# Redireccionar salida y errores
exec > $WORKSPACE/log/backup2.log 2>&1

echo "Beginning backup of virtual machines at $(date)"

for VMName in $VMLIST
do
  uuid=$(xe vm-list params=uuid name-label=$VMName --minimal)
  echo "Beginning backup of $VMName  @  $(date)"

  echo "Taking a snapshot of: $VMName"
  snapshotUUID=$(xe vm-snapshot vm=$uuid new-name-label=backup_vm)
  echo "Snapshot: $VMName created"

  echo "Turning $VMName snapshot into a vm"
  xe template-param-set is-a-template=false ha-always-run=false uuid=$snapshotUUID
  
  echo "Exporting: $VMName"
  exportstring=$BACKUP_DIR/$VMName.xva-$(date +%d%m%y)
  xe vm-export vm=$snapshotUUID filename=$exportstring
  
  echo "Done, Removing snapshot: $VMName"
  xe vm-uninstall uuid=$snapshotUUID force=true
  
  echo "Compressing $VMName backup"
  gzip $exportstring

  echo "Completed backup of $VMName  @  $(date)"
done

echo "Backup completed at $(date)"
