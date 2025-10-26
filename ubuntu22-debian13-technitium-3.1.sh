#!/bin/bash

# Színkódok definiálása tput segítségével
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)      # Reset all attributes

# Rendszer változók
SCRIPT_NAME="Technitium DNS Telepítő"
SCRIPT_VER="3.1 (Tiszta Behúzásokkal)"
SCRIPT_AUTHOR="DevOFALL"
SUPPORTED_OS=("Ubuntu" "Debian")

# Segédfüggvény gombnyomásra váráshoz
wait_for_key() {
    echo
    read -n 1 -s -r -p "${WHITE}Nyomj meg egy gombot a főmenübe való visszatéréshez...${RESET}"
    echo
}

# Függvény a rendszer ellenőrzéséhez
check_system() {
    echo "${YELLOW}--- Rendszer ellenőrzése ---${RESET}"
    local is_ok=0
    
    # OS ellenőrzés
    if [ ! -f /etc/os-release ]; then
        echo "${RED}HIBA: Nem található /etc/os-release fájl.${RESET}"
        is_ok=1
    else
        source /etc/os-release
        if [[ ! " ${SUPPORTED_OS[@]} " =~ " ${NAME} " ]]; then
            echo "${RED}HIBA: Nem támogatott operációs rendszer: ${NAME}${RESET}"
            echo "${WHITE}Támogatott rendszerek: ${SUPPORTED_OS[*]}${RESET}"
            is_ok=1
        else
            echo "${GREEN}✓ Operációs rendszer: ${NAME} ${VERSION_ID}${RESET}"
        fi
    fi
    
    # Root jogosultság ellenőrzése
    if [[ $EUID -ne 0 ]]; then
        echo "${RED}HIBA: A szkriptet root joggal kell futtatni!${RESET}"
        return 1
    fi
    echo "${GREEN}✓ Root jogosultság ellenőrizve.${RESET}"
    
    # Internet kapcsolat ellenőrzése
    if ! ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
        echo "${RED}HIBA: Nincs internet kapcsolat!${RESET}"
        is_ok=1
    else
        echo "${GREEN}✓ Internet kapcsolat elérhető${RESET}"
    fi
    
    return $is_ok
}

# Függvény a függőségek telepítéséhez
install_dependencies() {
    echo "${YELLOW}--- 1. Rendszerfrissítés és alapcsomagok telepítése ---${RESET}"
    echo "${WHITE}Először frissítjük a csomaglistákat (apt update)...${RESET}"
    
    if ! apt update; then
        echo "${RED}${BOLD}HIBA:${RESET} A csomaglisták frissítése sikertelen."
        return 1
    fi
    
    local packages=("curl" "tar" "iproute2" "procps")
    local packages_to_install=()
    
    # Csomagok ellenőrzése
    for package in "${packages[@]}"; do
        if ! dpkg -l 2>/dev/null | grep -q "^ii  $package "; then
            packages_to_install+=("$package")
        fi
    done
    
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo "${GREEN}Minden szükséges alapcsomag már telepítve van.${RESET}"
        return 0
    fi
    
    echo "${YELLOW}Telepítendő csomagok: ${packages_to_install[*]} (apt install -y)...${RESET}"
    
    if ! apt install -y "${packages_to_install[@]}"; then
        echo "${RED}${BOLD}HIBA:${RESET} A csomagok telepítése sikertelen."
        return 1
    fi
    
    echo "${GREEN}✓ A szükséges alapcsomagok telepítve.${RESET}"
    return 0
}

# Függvény a portütközések vizsgálatához
check_port() {
    local PORT=$1
    local PROTOCOL=$2
    local PROCESS_PID
    local PROCESS_NAME

    # Megpróbáljuk megtalálni a PID-et és a nevet
    PROCESS_PID=$(ss -Hltupn sport = :$PORT 2>/dev/null | awk '{print $NF}' | grep -oP 'pid=\K\d+' | head -n 1)

    if [ -n "$PROCESS_PID" ]; then
        # A PID alapján megkeressük a folyamat nevét
        PROCESS_NAME=$(ps -p "$PROCESS_PID" -o comm= 2>/dev/null || echo "Ismeretlen (PID: $PROCESS_PID)")
        echo "${RED}✗ FIGYELMEZTETÉS:${RESET} A ${BOLD}$PORT/$PROTOCOL${RESET} port foglalt: ${BOLD}${PROCESS_NAME}${RESET}"
        return 0 # Foglalt
    else
        echo "${GREEN}✓${RESET} A ${BOLD}$PORT/$PROTOCOL${RESET} port szabad."
        return 1 # Szabad
    fi
}

