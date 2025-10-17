#!/bin/bash
#
# Univerzális CloudPanel és Mailcow Telepítő Szkript (beta2)
# Támogatott verziók: Ubuntu 22.04 LTS és 24.04 LTS
# Kompatibilitás: AWS EC2, KVM, VMware, és egyéb VPS/dedikált környezetek.
#

# =======================================================
# SZÍNEK ÉS ALAP FÜGGVÉNYEK
# =======================================================
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_NC='\033[0m' # No Color

# Globális változók
SERVER_HOSTNAME=""
MAILCOW_HOSTNAME=""
MAILCOW_HTTP_PORT="8081"
MAILCOW_HTTPS_PORT="8444"
MAILCOW_DIR="/opt/mailcow-dockerized"

# 8. Log fájl beállítás - Minden kimenet mentése
sudo mkdir -p /var/log
exec > >(tee -a /var/log/cloudpanel-mailcow-install.log)
exec 2>&1

LOG() {
    echo -e "${C_CYAN}[LOG]${C_NC} $(date +%H:%M:%S) $1"
}

ERROR() {
    echo -e "${C_RED}[HIBA]${C_NC} $(date +%H:%M:%S) $1" >&2
}

SUCCESS() {
    echo -e "${C_GREEN}[KÉSZ]${C_NC} $(date +%H:%M:%S) $1"
}

WARN() {
    echo -e "${C_YELLOW}[FIGYELEM]${C_NC} $(date +%H:%M:%S) $1"
}

PAUSE() {
    echo
    read -rp "Nyomj ENTER-t a folytatáshoz..."
    echo
}

# =======================================================
# 7. BACKUP ÉS RECOVERY PONT LÉTREHOZÁSA
# =======================================================
create_backup_point() {
    echo -e "\n${C_BLUE}--- Rendszer Állapot Mentése ---${C_NC}"
    LOG "Készít egy tömörített mentést a kritikus konfigurációs mappákról..."
    
    local backup_file="/root/pre-install-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    sudo tar -czf "$backup_file" \
        /etc/nginx /etc/mysql /etc/php /var/www /etc/ufw /etc/hosts /etc/hostname 2>/dev/null || true
    
    if [ -f "$backup_file" ]; then
        SUCCESS "Backup készült: $backup_file"
    else
        WARN "Backup készítése nem sikerült, de folytatjuk..."
    fi
    PAUSE
}

# =======================================================
# 2. HIÁNYZÓ FÜGGŐSSÉG ELLENŐRZÉS
# =======================================================
check_system_requirements() {
    echo -e "\n${C_BLUE}--- Rendszerkövetelmények ellenőrzése ---${C_NC}"
    
    # Ubuntu verzió ellenőrzés
    LOG "Ubuntu verzió ellenőrzése..."
    if ! command -v lsb_release >/dev/null 2>&1; then
        LOG "lsb_release nem található, telepítjük..."
        sudo apt update && sudo apt install -y lsb-release
    fi
    
    local ubuntu_version
    ubuntu_version=$(lsb_release -rs)
    if ! [[ "$ubuntu_version" =~ ^(22\.04|24\.04) ]]; then
        ERROR "Csak Ubuntu 22.04 LTS és 24.04 LTS támogatott! Talált: $ubuntu_version"
        exit 1
    fi
    SUCCESS "Ubuntu verzió OK: $(lsb_release -ds)"
    
    # Memória ellenőrzés (CloudPanel + Mailcow = minimum 4GB)
    LOG "Memória (RAM) ellenőrzése..."
    local total_mem
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 4 ]; then
        WARN "Kevesebb mint 4GB RAM ($total_mem GB) található. Ajánlott minimum: 6GB CloudPanel + Mailcow-hoz."
        read -rp "Folytatod így is? (i/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ii]$ ]]; then
            exit 1
        fi
    fi
    SUCCESS "RAM ($total_mem GB) elegendő (vagy megerősítetted a folytatást)."
    
    # Szabad lemezterület
    LOG "Szabad lemezterület ellenőrzése..."
    local free_space
    free_space=$(df / | awk 'NR==2 {print $4}') # Kilobytes
    if [ "$free_space" -lt 10485760 ]; then  # 10GB minimum KB-ban
        ERROR "Kevesebb mint 10GB szabad lemezterület! ($((free_space / 1024 / 1024)) GB). Kilépés."
        exit 1
    fi
    SUCCESS "Szabad lemezterület OK. ($((free_space / 1024 / 1024)) GB)"
    PAUSE
}

