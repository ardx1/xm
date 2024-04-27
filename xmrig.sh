# preparando script

echo "[*] Criando o script $HOME/minershell-main/miner.sh"
cat >$HOME/minershell-main/miner.sh <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice $HOME/minershell-main/xmrig \$*
else
  echo "O minerador de Monero já está sendo executado em segundo plano. Recusando-se a executar outro."
  echo "Execute \"killall xmrig\" ou \"sudo killall xmrig\" se desejar remover o minerador em segundo plano primeiro."
fi
EOL

chmod +x $HOME/minershell-main/miner.sh

# preparando trabalho de segundo plano do script e trabalho sob reinicialização

if ! sudo -n true 2>/dev/null; then
  if ! grep minershell-main/miner.sh $HOME/.profile >/dev/null; then
    echo "[*] Adicionando o script $HOME/minershell-main/miner.sh ao $HOME/.profile"
    echo "$HOME/minershell-main/miner.sh --config=$HOME/minershell-main/config_background.json >/dev/null 2>&1" >>$HOME/.profile
  else 
    echo "Parece que o script $HOME/minershell-main/miner.sh já está no $HOME/.profile"
  fi
  echo "[*] Executando o minerador em segundo plano (consulte os registros no arquivo $HOME/minershell-main/xmrig.log)"
  /bin/bash $HOME/minershell-main/miner.sh --config=$HOME/minershell-main/config_background.json >/dev/null 2>&1
else

  if [[ $(grep MemTotal /proc/meminfo | awk '{print $2}') > 3500000 ]]; then
    echo "[*] Habilitando páginas grandes"
    echo "vm.nr_hugepages=$((1168+$(nproc)))" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.nr_hugepages=$((1168+$(nproc)))
  fi

  if ! type systemctl >/dev/null; then

    echo "[*] Executando o minerador em segundo plano (consulte os registros no arquivo $HOME/minershell-main/xmrig.log)"
    /bin/bash $HOME/minershell-main/miner.sh --config=$HOME/minershell-main/config_background.json >/dev/null 2>&1
    echo "ERRO: Este script requer a utilidade \"systemctl\" do systemd para funcionar corretamente."
    echo "Mova-se para uma distribuição Linux mais moderna ou configure a ativação do minerador após a reinicialização por conta própria, se possível."

  else

    echo "[*] Criando o serviço systemd minershell-main_miner"
    cat >/tmp/minershell-main_miner.service <<EOL
[Unit]
Descrição=Serviço de minerador de Monero

[Serviço]
ExecStart=$HOME/minershell-main/xmrig --config=$HOME/minershell-main/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL
    sudo mv /tmp/minershell-main_miner.service /etc/systemd/system/minershell-main_miner.service
    echo "[*] Iniciando o serviço systemd minershell-main_miner"
    sudo killall xmrig 2>/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable minershell-main_miner.service
    sudo systemctl start minershell-main_miner.service
    echo "Para ver os registros do serviço do minerador, execute o comando \"sudo journalctl -u minershell-main_miner -f\""
  fi
fi

echo ""
echo "NOTA: Se você estiver usando um VPS compartilhado, é recomendável evitar o uso de 100% da CPU produzido pelo minerador ou você será banido"
if [ "$CPU_THREADS" -lt "4" ]; then
  echo "DICA: Execute esses ou comandos semelhantes como root para limitar o minerador a 75% do uso da CPU:"
  echo "sudo apt-get update; sudo apt-get install -y cpulimit"
  echo "sudo cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b"
  if [ "`tail -n1 /etc/rc.local`" != "exit 0" ]; then
    echo "sudo sed -i -e '\$acpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  else
    echo "sudo sed -i -e '\$i \\cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  fi
else
  echo "DICA: Execute esses comandos e reinicie seu VPS depois disso para limitar o minerador a 75% do uso da CPU:"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/minershell-main/config.json"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/minershell-main/config_background.json"
fi
echo ""

echo "[*] Configuração completa"
