#!/bin/bash
# Script: install_pihole.sh
# Készítette: DevOFALL
# Cél: Pi-hole telepítése Debian/Ubuntu rendszereken, automatikus konfigurációval, hibatűréssel, tűzfal- és jelszókezeléssel.

# A szkript azonnal kilép, ha bármely parancs hibakóddal tér vissza (set -e).
set -e

# --- ANSI SZÍNKÓDOK (fejléc kiemeléshez és állapotjelzéshez) ---
BLUE='\033[1;34m'   # Debian kék
ORANGE='\033[1;33m' # Ubuntu narancs
RED='\033[1;31m'    # Hibák és figyelmeztetések
GREEN='\033[1;32m'  # Sikeres műveletek
RESET='\033[0m'     # Szín visszaállítása a terminál alapértelmezettre

# --- KONFIGURÁCIÓS VÁLTOZÓK ---
# Upstream DNS szolgáltatók (ezek kerülnek átadásra a Pi-hole telepítőnek)
PIHOLE_DNS_1="1.1.1.1"
PIHOLE_DNS_2="1.0.0.1"
# Telepítési opciók (unattended módhoz szükségesek)
INSTALL_WEB_SERVER="true"       # Telepíti a Lighttpd webszervert
INSTALL_WEB_INTERFACE="true"    # Telepíti a webes admin felületet
QUERY_LOGGING="true"            # Engedélyezi a lekérdezés naplózását
BLOCKING_ENABLED="true"         # Engedélyezi az alapértelmezett blokkolást
WEBPASSWORD=""                  # Üresen hagyva a szkript automatikusan generál egyet. 

# --- FUNKCIÓK ---

# Hibaüzenet megjelenítése és kilépés
error_exit() {
    echo -e "${RED}\n_!!! FATÁLIS HIBA !!!_: $1${RESET}" >&2
    exit 1
}

# Root jogosultság ellenőrzése
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "Root jogosultság szükséges. Kérjük, futtassa **sudo**-val!"
    fi
}

# Tűzfal (UFW) és Portok ellenőrzése/beállítása
check_firewall() {
    echo -e "\n**--- Tűzfal (UFW) és Portok Ellenőrzése ---**"
    
    # Ellenőrizzük, hogy az ufw telepítve van-e
    if ! command -v ufw &> /dev/null; then
        echo -e "${ORANGE}FIGYELMEZTETÉS:${RESET} Az UFW tűzfal nincs telepítve, de most telepíteni fogjuk."
        # A telepítés az 1. lépésben (csomagtelepítés) megtörténik.
        return 0
    fi
    
    local UFW_STATUS=$(ufw status | head -n 1)
    
    # Csak akkor engedélyezünk portokat, ha az UFW aktív, különben csak figyelmeztetünk.
    if [[ "$UFW_STATUS" == "Status: active" ]]; then
        echo -e "${GREEN}UFW tűzfal aktív.${RESET} Engedélyezzük a Pi-hole portjait..."
        
        # DNS port: UDP/TCP 53 (Pi-hole DNS)
        ufw allow 53/udp comment 'Pi-hole DNS' || error_exit "UFW 53/udp engedélyezése sikertelen."
        ufw allow 53/tcp comment 'Pi-hole DNS' || error_exit "UFW 53/tcp engedélyezése sikertelen."
        
        # HTTP port: TCP 80 (Web Admin)
        ufw allow 80/tcp comment 'Pi-hole Web Admin' || error_exit "UFW 80/tcp engedélyezése sikertelen."
        
        echo -e "${GREEN}Pi-hole portok (53/udp, 53/tcp, 80/tcp) sikeresen engedélyezve UFW-ben.${RESET}"
    else
        echo -e "${ORANGE}FIGYELMEZTETÉS:${RESET} UFW telepítve, de ${UFW_STATUS//Status: }."
        echo "A portok nem lettek engedélyezve. Kérjük, aktiválja az UFW-t (ufw enable) és engedélyezze a portokat a használt tűzfalon."
    fi
}

# Időzóna beállítása Europe/Budapest-re
set_timezone() {
    echo -e "\n**--- Időzóna beállítása (Europe/Budapest) és Időszinkronizálás ---**"
    
    # timedatectl használata (modern rendszerek)
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone Europe/Budapest || error_exit "Időzóna beállítása timedatectl-lel sikertelen."
        timedatectl set-ntp true
        echo "Időzóna és NTP beállítva timedatectl-lel."
    else
        # Manuális beállítás (LXC vagy minimalista install)
        ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime 2>/dev/null
        echo "Europe/Budapest" > /etc/timezone
        echo "Manuálisan beállított időzóna."
    fi
    echo "Jelenlegi idő és időzóna: $(date)"
}

