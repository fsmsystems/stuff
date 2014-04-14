#!/usr/bin/python

#python novaxenvm.py vm_name ipaddr pool_name enviroment

import mechanize
import cookielib, urllib2, urllib
import sys, time
import os

import get_uuid_from_ci

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


def search_uuid(uuid):
  url='http://cmdb.domain.es:8888/ViewCIDetails.do?ciId='+uuid
  r2 = br.open(url)
  html2 = r2.read()
  out = br.response().read()
  txt = out.split('h1>')[1].split('\n')[0]
  return txt


def insert_relationship(ci_uuid,relation_ciname):
  headers = { 'User-Agent' : 'Mozilla/5.0 (Windows NT 6.1; rv:18.0) Gecko/20100101 Firefox/18.0' }
  cj = cookielib.CookieJar()
  opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))
  home = opener.open(url)

  values2 = {'j_username': 'cmdbuser', 'j_password': 'cmdbuser'}
  data = urllib.urlencode(values2)
  response = opener.open('http://cmdb.domain.es:8888/j_security_check', data)

  if relation_ciname == 'Env_VIRTUA':
        env_code="12378"
  if  relation_ciname == 'Env_PRO':
        env_code="12375"
  if  relation_ciname == 'Env_PRE':
        env_code="15995"
  if   relation_ciname == 'XEN_TEST':
        env_code="12377"
  if   relation_ciname == 'Env_TEST':
	 env_code="17551"
  if   relation_ciname =='Env_PRO_USA01':
        env_code="12434"
  if   relation_ciname =='Env_PRO_USAI02':
        env_code="19961"
  if   relation_ciname =='Env_PRO_2':
        env_code="19934"

  rel_data="submit=true&action=addRelationship&reloadChart=null&=-1&pageLength=10&pageLength=10&CINAME="+relation_ciname+"&ATTRIBUTE_4801=&ATTRIBUTE_4802=&checkbox="+env_code+"&text_ATTRIBUTE_4801_"+env_code+"=&text_ATTRIBUTE_4802_"+env_code+"=&text_ATTRIBUTE_4801_12434=&text_ATTRIBUTE_4802_12434=&text_ATTRIBUTE_4801_12378=&text_ATTRIBUTE_4802_12378=&text_ATTRIBUTE_4801_12479=&text_ATTRIBUTE_4802_12479=&text_ATTRIBUTE_4801_13211=&text_ATTRIBUTE_4802_13211=&text_ATTRIBUTE_4801_12474=&text_ATTRIBUTE_4802_12474=&text_ATTRIBUTE_4801_12376=&text_ATTRIBUTE_4802_12376=&text_ATTRIBUTE_4801_12377=&text_ATTRIBUTE_4802_12377=&ciTypeId=601&ciId="+ci_uuid+"&relationshipId=3002&viewName=RelView_3002&relationshipTypeId=314&isSWIns=false&ciTypeId2=1201"
  response2 = opener.open('http://cmdb.domain.es:8888/AddRelationshipForWS.do', rel_data)
  ciname=search_uuid(ci_uuid)
  print ' + Afegida relacio: '+ str(ciname) 
  print ' -> Esta suportat per - ' + bcolors.OKGREEN + relation_ciname + bcolors.ENDC




#validacion http
url = 'http://cmdb.domain.es:8888'
user = 'cmdbuser'
passwd = 'cmdbuser'
new_ci = sys.argv[1].upper()
manage_ip = sys.argv[2]
pool = sys.argv[3]
entorn= sys.argv[4]
estat= 'ActiuRevisat'

#parametros del mechanize
br = mechanize.Browser()
cj = cookielib.LWPCookieJar()
br.set_cookiejar(cj)
br.set_handle_equiv(True)
br.set_handle_redirect(True)
br.set_handle_referer(True)
br.set_handle_robots(False)

# Follows refresh 0 but not hangs on refresh > 0
br.set_handle_refresh(mechanize._http.HTTPRefreshProcessor(), max_time=1)

# User-Agent (this is cheating, ok?)
br.addheaders = [('User-agent', 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.1) Gecko/2008071615 Fedora/3.0.1-1.fc9 Firefox/3.0.1')]

# Open some site, let's pick a random one, the first that pops in mind:
r = br.open(url)

#Validacion cookiejar
br.select_form(nr=0)
br.form['j_username'] = user
br.form['j_password'] = passwd
br.form.action = 'http://cmdb.domain.es:8888/j_security_check'
br.submit()
url_addci='http://cmdb.domain.es:8888/AddCI.do?mode=showForm&ciTypeId=601'

#primero miramos si el ci existe y si no es asi procede
ci=get_uuid_from_ci.search_ci(new_ci)
if ci is None:
#	print 'El CI no existe, dando de alta nuevo CI'
	r2 = br.open(url_addci)
	html2 = r2.read()
	#Ponemos el site en funcion de la ubicacion fisica del ci
	if "Env_PRO" in pool:
		site='4'
	if "Env_PRO_USAI02" in pool:
		 site='5'
	if "Env_VIRTUA" in pool:
		site='4'
	if "Env_PRE" in pool:
		site='5'
	if "XEN_TEST" in pool:
	        site='5'   
	if  'Env_TEST' in pool:
		site='5'
	if "Env_PRO_USA01" in pool:
	        site='5'  
	if "Env_PRO_2" in pool:
                site='4'

	#Formulario para anadir CI
	br.select_form('AddCI')
	br.form['ciName']=new_ci
	br.form['ciSite']=site.split(',')
	br.form['CI_CIType_603_ATTRIBUTE_921']=manage_ip
	br.form['CI_CIType_603_ATTRIBUTE_918']=estat.split(',')
	br.form['CI_CIType_603_ATTRIBUTE_3901']=entorn.split(',')
	br.submit(name='save')
	print 'Afegit nou CI: ' + bcolors.OKBLUE + new_ci + bcolors.ENDC 
	#Buscamos el uuid del ci que acabamos de crear
	ci=get_uuid_from_ci.search_ci(new_ci)
	#Anadimos las relaciones pertinentes
	insert_relationship(ci,pool)
else:
	#Si ya existe el ci, no hacemos nada
	print bcolors.FAIL + ' El ci=' + new_ci + ' existe: uuid=' +ci+ ' \n Aio Aio...' + bcolors.ENDC
