#!/bin/bash

CURRENT_BACK_TITLE=""
CURRENT_TITLE=""
CURRENT_MSG=""
YESNO=""
IMG=""
MNT=""

DATE=$(date +"%Y-%m-%d")
DIR="fontes/"
BASE_URL='https://downloads.raspberrypi.org/raspios_full_armhf/images/'
RASPBERRY_IP=$(arp -na | grep -E "(b8:27:eb|dc:a6:32)" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

base_name=$(basename "${3}")

if ! which dialog > /dev/null 2>&1;
then
  echo 'Instalando dependências...'
  sudo apt-get install dialog
fi

if ! which qemu-arm-static > /dev/null 2>&1;
then
  echo 'Instalando dependências...'
  sudo apt-get install -y gcc-arm-linux-gnueabihf libc6-dev-armhf-cross qemu-user-static > /dev/null 2>&1
  sudo apt install -y qemu qemu-user-static binfmt-support > /dev/null 2>&1
fi

if ! which nmap > /dev/null 2>&1;
then
  echo 'Instalando dependências...'
  sudo apt install nmap -y > /dev/null 2>&1
fi

help () {
  echo """
USAGE: ./chroot-to-pi.sh ['image_name'] ['mount_dir'] ['optional: fonts_dir']
"""
exit
}

yes_no () {
  reset

  high=10

  rows=$(stty size | cut -d' ' -f1)
  [ -z "$rows" ] && rows=$high
  [ $rows -gt $high ] && rows=$high
  cols=$(stty size | cut -d' ' -f2)
  dialog --backtitle "$CURRENT_BACK_TITLE" \
         --title "$CURRENT_TITLE" \
         --yesno "$CURRENT_MSG" $rows $((cols - 5))

  response=$?
  case $response in
     0)
       YESNO="YES"
       ;;
     1)
       YESNO="NO"
       ;;
     255) echo "[ESC] key pressed.";;
  esac

  reset
}

