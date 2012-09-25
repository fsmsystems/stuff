#!/usr/bin/env python
import sys, time
import XenAPI 
from datetime import datetime

def read_os_name(vm):
        vgm = session.xenapi.VM.get_guest_metrics(vm)
        try:
            os = session.xenapi.VM_guest_metrics.get_os_version(vgm)
            if "name" in os.keys():
                return str(os["name"].encode('utf-8'))
            return None
        except:
            return None

def get_today_month():
        today = str(datetime.today()) 
        date = today.split(" ")       
        yearspli = str(date[0]).split("-")
        year = yearspli[1]
        return year

def get_today_year():
	today = str(datetime.today()) 
        date = today.split(" ")       
        yearspli = str(date[0]).split("-")
        year = yearspli[0]
	return year

def get_mailcontact(vm):
	vmdescription=session.xenapi.VM.get_name_description(vm).split("//")
	return str(vmdescription[0].encode('utf-8'))

def get_littledescription(vm):
        vmdescription=session.xenapi.VM.get_name_description(vm).split("//")
        return str(vmdescription[1].encode('utf-8'))

def check_caducated(vm):
	nom=session.xenapi.VM.get_name_label(vm)
        record = session.xenapi.VM.get_record(vm) 
        other_config = session.xenapi.VM.get_other_config(vm)
        vmdate=other_config['XenCenter.CustomFields.Caduca']                
	vmdatesplited=vmdate.split("/")
	if vmdatesplited[2] < get_today_year():
		print  nom.upper() + ' : '+ vmdate + " SUPER CADUCADA"
	if vmdatesplited[2] == get_today_year():
		if get_today_month() >= vmdatesplited[1]:
			print  nom.upper() + ' : '+ vmdate + " CADUCADA" +' : '+ get_mailcontact(vm) + ' -> ' + get_littledescription(vm)
			#print  nom.upper() + ' : CADUCADA ' +' : '+ get_mailcontact(vm) + ' -> ' + get_littledescription(vm)

def main(session):
	hosts=[]
   	hosts.append(len(session.xenapi.host.get_all()))
   	for s in session.xenapi.host.get_all():
    		servers=session.xenapi.host.get_name_label(s)
		#Vemos que vms estan en este servidor y las exploramos
		vms_in_host=session.xenapi.host.get_resident_VMs(s)
    		for vm in vms_in_host:
			if not  session.xenapi.VM.get_is_a_template(vm) and not  session.xenapi.VM.get_is_control_domain(vm):
				check_caducated(vm)
	#Closing xenapi session
   	session.xenapi.session.logout()

if __name__ == "__main__":
	servers = {'serverip':'passwd'}
	for s,p in servers.iteritems():
		username = 'root'
               	url = "http://"+ s 
		try:
               	 	session = XenAPI.Session(url)
                	session.xenapi.login_with_password(username,p)
                 	main(session)
	 	
		except XenAPI.Failure, e:
			if e.details[0]=='HOST_IS_SLAVE':
		        	session=XenAPI.Session('https://'+e.details[1])
        			session.login_with_password(username, p)
    			else:
        			raise 

