#!/usr/bin/env python
import sys, time
import XenAPI 

def read_os_name(vm):
        vgm = session.xenapi.VM.get_guest_metrics(vm)
        try:
            os = session.xenapi.VM_guest_metrics.get_os_version(vgm)
            if "name" in os.keys():
                return str(os["name"].encode('utf-8'))
            return None
        except:
            return None

def table_intro():
	print '<div id="middle">'

	
def main(session,hosts):
   xen_icon='<IMG SRC="/img/server.png" NAME="1" ALIGN=LEFT WIDTH=15 HEIGHT=15 BORDER=0>'
   b_table_format='<P STYLE="margin-left: 2cm; margin-bottom: 0cm"><b>'
   blau_font='<FONT COLOR="#000080">' 
   blau_font2='<FONT COLOR="#004586">' 
   

   #Pillamos el los atributos pool
   pool=session.xenapi.pool.get_all()[0]

   #Cambiamos el ID por el nombre Human	y lo pintamos way
   pool_name=session.xenapi.pool.get_name_label(pool)
   pool_desc=session.xenapi.pool.get_name_description(pool)
   table_intro()
   print '<div id="pool">' , xen_icon , pool_name,' ',pool_desc, '</div>'
   #Entro en el pool y saco los servidores dom0 que hay
   vms_in_pool=0
   hosts.append(len(session.xenapi.host.get_all()))
   for s in session.xenapi.host.get_all():
	#hrecord = session.xenapi.host.get_record(s)
        #host_metrics=session.xenapi.host.get_record(s)
    	servers=session.xenapi.host.get_name_label(s)
	print '<div id="host">',servers ,'</div>'
	#Vemos que vms estan en este servidor y las exploramos
	vms_in_host=session.xenapi.host.get_resident_VMs(s)
	vms_in_server=0
	server_used_mem=0
    	for vm in vms_in_host:
		if not  session.xenapi.VM.get_is_a_template(vm) and not  session.xenapi.VM.get_is_control_domain(vm):
			nom=session.xenapi.VM.get_name_label(vm)
			desc=session.xenapi.VM.get_name_description(vm)
			os=read_os_name(vm) 
			cpu=session.xenapi.VM.get_VCPUs_max(vm)
			record = session.xenapi.VM.get_record(vm) 
			vm_metrics = record["metrics"]
			vm_metric = session.xenapi.VM_metrics.get_record(vm_metrics) 
			memory = round (float(vm_metric ["memory_actual"])/1024000000,3) 
		
			print '<div id="vm">', blau_font , "      ",nom, '</FONT>'," -> ",blau_font2,os,'</FONT>', " --> ", "VCPUs: ", cpu,"Mem: ",memory,"->" , desc.encode('utf-8'),"<br></div>"
   			vms_in_server+= 1
			server_used_mem+=memory
	print '<div id="vm">    -> Domain0 Used Mem:',server_used_mem ,'</div>'		
	#print vms_in_server , ": Virtual Machines running on this server"
	vms_in_pool+=vms_in_server
	
   print '<div id="poolvms">' ,vms_in_pool, "Virtual Machines running on this pool </div>" 
   print"</div>"

   #Closing xenapi session
   session.xenapi.session.logout()
   return vms_in_pool

def html_intro():
	print "<HTML>"
	print "<HEAD>"
	print 	"<META HTTP-EQUIV='CONTENT-TYPE' CONTENT='text/html; charset=utf-8'>"
	print '<link rel="stylesheet" href="xen.css">'
	print '<title>Virtual UOC - Universitat Oberta de Catalunya</title>'
	print '<link rel="shortcut icon" type="image/x-icon" href="http://www.uoc.edu/favicon.ico">'
	print	"</HEAD>"
	print	"<BODY>"
	print '<div id="top_logo"><a href="http://www.uoc.edu/portal/catala/index.html" target="_self"><img src="/img/ca_home.gif" alt="Anar a la pgina principal"><input class="img" src="img/main-banner-inner.gif" width="450" height="49" alt="Entra" tabindex="12" type="image"</div></a></div>'
	print "<FONT FACE='Verdana, sans-serif'<FONT SIZE=2>"

def html_eof():
	print "<P><BR><BR>"
	print "</P>"
	print "</BODY>"
	print "</HTML>"


if __name__ == "__main__":
	html_intro()
	totalvm=0
	total_hosts=[]
	servers = {'server.domain.es':'passwdx' }
	for s,p in servers.iteritems():
			username = 'root'
                	url = "http://"+ s 
               	 	session = XenAPI.Session(url)
                	session.xenapi.login_with_password(username,p)
               
			try:
                       		totalvm+=main(session,total_hosts)
               		except Exception, e:
                       		print str(e)
                       		raise
	print '<div id="stats"> STATISTICS:'
	print '<div id="allvms">', totalvm, "Virtual Machines"
	print '<div id="allvms">',sum(total_hosts) , "Physical Machines"

	html_eof()
