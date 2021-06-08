#!/bin/bash

COMMAND=$1

RASPBERRY_IP=$(arp -na | grep -E "(b8:27:eb|dc:a6:32)" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

MELINUX_DIR="/home/melinux"

if [ "$COMMAND" = "quiet" ]
then
  sudo ./compila >/dev/null
else
  sudo ./compila
fi

function exec_melinux() {
  putty -ssh -load melinux $RASPBERRY_IP -pw melinux
}

function export_bin() {
  echo 'Movendo arquivo para: ===>>> melinux@'$RASPBERRY_IP:$MELINUX_DIR
  if [ "$COMMAND" = "quiet" ]
  then
    pscp -pw "melinux" melinux 'melinux@'$RASPBERRY_IP:'./' >/dev/null &
  else
    pscp -pw "melinux" melinux 'melinux@'$RASPBERRY_IP:'./'
  fi

  if [ $? -eq 0 ]
  then
    echo 'Arquivo movido com sucesso!!!'
    sleep 2
    #exec_melinux
  else
    echo 'Erro ao mover arquivo.'
  fi
  exit
}

if [ -s error ]
then
  echo 'Falha ao compilar arquivo!!!'
else
  echo 'Arquivo compilado com sucesso!!!'
  if [ -z "$RASPBERRY_IP" ]
  then
    echo 'Nenhuma raspberry disponível na rede!!!'
    exit
  fi
  export_bin
fi
