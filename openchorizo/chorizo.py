#!/usr/bin/python
#
# 26/04/2010 
import os
import sys
import getopt


list_servers=[]
list_tasks=[]

#-------------------------------------------------------------------------------
class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
#-------------------------------------------------------------------------------
    def disable(self):
        self.HEADER = ''
        self.OKBLUE = ''
        self.OKGREEN = ''
        self.WARNING = ''
        self.FAIL = ''
        self.ENDC = ''
#-------------------------------------------------------------------------------
def req_servers():
	print "Lo que voy a ejecutar"
	print 
	print bcolors.OKGREEN + "--------------------------" + bcolors.ENDC
	print bcolors.OKGREEN + "Lista servidores" + bcolors.ENDC
	print bcolors.OKGREEN + "--------------------------" + bcolors.ENDC
#-------------------------------------------------------------------------------
def req_commands():
	print bcolors.OKGREEN + "--------------------------" + bcolors.ENDC
	print
	print bcolors.OKBLUE + "--------------------------" + bcolors.ENDC
	print bcolors.OKBLUE + "Lista Comandos" + bcolors.ENDC
	print bcolors.OKBLUE + "--------------------------" + bcolors.ENDC
#-------------------------------------------------------------------------------
def hello():
	print "Open Chorizo. 0.1 stable"
	print "---------------------------------------------------"
	print "Executa una llista de tasques en els equips remots que hi hagin en una llista"
	print "[EXEMPLE] chorizo -s llista_servers.txt -t llista_tasques.txt"
#-------------------------------------------------------------------------------
def usage():
    print "Usage: " + sys.argv[0] + " [ -h | --help ]  [ -s | --servers ] [ -t | --tasques ] "
#-------------------------------------------------------------------------------
def check_file(f):
	return os.path.isfile(f)
#-------------------------------------------------------------------------------
def file_read(f):
	llista=[]
	if check_file(f) == True:
		f_read=open(f,"r")	
		for line in f_read:
			line_r=str.split(line,"\n")
			llista.append(line_r)
		f_read.close
		return llista
	else:
		print "Chorizo no trova el fitxer!: "+ f
#-------------------------------------------------------------------------------
def execute_chorix():
	for server in list_servers:
		counter=1
		print bcolors.OKGREEN +  "--------------------------" + bcolors.ENDC
		print ">>: Executant en: "+ bcolors.OKGREEN  + server[0] + bcolors.ENDC
		print bcolors.OKGREEN +  "--------------------------" + bcolors.ENDC
		for command in list_tasks:
			print "(" + str(counter) + "/" + str(len(list_tasks)) + ") " + bcolors.OKGREEN + "#" + server[0] + bcolors.OKBLUE +  " >>>> " + command[0] + bcolors.ENDC
			c="ssh root@" + server[0] + " -C '" + command[0] + "'"
			com=os.popen(c).read()
			counter=counter+1
			print com
			#print bcolors.OKBLUE +  "--------------------------" + bcolors.ENDC
	return com
#-------------------------------------------------------------------------------
try:
	optlist, args = getopt.getopt(sys.argv[1:], 't:s:h' , ["tasques","servers","help"])
except getopt.GetoptError, err:
        print str(err) # will print something like "option -a not recognized"
        usage()
        sys.exit(2)
	
for k,v in optlist:
	if k in ('-h','--help'):            
		hello()
		sys.exit(0)
	elif k in ('-s','--servers'):
		list_servers=file_read(str(v))	#print list_servers
	elif k in ('-t','--tasques'):
		list_tasks=file_read(str(v)) #print list_tasks
req_servers()
for server in list_servers:
	print ">> | " + server[0]
req_commands()
for command in list_tasks:
	print "<< | " + command[0]
print bcolors.OKBLUE +  "--------------------------" + bcolors.ENDC
print
print bcolors.WARNING + "Tot Ok? [s/n]" + bcolors.ENDC
go=raw_input("> ")
if go=="s":
	output = execute_chorix()
else:
	print "no s'ha executat res"

