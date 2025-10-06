#!/bin/bash

# --- Színkódok az Ubuntu stílushoz (Lila/Narancs/Zöld/Piros) ---
PURPLE='\e[1;35m' # Ubuntu lila
ORANGE='\e[1;33m' # A narancs legközelebbi terminál színkódja (sárga)
GREEN='\e[1;32m' # Siker
RED='\e[1;31m' # Hiba/Figyelem
NC='\e[0m' # Nincs szín

# --- Globális változók és konfiguráció ---
SCRIPT_VERSION="2.0" # Verziószám frissítve a robusztus NM telepítés miatt
BACKUP_DIR="/root/script_backups"
LOG_FILE="/var/log/ubuntu_setup.log"
SCRIPT_NAME="ubuntu-22-25-defs.sh"

# Naplózási funkció
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Hibakezelés (Script Exit) - Csak kritikus rendszerellenőrzéseknél!
error_exit() {
    echo -e "${RED}❌ KRITIKUS HIBA: $1${NC}" >&2
    log_message "KRITIKUS HIBA: $1"
    exit 1
}

# Ellenőrizzük, hogy a szkript root felhasználóként fut-e
check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "Ez a szkript root jogosultságokat igényel. Kérjük, futtassa 'sudo' vagy 'su' használatával."
    fi
}

# Függőségek ellenőrzése
check_dependencies() {
    local missing_deps=()
    
    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi
    if ! command -v lsb_release &> /dev/null; then
        missing_deps+=("lsb-release")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${ORANGE}⚠️ Hiányzó alapvető függőségek telepítése: ${missing_deps[*]}${NC}"
        apt update && apt install -y "${missing_deps[@]}" || error_exit "Alapvető függőségek (lsb-release/bc) telepítése sikertelen"
    fi
}

# Biztonsági mentés könyvtár létrehozása
setup_backup_dir() {
    mkdir -p "$BACKUP_DIR"
}

# Operációs rendszer verziójának és kódnevének meghatározása
detect_os_info() {
    if ! command -v lsb_release &> /dev/null; then
        error_exit "Az lsb_release parancs nem elérhető. Telepítsd az lsb-release csomagot."
    fi
    
    OS_VERSION=$(lsb_release -rs)
    OS_CODENAME=$(lsb_release -cs)
    
    if [ -z "$OS_VERSION" ] || [ -z "$OS_CODENAME" ]; then
        error_exit "Nem sikerült meghatározni az operációs rendszer információit."
    fi
    
    echo -e "${GREEN}✅ Észlelt rendszer: Ubuntu $OS_VERSION ($OS_CODENAME)${NC}"
}

# Cél Ubuntu verzió kódnevének meghatározása
set_target_codename() {
    TARGET_CODENAME=""
    
    if [[ "$OS_VERSION" == "22.04" ]]; then
        TARGET_CODENAME="jammy"
    elif (( $(echo "$OS_VERSION >= 22.04" | bc -l 2>/dev/null) )); then
        TARGET_CODENAME="$OS_CODENAME"
        if [[ "$TARGET_CODENAME" == "n/a" || "$TARGET_CODENAME" == "" ]]; then
            TARGET_CODENAME="devel"
        fi
    else
        echo -e "${RED}⚠️ A szkript nem a 22.04 LTS vagy újabb Ubuntu Server rendszert futtatja. A csomagforrások konfigurálása hibás lehet! Folytatás 'jammy' kódnévvel (22.04).${NC}"
        TARGET_CODENAME="jammy"
    fi
}

# --- Csomagkezelési és telepítési funkciók (Repo) ---

# Ellenőrzi és konfigurálja az Ubuntu repókat (Előkészítő ellenőrzés)
check_and_configure_ubuntu_repos() {
    if ! grep -q "$TARGET_CODENAME main" /etc/apt/sources.list 2>/dev/null; then
        echo -e "${ORANGE}⚙️ A sources.list fájl hiányos vagy hibás. Hozzáadjuk a(z) '${TARGET_CODENAME}' repókat.${NC}"
        configure_repos
        if [ $? -ne 0 ]; then
            return 1 # Hiba volt a configure_repos-ban
        fi
        echo -e "${GREEN}✅ A csomaglista frissítése sikeres.${NC}"
    fi
    return 0
}

