#!/bin/bash
vol=0
base_copy=0
asigned=0
ocuppied=0
total_asignado=0
total_base_copy=0
total_unasigned=0
sr=a5c56e04-396e-cfa6-10ed-5120cd30e62b
total_sr=`xe sr-param-list uuid=$sr |grep physical-size |cut -d" " -f15`
VG=VG_XenStorage-$sr
	        for i in $(lvdisplay |grep "LV Name"|cut -c 86-121);do
                ((vol++))
                if [ "$(xe vdi-list uuid=$i)" != "" ]; then
                        vbd=$(xe vdi-param-list uuid=$i |grep vbd-uuids |cut -c 33-68)
                        if [ "$vbd" != "" ]; then
                                vm=$(xe vbd-list uuid=$vbd |grep vm-name|cut -c 25-68)
                                ((asigned++))
				ocuppied=$(xe vdi-param-list uuid=$i |grep physical-utilisation |cut -d" " -f8)
				total_asignado=`echo "$total_asignado+$ocuppied"|bc`;
				#echo "lv=$i vbd=$vbd vm=$vm ocuppied=$ocuppied total_asignado=$total_asignado"
				echo "lv=$i vbd=$vbd vm=$vm ocuppied=$ocuppied Asigned."
                        else
                                ((base_copy++))
				ocuppied=$(xe vdi-param-list uuid=$i |grep physical-utilisation |cut -d" " -f8)
				total_base_copy=`echo "$total_base_copy+$ocuppied"|bc`;
				#echo "lv=$i ocuppied=$ocuppied total_basecopy=$total_base_copy"
				echo "lv=$i ocuppied=$ocuppied Base Copy."
                        fi
                else
                        ((unasigned++))
			ocuppied=$(lvs /dev/$VG/VHD-$i --units b |tail -n1 |cut -d" " -f6)
			ocuppied=$(echo $ocuppied|sed s/.$//)
			total_unasigned=`echo "$total_unasigned+$ocuppied"|bc`;
                        #echo "lv=$i ocuppied=$ocuppied total_unasigned=$total_unasigned"
			echo "lv=$i ocuppied=$ocuppied Not asigned."
                fi
        done
	let total_sr=$total_sr/1024/1024/1024
	let total_asignado=$total_asignado/1024/1024/1024
	let total_base_copy=$total_base_copy/1024/1024/1024
	let total_unasigned=$total_unasigned/1024/1024/1024
	let libre=$total_sr-$total_asignado-$total_base_copy-$total_unasigned
        echo "Volumenes Totales ($vol), Asignados ($asigned)($total_asignado G), No asignados ($unasigned)($total_unasigned G), Base Copy ($base_copy) ($total_base_copy G), Total SR($total_sr), Free SR($libre)."
exit 0

