#!/usr/bin/python
# WTFPL (Do What The Fuck You Want To Public License)
#
#           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                   Version 2, December 2004
#
#Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
#
#Everyone is permitted to copy and distribute verbatim or modified
#copies of this license document, and changing it is allowed as long
#as the name is changed.
#
#           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#  TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
# 0. You just DO WHAT THE FUCK YOU WANT TO.
# python xendeployer.py llobregat root 1riudcat ubuntu test-xapi


import sys, time
import os
import XenAPI, provision


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    def disable(self):
        self.HEADER = ''
        self.OKBLUE = ''
        self.OKGREEN = ''
        self.WARNING = ''
        self.FAIL = ''
        self.ENDC = ''

def deployvm(session,template,namelabel):
	pool=session.xenapi.pool.get_all()[0]
	pool_name=session.xenapi.pool.get_name_label(pool)
	# List all the VM objects
	vms = session.xenapi.VM.get_all_records()
	templates = []
	for vm in vms:
        	record = vms[vm]
        	if record["is_a_template"]:
			if 'ubuntu' in template:
        		# Look for a ubuntu template
#		        	if record["name_label"].startswith("Ubuntu 12.04.1 LTS"):
				if record["name_label"].startswith("Ubuntu 12.04.3 LTS"):
        		        	templates.append(vm)
				if record["name_label"].startswith("Ubuntu 12.04 LTS virtua"):
					templates.append(vm)
			if 'redhat' in template:
			 # Look for a redhat template
				 if record["name_label"].startswith("Red Hat Enterprise Linux 5.5 (64-bit) PV"):
				 	templates.append(vm)
			if 'CV_Frontend_pre' in template:
				 if record["name_label"].startswith("CV_Frontend_pre"):
					templates.append(vm)
	xentemplate=templates[0]

	if xentemplate == []:
		print "I Suck"
		sys.exit(1)
	
	vm = session.xenapi.VM.clone(xentemplate, namelabel)
	print bcolors.OKGREEN +  "Deploying VM: " + bcolors.ENDC + namelabel +' >> ' +  bcolors.OKBLUE + pool_name +  bcolors.ENDC 
	print "* Choosing an SR to instaniate the VM's disks"
	default_sr = session.xenapi.pool.get_default_SR(pool)
	default_sr = session.xenapi.SR.get_record(default_sr)
	print "* Choosing SR: %s (uuid %s)" % (default_sr['name_label'], default_sr['uuid'])

	print "* Asking server to provision storage from the template specification"
    	session.xenapi.VM.provision(vm)
   	print "* Starting VM"

	#Write VDI name_label & description	
	vbds=session.xenapi.VM.get_VBDs(vm)
	vm_record = session.xenapi.VM.get_record(vm)
	for vbd in vm_record['VBDs']:
                vbd_record = session.xenapi.VBD.get_record(vbd)
                if vbd_record['type'].lower() != 'disk':
                    continue                
                vdi = vbd_record['VDI']

		vdi_name=namelabel+'-disk0'
		session.xenapi.VDI.set_name_label(vdi,vdi_name)
		session.xenapi.VDI.set_name_description(vdi,vdi_name)

    	session.xenapi.VM.start(vm, False, True)
    	print " >> VM is booting"
	#.xen.log('Destroying vm: %s' % vm_record['name_label'])
    	print "* Waiting for the installation to complete"

def main(session,template,namelabel):
	deployvm(session,template,namelabel)


if __name__ == "__main__":
    if len(sys.argv) <= 3:
        print "Usage:"
        print sys.argv[0], " <url> <username> <password> <ubuntu/windows2008/redhat/centos> <vm_name>"
        sys.exit(1)
    url = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]
    template= sys.argv[4]
    namelabel=sys.argv[5]
    #Try if is master, if not, get master IP like a boss
    try:
	session = XenAPI.Session('https://'+url)
	session.xenapi.login_with_password(username, password)
    except XenAPI.Failure, e:
      if e.details[0]=='HOST_IS_SLAVE':
        session=XenAPI.Session('https://'+e.details[1])
        session.login_with_password(username, password)
      else:
        raise
    main(session,template,namelabel)

