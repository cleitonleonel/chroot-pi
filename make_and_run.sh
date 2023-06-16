#!/bin/bash

DEVICE=$1

echo 'Compilando para ' "$DEVICE"

function exec_melinux() {
  putty -ssh -load melinux "$RASPBERRY_IP" -pw melinux
}

function export_bin() {
  echo "Envinando executável para ""$RASPBERRY_IP"
  pscp -P 22 -pw "melinux" melinux 'melinux@'"$RASPBERRY_IP":'./'

  if [ $? -eq 0 ]
  then
    echo 'Arquivo copiado com sucesso!!!'
    echo 'Tecle Enter para continuar'
    #sleep 2
    #exec_melinux
  else
    echo 'Erro ao copiar arquivo.'
  fi
}

if [ "$DEVICE" = "ubuntu" ]
then
  ./compila
else
  sudo ./compila
fi

if [ -s error ]
then
  echo 'Falha ao compilar arquivo!!!'
else
  echo 'Arquivo compilado com sucesso!!!'
  if [ "$DEVICE" = "raspberry" ]
  then
    RASPBERRY_IP=$(arp -na | grep -E "(b8:27:eb|dc:a6:32)" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    if [ -z "$RASPBERRY_IP" ]
    then
      echo 'Nenhuma raspberry disponível na rede!!!'
    else
      export_bin
    fi
  fi
fi
