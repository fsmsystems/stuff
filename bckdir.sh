#!/usr/bin/bash
# Compara 2 directorios creando un backup de los ficheros del primer directorio presentes en el segundo con diferente checksum.
#set -x
for i in rsync basename dirname readlink mkdir find md5sum sort; do
    [ -f "$(which $i)" ] || { echo "Falta $i o no esta en el path."; exit 1;}
done
[ -d "$1" ] && [ -d "$2" ] || {
    echo "$(basename $0) <src_dir> <dst_dir>"
    echo "ex: $(basename $0) jspHome /home/campus/jspHome"
    exit 1
}
set -u
counter1=0 # Todos los ficheros del directorio origen
counter2=0 # Ficheros del directorio origen presentes en el directorio destino
counter3=0 # Ficheros copiados en el directorio de backup
counter4=0 # Errores en la copia
dirn1="$(dirname $(readlink -f $1))"
bckdir="$PWD/$(basename $1)_Backup_$(date +%y-%m-%d_%H:%M:%S)"
cd $dirn1
find $(basename $1) -type f | sort | while read file; do
    ((counter1++))
    dirn2file="$(dirname $(readlink -f $2))/${file/#$(basename $1)/$(basename $2)}"
    [ -f "$dirn2file" ] && {
        ((counter2++))
        md5_1=$(md5sum "$dirn1/$file")
        md5_2=$(md5sum $dirn2file)
        [ "${md5_1%% *}" != "${md5_2%% *}" ] && {
            echo -e "\n/ $file"
            echo "| SRC ${md5_1%% *} DST ${md5_2%% *}"
            echo "\ > Copiando en $(basename $bckdir)"
            rsync -Raih --progress "$dirn2file" "$bckdir"
            if [ $? -eq 0 ]; then
                ((counter3++))
            else
                ((counter4++))
                echo "+ ERROR!!"
                sleep 5
            fi
        }
    }
    echo -en "\r+ $counter3 de $counter1/$counter2 ficheros copiados, $counter4 errores."
done
echo