# =======================================================
# 6. HIÁNYZÓ check_environment_and_firewall FÜGGVÉNY
# =======================================================
check_environment_and_firewall() {
    echo -e "\n${C_BLUE}--- Környezet és Tűzfal Összegzés ---${C_NC}"
    
    # Publikus IP
    LOG "Publikus IP cím lekérése..."
    local public_ip
    public_ip=$(curl -s -4 ifconfig.me || curl -s -6 ifconfig.me || echo "ismeretlen")
    echo -e "Publikus IP: ${C_CYAN}$public_ip${C_NC}"
    
    # Cloud provider detektálás
    LOG "Felhő szolgáltató ellenőrzése..."
    if curl -s -m 5 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        WARN "AWS EC2 környezet detectálva! Ellenőrizd a Security Group beállításokat!"
    else
        SUCCESS "AWS nem detektálva (KVM/VPS/Dedikált valószínű)."
    fi
    
    # Port teszt külsőleg (csak ha ismert az IP)
    if [[ "$public_ip" != "ismeretlen" ]]; then
        WARN "Külső port elérhetőség ellenőrzése (Tűzfalon/Security Group-ban nyitva kell lennie!):"
        local test_ports=("80" "443" "8443" "$MAILCOW_HTTPS_PORT" "25" "587")
        for port in "${test_ports[@]}"; do
            if timeout 2 bash -c "echo >/dev/tcp/$public_ip/$port" 2>/dev/null; then
                echo -e "  Port $port: ${C_GREEN}NYITVA${C_NC}"
            else
                echo -e "  Port $port: ${C_RED}ZÁRVA${C_NC}"
            fi
        done
    else
        WARN "Publikus IP nem érhető el, port teszt kihagyva."
    fi
    
    # DNS beállítások ellenőrzése
    if [[ -n "$MAILCOW_HOSTNAME" && "$public_ip" != "ismeretlen" ]]; then
        LOG "DNS A rekord ellenőrzése a Mailcow domainhez..."
        if command -v dig >/dev/null 2>&1; then
            if dig +short "$MAILCOW_HOSTNAME" | grep -q "$public_ip"; then
                SUCCESS "DNS A rekord helyes: $MAILCOW_HOSTNAME → $public_ip"
            else
                WARN "DNS A rekord HIBA! Nem mutat a szerver IP-re."
                echo "  Beállítandó: $MAILCOW_HOSTNAME A $public_ip"
            fi
        else
            WARN "dig parancs nem elérhető, DNS ellenőrzés kihagyva."
        fi
    fi
    PAUSE
}

# =======================================================
# 1. TŰZFAL ELŐKÉSZÍTÉSE ÉS KIKAPCSOLÁSA
# =======================================================
prepare_firewall() {
    echo -e "\n${C_BLUE}--- Tűzfal Előkészítés (UFW) ---${C_NC}"
    
    LOG "UFW telepítés ellenőrzése..."
    if ! command -v ufw >/dev/null 2>&1; then
        LOG "Telepíti az UFW-t (Uncomplicated Firewall)..."
        sudo apt update && sudo apt install -y ufw
    fi

    if sudo ufw status | grep -q "active"; then
        WARN "Az UFW tűzfal jelenleg aktív. A zökkenőmentes telepítés érdekében ${C_RED}ideiglenesen kikapcsoljuk${C_NC}."
        sudo ufw disable
        SUCCESS "UFW tűzfal ideiglenesen KIkapcsolva."
    else
        SUCCESS "UFW telepítve. Jelenleg inaktív."
    fi
    
    WARN "FIGYELEM: AWS-nél ne feledd a Security Groupok beállítását!"
    PAUSE
}