# Függvény a Portvizsgálat futtatásához
run_port_check() {
    echo "${YELLOW}--- 2. Kritikus portok ellenőrzése (53 és 5380) ---${RESET}"
    local IS_PORT_53_USED
    
    check_port 53 "UDP/TCP (DNS)"
    IS_PORT_53_USED=$?
    
    check_port 5380 "TCP (Web UI)"
    
    if [ $IS_PORT_53_USED -eq 0 ]; then
        echo
        echo "${RED}${BOLD}!!! DNS ÜTKÖZÉS LEHETSÉGES !!!${RESET}"
        echo "${WHITE}A ${GREEN}systemd-resolved${WHITE} (vagy más szolgáltatás) használja az ${BOLD}53-as portot${RESET}. Le kell állítani."
        echo "${WHITE}Javaslat: Használja a ${BOLD}3. menüpontot${RESET} a telepítés előtt.${RESET}"
    else
        echo
        echo "${GREEN}✓ Minden szükséges port szabad a Technitium telepítéséhez.${RESET}"
    fi
    
    wait_for_key
}

# Függvény a systemd-resolved leállításához
stop_and_mask_resolved() {
    echo "${YELLOW}--- 3. systemd-resolved leállítása és maszkolása ---${RESET}"
    echo "${WHITE}Ez felszabadítja az ${BOLD}53-as portot${RESET} a Technitium számára.${RESET}"
    
    if ! systemctl is-active systemd-resolved &>/dev/null; then
        echo "${GREEN}A systemd-resolved nem fut.${RESET}"
    else
        echo "${YELLOW}systemd-resolved szolgáltatás aktív. Leállítás...${RESET}"
        systemctl stop systemd-resolved
        echo "${GREEN}✓ systemd-resolved leállítva${RESET}"
    fi
    
    if systemctl is-enabled systemd-resolved &>/dev/null; then
        systemctl mask systemd-resolved
        echo "${GREEN}✓ systemd-resolved maszkolva${RESET}"
    else
        echo "${GREEN}A systemd-resolved már maszkolva van.${RESET}"
    fi
    
    echo "${WHITE}resolv.conf fájl biztonsági mentése és felülírása...${RESET}"
    cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    echo -e "nameserver 127.0.0.1\nnameserver 8.8.8.8\nnameserver 1.1.1.1" | tee /etc/resolv.conf > /dev/null
    echo "${WHITE}A /etc/resolv.conf most már a ${BOLD}127.0.0.1${RESET} IP-t használja.${RESET}"
    
    echo "${GREEN}${BOLD}✓ Sikeresen leállítva és maszkolva!${RESET}"
    echo "${YELLOW}Ne felejtse el a 4. ponttal visszaállítani, ha eltávolítja a DNS szervert!${RESET}"
    
    wait_for_key
}

# Függvény a systemd-resolved visszaállításához
restore_resolved() {
    echo "${YELLOW}--- 4. systemd-resolved visszaállítása ---${RESET}"
    echo "${WHITE}A maszkolás visszavonása és a systemd-resolved visszaállítása...${RESET}"
    
    echo "${WHITE}Maszkolás visszavonása...${RESET}"
    systemctl unmask systemd-resolved
    
    echo "${WHITE}Szolgáltatás engedélyezése...${RESET}"
    systemctl enable systemd-resolved
    
    echo "${WHITE}Szolgáltatás indítása...${RESET}"
    if systemctl start systemd-resolved; then
        echo "${GREEN}✓ systemd-resolved sikeresen elindítva${RESET}"
        
        if [ -L /etc/resolv.conf ]; then
            echo "${GREEN}A resolv.conf már szimlink.${RESET}"
        else
            echo "${WHITE}resolv.conf visszaállítása szimlinkre...${RESET}"
            rm -f /etc/resolv.conf
            ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        fi
        
        echo "${GREEN}✓ A rendszer DNS beállításai visszaálltak az alapértelmezettre.${RESET}"
    else
        echo "${RED}HIBA: A systemd-resolved indítása sikertelen${RESET}."
    fi
    
    wait_for_key
}

# Függvény a Technitium telepítéséhez
install_technitium() {
    echo "${YELLOW}--- 5. Technitium DNS Server telepítése ---${RESET}"
    
    if ! check_system; then
        echo "${RED}A rendszer nem felel meg. Folytatod így is? (i/n)${RESET}"
        read -n 1 -r response
        echo
        if [[ ! $response =~ ^[Ii]$ ]]; then
            echo "${YELLOW}Kilépés.${RESET}"
            wait_for_key
            return 1
        fi
    fi
    
    if ! install_dependencies; then
        wait_for_key
        return 1
    fi
    
    echo "${WHITE}Portok ellenőrzése...${RESET}"
    check_port 53 "UDP/TCP"
    local port_53_used=$?
    
    if [ $port_53_used -eq 0 ]; then
        echo "${RED}${BOLD}!!! KRITIKUS HIBA !!!${RESET}"
        echo "${WHITE}A 53-as port foglalt. Futtasd a 3. menüpontot!${RESET}"
        wait_for_key
        return 1
    fi
    
    echo "${YELLOW}Technitium DNS Server telepítése...${RESET}"
    echo "${WHITE}A hivatalos telepítőt futtatjuk (.NET Runtime telepítése is)...${RESET}"
    
    # A hivatalos Technitium telepítő futtatása
    if curl -sSL https://download.technitium.com/dns/install.sh | bash; then
        echo
        echo "${GREEN}${BOLD}=== TELEPÍTÉS SIKERES ===${RESET}"
        echo "${WHITE}Futó szolgáltatásként. Web UI: ${BOLD}http://<szerver_IP>:5380/${RESET}"
        echo "${WHITE}Alap user/pass: ${BOLD}admin/admin${RESET}"
        echo
        echo "${RED}${BOLD}!!! VÁLTOZTASD MEG AZONNAL A JELSZÓT A WEB UI-BAN !!!${RESET}"
        show_final_explanation
    else
        echo
        echo "${RED}${BOLD}=== HIBA A TELEPÍTÉS SORÁN ===${RESET}"
        echo "${WHITE}Ellenőrizd a kimenetet.${RESET}"
    fi
    
    wait_for_key
}

