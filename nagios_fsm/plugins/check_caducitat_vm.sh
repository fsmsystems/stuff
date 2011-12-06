#!/bin/bash

#Script de control de les VM's caducades al XENVIRTUA

xe_command=`xe vm-list params=name-label,name-description`
mes=`date +%m`
any=`date +%Y` 

#Llegim linea a linea xe_command, ens quedem amb el nom de host+data venciment i comaparem amb el mes actual

while read line; do
        

	field=`echo "${line}" | awk '{print $1}'`
		
		#Busquem el Nom de la VM
		if [[ $field  == name-label ]]; then 
			host=`echo "${line}" | awk -F":" '{print $2}'`
		 
		fi

		#Busquem la info que ens interesa
		
		if [ $host != domain ]; then
			if [[ $field  == name-description ]];then
				Responsable=`echo "${line}" |  awk -F"//" '{print $1}'`
				Caducitat=`echo "${line}" |  awk -F"//" '{print $3}'| awk -F":" '{print $2}'`				
				Mes_caducitat=`echo "${line}" |  awk -F"//" '{print $3}'| awk -F":" '{print $2}'| awk -F"/" '{print $2}'`
				Any_caducitat=`echo "${line}" |  awk -F"//" '{print $3}'| awk -F":" '{print $2}'| awk -F"/" '{print $3}'`
				#echo "VM:"$host "-"  $Mes_caducitat $Any_caducitat		
			
				#Comprobem si la VM caduca aquest mes
         	        	if [ $Any_caducitat -eq $any ] && [ $Mes_caducitat -eq $mes ]; then
                        		echo "VM:" $host "caduca aquest mes!!!!"
                		fi

			fi
		fi
		

#	echo $caducitat_VM
done < <(xe vm-list params=name-label,name-description)
