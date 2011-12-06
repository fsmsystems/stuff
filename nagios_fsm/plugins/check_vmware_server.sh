#!/bin/bash
#
# Checks vmware server settings
# Based on RedHat Linux 5.2, should work for all RHEL/Fedora/Debian Linuxes with kernel 2.6
#
# Version 1.0
# Written by Rob Moss, coding@mossko.com
# 2008-11-11
#
# Checks ALL running VMs
# This script assumes the following
# - All VMs should be running
# - All VMs have been set up correctly
#
# Could be modified to
# - Check individual VMs from commandline
#

# Load in standard nagios utils
. /usr/lib/nagios/plugins/utils.sh
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

# executables
find=/usr/bin/find
wc=/usr/bin/wc
awk=/usr/bin/awk
grep=/bin/grep
date=/bin/date
ls=/bin/ls
sed=/bin/sed
vmwarecmd=/usr/bin/vmware-cmd
pmap=/usr/bin/pmap

# thresholds
uptime_min=3600		# 1 hour, in seconds

# runtime variables
VMNUM=0			# Number of VMs
VMCONF=""		# config file
VMSTATE=""		# on or off
VMUPTIME=""		# UPTIME / 60 / 60 / 24 = days
VMCONFPATH=""		# VM config path from config file
VMCONFMEM=""		# VM Memory size
VMRUNMEM=""		# How much memory the VM is using now


# Check if 0 VMs are running
VMNUM=`$vmwarecmd -l | $wc -l`
if [ $VMNUM -eq 0 ]; then
	echo "CRITICAL - No VMs are running!"
	exit 2
fi


# Each VM config may have spaces.  The IFS (Input File Separator) is required as a CR
IFS="
"
# Main loop
for VMCONF in `$vmwarecmd -l`
do
#	echo "Checking [$VMCONF]"

	# STATE Check
	VMSTATE=`$vmwarecmd "$VMCONF" getstate | $awk '{print $3}'`
#	echo "State = $VMSTATE"
	if [ "x$VMSTATE" == "xoff" ]; then
		echo "CRITICAL - $VMCONF is not running!"
		exit 2
	fi

	# UPTIME Check
	# vmware-cmd /path/vm.vmx getuptime
	# getuptime() = 3473695
	VMUPTIME=`$vmwarecmd $VMCONF getuptime | $awk '{print $3}'`
#	echo "Uptime = $VMUPTIME"
	if [ $VMUPTIME -lt $uptime_min ]; then
		echo "WARNING - $VMCONF has only been running for $VMUPTIME seconds! Did someone restart it?"
		exit 1
	fi


	# CONFIGPATH Check
	VMCONFPATH=`$vmwarecmd $VMCONF getconfigfile | $sed 's/getconfigfile() = //g;'`
#	echo "VMCONFPATH = $VMCONFPATH"
	if [ "x$VMCONF" != "x$VMCONFPATH" ]; then
		echo "WARNING - $VMCONF shows the wrong config file $VMCONFPATH"
		exit 1
	fi

	# vmware-cmd /path/vm.vmx getpid
	#VMPID=`$vmwarecmd $VMCONF getpid | $awk '{print $3}'`
	VMPID=`ps auxww |grep $VMCONF|egrep -v grep| $awk '{print $2}'`
#	echo "VMPID = [$VMPID]"

	# MEMORY Check
	# Check if VM is using much more memory than is configured
	# getconfig memsize
	VMCONFMEM=`$vmwarecmd $VMCONF getconfig memsize | $awk '{print $3}'`
#	echo "VMCONFMEM = [$VMCONFMEM]"


	# pmap is perfect but only allows showing processes for current user, uness root
	# We are not root, so must check out alternatives
#
#	VMRUNMEM=`$pmap -x $VMPID |  grep 'total kB' | $awk '{print $3}'`
#	VMRUNMEM=$(( $VMRUNMEM / 1000 ))
##	echo "VMRUNMEM = [$VMRUNMEM]"

	# Using /proc/<pid>/status
	# Diving in to /proc may not be 100% compatable with different kernels.
	VMRUNMEM=`grep 'VmSize:' /proc/$VMPID/status | $awk '{print $2}'`
	VMRUNMEM=$(( $VMRUNMEM / 1000 ))

	# Allow 1.5x the configured memory to be allowed in real memory.
	# Otherwise there may be a memory leak, or something is wrong.
	VMCONFMEMMAX=$(($VMCONFMEM / 2 + $VMCONFMEM))
#	echo "VMCONFMEMMAX = [$VMCONFMEMMAX]"

	if [ $VMRUNMEM -gt $VMCONFMEMMAX ]; then
		echo "CRITIAL - VM $VMCONF is using $VMRUNMEM: above the maximum allowed of $VMCONFMEMMAX"
		exit 2
	fi

	msg="$msg[$VMCONF]: running, PID $VMPID, using $VMRUNMEM MBytes of RAM. "

done


echo "OK - $msg"
exit 0