# =======================================================
# 2. INTERAKTÍV ADATBEKÉRÉS
# =======================================================
input_config() {
    echo -e "\n${C_BLUE}--- Kezdeti Beállítások és Adatbekérés ---${C_NC}"

    # Szerver Hostname beállítása
    read -rp "1. Add meg a szerver fő (CloudPanel) Hostname-jét (pl. 'vps.pelda.hu'): " SERVER_HOSTNAME
    if [[ -z "$SERVER_HOSTNAME" ]]; then
        ERROR "A Hostname nem lehet üres. Kilépés."
        exit 1
    fi
    sudo hostnamectl set-hostname "$SERVER_HOSTNAME"
    # Hostname hozzáadása a hosts fájlhoz
    echo "127.0.0.1 $SERVER_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
    SUCCESS "A szerver Hostname beállítva: $SERVER_HOSTNAME"

    # Mailcow Hostname
    read -rp "2. Add meg a Mailcow (levelező) Domain nevét (pl. 'mail.sajatdomain.hu'): " MAILCOW_HOSTNAME
    if [[ -z "$MAILCOW_HOSTNAME" ]]; then
        ERROR "A Mailcow domain név nem lehet üres. Kilépés."
        exit 1
    fi

    # Mailcow Webes Portok (eltérő portok a CloudPanel miatt)
    WARN "A 80/443 portok a CloudPanel weboldalaihoz kellenek. A Mailcow webes felületét egyedi portokra irányítjuk."
    read -rp "3. Add meg a Mailcow HTTP portját (Alapértelmezett: 8081): " MAILCOW_HTTP_PORT
    MAILCOW_HTTP_PORT=${MAILCOW_HTTP_PORT:-8081}
    read -rp "4. Add meg a Mailcow HTTPS portját (Alapértelmezett: 8444): " MAILCOW_HTTPS_PORT
    MAILCOW_HTTPS_PORT=${MAILCOW_HTTPS_PORT:-8444}

    echo -e "\n${C_MAGENTA}Összegzés:${C_NC}"
    echo "  - CloudPanel Weboldalak: ${C_GREEN}80/443${C_NC}"
    echo "  - CloudPanel Admin: ${C_GREEN}8443${C_NC}"
    echo "  - Mailcow Admin: ${C_RED}$MAILCOW_HTTPS_PORT${C_NC}"
    PAUSE
}

# =======================================================
# 3. CLOUDPANEL TELEPÍTÉS (Javított ellenőrzéssel)
# =======================================================
install_cloudpanel() {
    echo -e "\n${C_BLUE}--- CloudPanel Telepítése (3. lépés) ---${C_NC}"
    
    LOG "Előfeltételek telepítése..."
    sudo apt update
    sudo apt install -y curl wget git lsb-release ca-certificates
    
    LOG "CloudPanel telepítő letöltése és futtatása..."
    # Hivatalos telepítő futtatása és ellenőrzése
    if ! curl -sS https://installer.cloudpanel.io/ce/v2/install.sh | sudo CLOUD_PANEL_BRANCH=stable bash; then
        ERROR "CloudPanel telepítése sikertelen! Nézd meg a log fájlt!"
        ERROR "Hibakeresés: sudo tail -f /var/log/cloudpanel/install.log"
        exit 1
    fi
    
    LOG "Várakozás a CloudPanel szolgáltatások elindulására (30 mp)..."
    sleep 30
    
    # NGINX ellenőrzése és újraindítása, ha szükséges
    if ! systemctl is-active --quiet nginx; then
        WARN "NGINX nem fut, újraindítás..."
        sudo systemctl restart nginx
        sleep 5
    fi
    
    SUCCESS "CloudPanel telepítés befejezve!"
    PAUSE
}

