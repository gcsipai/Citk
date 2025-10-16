#!/bin/bash

# Ellenőrizzük, hogy a szkript root felhasználóként fut-e
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m⚠️ Ez a szkript root jogosultságokat igényel. Kérjük, futtassa 'sudo' vagy 'su' használatával.\033[0m"
    exit 1
fi

# Debian színek
DEBIAN_RED="\033[1;31m"
DEBIAN_GREEN="\033[1;32m"
DEBIAN_BLUE="\033[1;34m"
DEBIAN_YELLOW="\033[1;33m"
DEBIAN_PURPLE="\033[1;35m"
DEBIAN_CYAN="\033[1;36m"
DEBIAN_WHITE="\033[1;37m"
DEBIAN_RESET="\033[0m"

# A szkript interaktív menüjének megjelenítése
show_main_menu() {
    clear
    echo -e "${DEBIAN_RED}=========================================${DEBIAN_RESET}"
    echo -e "${DEBIAN_RED}Debian 13 Beállító Szkript 1.6a Citk 2025${DEBIAN_RESET}"
    echo -e "${DEBIAN_RED}=========================================${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}1. Csomagforrások konfigurálása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}2. Rendszer frissítése (apt update & upgrade)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}3. Alapvető alkalmazások telepítése${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}4. Hálózati beállítások (NetworkManager)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}5. Időzóna és NTP beállítások${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}6. Hostnév és FQDN beállítása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}7. Felhasználókezelés${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}8. SSH root bejelentkezés engedélyezése${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}9. Rendszeradatok listázása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}10. Cockpit telepítése és beállítása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}11. SSH bejelentkező szöveg szerkesztése${DEBIAN_RESET}"
    echo -e "${DEBIAN_RED}12. Kilépés${DEBIAN_RESET}"
    echo -e "${DEBIAN_RED}=========================================${DEBIAN_RESET}"
    read -p "Válassz egy opciót: " choice
}

# --- Segédfunkciók ---

# Ellenőrzi és hozzáadja a trixie repókat
check_and_configure_trixie_repos() {
    if ! grep -q "trixie main" /etc/apt/sources.list; then
        echo -e "${DEBIAN_YELLOW}⚙️ A sources.list fájl hiányos vagy hibás. Hozzáadjuk a 'trixie' repókat a teljes funkcionalitás érdekében.${DEBIAN_RESET}"
        configure_repos
        echo -e "${DEBIAN_BLUE}Csomaglista frissítése...${DEBIAN_RESET}"
        apt update
        echo -e "${DEBIAN_GREEN}✅ A csomaglista frissítése sikeres.${DEBIAN_RESET}"
    fi
}

# --- Időzóna és NTP funkciók ---

# Időzóna beállítása
configure_timezone() {
    echo -e "${DEBIAN_BLUE}🌍 Időzóna beállítása${DEBIAN_RESET}"
    
    # Jelenlegi időzóna megjelenítése
    echo -e "${DEBIAN_CYAN}Jelenlegi időzóna:${DEBIAN_RESET}"
    timedatectl status
    
    # Időzóna lista megjelenítése
    echo -e "${DEBIAN_CYAN}Elérhető időzónák (Európa/Budapest ajánlott):${DEBIAN_RESET}"
    timedatectl list-timezones | grep -E "Europe|UTC" | head -20
    
    read -p "Add meg az új időzónát (pl. Europe/Budapest): " timezone
    
    if timedatectl set-timezone "$timezone"; then
        echo -e "${DEBIAN_GREEN}✅ Időzóna beállítva: $timezone${DEBIAN_RESET}"
    else
        echo -e "${DEBIAN_RED}❌ Hiba az időzóna beállítása során.${DEBIAN_RESET}"
    fi
    
    echo -e "${DEBIAN_CYAN}Friss időzóna információk:${DEBIAN_RESET}"
    timedatectl status
    read -p "Nyomj Entert a folytatáshoz..."
}

# NTP beállítása magyar szerverekkel
configure_ntp() {
    echo -e "${DEBIAN_BLUE}⏰ NTP (időszinkronizáció) beállítása${DEBIAN_RESET}"
    
    # Ellenőrizzük, hogy systemd-timesyncd fut-e
    if systemctl is-active systemd-timesyncd >/dev/null 2>&1; then
        echo -e "${DEBIAN_CYAN}Jelenlegi NTP beállítások:${DEBIAN_RESET}"
        timedatectl timesync-status
        
        echo -e "${DEBIAN_YELLOW}⚠️ Magyar NTP szerverek beállítása...${DEBIAN_RESET}"
        
        # timesyncd konfigurációjának módosítása
        cat <<EOF > /etc/systemd/timesyncd.conf
[Time]
# Magyar NTP szerverek
NTP=ntp.bme.hu time.kfki.hu pool.ntp.org
FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
        
        # Szolgáltatás újraindítása
        systemctl daemon-reload
        systemctl restart systemd-timesyncd
        systemctl enable systemd-timesyncd
        
        echo -e "${DEBIAN_GREEN}✅ NTP szerverek beállítva: ntp.bme.hu, time.kfki.hu${DEBIAN_RESET}"
        
        # Várjunk egy kicsit, majd ellenőrizzük
        sleep 3
        echo -e "${DEBIAN_CYAN}Friss NTP állapot:${DEBIAN_RESET}"
        timedatectl timesync-status
    else
        echo -e "${DEBIAN_RED}❌ A systemd-timesyncd szolgáltatás nem aktív.${DEBIAN_RESET}"
    fi
    
    read -p "Nyomj Entert a folytatáshoz..."
}

# Kézi idő beállítása
set_manual_time() {
    echo -e "${DEBIAN_BLUE}🕐 Kézi dátum és idő beállítása${DEBIAN_RESET}"
    
    echo -e "${DEBIAN_CYAN}Jelenlegi dátum és idő:${DEBIAN_RESET}"
    date
    
    read -p "Add meg az új dátumot (ÉÉÉÉ-HH-NN formátumban, pl. 2025-01-15): " new_date
    read -p "Add meg az új időt (ÓÓ:PP:MM formátumban, pl. 14:30:00): " new_time
    
    if [ -n "$new_date" ] && [ -n "$new_time" ]; then
        if timedatectl set-time "${new_date} ${new_time}"; then
            echo -e "${DEBIAN_GREEN}✅ Dátum és idő beállítva: ${new_date} ${new_time}${DEBIAN_RESET}"
        else
            echo -e "${DEBIAN_RED}❌ Hiba a dátum és idő beállítása során.${DEBIAN_RESET}"
        fi
    else
        echo -e "${DEBIAN_YELLOW}⚠️ Dátum és idő megadása kötelező.${DEBIAN_RESET}"
    fi
    
    echo -e "${DEBIAN_CYAN}Friss dátum és idő:${DEBIAN_RESET}"
    date
    read -p "Nyomj Entert a folytatáshoz..."
}

# NTP szolgáltatás állapotának ellenőrzése
check_ntp_status() {
    echo -e "${DEBIAN_BLUE}📊 NTP szolgáltatás állapotának ellenőrzése${DEBIAN_RESET}"
    
    echo -e "${DEBIAN_CYAN}Timedatectl állapot:${DEBIAN_RESET}"
    timedatectl status
    
    echo -e "${DEBIAN_CYAN}NTP szinkronizációs állapot:${DEBIAN_RESET}"
    if systemctl is-active systemd-timesyncd >/dev/null 2>&1; then
        timedatectl timesync-status --no-pager
    else
        echo -e "${DEBIAN_RED}❌ A systemd-timesyncd szolgáltatás nem fut.${DEBIAN_RESET}"
    fi
    
    echo -e "${DEBIAN_CYAN}Aktuális NTP kapcsolatok:${DEBIAN_RESET}"
    ss -tuln | grep :123 || echo -e "${DEBIAN_YELLOW}Nincs aktív NTP kapcsolat.${DEBIAN_RESET}"
    
    read -p "Nyomj Entert a folytatáshoz..."
}

# Időbeállítási menü
show_time_menu() {
    clear
    echo -e "${DEBIAN_BLUE}--- Időzóna és NTP Beállítások ---${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}1. Időzóna beállítása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}2. NTP beállítása magyar szerverekkel${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}3. Kézi dátum és idő beállítása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}4. NTP állapot ellenőrzése${DEBIAN_RESET}"
    echo -e "${DEBIAN_RED}5. Vissza a főmenübe${DEBIAN_RESET}"
    echo -e "${DEBIAN_BLUE}-----------------------------------${DEBIAN_RESET}"
    read -p "Válassz egy időbeállítási opciót: " time_choice

    case $time_choice in
        1) configure_timezone ;;
        2) configure_ntp ;;
        3) set_manual_time ;;
        4) check_ntp_status ;;
        5) return ;;
        *) echo -e "${DEBIAN_RED}Érvénytelen választás.${DEBIAN_RESET}"; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
}

