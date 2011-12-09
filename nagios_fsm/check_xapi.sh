#!/bin/bash
#Check que comprueba el estado de la XAPI

#contamos los procesos que hay de xapi
procs=`ps -elf | grep xapi | grep -v grep | wc -l`

#Verificamos que haya algun proc xapi y si no lo hay, critical
if [ -z "$procs" ] ; then
	echo "Critical: No hay procesos de Xapi"
	exit=2

else #Hay procesos, pues lanzamos una peticion para ver si respnde ok

	#Vemos si es capaz de conectar con la Xapi y extramos el numero de hosts del pool

	test_xapi=`sudo xe host-list | grep name-label | wc -l`
	#test_xapi="1" #Fuerza a warning
	if [ $test_xapi -gt 0 ]; then
		ok_test=$(sudo xe host-list name-label=`hostname` params=name-label --minimal)
		echo "OK: XAPI respondiendo en $ok_test "
		exit=0
	else
		new_test=$(sudo xe host-list name-label=`hostname` params=name-label --minimal)
		echo "Warning: Hay procs de XAPI pero algo falla $new_test"
		exit=1
	fi
fi

#Salida con el codigo de error para Nagios
exit $exit

