# Insert VMLIST to initializate the XAPI Backup CustomField
VMLIST=""

for vm in $VMLIST; do
	uuid=$(xe vm-list name-label=$vm --minimal)
	xe vm-param-set uuid=$uuid other-config:XenCenter.CustomFields.Backup='s'
done