# --- Csomagkezelési és telepítési funkciók ---

# Csomagforrások konfigurálása
configure_repos() {
    echo -e "${DEBIAN_BLUE}⚙️ Csomagforrások konfigurálása...${DEBIAN_RESET}"
    
    # Eltávolítjuk a régi repókat, és hozzáadjuk a Debian 13 "trixie" repókat
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free non-free-firmware
EOF
    
    echo -e "${DEBIAN_GREEN}✅ Csomagforrások sikeresen konfigurálva 'trixie'-re.${DEBIAN_RESET}"
    echo -e "${DEBIAN_YELLOW}Most frissíteni kell a csomaglistát az új beállítások érvénybelépéséhez.${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# Rendszer frissítése
update_system() {
    check_and_configure_trixie_repos
    echo -e "${DEBIAN_BLUE}🔄 Rendszer frissítése...${DEBIAN_RESET}"
    apt update
    apt upgrade -y
    echo -e "${DEBIAN_GREEN}✅ A rendszer naprakész.${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# Alapvető alkalmazások telepítése
install_basic_apps() {
    check_and_configure_trixie_repos
    echo -e "${DEBIAN_BLUE}🚀 Alapvető alkalmazások telepítése: mc, unzip, zip, htop, bpytop, curl...${DEBIAN_RESET}"
    apt update
    if ! apt install -y mc unzip zip htop bpytop curl; then
        echo -e "${DEBIAN_RED}❌ Hiba az alapvető alkalmazások telepítése során.${DEBIAN_RESET}"
        read -p "Nyomj Entert a folytatáshoz..."
        return
    fi
    echo -e "${DEBIAN_GREEN}✅ Az alkalmazások sikeresen telepítve.${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Hálózati funkciók (NetworkManager alapú) ---

install_network_dependencies() {
    check_and_configure_trixie_repos
    echo -e "${DEBIAN_BLUE}🚀 A szükséges hálózati függőségek telepítése: network-manager, net-tools, ifenslave, vlan...${DEBIAN_RESET}"
    
    apt update
    if ! apt install -y network-manager net-tools ifenslave vlan; then
        echo -e "${DEBIAN_RED}❌ Hiba a hálózati csomagok telepítése során.${DEBIAN_RESET}"
        read -p "Nyomj Entert a folytatáshoz..."
        return
    fi
    
    echo -e "${DEBIAN_YELLOW}🔄 A hagyományos 'ifupdown' és 'systemd-networkd' rendszer letiltása...${DEBIAN_RESET}"
    systemctl stop networking 2>/dev/null || true
    systemctl disable networking 2>/dev/null || true
    systemctl mask networking
    
    systemctl stop systemd-networkd 2>/dev/null || true
    systemctl disable systemd-networkd 2>/dev/null || true
    systemctl mask systemd-networkd

    echo -e "${DEBIAN_GREEN}✅ A NetworkManager engedélyezése és indítása...${DEBIAN_RESET}"
    systemctl unmask NetworkManager
    systemctl enable --now NetworkManager
    
    echo -e "${DEBIAN_BLUE}⚙️ NetworkManager konfiguráció beállítása managed=true-ra...${DEBIAN_RESET}"
    if [ -f "/etc/NetworkManager/NetworkManager.conf" ]; then
        if ! grep -q "managed=true" /etc/NetworkManager/NetworkManager.conf; then
            sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
        fi
    fi

    echo -e "${DEBIAN_BLUE}⚙️ /etc/network/interfaces fájl megtisztítása a konfliktusok elkerülése érdekében...${DEBIAN_RESET}"
    if [ -f "/etc/network/interfaces" ]; then
        cp /etc/network/interfaces /etc/network/interfaces.backup
        cat <<EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
EOF
        echo -e "${DEBIAN_GREEN}✅ interfaces fájl megtisztítva.${DEBIAN_RESET}"
    fi

    echo -e "${DEBIAN_GREEN}✅ A hálózati függőségek telepítése és a NetworkManager konfigurálása befejeződött.${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# NetworkManager problémák javítása
fix_network_manager_issues() {
    echo -e "${DEBIAN_BLUE}🔧 NetworkManager problémák diagnosztizálása és javítása...${DEBIAN_RESET}"
    echo -e "${DEBIAN_CYAN}1. NetworkManager szolgáltatás ellenőrzése...${DEBIAN_RESET}"
    systemctl status NetworkManager --no-pager -l
    
    echo -e "\n${DEBIAN_CYAN}2. Hálózati interfészek állapota:${DEBIAN_RESET}"
    nmcli device status
    
    echo -e "\n${DEBIAN_CYAN}3. /etc/network/interfaces fájl ellenőrzése:${DEBIAN_RESET}"
    if [ -f "/etc/network/interfaces" ]; then
        cat /etc/network/interfaces
        read -p "Szeretnéd megtisztítani az interfaces fájlt? (y/n): " clean_interfaces
        if [[ "$clean_interfaces" == "y" || "$clean_interfaces" == "Y" ]]; then
            cp /etc/network/interfaces /etc/network/interfaces.backup
            cat <<EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
EOF
            echo -e "${DEBIAN_GREEN}✅ interfaces fájl megtisztítva${DEBIAN_RESET}"
        fi
    fi
    
    echo -e "\n${DEBIAN_CYAN}4. NetworkManager konfiguráció ellenőrzése:${DEBIAN_RESET}"
    if [ -f "/etc/NetworkManager/NetworkManager.conf" ]; then
        cat /etc/NetworkManager/NetworkManager.conf
        if ! grep -q "managed=true" /etc/NetworkManager/NetworkManager.conf; then
            echo -e "${DEBIAN_YELLOW}⚠️ NetworkManager nincs managed módban${DEBIAN_RESET}"
            read -p "Szeretnéd beállítani managed=true-ra? (y/n): " set_managed
            if [[ "$set_managed" == "y" || "$set_managed" == "Y" ]]; then
                sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
                echo -e "${DEBIAN_GREEN}✅ NetworkManager beállítva managed=true-ra${DEBIAN_RESET}"
            fi
        fi
    fi
    
    echo -e "\n${DEBIAN_BLUE}5. NetworkManager újraindítása...${DEBIAN_RESET}"
    systemctl restart NetworkManager
    sleep 3
    
    echo -e "\n${DEBIAN_CYAN}6. Végleges állapot ellenőrzése:${DEBIAN_RESET}"
    nmcli device status
    
    echo -e "\n${DEBIAN_GREEN}✅ NetworkManager problémajavítás befejezve${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# NetworkManager konfigurációs fájlok javítása
fix_nm_config_files() {
    echo -e "${DEBIAN_BLUE}🔧 NetworkManager konfigurációs fájlok javítása...${DEBIAN_RESET}"
    
    echo -e "${DEBIAN_CYAN}1. Netplan konfliktusok ellenőrzése és eltávolítása...${DEBIAN_RESET}"
    if [ -d "/etc/netplan/" ]; then
        echo -e "${DEBIAN_CYAN}Netplan fájlok a /etc/netplan/ könyvtárban:${DEBIAN_RESET}"
        ls -la /etc/netplan/
        
        conflicting_files=$(find /etc/netplan/ -name "*.yaml" -o -name "*.yml" 2>/dev/null || true)
        
        if [ -n "$conflicting_files" ]; then
            echo -e "${DEBIAN_YELLOW}⚠️ Netplan konfliktusok találhatók: $conflicting_files${DEBIAN_RESET}"
            read -p "Szeretnéd biztonsági másolatot készíteni és eltávolítani ezeket? (y/n): " remove_netplan
            if [[ "$remove_netplan" == "y" || "$remove_netplan" == "Y" ]]; then
                for file in $conflicting_files; do
                    backup_file="${file}.backup"
                    cp "$file" "$backup_file"
                    echo -e "${DEBIAN_GREEN}✅ $file biztonsági másolat készítve: $backup_file${DEBIAN_RESET}"
                    rm "$file"
                    echo -e "${DEBIAN_GREEN}✅ $file eltávolítva${DEBIAN_RESET}"
                done
                netplan apply
            fi
        else
            echo -e "${DEBIAN_GREEN}✅ Nincsenek Netplan konfliktusok${DEBIAN_RESET}"
        fi
    fi
    
    echo -e "\n${DEBIAN_CYAN}2. NetworkManager kapcsolati fájlok törlése...${DEBIAN_RESET}"
    read -p "Szeretnéd eltávolítani az összes NetworkManager kapcsolati fájlt? Ez újrakonfigurálást igényel! (y/n): " remove_nm_files
    if [[ "$remove_nm_files" == "y" || "$remove_nm_files" == "Y" ]]; then
        rm -f /etc/NetworkManager/system-connections/*
        echo -e "${DEBIAN_GREEN}✅ Összes kapcsolati fájl eltávolítva.${DEBIAN_RESET}"
    fi
    
    echo -e "\n${DEBIAN_BLUE}3. NetworkManager újraindítása...${DEBIAN_RESET}"
    systemctl restart NetworkManager
    sleep 3
    
    echo -e "\n${DEBIAN_GREEN}✅ Konfigurációs fájlok javítása befejeződött.${DEBIAN_RESET}"
    echo -e "${DEBIAN_YELLOW}Most hozz létre új kapcsolatokat az nmtui vagy nmcli használatával.${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# Statikus IP beállítása nmcli-vel
configure_static_ip_nmcli() {
    echo -e "${DEBIAN_BLUE}🔧 Statikus IP beállítása a NetworkManager-rel (nmcli)...${DEBIAN_RESET}"
    nmcli device status
    read -p "Add meg a konfigurálandó hálózati interfész nevét (pl. eth0 vagy ens33): " interface_name
    read -p "Add meg a kapcsolat nevét (pl. 'Static IP'): " connection_name
    
    # Kapcsolat létrehozása
    nmcli connection add type ethernet con-name "$connection_name" ifname "$interface_name"
    
    # Statikus IP beállítása
    echo -e "\n${DEBIAN_CYAN}--- Statikus IP cím beállítása ---${DEBIAN_RESET}"
    read -p "Add meg az IPv4 címet (pl. 192.168.1.100/24): " ip_address
    nmcli connection modify "$connection_name" ipv4.method manual ipv4.addresses "$ip_address"
    
    read -p "Add meg az IPv4 átjárót (pl. 192.168.1.1): " gateway
    nmcli connection modify "$connection_name" ipv4.gateway "$gateway"
    
    read -p "Add meg a DNS szervereket (szóközzel elválasztva, pl. 8.8.8.8 8.8.4.4): " dns_servers
    nmcli connection modify "$connection_name" ipv4.dns "$dns_servers"

    # IPv6 letiltása
    nmcli connection modify "$connection_name" ipv6.method disabled

    echo -e "${DEBIAN_GREEN}✅ Statikus IP beállításai elmentve.${DEBIAN_RESET}"
    
    # Kapcsolat aktiválása
    echo -e "\n${DEBIAN_BLUE}🔄 Kapcsolat aktiválása...${DEBIAN_RESET}"
    nmcli connection up "$connection_name"
    sleep 3
    
    echo -e "\n${DEBIAN_GREEN}✅ A(z) '$connection_name' nevű statikus kapcsolat aktív.${DEBIAN_RESET}"
    echo -e "${DEBIAN_CYAN}--- Aktuális hálózati beállítások ---${DEBIAN_RESET}"
    ip addr show "$interface_name"
    
    read -p "Nyomj Entert a folytatáshoz..."
}

# Hálózati naplók megjelenítése
show_network_logs() {
    echo -e "${DEBIAN_BLUE}📋 Hálózati naplók megjelenítése...${DEBIAN_RESET}"
    echo -e "${DEBIAN_CYAN}1. NetworkManager naplók (utolsó 20 sor):${DEBIAN_RESET}"
    journalctl -u NetworkManager -n 20 --no-pager
    
    echo -e "\n${DEBIAN_CYAN}2. Aktuális hálózati konfiguráció:${DEBIAN_RESET}"
    ip addr show
    
    echo -e "\n${DEBIAN_CYAN}3. Útválasztási tábla:${DEBIAN_RESET}"
    ip route show
    
    echo -e "\n${DEBIAN_CYAN}4. DNS beállítások:${DEBIAN_RESET}"
    cat /etc/resolv.conf
    
    read -p "Nyomj Entert a folytatáshoz..."
}

show_network_menu() {
    clear
    echo -e "${DEBIAN_BLUE}--- Hálózati Beállítások (NetworkManager) ---${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}0. Hálózati függőségek telepítése és konfigurálása (Ezzel kell kezdeni!)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}1. Hálózati beállítás grafikus karakteres felületen (nmtui)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}2. Statikus IP beállítása (nmcli)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}3. NetworkManager problémák javítása (diagnosztika)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}4. NM konfigurációs fájlok javítása (törlés)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}5. Hálózati interfészek listázása (nmcli)${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}6. Hálózati naplók megjelenítése${DEBIAN_RESET}"
    echo -e "${DEBIAN_RED}7. Vissza a főmenübe${DEBIAN_RESET}"
    echo -e "${DEBIAN_BLUE}----------------------------------------------${DEBIAN_RESET}"
    read -p "Válassz egy hálózati opciót: " net_choice

    case $net_choice in
        0) install_network_dependencies ;;
        1) 
            if command -v nmtui &> /dev/null; then
                nmtui
            else
                echo -e "${DEBIAN_RED}❌ Az nmtui nincs telepítve. Először telepítsd a hálózati függőségeket (0. opció).${DEBIAN_RESET}"
                read -p "Nyomj Entert a folytatáshoz..."
            fi
            ;;
        2) configure_static_ip_nmcli ;;
        3) fix_network_manager_issues ;;
        4) fix_nm_config_files ;;
        5) 
            echo -e "${DEBIAN_CYAN}--- Hálózati interfészek állapota ---${DEBIAN_RESET}"
            nmcli device status
            echo -e "\n${DEBIAN_CYAN}--- Részletes interfész információk ---${DEBIAN_RESET}"
            ip addr show
            read -p "Nyomj Entert a folytatáshoz..."
            ;;
        6) show_network_logs ;;
        7) return ;;
        *) echo -e "${DEBIAN_RED}Érvénytelen választás.${DEBIAN_RESET}"; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
}

# --- Felhasználókezelési funkciók ---

list_users() {
    echo -e "${DEBIAN_CYAN}--- Felhasználók listája ---${DEBIAN_RESET}"
    awk -F':' '{ print $1}' /etc/passwd | grep -v 'nologin' | grep -v 'false' | grep -v 'sync'
    read -p "Nyomj Entert a folytatáshoz..."
}

delete_user() {
    read -p "Add meg a törölni kívánt felhasználó nevét: " user_to_delete
    read -p "⚠️ Biztosan törölni szeretnéd a(z) '$user_to_delete' felhasználót és a home könyvtárát? (y/n): " confirm_delete
    if [[ "$confirm_delete" == "y" || "$confirm_delete" == "Y" ]]; then
        /usr/sbin/userdel -r "$user_to_delete"
        echo -e "${DEBIAN_GREEN}✅ A(z) '$user_to_delete' felhasználó sikeresen törölve.${DEBIAN_RESET}"
    else
        echo -e "${DEBIAN_RED}❌ Felhasználó törlése megszakítva.${DEBIAN_RESET}"
    fi
    read -p "Nyomj Entert a folytatáshoz..."
}

manage_users() {
    clear
    echo -e "${DEBIAN_BLUE}--- Felhasználókezelés ---${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}1. Új felhasználó hozzáadása és sudo beállítása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}2. Felhasználók listázása${DEBIAN_RESET}"
    echo -e "${DEBIAN_GREEN}3. Felhasználó törlése${DEBIAN_RESET}"
    echo -e "${DEBIAN_RED}4. Vissza a főmenübe${DEBIAN_RESET}"
    echo -e "${DEBIAN_BLUE}---------------------------${DEBIAN_RESET}"
    read -p "Válassz egy felhasználókezelési opciót: " user_choice
    case $user_choice in
        1) add_user_sudo ;;
        2) list_users ;;
        3) delete_user ;;
        4) return ;;
        *) echo -e "${DEBIAN_RED}Érvénytelen választás.${DEBIAN_RESET}"; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
}

add_user_sudo() {
    read -p "Add meg az új felhasználó nevét: " new_user
    /usr/sbin/adduser "$new_user"
    /usr/sbin/usermod -aG sudo "$new_user"
    echo -e "${DEBIAN_GREEN}✅ A(z) '$new_user' felhasználó hozzáadva és a 'sudo' csoporthoz rendelve.${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Egyéb konfigurációs funkciók ---

# Hostnév és FQDN beállítása
configure_hostname() {
    read -p "Add meg az új hosztnevet: " new_hostname
    hostnamectl set-hostname "$new_hostname"
    
    if grep -q "127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*$/127.0.1.1\t$new_hostname.local\t$new_hostname/" /etc/hosts
    else
        echo -e "127.0.1.1\t$new_hostname.local\t$new_hostname" | tee -a /etc/hosts > /dev/null
    fi
    echo -e "${DEBIAN_GREEN}✅ Hostnév beállítva: $new_hostname${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# SSH root bejelentkezés engedélyezése
enable_ssh_root() {
    echo -e "${DEBIAN_RED}⚠️ FIGYELEM: A root bejelentkezés engedélyezése biztonsági kockázatot jelent.${DEBIAN_RESET}"
    read -p "Biztosan folytatod? (y/n): " ssh_choice
    if [[ "$ssh_choice" == "y" || "$ssh_choice" == "Y" ]]; then
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl restart sshd
        echo -e "${DEBIAN_GREEN}✅ SSH root bejelentkezés engedélyezve.${DEBIAN_RESET}"
    else
        echo -e "${DEBIAN_RED}❌ Művelet megszakítva.${DEBIAN_RESET}"
    fi
    read -p "Nyomj Entert a folytatáshoz..."
}

# Rendszeradatok listázása
list_system_info() {
    echo -e "${DEBIAN_CYAN}--- Rendszerinformációk ---${DEBIAN_RESET}"
    hostnamectl
    echo -e "${DEBIAN_CYAN}--- OS információ ---${DEBIAN_RESET}"
    lsb_release -a
    echo -e "${DEBIAN_CYAN}--- Kernel információ ---${DEBIAN_RESET}"
    uname -a
    echo -e "${DEBIAN_CYAN}--- CPU információ ---${DEBIAN_RESET}"
    lscpu
    read -p "Nyomj Entert a folytatáshoz..."
}

# Cockpit telepítése és beállítása
install_cockpit() {
    check_and_configure_trixie_repos
    echo -e "${DEBIAN_BLUE}🚀 Cockpit telepítése...${DEBIAN_RESET}"
    apt update
    apt install -y cockpit
    systemctl enable --now cockpit.socket
    echo -e "${DEBIAN_GREEN}✅ Cockpit telepítve és fut.${DEBIAN_RESET}"
    echo -e "${DEBIAN_CYAN}A webes felület a következő címen érhető el: https://<your-server-ip>:9090${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# SSH bejelentkező szöveg szerkesztése
edit_ssh_banner() {
    echo -e "${DEBIAN_BLUE}✍️ SSH bejelentkező szöveg szerkesztése.${DEBIAN_RESET}"
    
    if ! command -v nano &> /dev/null; then
        echo -e "${DEBIAN_YELLOW}A 'nano' szerkesztő nincs telepítve. Telepítjük...${DEBIAN_RESET}"
        apt update && apt install -y nano
    fi
    
    nano /etc/issue.net
    
    sed -i '/^Banner/d' /etc/ssh/sshd_config
    echo "Banner /etc/issue.net" | tee -a /etc/ssh/sshd_config > /dev/null
    systemctl restart sshd
    echo -e "${DEBIAN_GREEN}✅ SSH bejelentkező szöveg elmentve és beállítva.${DEBIAN_RESET}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# Fő ciklus
while true; do
    show_main_menu
    case $choice in
        1) configure_repos ;;
        2) update_system ;;
        3) install_basic_apps ;;
        4) show_network_menu ;;
        5) show_time_menu ;;
        6) configure_hostname ;;
        7) manage_users ;;
        8) enable_ssh_root ;;
        9) list_system_info ;;
        10) install_cockpit ;;
        11) edit_ssh_banner ;;
        12) echo -e "${DEBIAN_RED}👋 Viszlát!${DEBIAN_RESET}"; exit 0 ;;
        *) echo -e "${DEBIAN_RED}Érvénytelen választás. Kérlek, próbáld újra.${DEBIAN_RESET}"; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
done