# Csomagforrások konfigurálása (1. menüpont)
configure_repos() {
    echo -e "${ORANGE}⚙️ Csomagforrások konfigurálása... Cél kódnév: ${TARGET_CODENAME}${NC}"
    
    local backup_file="$BACKUP_DIR/sources.list.backup.$(date +%Y%m%d_%H%M%S)"
    cp /etc/apt/sources.list "$backup_file" || { echo -e "${RED}❌ Hiba: sources.list biztonsági mentése sikertelen${NC}"; return 1; }
    echo -e "${GREEN}✅ Biztonsági mentés készült: $backup_file${NC}"
    
    cat <<EOF > /etc/apt/sources.list
# Ubuntu repók - konfigurálva a szkript által ($(date))
deb http://archive.ubuntu.com/ubuntu/ $TARGET_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $TARGET_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $TARGET_CODENAME-security main restricted universe multiverse
# deb http://archive.ubuntu.com/ubuntu/ $TARGET_CODENAME-backports main restricted universe multiverse
EOF
    
    echo -e "${GREEN}✅ Csomagforrások sikeresen konfigurálva '${TARGET_CODENAME}'-re.${NC}"
    log_message "Csomagforrások konfigurálva: $TARGET_CODENAME"

    echo "Csomaglista frissítése..."
    if ! apt update; then
        echo -e "${RED}❌ HIBA A FRISSÍTÉS SORÁN: Kérjük, ellenőrizd a sources.list fájlt a hálózati beállítások ellenőrzése után!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi

    echo -e "${GREEN}✅ Csomaglista frissítése sikeresen befejeződött a repók konfigurálása után.${NC}"
    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
    return 0
}