# Teljes elővizsgálat
run_full_check() {
    echo "${YELLOW}${BOLD}--- Teljes elővizsgálat ---${RESET}"
    
    if ! check_system; then
        echo "${RED}Rendszerhiba, de folytatjuk...${RESET}"
    fi
    
    if ! install_dependencies; then
        wait_for_key
        return 1
    fi
    
    run_port_check
}

# Összefoglaló magyarázat
show_final_explanation() {
    echo
    echo "${YELLOW}${BOLD}=================== KÖVETKEZŐ LÉPÉSEK ===================${RESET}"
    echo "${WHITE}${BOLD}1. Jelszóváltás:${RESET} Lépj be a Web UI-ba (${BOLD}http://<IP>:5380/${RESET}) és változtasd meg az ${BOLD}admin/admin${RESET} jelszót!"
    echo "${WHITE}${BOLD}2. Tűzfal:${RESET} Engedélyezd a ${BOLD}53/UDP/TCP${RESET} és ${BOLD}5380/TCP${RESET} portokat (pl. ${BOLD}ufw allow 53; ufw allow 5380/tcp${RESET})."
    echo "${WHITE}${BOLD}3. DNS Beállítás:${RESET} A szerver már ezt a DNS-t használja. Más gépeken állítsd be a DNS-t a szerver IP-címére."
    echo "${WHITE}${BOLD}4. Eltávolításkor:${RESET} Futtasd a ${BOLD}4. menüpontot${RESET} a rendszer DNS visszaállításához!"
    echo "${YELLOW}${BOLD}===========================================================${RESET}"
}

# Főmenü függvény
show_menu() {
    clear
    echo "${YELLOW}${BOLD}====================================================${RESET}"
    echo "${WHITE}${BOLD} $SCRIPT_NAME ${RESET}"
    echo "${YELLOW}${BOLD} Készítette: $SCRIPT_AUTHOR ${RESET}"
    echo "${YELLOW}${BOLD} Verzió: $SCRIPT_VER ${RESET}"
    echo "${WHITE}${BOLD} (Ubuntu 22.04 LTS+ és Debian 13 rendszerekhez)      ${RESET}"
    echo "${YELLOW}${BOLD}====================================================${RESET}"
    echo
    echo "${GREEN}0)${RESET} ${BOLD}Teljes Elővizsgálat + Függőség Telepítés (ajánlott)${RESET}"
    echo
    echo "${GREEN}1)${RESET} Rendszerfrissítés és Alap Függőségek Telepítése"
    echo "${GREEN}2)${RESET} Portütközések Vizsgálata (53/DNS és 5380/Web UI)"
    echo "${GREEN}3)${RESET} ${RED}systemd-resolved LEÁLLÍTÁSA${RESET} (53-as port felszabadítás)"
    echo "${GREEN}4)${RESET} ${GREEN}systemd-resolved VISSZAÁLLÍTÁSA${RESET} (Eltávolítás utáni teendő)"
    echo "${GREEN}5)${RESET} ${YELLOW}${BOLD}Technitium DNS Server TELEPÍTÉSE${RESET}"
    echo
    echo "${RED}6)${RESET} Kilépés"
    echo "${YELLOW}====================================================${RESET}"
    
    read -p "${WHITE}Válassz egy opciót [0-6]: ${RESET}" choice
}

# Fő program
main() {
    # Ellenőrizzük, hogy a tput elérhető-e
    if ! command -v tput &> /dev/null; then
        echo "HIBA: A 'tput' parancs nem található. Telepítsd az 'ncurses-bin' csomagot (apt install ncurses-bin)."
        exit 1
    fi

    # Kezdeti rendszer ellenőrzés
    if ! check_system; then
        echo "${RED}A kezdeti rendszerellenőrzés sikertelen. Kilépés.${RESET}"
        exit 1
    fi

    # Fő ciklus
    while true; do
        show_menu
        case $choice in
            0) run_full_check ;;
            1) install_dependencies ;;
            2) run_port_check ;;
            3) stop_and_mask_resolved ;;
            4) restore_resolved ;;
            5) install_technitium ;;
            6)
                echo "${YELLOW}Kilépés. Viszontlátásra!${RESET}"
                exit 0
                ;;
            *)
                echo "${RED}Érvénytelen választás. Kérem válassz a menüpontok közül.${RESET}"
                wait_for_key
                ;;
        esac
    done
}

# Program indítása
main "$@"
