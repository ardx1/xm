#!/bin/bash

VERSION=2.11

# printing greetings

echo "MoneroOcean mining setup script v$VERSION."
echo "(please report issues with full output of this script with extra \"-x\" \"bash\" option)"
echo

# command line argument
WALLET=$1

# checking prerequisites

if [ -z $WALLET ]; then
  echo "Script usage:"
  echo "> setup_minershell-main_miner.sh <wallet address>"
  echo "ERROR: Please specify your wallet address"
  exit 1
fi

WALLET_BASE=`echo $WALLET | cut -f1 -d"."`
if [ ${#WALLET_BASE} != 106 -a ${#WALLET_BASE} != 95 ]; then
  echo "ERROR: Wrong wallet base address length (should be 106 or 95): ${#WALLET_BASE}"
  exit 1
fi

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists or set it yourself using this command:"
  echo '  export HOME=<dir>'
  exit 1
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

# calculating CPU threads

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

# printing intentions

echo "I will download, setup and run in background Monero CPU miner."
echo "Mining will happen to $WALLET wallet."

echo
echo "JFYI: This host has $CPU_THREADS CPU threads, so projected Monero hashrate is around $EXP_MONERO_HASHRATE KH/s."
echo

echo "Sleeping for 15 seconds before continuing (press Ctrl+C to cancel)"
sleep 15
echo
echo

# start doing stuff: preparing miner

echo "[*] Removing previous minershell-main miner (if any)"
systemctl stop minershell-main_miner.service >/dev/null 2>&1
killall -9 xmrig >/dev/null 2>&1

echo "[*] Removing $HOME/minershell-main directory"
rm -rf $HOME/minershell-main

echo "[*] Downloading minershell-main advanced version of xmrig to /tmp/xmrig.tar.gz"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/ardx1/xm/main/minershell-main.tar.gz" -o /tmp/xmrig.tar.gz; then
  echo "ERROR: Can't download https://raw.githubusercontent.com/ardx1/xm/main/minershell-main.tar.gz file to /tmp/xmrig.tar.gz"
  exit 1
fi

echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/minershell-main"
[ -d $HOME/minershell-main ] || mkdir $HOME/minershell-main
if ! tar xf /tmp/xmrig.tar.gz -C $HOME/minershell-main; then
  echo "ERROR: Can't unpack /tmp/xmrig.tar.gz to $HOME/minershell-main directory"
  exit 1
fi
rm /tmp/xmrig.tar.gz

echo "[*] Checking if advanced version of $HOME/minershell-main/xmrig works fine (and not removed by antivirus software)"
sed -i 's/"donate-level": *[^,]*,/"donate-level": 1,/' $HOME/minershell-main/config.json
$HOME/minershell-main/xmrig --help >/dev/null
if (test $? -ne 0); then
  if [ -f $HOME/minershell-main/xmrig ]; then
    echo "WARNING: Advanced version of $HOME/minershell-main/xmrig is not functional"
  else 
    echo "WARNING: Advanced version of $HOME/minershell-main/xmrig was removed by antivirus (or some other problem)"
  fi

  echo "[*] Looking for the latest version of Monero miner"
  LATEST_XMRIG_RELEASE=`curl -s https://github.com/xmrig/xmrig/releases/latest  | grep -o '".*"' | sed 's/"//g'`
  LATEST_XMRIG_LINUX_RELEASE="https://github.com"`curl -s $LATEST_XMRIG_RELEASE | grep xenial-x64.tar.gz\" |  cut -d \" -f2`

  echo "[*] Downloading $LATEST_XMRIG_LINUX_RELEASE to /tmp/xmrig.tar.gz"
  if ! curl -L --progress-bar $LATEST_XMRIG_LINUX_RELEASE -o /tmp/xmrig.tar.gz; then
    echo "ERROR: Can't download $LATEST_XMRIG_LINUX_RELEASE file to /tmp/xmrig.tar.gz"
    exit 1
  fi

  echo "[*] Unpacking /tmp/xmrig.tar.gz to $HOME/minershell-main"
  if ! tar xf /tmp/xmrig.tar.gz -C $HOME/minershell-main --strip=1; then
    echo "WARNING: Can't unpack /tmp/xmrig.tar.gz to $HOME/minershell-main directory"
  fi
  rm /tmp/xmrig.tar.gz

  echo "[*] Checking if stock version of $HOME/minershell-main/xmrig works fine (and not removed by antivirus software)"
  sed -i 's/"donate-level": *[^,]*,/"donate-level": 0,/' $HOME/minershell-main/config.json
  $HOME/minershell-main/xmrig --help >/dev/null
  if (test $? -ne 0); then 
    if [ -f $HOME/minershell-main/xmrig ]; then
      echo "ERROR: Stock version of $HOME/minershell-main/xmrig is not functional too"
    else 
      echo "ERROR: Stock version of $HOME/minershell-main/xmrig was removed by antivirus too"
    fi
    exit 1
  fi
fi

echo "[*] Miner $HOME/minershell-main/xmrig is OK"

PASS="x"

sed -i 's/"url": *"[^"]*",/"url": "pool.hashvault.pro:80",/' $HOME/minershell-main/config.json
sed -i 's/"max-cpu-usage": *[^,]*,/"max-cpu-usage": 70,/' $HOME/minershell-main/config.json
sed -i 's#"log-file": *null,#"log-file": "'$HOME/minershell-main/xmrig.log'",#' $HOME/minershell-main/config.json
sed -i 's/"syslog": *[^,]*,/"syslog": true,/' $HOME/minershell-main/config.json

# Copiando o arquivo config.json para config_background.json
cp $HOME/minershell-main/config.json $HOME/minershell-main/config_background.json

# preparing script

echo "[*] Creating $HOME/minershell-main/miner.sh script"
cat >$HOME/minershell-main/miner.sh <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice $HOME/minershell-main/xmrig \$*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall xmrig\" or \"killall -9 xmrig\" if you want to remove background miner first."
fi
EOL

chmod +x $HOME/minershell-main/miner.sh

# preparing script background work and work under reboot

echo "[*] Creating minershell-main_miner systemd service"
cat >/tmp/minershell-main_miner.service <<EOL
[Unit]
Description=Monero miner service

[Service]
ExecStart=$HOME/minershell-main/xmrig --url pool.hashvault.pro:80 --user $WALLET --pass $PASS --donate-level 1 --tls --tls-fingerprint 420c7850e09b7c0bdcf748a7da9eb3647daf8515718f36d9ccfdd6b9ff834b14 --config=$HOME/minershell-main/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL

mv /tmp/minershell-main_miner.service $HOME/minershell-main/minershell-main_miner.service
if [ $? -eq 0 ]; then
  echo "[*] minershell-main_miner systemd service created successfully"
else
  echo "ERROR: Failed to create minershell-main_miner systemd service"
  exit 1
fi

echo "[*] Starting minershell-main_miner systemd service"
killall xmrig >/dev/null 2>&1
systemctl --user daemon-reload >/dev/null 2>&1
systemctl --user enable minershell-main_miner.service >/dev/null 2>&1
systemctl --user start minershell-main_miner.service >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "To see miner service logs run \"journalctl -u minershell-main_miner -f\" command"
else
  echo "ERROR: Failed to start minershell-main_miner systemd service"
fi

echo "[*] Setup complete"