# Rendszer frissítése (2. menüpont)
update_system() {
    check_and_configure_ubuntu_repos || { read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"; return 1; }
    echo -e "${ORANGE}🔄 Rendszer frissítése...${NC}"
    
    if ! apt update; then
        echo -e "${RED}❌ HIBA: Hiba a csomaglisták frissítése során. Ellenőrizd a hálózati kapcsolatot és a repókat!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    if ! apt upgrade -y; then
        echo -e "${RED}❌ HIBA: Hiba a csomagok frissítése során. Lehet, hogy megszakadt a letöltés, vagy csomagütközés történt.${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    echo -e "${GREEN}✅ A rendszer naprakész.${NC}"
    log_message "Rendszer frissítve"
    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
    return 0
}

# Alapvető alkalmazások telepítése (3. menüpont)
install_basic_apps() {
    check_and_configure_ubuntu_repos || { read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"; return 1; }
    echo -e "${ORANGE}🚀 Alapvető alkalmazások telepítése...${NC}"
    
    local basic_packages=("mc" "unzip" "zip" "htop" "curl" "nano" "net-tools" "wget" "sudo")
    
    if ! apt update; then
        echo -e "${RED}❌ HIBA: Hiba a csomaglisták frissítése során a telepítés előtt.${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    local available_packages=()
    for pkg in "${basic_packages[@]}"; do
        if apt-cache show "$pkg" &>/dev/null; then
            available_packages+=("$pkg")
        else
            echo -e "${ORANGE}⚠️ A(z) '$pkg' csomag nem érhető el a jelenlegi repókban.${NC}"
        fi
    done
    
    if [ ${#available_packages[@]} -eq 0 ]; then
        echo -e "${RED}❌ Egyetlen csomag sem érhető el a telepítésre. Ellenőrizd a repókat!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    echo -e "Telepítendő csomagok: ${available_packages[*]}"
    
    if ! apt install -y "${available_packages[@]}"; then
        echo -e "${RED}❌ HIBA: Hiba az alapvető alkalmazások telepítése során. Nézz utána a hibaüzenetnek!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    # Külön kezelt opcionális csomag
    if apt-cache show bpytop &>/dev/null; then
        echo -e "${ORANGE}📊 bpytop telepítése...${NC}"
        apt install -y bpytop || echo -e "${ORANGE}⚠️ bpytop telepítése sikertelen, de a többi csomag telepítve lett.${NC}"
    fi
    
    echo -e "${GREEN}✅ Az alkalmazások sikeresen telepítve.${NC}"
    log_message "Alapvető alkalmazások telepítve"
    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
    return 0
}

# --- NetworkManager Telepítés és Konfiguráció ---

# NetworkManager és NMTUI telepítése (4. menü 1. opció)
install_network_manager() {
    check_and_configure_ubuntu_repos || { read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"; return 1; }
    echo -e "${ORANGE}🚀 NetworkManager telepítése...${NC}"

    local main_package=("network-manager")
    local ui_package=("nmtui")
    
    if ! apt update; then
        echo -e "${RED}❌ HIBA: Hiba a csomaglisták frissítése során NetworkManager telepítése előtt.${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    # 1. NetworkManager telepítése (ez a kritikus)
    if ! apt install -y "${main_package[@]}"; then
        echo -e "${RED}❌ KRITIKUS HIBA: A NetworkManager alapcsomag telepítése sikertelen!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    echo -e "${GREEN}✅ NetworkManager alapcsomag sikeresen telepítve.${NC}"

    # 2. NMTUI telepítése (ez az opcionális UI, de fontos a kényelem miatt)
    echo -e "${ORANGE}🖥️ NMTUI (Text UI) telepítése...${NC}"
    if ! apt install -y "${ui_package[@]}"; then
        echo -e "${ORANGE}⚠️ FIGYELEM: Az 'nmtui' csomag telepítése sikertelen volt. A NetworkManager funkcionalitás attól még működik (nmcli), de az NMTUI nem érhető el.${NC}"
    else
        echo -e "${GREEN}✅ NMTUI sikeresen telepítve.${NC}"
    fi

    # NetworkManager engedélyezése
    systemctl unmask NetworkManager || true
    systemctl enable NetworkManager
    systemctl start NetworkManager

    echo -e "${GREEN}✅ NetworkManager elindítva.${NC}"
    log_message "NetworkManager telepítve (nmtui opcionális)"
    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
    return 0
}

# Átváltás NetworkManager-re (Netplan konfiguráció módosítása)
switch_to_network_manager() {
    if ! command -v nmcli &> /dev/null; then
        echo -e "${RED}❌ A NetworkManager nincs telepítve. Kérlek, telepítsd az 1. opcióval!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi

    echo -e "${RED}⚠️ FIGYELEM: A NetworkManagerre való váltás letiltja a Netplan-t és újraindítja a hálózati szolgáltatásokat!${NC}"
    read -p "$(echo -e "${RED}Biztosan váltasz NetworkManager-re? (y/n): ${NC}")" confirm_switch
    if [[ "$confirm_switch" != "y" && "$confirm_switch" != "Y" ]]; then
        echo -e "${RED}❌ Váltás megszakítva.${NC}"
        return 0
    fi

    echo -e "${ORANGE}⚙️ Netplan konfiguráció átállítása NetworkManagerre...${NC}"

    local config_file="/etc/netplan/01-netcfg.yaml"
    local backup_file="$BACKUP_DIR/netplan.backup.nm-switch.$(date +%Y%m%d_%H%M%S).yaml"
    
    if [ -f "$config_file" ]; then
        cp "$config_file" "$backup_file" && echo -e "${GREEN}✅ Biztonsági mentés készült: $backup_file${NC}"
    fi

    cat <<EOF > "$config_file"
# This file is set to use NetworkManager for network configuration.
network:
  version: 2
  renderer: NetworkManager
EOF
    
    if ! netplan apply; then
        echo -e "${RED}❌ HIBA: Hiba a Netplan konfiguráció alkalmazása során. Kérjük, ellenőrizd a YAML fájlt, vagy a hálózati kapcsolatot!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi

    systemctl restart NetworkManager

    echo -e "${GREEN}✅ Sikeresen átváltottál NetworkManagerre! A hálózati beállításokat most már az NMTUI/NMCLI-vel kell kezelni.${NC}"
    log_message "Átváltás NetworkManagerre"
    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
}

# NetworkManager kezelő almenü
manage_network_manager() {
    if ! command -v nmcli &> /dev/null; then
        echo -e "${RED}❌ A NetworkManager nincs telepítve. Kérlek, telepítsd az 1. opcióval!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi

    while true; do
        clear
        echo -e "${PURPLE}--- NetworkManager Kezelés ---${NC}"
        
        # NMTUI elérhetőségének ellenőrzése
        if command -v nmtui &> /dev/null; then
            echo -e "1. Hálózati beállítások kezelése (nmtui)"
        else
            echo -e "1. Hálózati beállítások kezelése (nmtui) ${RED}(Nincs telepítve)${NC}"
        fi
        
        echo -e "2. Kapcsolatok listázása és állapot (nmcli)"
        echo -e "3. Vissza a Hálózati Beállítások menübe"
        echo -e "${PURPLE}-------------------------------${NC}"
        read -p "$(echo -e "${ORANGE}Válassz egy NetworkManager opciót: ${NC}")" nm_choice

        case $nm_choice in
            1)
                if command -v nmtui &> /dev/null; then
                    echo -e "${ORANGE}🔄 Elindítjuk az NMTUI (NetworkManager Text User Interface) alkalmazást...${NC}"
                    nmtui
                else
                    echo -e "${RED}❌ Az 'nmtui' nincs telepítve. Kérlek, használd az 'nmcli'-t vagy telepítsd újra az 1. menüponttal!${NC}"
                    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
                fi
                ;;
            2)
                echo -e "${PURPLE}--- NetworkManager Állapot (nmcli) ---${NC}"
                nmcli device
                nmcli connection show
                read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
                ;;
            3) return 0 ;;
            *) echo -e "${RED}Érvénytelen választás.${NC}"; read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")" ;;
        esac
    done
}

# --- Hálózati funkciók (Netplan alapú) ---

# Netplan fájlok listázása
list_netplan_files() {
    find /etc/netplan/ -name "*.yaml" -o -name "*.yml" 2>/dev/null
}

# Netplan YAML fájl alapvető struktúrájának létrehozása
create_basic_netplan_config() {
    echo -e "${ORANGE}⚙️ Alapvető Netplan konfiguráció létrehozása dhcp4-gyel...${NC}"
    local interface_name=$(ip -o link show | awk -F': ' '$2 != "lo" && $2 !~ /^docker/ && $2 !~ /^veth/ {print $2; exit}')
    if [ -z "$interface_name" ]; then echo -e "${RED}❌ Nem található hálózati interfész a Netplan konfigurációhoz!${NC}"; return 1; fi
    local config_file="/etc/netplan/01-netcfg.yaml"
    local backup_file="$BACKUP_DIR/netplan.backup.$(date +%Y%m%d_%H%M%S).yaml"
    if [ -f "$config_file" ]; then cp "$config_file" "$backup_file" && echo -e "${GREEN}✅ Biztonsági mentés készült: $backup_file${NC}"; fi
    mkdir -p /etc/netplan/
    cat <<EOF > "$config_file"
# This file is generated by the setup script.
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface_name:
      dhcp4: true
      dhcp6: false
EOF
    echo -e "${GREEN}✅ Alapvető Netplan konfiguráció ('$config_file') létrehozva a(z) '$interface_name' interfészre DHCP-vel.${NC}"
    log_message "Alap Netplan konfiguráció létrehozva: $interface_name"
}

apply_netplan_config() {
    echo -e "${ORANGE}🔄 Netplan konfiguráció ellenőrzése és alkalmazása...${NC}"
    if ! netplan generate; then 
        echo -e "${RED}❌ HIBA: Hiba a Netplan konfiguráció generálásában. Ellenőrizd a YAML szintaxisát!${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    if ! netplan try --timeout 30; then 
        echo -e "${RED}❌ HIBA: Hiba a Netplan konfigurációban. A módosítások nem kerültek alkalmazásra. Visszaállás történt.${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    echo -e "${GREEN}✅ Netplan konfiguráció sikeresen alkalmazva.${NC}"
    log_message "Netplan konfiguráció alkalmazva"
    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
}

# Hálózati naplók megjelenítése
show_netplan_logs() {
    echo -e "${ORANGE}📋 Hálózati naplók megjelenítése...${NC}"
    
    echo -e "\n${PURPLE}--- 1. systemd-networkd (Netplan) állapot és naplók ---${NC}"
    if systemctl is-active systemd-networkd &>/dev/null; then
        echo -e "${GREEN}✅ systemd-networkd aktív. Utolsó 20 sor:${NC}"
        journalctl -u systemd-networkd -n 20 --no-pager
    else
        echo -e "${RED}❌ systemd-networkd inaktív vagy nem fut.${NC}"
    fi
    
    echo -e "\n${PURPLE}--- 2. NetworkManager állapot és naplók ---${NC}"
    if systemctl is-active NetworkManager &>/dev/null; then
        echo -e "${GREEN}✅ NetworkManager aktív. Utolsó 20 sor:${NC}"
        journalctl -u NetworkManager -n 20 --no-pager
    else
        echo -e "${RED}❌ NetworkManager inaktív vagy nem fut.${NC}"
    fi
    
    echo -e "\n${PURPLE}--- 3. Aktuális hálózati konfiguráció (IP) ---${NC}"
    ip addr show
    
    echo -e "\n${PURPLE}--- 4. Útválasztási tábla ---${NC}"
    ip route show
    
    echo -e "\n${PURPLE}--- 5. DNS beállítások (/etc/resolv.conf) ---${NC}"
    cat /etc/resolv.conf 2>/dev/null || echo -e "${RED}Nem sikerült olvasni /etc/resolv.conf${NC}"

    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
}

# Hálózati Beállítások Főmenü
show_network_menu() {
    while true; do
        clear
        echo -e "${PURPLE}--- Hálózati Konfiguráció Kezelése ---${NC}"
        
        local renderer=$(grep "renderer:" /etc/netplan/*.yaml 2>/dev/null | head -n 1 | awk '{print $NF}')
        
        echo -e "Jelenlegi renderelő: ${ORANGE}${renderer:-networkd / n/a}${NC}"
        echo -e "${PURPLE}-------------------------------------${NC}"
        
        echo -e "I. NetworkManager Kezelés (${GREEN}NMCLI/NMTUI${NC})"
        echo -e "1. NetworkManager Telepítése és Konfigurálása"
        echo -e "2. Átváltás NetworkManager-re (Netplan módosítása)"
        echo -e "3. NetworkManager menü (NMTUI/NMCLI)"
        
        echo -e "${PURPLE}-------------------------------------${NC}"
        
        echo -e "II. Netplan Beállítások (${RED}networkd${NC})"
        echo -e "4. Netplan konfigurációs fájl szerkesztése (nano)"
        echo -e "5. Hálózati interfészek listázása (ip addr)"
        echo -e "6. Hálózati naplók megjelenítése"
        
        echo -e "${PURPLE}-------------------------------------${NC}"
        echo -e "7. Vissza a főmenübe"
        echo -e "${PURPLE}-------------------------------------${NC}"
        read -p "$(echo -e "${ORANGE}Válassz egy hálózati opciót: ${NC}")" net_choice

        case $net_choice in
            1) install_network_manager ;;
            2) switch_to_network_manager ;;
            3) manage_network_manager ;;
            4) 
                local netplan_files=$(list_netplan_files)
                if [ -z "$netplan_files" ]; then
                    create_basic_netplan_config
                    netplan_files=$(list_netplan_files)
                fi
                
                if [ -n "$netplan_files" ]; then
                    nano $netplan_files
                    apply_netplan_config
                else
                    echo -e "${RED}❌ Nincs szerkeszthető Netplan fájl${NC}"
                    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
                fi
                ;;
            5) 
                echo -e "${PURPLE}--- Hálózati interfészek állapota ---${NC}"
                ip addr show
                read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
                ;;
            6) show_netplan_logs ;;
            7) return 0 ;;
            *) echo -e "${RED}Érvénytelen választás.${NC}"; read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")" ;;
        esac
    done
}


# --- Felhasználókezelési funkciók ---

list_users() {
    echo -e "${PURPLE}--- Felhasználók listája ---${NC}"
    awk -F':' '{ if ($7 != "/usr/sbin/nologin" && $7 != "/bin/false") print $1 }' /etc/passwd
    echo -e "${PURPLE}--- Sudo joggal rendelkező felhasználók ---${NC}"
    getent group sudo | cut -d: -f4 | tr ',' '\n'
}

delete_user() {
    read -p "$(echo -e "${ORANGE}Add meg a törölni kívánt felhasználó nevét: ${NC}")" user_to_delete
    
    if ! id "$user_to_delete" &>/dev/null; then
        echo -e "${RED}❌ A(z) '$user_to_delete' felhasználó nem létezik${NC}"
        return 1
    fi
    
    if [ "$user_to_delete" == "root" ]; then
        echo -e "${RED}❌ A root felhasználó nem törölhető!${NC}"
        return 1
    fi
    
    read -p "$(echo -e "${RED}⚠️ Biztosan törölni szeretnéd a(z) '$user_to_delete' felhasználót és a home könyvtárát? (y/n): ${NC}")" confirm_delete
    if [[ "$confirm_delete" == "y" || "$confirm_delete" == "Y" ]]; then
        if userdel -r "$user_to_delete" 2>/dev/null; then
            echo -e "${GREEN}✅ A(z) '$user_to_delete' felhasználó sikeresen törölve.${NC}"
            log_message "Felhasználó törölve: $user_to_delete"
        else
            echo -e "${RED}❌ Hiba a felhasználó törlése során${NC}"
        fi
    else
        echo -e "${RED}❌ Felhasználó törlése megszakítva.${NC}"
    fi
}

add_user_sudo() {
    read -p "$(echo -e "${ORANGE}Add meg az új felhasználó nevét: ${NC}")" new_user
    
    if id "$new_user" &>/dev/null; then
        echo -e "${ORANGE}⚠️ A(z) '$new_user' felhasználó már létezik${NC}"
        read -p "$(echo -e "${ORANGE}Szeretnéd hozzáadni a sudo csoporthoz? (y/n): ${NC}")" add_sudo
        if [[ "$add_sudo" == "y" || "$add_sudo" == "Y" ]]; then
            usermod -aG sudo "$new_user"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ A(z) '$new_user' felhasználó hozzáadva a sudo csoporthoz.${NC}"
            else
                 echo -e "${RED}❌ Hiba a felhasználó sudo csoporthoz adása során.${NC}"
            fi
        fi
        return
    fi
    
    if adduser --gecos "" "$new_user"; then
        usermod -aG sudo "$new_user"
        echo -e "${GREEN}✅ A(z) '$new_user' felhasználó hozzáadva és a 'sudo' csoporthoz rendelve.${NC}"
        log_message "Felhasználó létrehozva: $new_user (sudo)"
    else
        echo -e "${RED}❌ Hiba a felhasználó létrehozása során${NC}"
    fi
}

manage_users() {
    while true; do
        clear
        echo -e "${PURPLE}--- Felhasználókezelés ---${NC}"
        echo -e "1. Új felhasználó hozzáadása és sudo beállítása"
        echo -e "2. Felhasználók listázása"
        echo -e "3. Felhasználó törlése"
        echo -e "4. Vissza a főmenübe"
        echo -e "${PURPLE}---------------------------${NC}"
        read -p "$(echo -e "${ORANGE}Válassz egy felhasználókezelési opciót: ${NC}")" user_choice
        
        case $user_choice in
            1) add_user_sudo ;;
            2) 
                list_users
                read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
                ;;
            3) delete_user ;;
            4) return 0 ;;
            *) echo -e "${RED}Érvénytelen választás.${NC}"; read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")" ;;
        esac
    done
}

# --- Egyéb konfigurációs funkciók ---

configure_hostname() {
    local current_hostname=$(hostname)
    echo -e "${ORANGE}Jelenlegi hosztnév: $current_hostname${NC}"
    read -p "$(echo -e "${ORANGE}Add meg az új hosztnevet: ${NC}")" new_hostname
    
    if [ -z "$new_hostname" ]; then
        echo -e "${RED}❌ A hosztnév nem lehet üres${NC}"
        return 1
    fi
    
    if hostnamectl set-hostname "$new_hostname"; then
        sed -i "/^127\.0\.1\.1/d" /etc/hosts
        echo -e "127.0.1.1\t$new_hostname.local\t$new_hostname" >> /etc/hosts
        
        echo -e "${GREEN}✅ Hostnév beállítva: $new_hostname${NC}"
        echo -e "${ORANGE}⚠️ A változások teljes érvényre jutásához lehet, hogy újra kell indítani a rendszert.${NC}"
        log_message "Hostnév módosítva: $current_hostname -> $new_hostname"
    else
        echo -e "${RED}❌ Hiba a hosztnév beállítása során${NC}"
    fi
}

enable_ssh_root() {
    echo -e "${RED}⚠️ FIGYELEM: A root bejelentkezés engedélyezése biztonsági kockázatot jelent!${NC}"
    echo -e "${ORANGE}Ajánlott alternatíva: használj sudo joggal rendelkező felhasználót SSH kulcsokkal.${NC}"
    
    read -p "$(echo -e "${RED}Biztosan folytatod? (y/n): ${NC}")" ssh_choice
    if [[ "$ssh_choice" != "y" && "$ssh_choice" != "Y" ]]; then
        echo -e "${RED}❌ Művelet megszakítva.${NC}"
        return 1
    fi
    
    local sshd_config="/etc/ssh/sshd_config"
    local backup_file="$BACKUP_DIR/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    
    cp "$sshd_config" "$backup_file" && echo -e "${GREEN}✅ Biztonsági mentés készült: $backup_file${NC}"
    
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$sshd_config"
    
    if ! grep -q "^PermitRootLogin yes" "$sshd_config"; then
        echo "PermitRootLogin yes" >> "$sshd_config"
    fi
    
    if systemctl restart sshd; then
        echo -e "${GREEN}✅ SSH root bejelentkezés engedélyezve.${NC}"
        log_message "SSH root login engedélyezve"
    else
        echo -e "${RED}❌ Hiba az SSH szolgáltatás újraindítása során${NC}"
    fi
}

# Rendszerinformációk listázása (8. menüpont)
list_system_info() {
    echo -e "${PURPLE}--- Rendszerinformációk ---${NC}"
    hostnamectl
    
    echo -e "${PURPLE}--- OS információ ---${NC}"
    lsb_release -a 2>/dev/null || echo "lsb_release nem elérhető"
    
    echo -e "${PURPLE}--- Kernel információ ---${NC}"
    uname -a
    
    echo -e "${PURPLE}--- Memória információ ---${NC}"
    free -h
    
    echo -e "${PURPLE}--- Lemez használat ---${NC}"
    df -h
    
    echo -e "${PURPLE}--- Uptime ---${NC}"
    uptime
    
    read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")" 
}

# Cockpit telepítése (9. menüpont)
install_cockpit() {
    check_and_configure_ubuntu_repos || { read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"; return 1; }
    echo -e "${ORANGE}🚀 Cockpit telepítése...${NC}"
    
    if ! apt update; then
        echo -e "${RED}❌ Hiba a csomaglisták frissítése során Cockpit telepítés előtt.${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
    
    if apt install -y cockpit; then
        systemctl enable --now cockpit.socket
        echo -e "${GREEN}✅ Cockpit telepítve és fut.${NC}"
        echo "A webes felület a következő címen érhető el: https://$(hostname -I | awk '{print $1}'):9090"
        log_message "Cockpit telepítve"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
    else
        echo -e "${RED}❌ Hiba a Cockpit telepítése során${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
        return 1
    fi
}

# SSH bejelentkező szöveg szerkesztése (10. menüpont)
edit_ssh_banner() {
    echo -e "${ORANGE}✍️ SSH bejelentkező szöveg szerkesztése (/etc/issue.net).${NC}"
    
    if ! command -v nano &> /dev/null; then
        echo "A 'nano' szerkesztő nincs telepítve. Telepítjük..."
        if ! apt update || ! apt install -y nano; then
            echo -e "${RED}❌ Nem sikerült telepíteni a nano szerkesztőt${NC}"
            read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
            return 1
        fi
    fi
    
    local banner_file="/etc/issue.net"
    local backup_file="$BACKUP_DIR/issue.net.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$banner_file" ]; then
        cp "$banner_file" "$backup_file" && echo -e "${GREEN}✅ Biztonsági mentés készült: $backup_file${NC}"
    fi
    
    nano "$banner_file"
    
    local sshd_config="/etc/ssh/sshd_config"
    if grep -q "^Banner" "$sshd_config"; then
        sed -i 's|^Banner.*|Banner /etc/issue.net|' "$sshd_config"
    else
        echo "Banner /etc/issue.net" >> "$sshd_config"
    fi
    
    if systemctl restart sshd; then
        echo -e "${GREEN}✅ SSH bejelentkező szöveg elmentve és beállítva.${NC}"
        log_message "SSH banner módosítva"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
    else
        echo -e "${RED}❌ Hiba az SSH szolgáltatás újraindítása során${NC}"
        read -p "$(echo -e "${ORANGE}Nyomj Entert a folytatáshoz...${NC}")"
    fi
}

# Főmenü megjelenítése
show_main_menu() {
    clear
    echo -e "${PURPLE}=========================================${NC}"
    echo -e "${ORANGE}Ubuntu Server Beállító Szkript $SCRIPT_VERSION${NC}"
    echo -e "(${SCRIPT_NAME})"
    echo -e "${PURPLE}=========================================${NC}"
    echo -e "Operációs rendszer: Ubuntu ${OS_VERSION} (${OS_CODENAME})"
    echo -e "Cél kódnév: ${TARGET_CODENAME}"
    echo -e "${PURPLE}=========================================${NC}"
    echo -e "1. Csomagforrások konfigurálása (${TARGET_CODENAME})"
    echo -e "2. Rendszer frissítése (apt update & upgrade)"
    echo -e "3. Alapvető alkalmazások telepítése"
    echo -e "4. ${GREEN}NetworkManager Telepítés és Hálózati Beállítások${NC}"
    echo -e "5. Hostnév és FQDN beállítása"
    echo -e "6. Felhasználókezelés"
    echo -e "7. SSH root bejelentkezés engedélyezése ${RED}(Nem ajánlott)${NC}"
    echo -e "8. Rendszeradatok listázása"
    echo -e "9. Cockpit telepítése és beállítása"
    echo -e "10. SSH bejelentkező szöveg szerkesztése"
    echo -e "11. Kilépés"
    echo -e "${PURPLE}=========================================${NC}"
    read -p "$(echo -e "${ORANGE}Válassz egy opciót: ${NC}")" choice
}

# Fő program
main() {
    # Inicializálás
    check_root_privileges
    setup_backup_dir
    check_dependencies
    detect_os_info
    set_target_codename
    
    echo -e "${GREEN}✅ Ubuntu Server Beállító Szkript $SCRIPT_VERSION inicializálva${NC}"
    echo -e "${GREEN}✅ Rendszer: Ubuntu ${OS_VERSION} (${OS_CODENAME})${NC}"
    echo -e "${GREEN}✅ Cél kódnév: ${TARGET_CODENAME}${NC}"
    log_message "Szkript elindítva - Ubuntu $OS_VERSION ($OS_CODENAME)"
    
    sleep 2
    
    # Főmenü ciklus
    while true; do
        show_main_menu
        case $choice in
            1) configure_repos ;;
            2) update_system ;;
            3) install_basic_apps ;;
            4) show_network_menu ;;
            5) configure_hostname ;;
            6) manage_users ;;
            7) enable_ssh_root ;;
            8) list_system_info ;;
            9) install_cockpit ;;
            10) edit_ssh_banner ;;
            11) 
                echo -e "${ORANGE}👋 Viszlát!${NC}"
                log_message "Szkript leállítva"
                exit 0 
                ;;
            *) 
                echo -e "${RED}Érvénytelen választás. Kérlek, próbáld újra.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Program indítása
main "$@"
