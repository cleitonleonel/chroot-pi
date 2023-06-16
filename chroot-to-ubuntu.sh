#!/bin/bash

CURRENT_BACK_TITLE=""
CURRENT_TITLE=""
CURRENT_MSG=""
YESNO=""
MNT=""

DATE=$(date +"%Y-%m-%d")
DIR="fontes/"

base_name=$(basename "${2}")

if ! which dialog > /dev/null 2>&1;
then
  echo 'Instalando dependências...'
  apt-get install dialog
fi

if ! which nmap > /dev/null 2>&1;
then
  echo 'Instalando dependências...'
  apt install nmap -y > /dev/null 2>&1
fi

help () {
  echo """
USAGE: ./chroot-to-media.sh ['mount_dir'] ['optional: fonts_dir']
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

if [ -z "$1" ]
then
  echo "O diretório de montagem temporária não é válido ou está vazio!!!"
  help
else
  MNT=$1
  echo "Analisando imagem..."
  sleep 2
  echo "Tudo ok!!!"
fi

if [ -z "$2" ]
then
  DIR=$DIR
else
  echo "Copiando fontes"
  rm -rf fontes/*
  rsync -r --exclude '.*' "${2}"/* fontes/"${base_name}"
fi

if [ -d "$DIR" ]; then
  echo "Movendo ${DIR} para: ===>>> ${MNT}/home/otma/fontes/${base_name}"
  rsync -r --exclude '.*' fontes/ "${MNT}"/home/otma/fontes/"${base_name}"/
  chmod 777 -R "${MNT}"/home/otma/fontes/"${base_name}"
else
  echo "Fontes não encontradas, copiando fontes de: ${MNT}/home/otma/"
  rsync -r --exclude '.*' "${MNT}"/home/otma/fontes/ ./
  chmod 777 -R fontes
fi

make_install () {
  echo "Mudando para diretório: ===>>> /home/otma/fontes/$BASE_FOLDER"
  cd /home/otma/fontes/"$BASE_FOLDER" && rm -rf .hbmk && chmod +x ./make_and_run.sh && ./make_and_run.sh ubuntu
  exit
}

quit () {
  losetup --detach-all
  sleep 1
  if [[ $(findmnt -M "$MNT") ]]; then
    umount -f "${MNT}" >/dev/null
  fi
}

copy_and_extract () {
  [ "$base_name" = "pdv" ] && EXEC="pdv" || EXEC="melinux"
  cp "${MNT}"/home/otma/fontes/"${base_name}"/"${EXEC}" ./"${EXEC}"_ubuntu  &>/dev/null
  gzip -rf "${EXEC}"_ubuntu &>/dev/null
  chmod 777 "${EXEC}"_ubuntu.gz
  rm "${EXEC}"_ubuntu &>/dev/null
}

send_email () {
  rtmp_to=$(dialog --title "Ubuntu HB Virtual Console" --inputbox "Digite o e-mail: " 8 40 3>&1 1>&2 2>&3 3>&-)
  rtmp_url="smtps://smtp.gmail.com:465"
  rtmp_from="email"
  rtmp_credentials="credentials"

  file_upload=$(pwd)"/melin_ubuntu.gz"
  mimetype=$(file --mime-type "$file_upload" | sed 's/.*: //')

  curl -s --url $rtmp_url \
  --ssl-reqd  --mail-from $rtmp_from \
  --mail-rcpt "$rtmp_to"  \
  --user $rtmp_credentials \
  -F '=(;type=multipart/mixed' \
  -F "=Melinux For Ubuntu 18.04 $DATE;type=text/plain" \
  -F "file=@$file_upload;type=$mimetype;encoder=base64" \
  -F '=)' \
  -H "Subject: Melinux Ubuntu 18.04" \
  -H "From: Otma solucoes <$rtmp_from>" \
  -H "To: <$rtmp_to>"\

  res=$?
  if test "$res" != "0"; then
     echo "sending failed with: $res"
  else
      echo "OK"
  fi
}

CURRENT_BACK_TITLE=""
CURRENT_TITLE="Ubuntu HB Virtual Console"
CURRENT_MSG="Deseja gerar executável agora ou acessar modo chroot ???\n\nOBS: se optar por não gerar executável agora será automaticamente redirecionando para o chroot."

yes_no

if [ $YESNO = YES ] &>/dev/null || [ $YESNO = yes ] &>/dev/null || [ $YESNO = y ] &>/dev/null; then
  rsync ./make_and_run.sh "${MNT}"/home/otma/fontes/"${base_name}"/
  export BASE_FOLDER="${base_name}"
  export -f make_install
  chroot "${MNT}" /bin/bash -c "make_install" #&>/dev/null && exit
  copy_and_extract
  quit
else
  chroot "${MNT}" /bin/bash
  exit
fi

if [ -x "$(which curl)" ]; then
  CURRENT_BACK_TITLE=""
  CURRENT_TITLE="Ubuntu HB Virtual Console"
  CURRENT_MSG="Deseja enviar o executável para um e-mail???"

  yes_no

  if [ $YESNO = YES ] &>/dev/null || [ $YESNO = yes ] &>/dev/null || [ $YESNO = y ] &>/dev/null; then
    send_email
  fi
fi

exit