# =======================================================
# 4. DOCKER ÉS MAILCOW TELEPÍTÉS (Automatizált konfiguráció)
# =======================================================
install_mailcow() {
    echo -e "\n${C_BLUE}--- Docker és Mailcow Telepítése (4. lépés) ---${C_NC}"
    
    # Docker telepítés
    LOG "Docker telepítés előkészítése..."
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl gnupg
    
    LOG "Docker hivatalos repository hozzáadása..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    LOG "Docker telepítése..."
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Docker szolgáltatás indítása
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Current user hozzáadása docker csoporthoz
    sudo usermod -aG docker $USER
    
    SUCCESS "Docker telepítve."

    # Mailcow letöltése
    LOG "Mailcow letöltése..."
    sudo mkdir -p "$MAILCOW_DIR"
    if [ ! -d "$MAILCOW_DIR/.git" ]; then
        sudo git clone https://github.com/mailcow/mailcow-dockerized "$MAILCOW_DIR"
    else
        LOG "Mailcow már létezik, frissítés..."
        cd "$MAILCOW_DIR"
        sudo git pull
    fi
    
    # Mailcow konfiguráció automatizálása
    LOG "Mailcow konfiguráció automatikus beállítása ($MAILCOW_HOSTNAME)..."
    cd "$MAILCOW_DIR" || { ERROR "Hiba a Mailcow könyvtárba váltásnál."; exit 1; }
    
    # Automatikus válasz a generate_config.sh-nek
    echo -e "$MAILCOW_HOSTNAME\n" | sudo ./generate_config.sh
    
    if [ ! -f mailcow.conf ]; then
        ERROR "mailcow.conf fájl nem jött létre! Ellenőrizd a generate_config.sh futását."
        exit 1
    fi
    
    # Portok beállítása
    LOG "Beállítja az egyedi webes portokat..."
    sudo sed -i "s/^HTTP_PORT=.*/HTTP_PORT=$MAILCOW_HTTP_PORT/" mailcow.conf
    sudo sed -i "s/^HTTPS_PORT=.*/HTTPS_PORT=$MAILCOW_HTTPS_PORT/" mailcow.conf

    # Mailcow indítása
    LOG "Mailcow konténerek indítása..."
    sudo docker compose pull
    sudo docker compose up -d
    
    # Várakozás a konténerek elindulására
    sleep 30
    
    SUCCESS "Mailcow telepítés és indítás kész!"
    PAUSE
}

# =======================================================
# 5. TŰZFAL BEKAPCSOLÁSA (PROTOKOLL ELLENŐRZÉSSEL)
# =======================================================
enable_firewall() {
    echo -e "\n${C_BLUE}--- Tűzfal Végleges Bekapcsolása (5. lépés) ---${C_NC}"
    
    LOG "UFW alaphelyzetbe állítása..."
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # CloudPanel és Alapvető Portok
    LOG "Alapvető portok engedélyezése..."
    sudo ufw allow 22/tcp comment 'SSH - Rendszer'
    sudo ufw allow 80/tcp comment 'HTTP - CloudPanel Web'
    sudo ufw allow 443/tcp comment 'HTTPS - CloudPanel Web'
    sudo ufw allow 8443/tcp comment 'CloudPanel Admin Felület'

    # Mailcow Protokollok és Portok
    LOG "Mailcow portok engedélyezése..."
    sudo ufw allow "$MAILCOW_HTTP_PORT"/tcp comment 'Mailcow HTTP Web Interface'
    sudo ufw allow "$MAILCOW_HTTPS_PORT"/tcp comment 'Mailcow HTTPS Web Interface'

    # Mailcow levelezési portok
    local mail_ports=("25/tcp" "143/tcp" "110/tcp" "587/tcp" "993/tcp" "995/tcp")
    for port in "${mail_ports[@]}"; do
        sudo ufw allow "$port" comment "Mailcow Protocol Port"
    done
    
    # Tűzfal végleges bekapcsolása
    sudo ufw --force enable
    
    # Állapot ellenőrzése
    if sudo ufw status | grep -q "active"; then
        SUCCESS "UFW tűzfal BEkapcsolva! Összes szükséges port engedélyezve."
        sudo ufw status verbose
    else
        ERROR "UFW tűzfal nem sikerült bekapcsolni!"
    fi
    PAUSE
}

# =======================================================
# 5. HIÁNYZÓ SERVICE ELLENŐRZÉSEK
# =======================================================
verify_services() {
    echo -e "\n${C_BLUE}--- Szolgáltatások állapotának ellenőrzése (6. lépés) ---${C_NC}"
    
    LOG "CloudPanel szolgáltatások ellenőrzése..."
    local services=("nginx" "mariadb" "php8.2-fpm" "php8.3-fpm")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            SUCCESS "$service - FUT"
        else
            WARN "$service - NEM FUT (lehet, hogy nincs telepítve)"
        fi
    done
    
    # Docker container állapot
    if command -v docker >/dev/null 2>&1 && [ -d "$MAILCOW_DIR" ]; then
        LOG "Mailcow Docker konténerek állapota:"
        cd "$MAILCOW_DIR" && sudo docker compose ps
    else
        WARN "Docker vagy Mailcow nem elérhető a konténer ellenőrzéshez"
    fi
    
    # CloudPanel elérhetőség ellenőrzése
    LOG "CloudPanel webes elérhetőség ellenőrzése..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200"; then
        SUCCESS "CloudPanel web felület elérhető (Port 80)"
    else
        WARN "CloudPanel web felület NEM elérhető (Port 80) - lehet, hogy még indul"
    fi
    PAUSE
}