img_download () {
  wget -q --save-cookies cookies.txt $BASE_URL -O- \
       | sed -rn 's/.*raspios_full_armhf-([0-9.-]*).*/\1/p' > dirname.txt

  DIR_URL='https://downloads.raspberrypi.org/raspios_full_armhf/images/raspios_full_armhf-'$( tail -n 1 dirname.txt )'/'
  wget -q --save-cookies cookies.txt "$DIR_URL" -O- \
     | sed -rn 's/.*href="([0-9A-Za-z.-]*)([.zip|.xz]*)".*/\1/p' > filename.txt

  echo 'Fazendo download da imagem mais recente de '"$( tail -n 1 dirname.txt )":

  IMG_LINK='https://downloads.raspberrypi.org/raspios_full_armhf/images/raspios_full_armhf-'$( tail -n 1 dirname.txt )'/'$( head -n 1 filename.txt )

  #echo 'Aguarde o download terminar...'
  #wget --load-cookies cookies.txt -O $(<filename.txt).zip \
       #'https://downloads.raspberrypi.org/raspios_full_armhf/images/raspios_full_armhf-'$( tail -n 1 dirname.txt)'/'$( tail -n 1 filename.txt).zip

	reset
  wget --load-cookies cookies.txt -O "$( head -n 1 filename.txt )" --progress=dot "${IMG_LINK}" 2>&1 |\
  grep "%" |\
  sed -u -e "s,\.,,g" | awk '{print $2}' | sed -u -e "s,\%,,g"  | dialog --gauge "$( head -n 1 filename.txt )" 10 100
  reset

  echo 'Descompactando arquivo!!! Aguarde...'

  file=$( head -n 1 filename.txt )
  extension=${file##*.}

  if [ "${extension}" = 'zip' ]
  then
    unzip "$( head -n 1 filename.txt )"
  else
    unxz "$( head -n 1 filename.txt )"
  fi

  IMG=$(sed 's/\(.*\)'."${extension}"'/\1/' filename.txt)

  if [ -z "$IMG" ]
  then
    echo "Imagem não encontrada!!!"
    echo "Fechando..."
    exit
  fi
}

if [ -z "$1" ]
then
  echo "Nenhuma imagem definida!!!"
  img_download
  rm ./dirname.txt
  rm ./filename.txt
  rm ./cookies.txt
else
  IMG=$1
fi

if [ -z "$2" ]
then
  echo "O diretório de montagem temporária não é válido ou está vazio!!!"
  help
else
  MNT=$2
  echo "Analisando imagem..."
  sleep 2
  echo "Tudo ok!!!"
fi

if [ -z "$3" ]
then
  DIR=$DIR
else
  #rm fontes
  #mkdir fontes
  echo "Copiando fontes"
  rm -rf fontes/*
  rsync -r --exclude '.*' "${3}"/* fontes/"${base_name}"
  chmod 777 -R fontes/"${base_name}"
fi

LOOP=$(losetup --show -f -P "${IMG}")

mkdir -p /mnt/"${MNT}"

mount -o rw "${LOOP}"p2  /mnt/"${MNT}"
mount -o rw "${LOOP}"p1 /mnt/"${MNT}"/boot

mount --bind /dev /mnt/"${MNT}"/dev/
mount --bind /sys /mnt/"${MNT}"/sys/
mount --bind /proc /mnt/"${MNT}"/proc/
mount --bind /dev/pts /mnt/"${MNT}"/dev/pts

sed -i 's/^/#CHROOT /g' /mnt/"${MNT}"/etc/ld.so.preload

cp /usr/bin/qemu-arm-static /mnt/"${MNT}"/usr/bin/
cp /etc/resolv.conf /mnt/"${MNT}"/etc/

if [ -d "$DIR" ]; then
  echo "Movendo ${DIR} para: ===>>> /mnt/${MNT}/home/pi/fontes/${base_name}"
  mkdir -p /mnt/"${MNT}"/home/pi/fontes/"${base_name}"
  rsync -r --exclude '.*' fontes/ /mnt/"${MNT}"/home/pi/fontes/
  chmod 777 -R /mnt/"${MNT}"/home/pi/fontes
else
  echo "Fontes não encontradas, copiando fontes de: /mnt/${MNT}/home/pi/"
  rsync -r --exclude '.*' /mnt/"${MNT}"/home/pi/fontes/ ./
  chmod 777 -R fontes
fi

make_install () {
  echo "Mudando para diretório: ===>>> /home/pi/fontes/$BASE_FOLDER"
  cd /home/pi/fontes/"$BASE_FOLDER" && rm -rf .hbmk && chmod +x ./make_and_run.sh && ./make_and_run.sh raspberry
  exit
}

quit () {
  sed -i 's/^#CHROOT //g' /mnt/"${MNT}"/etc/ld.so.preload
  umount /mnt/"${MNT}"/{dev/pts,dev,sys,proc,boot,}
  sleep 1
  losetup --detach-all
  sleep 1

  if [[ $(findmnt -M "$MNT") ]]; then
    sudo umount -f "${MNT}" >/dev/null
  fi
}

copy_and_extract () {
  echo "COPIANDO E EXTRAINDO ARQUIVO"
  cp /mnt/"${MNT}"/home/pi/fontes/"${base_name}"/melinux ./melin_rasp  &>/dev/null
  gzip -rf melin_rasp &>/dev/null
  sudo chmod 777 melin_rasp.gz
  rm melin_rasp &>/dev/null
}

send_email () {
  rtmp_to=$(dialog --title "RaspiberryPI Virtual Console" --inputbox "Digite o e-mail: " 8 40 3>&1 1>&2 2>&3 3>&-)
  rtmp_url="smtps://smtp.gmail.com:465"
  rtmp_from="contato@otmasolucoes.com.br"
  rtmp_credentials="contato@otmasolucoes.com.br:ulhsmuepjmrwyusf"

  file_upload=$(pwd)"/melin_rasp.gz"
  mimetype=$(file --mime-type "$file_upload" | sed 's/.*: //')

  curl -s --url $rtmp_url \
  --ssl-reqd  --mail-from $rtmp_from \
  --mail-rcpt "$rtmp_to"  \
  --user $rtmp_credentials \
  -F '=(;type=multipart/mixed' \
  -F "=Melinux For RaspiberryPI $DATE;type=text/plain" \
  -F "file=@$file_upload;type=$mimetype;encoder=base64" \
  -F '=)' \
  -H "Subject: Melinux RaspiberryPI" \
  -H "From: Otma solucoes <$rtmp_from>" \
  -H "To: <$rtmp_to>"\

  res=$?
  if test "$res" != "0"; then
     echo "sending failed with: $res"
  else
      echo "OK"
  fi
}

#read -p 'Digite (y) para gerar executável agora ou (n) para acessar modo chroot: [y/n] : ' YESNO
CURRENT_BACK_TITLE=""
CURRENT_TITLE="RaspiberryPI Virtual Console"
CURRENT_MSG="Deseja gerar executável agora ou acessar modo chroot ???\n\nOBS: se optar por não gerar executável agora será automaticamente redirecionando para o chroot pi."

yes_no

if [ $YESNO = YES ] &>/dev/null || [ $YESNO = yes ] &>/dev/null || [ $YESNO = y ] &>/dev/null; then
  rsync ./make_and_run.sh /mnt/"${MNT}"/home/pi/fontes/"${base_name}"/
  export BASE_FOLDER="${base_name}"
  export -f make_install
  chroot /mnt/"${MNT}" /bin/bash -c "make_install"
  copy_and_extract
  quit
else
  chroot /mnt/"${MNT}" /bin/bash
  quit
  exit
fi

if [ -x "$(which curl)" ]; then
  #read -p "Deseja enviar o executável para um e-mail??? [y/n] : " YESNO
  CURRENT_BACK_TITLE=""
  CURRENT_TITLE="RaspiberryPI Virtual Console"
  CURRENT_MSG="Deseja enviar o executável para um e-mail???"

  yes_no

  if [ $YESNO = YES ] &>/dev/null || [ $YESNO = yes ] &>/dev/null || [ $YESNO = y ] &>/dev/null; then
    send_email
  fi
fi

if [ -z "$RASPBERRY_IP" ]; then
  echo "Saindo..."
  exit
else
  #read -p 'RASPBERRY detectada "YES" para executá-la ou Enter para fechar: ' YESNO
  CURRENT_BACK_TITLE=""
  CURRENT_TITLE="RaspiberryPI Virtual Console"
  CURRENT_MSG="RASPBERRY detectada ${RASPBERRY_IP}, deseja executá-la???"

  yes_no

  if [ $YESNO = YES ] &>/dev/null || [ $YESNO = yes ] &>/dev/null || [ $YESNO = y ] &>/dev/null; then
    sudo -u "$SUDO_USER" putty -load melinux -ssh "${RASPBERRY_IP}" -pw "melinux"
  fi
fi

exit && sudo umount -f "${MNT}" >/dev/null && \
sudo umount -f "${MNT}"/{dev/pts,dev,sys,proc,boot,} >/dev/null && \
sudo umount -l "${MNT}" >/dev/null
