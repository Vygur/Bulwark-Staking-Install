#!/bin/bash

VPSTARBALLURL=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep linux64 | cut -d '"' -f 4)
VPSTARBALLNAME=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep linux64 | cut -d '"' -f 4 | cut -d "/" -f 9)
SHNTARBALLURL=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep ARM | cut -d '"' -f 4)
SHNTARBALLNAME=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep ARM | cut -d '"' -f 4 | cut -d "/" -f 9)
VULCVERSION=$(curl -s https://api.github.com/repos/vulcanocrypto/vulcano/releases/latest | grep browser_download_url | grep ARM | cut -d '"' -f 4 | cut -d "/" -f 8)

CHARS="/-\\|"


clear
echo "This script will update your wallet to version $VULCVERSION"
read -rp "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER="vulcano"
USERHOME="/home/vulcano"

echo "Shutting down wallet..."
if [ -e /etc/systemd/system/vulcanod.service ]; then
  systemctl stop vulcanod
else
  su -c "vulcano-cli stop" "vulcano"
fi

if grep -q "ARMv7" /proc/cpuinfo; then
  # Install Vulcano daemon for ARMv7 systems
  wget "$SHNTARBALLURL"
  tar -xzvf "$SHNTARBALLNAME" && mv bin "vulcano-$VULCVERSION"
  rm" $SHNTARBALLNAME"
  cp "./vulcano-$VULCVERSION/vulcanod" /usr/local/bin
  cp "./vulcano-$VULCVERSION/vulcano-cli" /usr/local/bin
  cp "./vulcano-$VULCVERSION/vulcano-tx" /usr/local/bin
  rm -rf "vulcano-$VULCVERSION"
else
  # Install Vulcano daemon for x86 systems
  wget "$VPSTARBALLURL"
  tar -xzvf "$VPSTARBALLNAME" && mv bin "vulcano-$VULCVERSION"
  rm "$VPSTARBALLNAME"
  cp "./vulcano-$VULCVERSION/vulcanod" /usr/local/bin
  cp "./vulcano-$VULCVERSION/vulcano-cli" /usr/local/bin
  cp "./vulcano-$VULCVERSION/vulcano-tx" /usr/local/bin
  rm -rf "vulcano-$VULCVERSION"
fi

if [ -e /usr/bin/vulcanod ];then rm -rf /usr/bin/vulcanod; fi
if [ -e /usr/bin/vulcano-cli ];then rm -rf /usr/bin/vulcano-cli; fi
if [ -e /usr/bin/vulcano-tx ];then rm -rf /usr/bin/vulcano-tx; fi

# Remove addnodes from vulcano.conf
sed -i '/^addnode/d' "/home/vulcano/.vulcanocore/vulcano.conf"

# Add Fail2Ban memory hack if needed
if ! grep -q "ulimit -s 256" /etc/default/fail2ban; then
  echo "ulimit -s 256" | sudo tee -a /etc/default/fail2ban
  systemctl restart fail2ban
fi

echo "Restarting Vulcano daemon..."
if [ -e /etc/systemd/system/vulcanod.service ]; then
  systemctl disable vulcanod
  rm /etc/systemd/system/vulcanod.service
fi

cat > /etc/systemd/system/vulcanod.service << EOL
[Unit]
Description=Vulcanos's distributed currency daemon
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/vulcanod -conf=${USERHOME}/.vulcanocore/vulcano.conf -datadir=${USERHOME}/.vulcanocore
ExecStop=/usr/local/bin/vulcano-cli -conf=${USERHOME}/.vulcanocore/vulcano.conf -datadir=${USERHOME}/.vulcanocore stop
Restart=on-failure
RestartSec=1m
StartLimitIntervalSec=5m
StartLimitInterval=5m
StartLimitBurst=3
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl enable vulcanod
sudo systemctl start vulcanod

until [ -n "$(vulcano-cli getconnectioncount 2>/dev/null)"  ]; do
  sleep 1
done

clear

echo "Your wallet is syncing. Please wait for this process to finish."

until su -c "vulcano-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" "vulcano"; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    echo -en "${CHARS:$i:1}" "\\r"
  done
done

clear

echo "Vulcano is now up to date. Do not forget to unlock your wallet!"
