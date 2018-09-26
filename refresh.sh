#!/bin/bash

BOOTSTRAPURL=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep bootstrap.dat.xz | grep browser_download_url | cut -d '"' -f 4)
BOOTSTRAPARCHIVE="bootstrap.dat.xz"

# Make sure curl is installed
apt -qqy install curl
clear

clear
echo "This script will refresh your wallet."
read -pr "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

USER=vulcano
USERHOME=/home/vulcano

sudo systemctl stop vulcanod

echo "Refreshing node, please wait."

sleep 5

sudo rm -Rf "$USERHOME/.vulcanocore/blocks"
sudo rm -Rf "$USERHOME/.vulcanocore/database"
sudo rm -Rf "$USERHOME/.vulcanocore/chainstate"
sudo rm -Rf "$USERHOME/.vulcanocore/peers.dat"

sudo cp "$USERHOME/.vulcanocore/vulcano.conf" "$USERHOME/.vulcanocore/vulcano.conf.backup"
sudo sed -i '/^addnode/d' "$USERHOME/.vulcanocore/vulcano.conf"

echo "Installing bootstrap file..."
wget "$BOOTSTRAPURL" && sudo xz -cd $BOOTSTRAPARCHIVE && sudo mv "./bootstrap.dat"  "$USERHOME/.vulcanocore/bootstrap.dat" && rm $BOOTSTRAPARCHIVE

sudo systemctl start vulcanod

clear

echo "Your wallet is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""

until [ -n "$(vulcano-cli getconnectioncount 2>/dev/null)"  ]; do
  sleep 1
done

until su -c "vulcano-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" "$USER"; do
  echo -ne "Current block: ""$(sudo su -c "vulcano-cli getinfo" "$USER" | grep blocks | awk '{print $3}' | cut -d ',' -f 1)"'\r'
  sleep 1
done

clear

echo "" && echo "Wallet refresh completed. Do not forget to unlock your wallet!" && echo ""