# Zárolási probléma kezelése (APT/DPKG lock files)
handle_locks() {
    echo -e "\n--- Zároláskezelés indítása ---"
    
    # Megpróbáljuk leállítani az automatikus frissítéseket
    systemctl stop unattended-upgrades.service 2>/dev/null || true
    
    local MAX_WAIT=60
    local WAIT_TIME=0
    
    # Várakozás a természetes feloldásra
    while [ -f /var/lib/dpkg/lock ] || [ -f /var/lib/dpkg/lock-frontend ]; do
        if [ "$WAIT_TIME" -ge "$MAX_WAIT" ]; then
            echo -e "\n${RED}_FIGYELEM_: A zárolások időtúlléptek. Erőszakos feloldás indítása...${RESET}"
            
            # Megpróbáljuk leállítani a lock-ot tartó folyamatot
            local PROCESS_ID=$(lsof /var/lib/dpkg/lock-frontend 2>/dev/null | awk 'NR>1 {print $2}' | head -n 1)
            if [ -n "$PROCESS_ID" ]; then
                echo "Megtalált folyamat (PID $PROCESS_ID), ami tartja a zárolást. Megpróbáljuk leállítani..."
                kill -9 "$PROCESS_ID" 2>/dev/null || true
            fi
            
            # Töröljük a lock fájlokat
            rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock
            
            # Helyreállítjuk a DPKG adatbázist
            dpkg --configure -a || true
            apt update || true
            
            echo "${GREEN}Zárolások sikeresen erőszakosan feloldva és DPKG helyreállítva.${RESET}"
            return 0
        fi
        
        echo -n "Várakozás az APT/DPKG zárolások feloldására (${WAIT_TIME}/${MAX_WAIT} mp)... "
        sleep 5
        WAIT_TIME=$((WAIT_TIME + 5))
        echo "Folytatás..."
    done
    echo "APT/DPKG zárolások sikeresen feloldva."
}

# --- FŐ PROGRAM ---
check_root # Ellenőrizzük, hogy a szkript root jogosultságokkal fut-e.

echo "====================================================="
echo -e "${BLUE}**Pi-hole AUTOMATIKUS TELEPÍTŐ${RESET} (DevOFALL)"
echo -e "${ORANGE}**Rendszerek: ${BLUE}Debian (kék) ${ORANGE}és Ubuntu (narancs/lila)${RESET} **"
echo "====================================================="

# --- 0. LÉPÉS: ELŐZETES ELLENŐRZÉSEK ÉS JÓVÁHAGYÁS KÉRÉSE ---

# 0a. Rendszer kompatibilitás ellenőrzése és jóváhagyás kérése
OS_INFO=$(cat /etc/os-release 2>/dev/null || echo "Nincs OS info")
if ! (echo "$OS_INFO" | grep -q "Ubuntu 22.04" || echo "$OS_INFO" | grep -q "Debian"); then
    echo -e "\n${ORANGE}_FIGYELMEZTETÉS_:${RESET} Ez a szkript Ubuntu 22.04+ vagy Debian rendszerekre lett tesztelve."
    read -r -p "Folytatja a telepítést? (i/n): " -n 1 -r REPLY
    echo 
    if [[ ! $REPLY =~ ^[Ii]$ ]]; then
        error_exit "A felhasználó megszakította a telepítést."
    fi
fi

# 0b. Interfész automatikus detektálás
echo -e "\n**--- Interfész Detektálás ---**"
# Megpróbáljuk az alapértelmezett kimeneti interfészt megtalálni (ahol a default route megy ki)
PIHOLE_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$PIHOLE_INTERFACE" ]; then
    error_exit "Nem sikerült automatikusan meghatározni az alapértelmezett interfészt."
fi
echo -e "Automatikusan detektált interfész: **$PIHOLE_INTERFACE**"

# 0c. Jelszó generálás
if [ -z "$WEBPASSWORD" ]; then
    WEBPASSWORD=$(openssl rand -base64 12)
    echo -e "\n${RED}_!!! BIZTONSÁGI RIASZTÁS !!!_${RESET}"
    echo -e "A Pi-hole Admin webes felület JELSZAVA automatikusan generálva lett:"
    echo -e "  ➡️ Jelszó: **$WEBPASSWORD**"
    echo -e "${RED}_KÉRJÜK, MENTSE EL EZT A JELSZÓT BIZTONSÁGOS HELYRE!_${RESET}"
