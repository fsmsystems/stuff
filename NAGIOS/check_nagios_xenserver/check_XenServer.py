#!/usr/bin/python
#http://community.citrix.com/display/xs/A+pool+checking+plugin+for+nagios

hostname, username, password = "server", "root", "xxxx"
 
#usual boilerplate login

import XenAPI,sys
try:
	session=XenAPI.Session('https://'+hostname)
	session.login_with_password(username, password)
except XenAPI.Failure, e:
    if e.details[0]=='HOST_IS_SLAVE':
        session=XenAPI.Session('https://'+e.details[1])
        session.login_with_password(username, password)
    else:
        raise 
sx=session.xenapi
hosts=sx.host.get_all()
hosts_with_status=[(sx.host.get_name_label(x),sx.host_metrics.get_live( sx.host.get_metrics(x) )) for x in hosts]
live_hosts=[name for (name,status) in hosts_with_status if (status==True)]
dead_hosts=[name for (name,status) in hosts_with_status if not (status==True)]

hosts_total=len(live_hosts)+len(dead_hosts)
hosts_min=hosts_total-1

if len(live_hosts)< hosts_min:
        exitcode=2
        print "CRITICAL " + str(len(dead_hosts)) + " caigut/s " + str(dead_hosts) + " sobrepassat el num de hosts minim n+1=",hosts_min
else:
        exitcode=0
        print str(len(live_hosts)) + " Doms0 Actius", live_hosts, str(len(dead_hosts)) + " Dom0 Morts", dead_hosts
sys.exit(exitcode)