# =======================================================
# 6. TESZT ÉS KONZOL MENÜ
# =======================================================
mailcow_bash_console() {
    echo -e "\n${C_YELLOW}--- Mailcow Konzol Belépés ---${C_NC}"
    WARN "Ez a funkció bevisz a Mailcow egyik fő konténerébe (Bash shell)."
    LOG "A konténer elhagyásához írd be, hogy ${C_RED}exit${C_NC}."
    
    if [ ! -d "$MAILCOW_DIR" ]; then
        ERROR "Mailcow könyvtár nem található: $MAILCOW_DIR"
        PAUSE
        return
    fi
    
    cd "$MAILCOW_DIR" || { ERROR "Hiba a Mailcow könyvtárban."; PAUSE; return; }
    
    if sudo docker compose ps | grep -q "Up"; then
        sudo docker compose exec dovecot-mailcow bash
    else
        ERROR "Mailcow konténerek nem futnak!"
    fi
    
    echo -e "\n${C_GREEN}Konzol elhagyva.${C_NC}"
    PAUSE
}

test_menu() {
    while true; do
        clear
        echo -e "${C_BLUE}--- Telepített Szolgáltatások Tesztmenüje (7. lépés) ---${C_NC}"
        
        local ip_address
        ip_address=$(curl -s -4 ifconfig.me || curl -s -6 ifconfig.me || echo "ismeretlen")
        
        echo -e "\n${C_MAGENTA}Szerver Adatok (Elérhetőségek):${C_NC}"
        echo "  CloudPanel Admin: ${C_GREEN}https://$ip_address:8443${C_NC}"
        echo "  Mailcow Admin:    ${C_RED}https://$MAILCOW_HOSTNAME:$MAILCOW_HTTPS_PORT${C_NC} (admin / moohoo)"
        echo -e "\n${C_MAGENTA}Menüpontok:${C_NC}"
        echo "1) Portok és Szolgáltatások Állapot Ellenőrzése"
        echo "2) AWS/DNS/Külső Hálózat Összegzés"
        echo "3) ${C_CYAN}Mailcow Konzol Belépés (Docker Bash Shell)${C_NC}"
        echo "4) Kilépés a szkriptből (Befejezve)"
        
        read -rp "Választás (1-4): " choice
        
        case $choice in
            1)
                verify_services
                ;;
            2)
                check_environment_and_firewall
                ;;
            3)
                mailcow_bash_console
                ;;
            4)
                echo -e "\n${C_GREEN}Telepítés befejezve. Köszönöm, hogy a szkriptet használtad!${C_NC}"
                exit 0
                ;;
            *)
                WARN "Érvénytelen választás. Próbáld újra."
                PAUSE
                ;;
        esac
    done
}

# =======================================================
# FŐ PROGRAM FUTTATÁSA (Javított sorrend)
# =======================================================
main() {
    clear
    echo -e "${C_MAGENTA}#############################################################${C_NC}"
    echo -e "${C_MAGENTA}# CLOUDPANEL ÉS MAILCOW UNIVERZÁLIS TELEPÍTÉS #${C_NC}"
    echo -e "${C_MAGENTA}#############################################################${C_NC}"
    
    # Root jogosultság ellenőrzése
    if [ "$EUID" -ne 0 ]; then
        ERROR "Root jogosultság szükséges! Futtasd sudo-val: sudo bash $0"
        exit 1
    fi
    
    # Előkészületek
    create_backup_point
    check_system_requirements
    
    # Konfiguráció és Tűzfal
    prepare_firewall
    input_config

    # Telepítések
    install_cloudpanel
    install_mailcow

    # Lezárás és Ellenőrzés
    enable_firewall
    verify_services
    
    test_menu
}

# Fő program indítása
main "$@"