fi

# 0d. VÉGSŐ MEGERŐSÍTÉS A TELEPÍTÉS ELŐTT
echo -e "\n${GREEN}_!!! KÉSZEN ÁLLUNK A TELEPÍTÉSRE !!!_${RESET}"
echo -e "A szkript most: 1. Frissíti a rendszert. 2. Beállítja az időzónát. 3. Telepíti a Pi-hole-t. 4. Konfigurálja a tűzfalat (UFW)."
read -r -p "Meggyőződött a statikus IP-címről és szeretné elindítani a Pi-hole telepítését? (i/n): " -n 1 -r FINAL_REPLY
echo 
if [[ ! $FINAL_REPLY =~ ^[Ii]$ ]]; then
    error_exit "A felhasználó megszakította a telepítést a végső megerősítésnél."
fi

# Exportáljuk a változókat, hogy a Pi-hole telepítő szkript elérje azokat
export PIHOLE_INTERFACE PIHOLE_DNS_1 PIHOLE_DNS_2
export INSTALL_WEB_SERVER INSTALL_WEB_INTERFACE
export QUERY_LOGGING BLOCKING_ENABLED WEBPASSWORD

# --- 1. LÉPÉS: RENDSZERFRISSÍTÉS ÉS CSOMAGTELEPÍTÉS ---
handle_locks # Zároláskezelés futtatása a frissítés előtt
echo -e "\n**--- 1. LÉPÉS: Rendszerfrissítés (apt update & apt upgrade) ---**"

# Frissítjük a csomagtárakat, frissítjük a rendszert, és eltávolítjuk a felesleges csomagokat
apt update -y
apt upgrade -y
apt autoremove -y

echo "--- A Pi-hole telepítéséhez szükséges csomagok telepítése (curl, ufw) ---"
# Telepítjük a curl-t a Pi-hole letöltéséhez és az ufw-t a tűzfal kezeléséhez
if ! apt install -y curl ufw; then
    error_exit "A curl vagy ufw telepítése sikertelen! Ellenőrizze a csomagtárakat."
fi

# --- 2. LÉPÉS: IDŐSZINKRONIZÁLÁS ÉS IDŐZÓNA BEÁLLÍTÁSA ---
set_timezone

# --- 3. LÉPÉS: TŰZFAL BEÁLLÍTÁSA ---
check_firewall # Ellenőrizzük és konfiguráljuk az UFW-t a Pi-hole portokhoz

# --- 4. LÉPÉS: PI-HOLE TELEPÍTÉS ---
echo -e "\n**--- 4. LÉPÉS: Pi-hole telepítés indítása automatikus módban ---**"

# Letöltjük a hivatalos telepítő szkriptet és futtatjuk a bash -s -- --unattended szintaxissal.
# Az "-s" jelzi a bash-nek, hogy a bemenetet stdin-ről olvassa, a "--" utáni opciók pedig a Pi-hole szkriptnek szólnak.
if ! curl -sSL https://install.pi-hole.net | bash -s -- --unattended; then
    error_exit "A Pi-hole telepítése sikertelen! Valószínűleg a telepítő szkript futott hibára."
fi

# --- 5. LÉPÉS: TELEPÍTÉS UTÁNI ÖSSZEFOGLALÓ ---
echo "====================================================="
echo -e "**Pi-hole TELEPÍTÉS SIKERES! (DevOFALL)**"
echo "====================================================="

# Kiolvassuk a Pi-hole IP-címét a sikeres telepítés után
PIHOLE_IP=$(ip a show dev ${PIHOLE_INTERFACE} | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

if [ -n "$PIHOLE_IP" ]; then
    echo -e "A Pi-hole Admin felületét ezen a címen éri el:"
    echo -e "  ➡️  _http://${PIHOLE_IP}/admin_"
    echo -e "  ➡️  _http://pi.hole/admin_"
    echo ""
    echo -e "Admin jelszó: **$WEBPASSWORD**"
    echo ""
    echo -e "${ORANGE}_!!! UTOLSÓ LÉPÉS: ÁLLÍTSA BE A ROUTERT VAGY AZ ESZKÖZÖKET DNS-RE !!!_${RESET}"
    echo -e "Használja a **${PIHOLE_IP}** címet DNS-szerverként a hálózatában."
else
    error_exit "Nem sikerült kiolvasni a Pi-hole IP-címét a(z) ${PIHOLE_INTERFACE} interfészről. Ellenőrizze a statikus IP-t!"
fi

echo "====================================================="
