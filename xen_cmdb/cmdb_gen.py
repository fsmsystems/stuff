#!/usr/bin/env python

import sys
import csv
import os
import XenAPI
from pprint import pprint


def read_ip_address(vm):
        vgm = session.xenapi.VM.get_guest_metrics(vm)
        try:
            os = session.xenapi.VM_guest_metrics.get_networks(vgm)
            if "0/ip" in os.keys():
                return os["0/ip"]
            return None
        except:
            return None

def main(sx):
    fileObj = open("test.txt","w")
    vms = sx.VM.get_all()
    real_vms = [ x for x in vms if not sx.VM.get_is_a_template(x) and not  sx.VM.get_is_control_domain(x)]
    for x in real_vms:
    	name_label = sx.VM.get_name_label(x) 
	vm_ip_addr = read_ip_address(x)
	output=name_label.upper()+',ActiuRevisat,CastelldefelsIN3,'+str(vm_ip_addr) +'\n' 
	fileObj.write(output)
    fileObj.close()

if __name__ == "__main__":
    if len(sys.argv) <> 4:
        print "Usage:"
        print sys.argv[0], " <url> <username> <password>"
        sys.exit(1)
    url = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]

#    print "List of non-template VMs on %s" % url
    session = XenAPI.Session(url)
    session.login_with_password(username, password)
    main(session.xenapi)
    session.logout()
