#!/bin/bash
# A Bash Szkript neve: Pritnul telepitő szkript
# Készítette: DevOFALL 2025
# Verzió: v3.2 (Ubuntu 22.04 LTS)

# --- Beállítások és Színek ---
set -eo pipefail

# Színek beállítása (Ubuntu Paletta)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Dinamikus kódnév és Globális változók
UBUNTU_CODENAME=$(lsb_release -cs)
BACKUP_DIR=""
LOG_FILE="" # Inicializálás

# --- Hiba Kezelés és Rollback ---

# Rollback funkció hiba esetén (triggerel: trap ERR)
rollback_installation() {
    # Ellenőrzés, hogy a LOG_FILE és BACKUP_DIR létezik-e
    if [[ -z "$LOG_FILE" || -z "$BACKUP_DIR" ]]; then
        echo -e "\n${RED}KRITIKUS HIBA! Rollback nem lehetséges, mert a biztonsági mentés nem készült el.${NC}"
        return
    fi
    
    echo -e "\n${RED}==============================================${NC}"
    echo -e "${RED}${BOLD}KRITIKUS HIBA TÖRTÉNT! Visszaállítás indítása...${NC}"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "${YELLOW}Visszaállítás a biztonsági mentésből (${BACKUP_DIR})...${NC}"
        cp -r "$BACKUP_DIR/sources.list.d"/* /etc/apt/sources.list.d/ 2>/dev/null || true
        cp -r "$BACKUP_DIR/ufw"/* /etc/ufw/ 2>/dev/null || true
        
        echo -e "${GREEN}Visszaállítás befejezve. Kérjük ellenőrizze a naplófájlt: $LOG_FILE${NC}"
    else
        echo -e "${RED}Biztonsági mentési mappa nem található! Manuális beavatkozás szükséges!${NC}"
    fi
    echo -e "${RED}==============================================${NC}"
}

# --- Segédfüggvények Definíciói ---

setup_logging() {
    LOG_FILE="/var/log/pritunl_install_$(date +%Y%m%d_%H%M%S).log"
    exec {original_stdout}>&1
    exec {original_stderr}>&2
    exec 1> >(tee -a "$LOG_FILE" >&${original_stdout})
    exec 2> >(tee -a "$LOG_FILE" >&${original_stderr})
    echo -e "${YELLOW}Telepítési napló: ${LOG_FILE}${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ez a script root (sudo) jogosultságokat igényel. Kérem futtassa így: sudo ./script_neve.sh${NC}"
        exit 1
    fi
}

check_system_compatibility() {
    echo -e "${YELLOW}Rendszer kompatibilitás ellenőrzése...${NC}"
    local os_id=$(lsb_release -is)
    local supported_os="Ubuntu"
    local supported_versions=("22.04" "24.04")
    if [[ "$os_id" != "$supported_os" ]]; then echo -e "${RED}Hiba: Nem támogatott operációs rendszer: ${os_id}${NC}"; exit 1; fi
    local ubuntu_version=$(lsb_release -rs)
    if [[ ! " ${supported_versions[@]} " =~ " ${ubuntu_version} " ]]; then echo -e "${YELLOW}Figyelem: Nem támogatott Ubuntu verzió: ${ubuntu_version}. Folytatás saját felelősségre.${NC}"; else echo -e "${GREEN}Ubuntu ${ubuntu_version} (Codename: ${UBUNTU_CODENAME}) támogatott.${NC}"; fi
}

check_resources() {
    echo -e "${YELLOW}Erőforrás ellenőrzések...${NC}"
    local required_disk=500  # MB
    local required_memory=1024 # MB
    local available_disk=$(df / | awk 'NR==2 {print int($4/1024)}')
    local available_memory=$(free -m | awk 'NR==2 {print $7}')
    if [[ $available_disk -lt $required_disk ]]; then echo -e "${RED}Hiba: Nincs elég (legalább ${required_disk} MB) hely a telepítéshez. Elérhető: ${available_disk} MB${NC}"; exit 1; fi
    if [[ $available_memory -lt $required_memory ]]; then echo -e "${YELLOW}Figyelem: Kevesebb mint $required_memory MB memória áll rendelkezésre. Elérhető: ${available_memory} MB.${NC}"; fi
    echo -e "${GREEN}Erőforrások elegendőnek tűnnek.${NC}"
}

create_backup() {
    echo -e "${YELLOW}Biztonsági mentés készítése...${NC}"
    BACKUP_DIR="/root/pritunl_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR" || { echo -e "${RED}Hiba: A biztonsági mentési könyvtár létrehozása sikertelen.${NC}"; exit 1; }
    cp -r /etc/apt/sources.list.d/ "$BACKUP_DIR/sources.list.d" 2>/dev/null || true
    cp -r /etc/ufw/ "$BACKUP_DIR/ufw" 2>/dev/null || true
    echo -e "${GREEN}Biztonsági mentés mentve ide: ${BACKUP_DIR}${NC}"
}

check_dependencies() {
    echo -e "${YELLOW}Függőségek (curl, gpg, ufw) ellenőrzése...${NC}"
    local dependencies=("curl" "gpg" "systemctl")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${YELLOW}Hiányzó függőség: $dep. Telepítés...${NC}"
            apt update > /dev/null
            apt install -y "$dep" || { echo -e "${RED}Hiba: $dep telepítése sikertelen.${NC}"; return 1; }
        fi
    done
    return 0
}

get_gpg_fingerprint() {
    local key_file="$1"
    gpg --with-fingerprint --with-colons "$key_file" 2>/dev/null | \
    awk -F: '$1 == "fpr" {print $10; exit}'
}

download_and_verify_key() {
    local url=$1
    local output_file=$2
    local expected_fingerprint=$3
    local key_name=$4

    echo -e "${WHITE}Letöltés és importálás: ${key_name} GPG kulcs...${NC}"
    
    if ! curl -fsSL "$url" | gpg --dearmor -o "$output_file" --yes; then
        echo -e "${RED}Hiba: ${key_name} kulcs letöltése vagy importálása sikertelen.${NC}"
        exit 1
    fi
    
    if [[ -n "$expected_fingerprint" ]]; then
        local actual_fingerprint
        actual_fingerprint=$(get_gpg_fingerprint "$output_file")

        if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
            echo -e "${RED}Hiba: Érvénytelen ${key_name} GPG kulcs ujjlenyomat!${NC}"
            echo -e "${RED}Várt: ${expected_fingerprint}${NC}"
            echo -e "${RED}Kapott: ${actual_fingerprint}${NC}"
            exit 1
        fi
        echo -e "${GREEN}${key_name} GPG kulcs ellenőrizve.${NC}"
    fi
}

configure_ufw() {
    echo -e "${YELLOW}Tűzfal (UFW) konfigurálása...${NC}"
    if ! command -v ufw >/dev/null 2>&1; then
        echo -e "${YELLOW}UFW telepítése...${NC}"
        if ! apt install -y ufw; then echo -e "${RED}Hiba: Az UFW telepítése sikertelen. Folytatás tűzfal nélkül...${NC}"; return 1; fi
    fi
    ufw --force reset
    ufw allow ssh comment 'SSH access'
    ufw allow 80/tcp comment 'HTTP (LetsEncrypt)'
    ufw allow 443/tcp comment 'HTTPS (Pritunl Web UI)'
    ufw allow 1194/udp comment 'OpenVPN default port'
    ufw allow 51820/udp comment 'WireGuard Default Port'
    ufw allow 2014/tcp comment 'Pritunl Zero Trust'
    ufw allow 2015/tcp comment 'Pritunl HTTP Proxy'
    ufw allow 9700:9800/tcp comment 'Pritunl User Port Range'
    ufw --force enable || { echo -e "${RED}Hiba: UFW engedélyezése sikertelen.${NC}"; exit 1; }
    echo -e "${GREEN}UFW konfigurálva és engedélyezve a szükséges portokon.${NC}"
}

post_installation_check() {
    echo -e "${YELLOW}==============================================${NC}"
    echo -e "${YELLOW}Telepítés utáni automatikus ellenőrzések...${NC}"
    local services_ok=true
    local services=("pritunl" "mongod")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then echo -e "${GREEN}✓ $service szolgáltatás fut${NC}"; else echo -e "${RED}✗ $service szolgáltatás NEM fut${NC}"; services_ok=false; fi
    done
    local ports_ok=true
    local ports=("443" "1194" "9700")
    echo -e "${WHITE}Portok ellenőrzése (ss -tuln)...${NC}"
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then echo -e "${GREEN}✓ Port $port nyitva (LISTEN)${NC}"; else echo -e "${YELLOW}⚠ Port $port nem figyel (LISTEN)${NC}"; ports_ok=false; fi
    done
    if $services_ok && $ports_ok; then echo -e "${GREEN}${BOLD}Alapvető ellenőrzések sikeresen befejeződtek!${NC}"; else echo -e "${YELLOW}Figyelem: Néhány ellenőrzés hibát jelzett. Kérem, ellenőrizze a logot.${NC}"; fi
}

verify_configuration() {
    echo -e "${YELLOW}Konfigurációs fájlok ellenőrzése...${NC}"
    local important_files=( "/etc/apt/sources.list.d/pritunl.list" "/etc/pritunl.conf" "/etc/mongod.conf" )
    for file in "${important_files[@]}"; do
        if [[ -f "$file" ]]; then echo -e "${GREEN}✓ $file létezik${NC}"; else echo -e "${YELLOW}⚠ $file nem található${NC}"; fi
    done
}

check_status() {
    echo -e "${YELLOW}==============================================${NC}"
    echo -e "${YELLOW}Pritunl és MongoDB állapot ellenőrzése...${NC}"
    echo -e "${YELLOW}==============================================${NC}"
    
    echo -e "${WHITE}Pritunl állapota:${NC}"
    systemctl status pritunl | grep -E 'Active|Load' || echo -e "${RED}Szolgáltatás nem található/ellenőrizhető.${NC}"
    echo ""
    
    echo -e "${WHITE}MongoDB (mongod) állapota:${NC}"
    systemctl status mongod | grep -E 'Active|Load' || echo -e "${RED}Szolgáltatás nem található/ellenőrizhető.${NC}"
    echo ""

    echo -e "${WHITE}UFW állapota (Tűzfal):${NC}"
    if command -v ufw &> /dev/null; then
        ufw status | head -n 8 | tail -n 7
    else
        echo -e "${YELLOW}UFW nincs telepítve.${NC}"
    fi
    echo ""
    
    echo -e "${WHITE}WireGuard telepítés ellenőrzése:${NC}"
    dpkg -l wireguard-tools 2>/dev/null | grep ii || echo -e "${YELLOW}A WireGuard Tools csomag nem telepített.${NC}"
    
    echo -e "${GREEN}Ellenőrzés befejezve.${NC}"
}

# --- Fő Telepítési Funkció ---
install_pritunl() {
    echo -e "${YELLOW}==============================================${NC}"
    echo -e "${YELLOW}${BOLD}Pritunl, MongoDB és Wireguard telepítése...${NC}"
    echo -e "${YELLOW}==============================================${NC}"
    
    trap 'rollback_installation' ERR
    
    create_backup
    check_system_compatibility
    check_resources
    check_dependencies

    read -r -p "Biztosan folytatja a telepítést? (i/n): " confirm
    
    if [[ "$confirm" != [iI] ]]; then
        echo -e "${RED}Telepítés megszakítva.${NC}"
        trap - ERR
        return
    fi
    
    # --- GPG Kulcsok Importálása és Ellenőrzése (JAVÍTOTT V3.2) ---
    echo -e "${YELLOW}GPG kulcsok importálása és ellenőrzése...${NC}"

    # MongoDB 8.0
    download_and_verify_key \
        "https://www.mongodb.org/static/pgp/server-8.0.asc" \
        "/usr/share/keyrings/mongodb-server-8.0.gpg" \
        "4B0752C1BCA238C0B4EE14DC41DE058A4E7DCA05" \
        "MongoDB"

    # OpenVPN
    download_and_verify_key \
        "https://swupdate.openvpn.net/repos/repo-public.gpg" \
        "/usr/share/keyrings/openvpn-repo.gpg" \
        "30EBF4E73CCE63EEE124DD278E6DA8B4E158C569" \
        "OpenVPN"

    # Pritunl (JAVÍTVA v3.2-ben)
    download_and_verify_key \
        "https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc" \
        "/usr/share/keyrings/pritunl.gpg" \
        "7568D9BB55FF9E5287D586017AE645C0CF8E292A" \
        "Pritunl"

    # --- Tárolók Hozzáadása (Dinamikus kódnévvel) ---
    echo -e "${YELLOW}Tárolók hozzáadása dinamikus kódnévvel (${UBUNTU_CODENAME})...${NC}"
    
    tee /etc/apt/sources.list.d/mongodb-org.list > /dev/null << EOF
deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${UBUNTU_CODENAME}/mongodb-org/8.0 multiverse
EOF

    tee /etc/apt/sources.list.d/openvpn.list > /dev/null << EOF
deb [ signed-by=/usr/share/keyrings/openvpn-repo.gpg ] https://build.openvpn.net/debian/openvpn/stable ${UBUNTU_CODENAME} main
EOF

    tee /etc/apt/sources.list.d/pritunl.list > /dev/null << EOF
deb [ signed-by=/usr/share/keyrings/pritunl.gpg ] https://repo.pritunl.com/stable/apt ${UBUNTU_CODENAME} main
EOF

    echo -e "${YELLOW}Csomaglista frissítése...${NC}"
    apt update

    echo -e "${YELLOW}Pritunl, OpenVPN, MongoDB és Wireguard telepítése...${NC}"
    apt --assume-yes install pritunl openvpn mongodb-org wireguard wireguard-tools

    configure_ufw

    echo -e "${YELLOW}Szolgáltatások indítása és engedélyezése...${NC}"
    systemctl start pritunl mongod
    systemctl enable pritunl mongod

    post_installation_check
    verify_configuration

    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}${BOLD}Telepítés sikeresen befejeződött!${NC}${GREEN}"
    echo -e "${GREEN}A Pritunl most már elérhető a https://IP-címed címen (port: 443).${NC}"
    echo -e "${GREEN}A kezdeti bejelentkezési adatokhoz futtasd a 'pritunl setup-key' parancsot!${NC}"
    echo -e "${GREEN}==============================================${NC}"
    
    trap - ERR
}

# --- Fő Menü Funkció ---
show_menu() {
    while true; do
        echo -e "${YELLOW}==============================================${NC}"
        echo -e "${BOLD}${WHITE}Pritunl Telepítő Szkript (DevOFALL 2025) v3.2${NC}"
        echo -e "${YELLOW}==============================================${NC}"
        echo -e "${WHITE}Válasszon egy opciót:${NC}"
        echo -e "  ${GREEN}1)${WHITE} Pritunl telepítése ${BOLD}(Biztonságos verzió)${NC}"
        echo -e "  ${GREEN}2)${WHITE} Pritunl és MongoDB ${BOLD}ÁLLAPOTÁNAK ELLENŐRZÉSE${NC}"
        echo -e "  ${RED}3)${WHITE} Kilépés${NC}"
        echo -e "${YELLOW}==============================================${NC}"
        
        read -r -p "Opció (1-3): " choice
        
        case "$choice" in
            1)
                install_pritunl
                ;;
            2)
                check_status
                ;;
            3)
                echo -e "${GREEN}Viszlát! 👋${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Érvénytelen választás. Kérem, válasszon 1, 2 vagy 3 közül.${NC}"
                ;;
        esac
        echo -e "\n"
    done
}

# --- Script Indítása ---
# Ezeknek a hívásoknak kell a legvégén lenniük, miután minden függvény definiálva van!
check_root
setup_logging
show_menu
