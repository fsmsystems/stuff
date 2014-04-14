#!/bin/bash
WORKSPACE=/backup/scripts
. $WORKSPACE/bin/backup2.cfg


rm -f $BACKUP/vms/*

# Redireccionar salida y errores
exec > $WORKSPACE/log/backup3.log 2>&1
echo "--------------------------------------------------"
echo "Beginning backup of virtual machines at $(date)"
echo "--------------------------------------------------"

ERR=0

#Getting VM uuid list
xe vm-list --minimal | sed s/','/'\n'/g > vm_list

#Search CustomField.Backup
for uuid in `cat vm_list` ; do
        backup_vm=`xe vm-param-get uuid=$uuid param-name=other-config param-key=XenCenter.CustomFields.Backup`
        if [ "$backup_vm" == "s" ] ; then
                 vm_name=`xe vm-list uuid=$uuid params=name-label | cut -f2 -d":" | cut -f2 -d" "`
                 echo $vm_name ' - Marked for backup'

#                uuid=$(xe vm-list params=uuid name-label=$vm_name --minimal)
                 echo "Beginning backup of $vm_name  @  $(date)"

                 echo "Taking a snapshot of: $vm_name"
                 snapshotUUID=$(xe vm-snapshot vm=$uuid new-name-label=backup_vm)
                 echo "Snapshot: $vm_name created"

                 echo "Turning $vm_name snapshot into a vm"
                 xe template-param-set is-a-template=false ha-always-run=false uuid=$snapshotUUID

                 echo "Exporting: $vm_name"
                 exportstring=$BACKUP_DIR/$vm_name.xva-$(date +%d%m%y)
                 xe vm-export vm=$snapshotUUID filename=$exportstring compress=true

                 if [ $? -eq 0 ] ; then
                        echo "Sin problemas"
                 else
                        ERR=1
                 fi

                 echo "Done, Removing snapshot: $vm_name"
                 xe vm-uninstall uuid=$snapshotUUID force=true

                 echo "Completed backup of $vm_name  @  $(date)"
                 echo "--------------------------------------------------"
                 echo

        else
                echo 'no hay backup'
        fi
done

echo "Backup completed at $(date)"
if [ $ERR -eq 0 ]
then
  ASUNTO="OK Backup VM XENBOX - $(uname -n)"
else
  ASUNTO="ERROR Backup VM XENBOX - $(uname -n)"
fi

echo $ASUNTO
echo Finalizamos - $(date)
LOGPROC=`/usr/bin/tail -100 /backup/scripts/log/backup3.log`

cat /backup/scripts/log/backup3.log | mail -s "$ASUNTO" maail@mail.com 

