#!/bin/sh
set -e
if [ $# -eq 1 ]
  then
    username=$(whoami)
    installdir=$1
    sudouser=$(sudo whoami)
    sudo bash ./install.sh $username $installdir
    exit
fi
echo "No arguments supplied"
echo "Please specify installation folder"
exit
