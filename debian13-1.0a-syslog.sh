#!/bin/bash

# Ellenőrizzük, hogy a szkript root felhasználóval fut-e
if [ "$(id -u)" -ne 0 ]; then
  echo "Ez a szkript root jogosultságot igényel. Kérlek, futtasd sudo-val."
  exit 1
fi

LOG_FILE="/var/log/rsyslog_setup.log"

function log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

function install_rsyslog() {
  log_message "Ellenőrzés: Az rsyslog telepítve van-e..."
  if ! dpkg -l | grep -q rsyslog; then
    log_message "Az rsyslog nincs telepítve. Telepítés megkezdése..."
    apt update >> "$LOG_FILE" 2>&1
    apt install -y rsyslog >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
      log_message "Az rsyslog sikeresen telepítve."
      systemctl enable rsyslog >> "$LOG_FILE" 2>&1
      systemctl start rsyslog >> "$LOG_FILE" 2>&1
    else
      log_message "Hiba: Az rsyslog telepítése sikertelen."
      exit 1
    fi
  else
    log_message "Az rsyslog már telepítve van."
  fi
}

function view_local_config() {
  log_message "Helyi rsyslog konfiguráció megtekintése (/etc/rsyslog.conf):"
  echo "------------------------------------------------------------"
  grep -v -E "^#|^$" /etc/rsyslog.conf | head -20
  echo "------------------------------------------------------------"
  read -p "Nyomj Enter-t a folytatáshoz..."
}

function configure_server() {
  read -p "Add meg a fogadni kívánt logokat küldő kliensek IP-címét vagy hálózatát (pl.: 127.0.0.1, 10.0.0.0/24, *.budapest.lan): " allowed_senders
  
  log_message "Rsyslog beállítása syslog szerverként..."
  
  RSYSLOG_CONF="/etc/rsyslog.conf"
  BACKUP_FILE="${RSYSLOG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
  
  # Biztonsági mentés készítése
  cp "$RSYSLOG_CONF" "$BACKUP_FILE"
  log_message "Eredeti rsyslog.conf fájl mentve: $BACKUP_FILE"
  
  # Modulok betöltésének aktiválása
  if ! grep -q "^module(load=\"imtcp\")" "$RSYSLOG_CONF"; then
    sed -i 's/^#*module(load="imtcp")/module(load="imtcp")/' "$RSYSLOG_CONF"
  fi
  
  # TCP port beállítás
  if ! grep -q "^input(type=\"imtcp\" port=\"514\")" "$RSYSLOG_CONF"; then
    sed -i 's/^#*input(type="imtcp" port="514")/input(type="imtcp" port="514")/' "$RSYSLOG_CONF"
  fi
  
  # Engedélyezett küldők beállítása
  if [ -n "$allowed_senders" ]; then
    # Eltávolítjuk a korábbi bejegyzéseket
    sed -i '/AllowedSender/d' "$RSYSLOG_CONF"
    # Hozzáadjuk az új bejegyzést
    sed -i "/input(type=\"imtcp\" port=\"514\")/a\\\$AllowedSender TCP, $allowed_senders" "$RSYSLOG_CONF"
  fi
  
  # UFW beállítás (ha telepítve van)
  if command -v ufw >/dev/null 2>&1; then
    ufw allow 514/tcp >> "$LOG_FILE" 2>&1
    log_message "UFW szabály hozzáadva a 514/TCP porthoz"
  fi
  
  log_message "Rsyslog szerver konfiguráció frissítve. Újraindítás..."
  systemctl restart rsyslog >> "$LOG_FILE" 2>&1
  
  if [ $? -eq 0 ]; then
    log_message "Rsyslog sikeresen újraindítva. A szerver most készen áll a logok fogadására."
    ss -tuln | grep 514 >> "$LOG_FILE" 2>&1
  else
    log_message "Hiba: Az rsyslog újraindítása sikertelen."
    journalctl -u rsyslog -n 10 --no-pager | tee -a "$LOG_FILE"
  fi
  read -p "Nyomj Enter-t a folytatáshoz..."
}

function configure_client() {
  read -p "Add meg a syslog szerver IP-címét vagy hosztnevét (pl.:lanserver.budapest.lan): " syslog_server
  if [ -z "$syslog_server" ]; then
    log_message "Hiba: A syslog szerver címe nem lehet üres."
    return 1
  fi
  
  log_message "Rsyslog beállítása syslog kliensként a(z) $syslog_server szerverhez..."
  
  RSYSLOG_CONF="/etc/rsyslog.conf"
  BACKUP_FILE="${RSYSLOG_CONF}.bak.$(date +%Y%m%d_%H%M%S)"

  # Biztonsági mentés készítése
  cp "$RSYSLOG_CONF" "$BACKUP_FILE"
  log_message "Eredeti rsyslog.conf fájl mentve: $BACKUP_FILE"
  
  # Ellenőrizzük, hogy a bejegyzés már létezik-e
  if ! grep -q "Target=\"${syslog_server}\"" "$RSYSLOG_CONF"; then
    cat <<EOF >> "$RSYSLOG_CONF"

# Szabály a logok küldésére egy távoli szerverre
*.* action(type="omfwd"
       queue.filename="fwdRule_${syslog_server//./_}"
       queue.maxdiskspace="1g"
       queue.saveonshutdown="on"
       queue.type="LinkedList"
       action.resumeRetryCount="-1"
       Target="$syslog_server" Port="514" Protocol="tcp")
EOF
    log_message "Kliens konfiguráció hozzáadva a rsyslog.conf fájlhoz."
  else
    log_message "Kliens konfiguráció már létezik a rsyslog.conf fájlban a(z) $syslog_server szerverhez."
  fi
  
  log_message "Rsyslog újraindítása..."
  systemctl restart rsyslog >> "$LOG_FILE" 2>&1

  if [ $? -eq 0 ]; then
    log_message "Rsyslog sikeresen újraindítva. A logok mostantól elküldésre kerülnek a(z) $syslog_server szerverre."
  else
    log_message "Hiba: Az rsyslog újraindítása sikertelen."
    journalctl -u rsyslog -n 10 --no-pager | tee -a "$LOG_FILE"
  fi
  read -p "Nyomj Enter-t a folytatáshoz..."
}

# Fő menü
function main_menu() {
  while true; do
    clear
    echo "------------------------------------------------"
    echo "Debian Rsyslog Konfigurátor 1.0a Citk 2025"
    echo "------------------------------------------------"
    echo "1. Rsyslog telepítése (ha nincs telepítve)"
    echo "2. Helyi log konfiguráció megtekintése"
    echo "3. Beállítás syslog szerverként"
    echo "4. Beállítás syslog kliensként"
    echo "5. Kilépés"
    echo "------------------------------------------------"
    read -p "Válaszd ki a kívánt opciót [1-5]: " choice
    
    case "$choice" in
      1)
        install_rsyslog
        ;;
      2)
        view_local_config
        ;;
      3)
        install_rsyslog
        configure_server
        ;;
      4)
        install_rsyslog
        configure_client
        ;;
      5)
        log_message "Kilépés. Viszlát!"
        exit 0
        ;;
      *)
        log_message "Érvénytelen választás. Kérlek, válassz 1 és 5 között."
        read -p "Nyomj Enter-t a folytatáshoz..."
        ;;
    esac
  done
}

# Szkript indítása
main_menu
