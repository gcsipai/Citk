#!/bin/bash
## OpenVPN telepítő (Hibajavított, teljes, MAGYAR változat, Zöld színekkel)
# Alap: Nyr https://github.com/Nyr/openvpn-install
# Továbbfejlesztette: Gcsipai https://github.com/gcsipai
#
# ----------------------------------------------------
# 📜 KIADÁSI MEGJEGYZÉS: V1.1 (Készítette: Gcsipai 2025)
# FIX: Fejlett hálózati ütközésvizsgálat és kézi CIDR bevitel
# FIX: Server.conf generálási hiba javítása.
# ÚJ: Kliens teljes törlése (visszavonás + fájltörlés)
# ÚJ: Rendszer állapot ellenőrzések (memória, lemez, port)
# FIX: Nem szabványos karakterhibák javítása a szkriptben (Bash hiba)
# ----------------------------------------------------

# --- SZÍNKÓDOK (Zöld/Fehér) ---
GREEN_BOLD='\033[1;32m'    # Fő címek, sikeres műveletek
WHITE_NORMAL='\033[0;37m' # Információk, alcímek
YELLOW_BOLD='\033[1;33m' # Figyelmeztetések, input kérdések
RED_BOLD='\033[1;31m'      # Hibaüzenetek, kritikus figyelmeztetések
BLUE_BOLD='\033[1;34m' # Kiegészítő információk, ellenőrzések
RESET='\033[0m'          # Alapértelmezett szín visszaállítása

# --- ALAPÉRTELMEZETT BEÁLLÍTÁSOK ---
DEFAULT_PORT="1194"
DEFAULT_PROTOCOL="udp"
DEFAULT_DNS="2"  
DEFAULT_CLIENT_NAME="kliens"
DEFAULT_OVPN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"  
VPN_NETWORK_CIDR="10.8.0.0/24"
VPN_NETWORK_BASE="10.8.0.0"
EASYRSA_VER="3.2.4"

# --- GLOBÁLIS VÁLTOZÓK ---
ip=""
port=""
protocol=""
client=""
ovpn_dir=""
os=""
group_name=""
local_network_route=""  
dns_server_1=""  
dns_server_2=""

# === JAVÍTOTT ELLENŐRZŐ FUNKCIÓK ===

# Naplózási függvény (Ellenőrzött, tiszta)
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" >> /var/log/openvpn-installer.log 2>/dev/null
}

# Parancs végrehajtás hibakezeléssel (Ellenőrzött, tiszta)
execute_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "${WHITE_NORMAL}⚙️ $description...${RESET}"
    log_message "INFO" "Executing: $description"
    
    # Próbálja meg a parancsot végrehajtani és a standard hibát a logba írni
    if eval "$cmd" 2>> /var/log/openvpn-installer.log; then
        echo -e "${GREEN_BOLD}✅ $description sikeres${RESET}"
        log_message "SUCCESS" "$description completed"
        return 0
    else
        echo -e "${RED_BOLD}❌ $description sikertelen${RESET}"
        log_message "ERROR" "$description failed"
        return 1
    fi
}

# Függőség ellenőrzése
check_dependencies() {
    local deps=("curl" "wget" "openssl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW_BOLD}📦 Hiányzó függőségek telepítése: ${missing[*]}${RESET}"
        if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
            execute_command "apt-get update && apt-get install -y ${missing[*]}" "Hiányzó függőségek telepítése"
        elif [[ "$os" = "centos" ]]; then
            execute_command "dnf install -y ${missing[*]}" "Hiányzó függőségek telepítése"
        fi
    fi
}

# Lemezterület ellenőrzés
check_disk_space() {
    local required_mb=500
    # Az awk a KB-ot adja vissza, 1024-gyel elosztva kapjuk meg a MB-ot
    local available_mb=$(df /tmp | awk 'NR==2 {print $4}')
    available_mb=$((available_mb / 1024))
    
    if [[ $available_mb -lt $required_mb ]]; then
        echo -e "${RED_BOLD}❌ Kevesebb mint $required_mb MB szabad lemezterület! (Jelenleg: ${available_mb}MB)${RESET}"
        return 1
    fi
    return 0
}

# Memória ellenőrzés
check_memory() {
    local required_mb=512
    local available_mb=$(free -m | awk 'NR==2{print $7}') # Available memory
    
    if [[ $available_mb -lt $required_mb ]]; then
        echo -e "${YELLOW_BOLD}⚠️ Alacsony memória: ${available_mb}MB (Ajánlott: ${required_mb}MB)${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Folytatja? [i/N]: ${RESET}")" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[iI]$ ]]; then
            return 1
        fi
    fi
    return 0
}

# Hálózati kapcsolat ellenőrzése
check_network_connectivity() {
    echo -e "${WHITE_NORMAL}🌐 Hálózati kapcsolat ellenőrzése...${RESET}"
    
    # Kétféle ellenőrzés, ha az első DNS alapú ping nem megy át
    if execute_command "ping -c 2 -W 3 google.com > /dev/null 2>&1 || ping -c 2 -W 3 8.8.8.8 > /dev/null 2>&1" "Hálózati elérhetőség ellenőrzés"; then
        return 0
    else
        echo -e "${YELLOW_BOLD}⚠️ Nincs stabil internetkapcsolat, a telepítés folytatódhat, de a csomagletöltés hibás lehet!${RESET}"
        return 0
    fi
}

# Port elérhetőség ellenőrzése (Látszólagos foglaltság)
check_port_availability() {
    local check_port="$1"
    local check_protocol="$2"
    
    # Ellenőrizzük, hogy a portot használja-e egy program
    if command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":${check_port}"; then
            echo -e "${RED_BOLD}❌ A $check_port port már foglalt!${RESET}"
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":${check_port}"; then
            echo -e "${RED_BOLD}❌ A $check_port port már foglalt!${RESET}"
            return 1
        fi
    fi
    
    return 0
}

# OpenVPN konfiguráció validálása
validate_openvpn_config() {
    local config_file="/etc/openvpn/server/server.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log_message "ERROR" "Missing OpenVPN configuration: $config_file"
        return 1
    fi
    
    local required_files=("ca.crt" "server.crt" "server.key" "dh.pem" "tc.key")
    for file in "${required_files[@]}"; do
        if [[ ! -f "/etc/openvpn/server/$file" ]]; then
            log_message "ERROR" "Missing required file: /etc/openvpn/server/$file"
            return 1
        fi
    done
    
    return 0
}

# Rendszer állapot ellenőrzése
system_health_check() {
    echo -e "${BLUE_BOLD}--- 🔍 Rendszer Állapot Ellenőrzés ---${RESET}"
    local health_ok=0
    
    if ! check_memory || ! check_disk_space; then
        health_ok=1
    fi
    
    check_dependencies
    
    if [[ $health_ok -eq 1 ]]; then
        echo -e "${RED_BOLD}❌ A rendszer nem felel meg a minimális követelményeknek!${RESET}"
        return 1
    fi
    
    echo -e "${GREEN_BOLD}✅ Rendszer állapot megfelelő${RESET}"
    return 0
}

# === MEGLÉVŐ FUNKCIÓK JAVÍTOTT VERZIÓI ===

# Operációs rendszer detektálása (javított)
detect_os() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED_BOLD}⚠️ Ezt a telepítőt rendszergazdai (root) jogosultságokkal kell futtatni. Használja a 'sudo bash $0' parancsot.${RESET}"
        exit 1
    fi
    
    # TUN eszköz ellenőrzés
    if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
        echo -e "${RED_BOLD}❌ A TUN eszköz nem elérhető. Engedélyezze a virtualizációt!${RESET}"
        echo -e "${WHITE_NORMAL}   Példa KVM-en: modprobe tun${RESET}"
        exit 1
    fi

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os="${ID:-unknown}"
        
        case "$os" in
            ubuntu|debian)
                group_name="nogroup"
                ;;
            centos|rhel|almalinux|rocky|fedora)
                os="centos"
                group_name="nobody"
                ;;
            *)
                echo -e "${RED_BOLD}❌ Nem támogatott disztribúció: $os${RESET}"
                exit 1
                ;;
        esac
    else
        echo -e "${RED_BOLD}❌ Nem található /etc/os-release fájl${RESET}"
        exit 1
    fi
    
    log_message "INFO" "Operating system detected: $os"
}

# Kliens nevének tisztítása
sanitize_client_name() {
    local unsanitized_client="$1"
    # Csak alfanumerikus karakterek, kötőjelek és aláhúzások
    local client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
    
    if [[ -z "$client" ]]; then
        client="$DEFAULT_CLIENT_NAME"
        echo -e "${YELLOW_BOLD}⚠️ Érvénytelen kliensnév, alapértelmezett használata: $client${RESET}"
    fi
    
    # Max 64 karakter (X.509 limitation)
    if [[ ${#client} -gt 64 ]]; then
        client="${client:0:64}"
        echo -e "${YELLOW_BOLD}⚠️ Kliensnév csonkolva 64 karakterre: $client${RESET}"
    fi
    
    echo "$client"
}

# Hálózati alhálózat érvényességének ellenőrzése (csak formátum)
validate_subnet() {
    local subnet_cidr="$1"
    # Érvényesíti a X.Y.Z.0/24 formátumot, ahol X.Y.Z.0 privát tartományban van
    if ! [[ "$subnet_cidr" =~ ^(10|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168)\.[0-9]{1,3}\.0/24$ ]]; then
        echo -e "${RED_BOLD}❌ Érvénytelen formátum. Csak privát X.Y.Z.0/24 tartomány engedélyezett (10.x.x.x, 172.16-31.x.x, 192.168.x.x) és az utolsó oktettnek .0-nak kell lennie!${RESET}"
        return 1
    fi
    return 0
}

# Fejlett Hálózati ütközés ellenőrzése
check_subnet_conflict() {
    local check_cidr="$1"
    local check_base=$(echo "$check_cidr" | cut -d '/' -f 1)
    
    # Az összes lokális útvonal kinyerése
    local_networks=$(ip -4 route show | grep -v 'default' | awk '{print $1}' | grep -vE '^(127|169|172\.17)' | grep /)
    
    for net in $local_networks; do
        # Megpróbálunk útvonalat lekérni a VPN hálózat bázis IP-jére a lokális hálózatokon keresztül
        if ip route get "$check_base" 2>/dev/null | grep -q "$net"; then
            log_message "WARNING" "Conflict detected with local network: $net"
            return 0 # Hiba: Ütközés észlelve
        fi
    done
    return 1 # Siker: Nincs ütközés
}

# Hálózat felderítése, ütközések vizsgálata és beállítás (Javított)
setup_vpn_network() {
    echo
    echo -e "${WHITE_NORMAL}--- 🌐 VPN Hálózat Beállítása és Ütközésvizsgálat ---${RESET}"
    
    local_vpn_cidr="$VPN_NETWORK_CIDR"  
    
    # 1. Ütközésvizsgálat
    if check_subnet_conflict "$local_vpn_cidr"; then
        echo -e "${YELLOW_BOLD}❌ Ütközés észlelve! A(z) $local_vpn_cidr VPN hálózat ütközik egy helyi hálózattal.${RESET}"
        
        # Javasolt, nem ütköző hálózat keresése (10.x.0.0/24 tartományban)
        for i in {8..254}; do
            local_vpn_cidr="10.$i.0.0/24"
            if ! check_subnet_conflict "$local_vpn_cidr"; then
                echo -e "${GREEN_BOLD}✅ Javasolt, nem ütköző VPN hálózat: $local_vpn_cidr${RESET}"
                break
            fi
            if [[ $i -eq 254 ]]; then
                echo -e "${RED_BOLD}❌ Nem sikerült automatikusan nem ütköző hálózatot találni a 10.x.x.x tartományban.${RESET}"
                local_vpn_cidr="10.8.0.0/24"  
                break
            fi
        done
    else
        echo -e "${GREEN_BOLD}✅ Az alapértelmezett VPN hálózat ($VPN_NETWORK_CIDR) biztonságosnak tűnik.${RESET}"
    fi

    # 2. Kézi felülírás opció
    read -p "$(echo -e "${YELLOW_BOLD}Szeretné módosítani a VPN hálózatot? [i/N]: ${RESET}")" modify_network
    
    if [[ "$modify_network" =~ ^[iI]$ ]]; then
        while true; do
            read -p "$(echo -e "${YELLOW_BOLD}Adja meg a kívánt VPN hálózatot (CIDR formátumban, pl. 10.15.0.0/24) [$local_vpn_cidr]: ${RESET}")" custom_vpn_cidr
            [[ -z "$custom_vpn_cidr" ]] && custom_vpn_cidr="$local_vpn_cidr"

            if validate_subnet "$custom_vpn_cidr"; then
                if check_subnet_conflict "$custom_vpn_cidr"; then
                    echo -e "${RED_BOLD}❌ A megadott $custom_vpn_cidr hálózat ütközik egy helyi hálózattal. Válasszon mást!${RESET}"
                    local_vpn_cidr="$custom_vpn_cidr"  
                else
                    echo -e "${GREEN_BOLD}✅ $custom_vpn_cidr elfogadva.${RESET}"
                    VPN_NETWORK_CIDR="$custom_vpn_cidr"
                    break
                fi
            else
                local_vpn_cidr="$custom_vpn_cidr"  
            fi
        done
    else
        VPN_NETWORK_CIDR="$local_vpn_cidr"
    fi
    
    VPN_NETWORK_BASE=$(echo "$VPN_NETWORK_CIDR" | cut -d '/' -f 1)
}

# Lokális hálózat felismerése és bekérése
get_local_network_route() {
    echo
    echo -e "${WHITE_NORMAL}--- Lokális Hálózat Elérése (opcionális) ---${RESET}"
    local_interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    
    if [[ -n "$local_interface" ]]; then
        # Lekéri az IP címet CIDR-rel (pl. 10.168.0.25/24)
        local_network_cidr_raw=$(ip a show dev "$local_interface" | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')
        
        if echo "$local_network_cidr_raw" | grep -qE '^(10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168)'; then
            
            IP=$(echo "$local_network_cidr_raw" | cut -d '/' -f 1)
            MASK=$(echo "$local_network_cidr_raw" | cut -d '/' -f 2)
            local_network_only=""
            
            # Kiszámítja a hálózati címet
            if [[ -n "$IP" && -n "$MASK" && "$MASK" -le 32 ]]; then
                # /24-nél egyszerűbb számítás
                if [[ "$MASK" -eq 24 ]]; then
                    local_network_only=$(echo "$IP" | cut -d '.' -f 1-3)".0/$MASK"
                else
                    # Nem /24, a teljes CIDR-t használjuk
                    local_network_only="$local_network_cidr_raw"
                fi
                
                if [[ -n "$local_network_only" ]]; then
                    echo -e "🔍 Érzékelt lokális hálózat: ${GREEN_BOLD}$local_network_only${RESET}"
                    read -p "$(echo -e "${YELLOW_BOLD}Szeretné, ha a VPN kliensek elérnék ezt a lokális hálózatot? [i/N]: ${RESET}")" push_local_network
                    
                    if [[ "$push_local_network" =~ ^[iI]$ ]]; then
                        echo -e "${GREEN_BOLD}✅ Hozzáadva a lokális hálózat ($local_network_only) elérésének beállítása.${RESET}"
                        local_network_route="$local_network_only"  
                    fi
                fi
            fi
        fi
    fi
}

# DNS beállítások hozzáadása a server.conf-hoz
add_dns_config() {
    local dns_servers=()
    
    case "$dns" in
        1)  
            if grep -q "127.0.0.53" /etc/resolv.conf && command -v systemd-resolve >/dev/null 2>&1; then
                dns_servers=($(systemd-resolve --status | grep "DNS Servers" | awk '{print $3}'))
            else
                dns_servers=($(grep -oP 'nameserver \K[\d\.]+' /etc/resolv.conf | head -2))
            fi
            ;;
        2) dns_servers=("8.8.8.8" "8.8.4.4") ;;
        3) dns_servers=("1.1.1.1" "1.0.0.1") ;;
        4) dns_servers=("208.67.222.222" "208.67.220.220") ;;
        5) dns_servers=("9.9.9.9" "149.112.112.112") ;;
        6)  
            dns_server_2_temp=""
            [[ -n "$dns_server_2" ]] && dns_server_2_temp="$dns_server_2"
            dns_servers=("$dns_server_1" "$dns_server_2_temp")
            ;;
    esac
    
    for dns_server in "${dns_servers[@]}"; do
        if [[ -n "$dns_server" ]]; then
            echo "push \"dhcp-option DNS $dns_server\"" >> /etc/openvpn/server/server.conf
        fi
    done
}

# Hálózati beállítások bekérése (javított)
get_network_settings() {
    echo
    echo -e "${WHITE_NORMAL}--- 🌐 Hálózati Beállítások ---${RESET}"
    
    # IP cím automatikus felderítése
    ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null ||  
          curl -s -4 ifconfig.me 2>/dev/null ||  
          curl -s -4 icanhazip.com 2>/dev/null ||
          ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n1)

    if [[ -z "$ip" ]]; then
        echo -e "${RED_BOLD}❌ Nem sikerült automatikusan felderíteni az IP címet${RESET}"
        ip="127.0.0.1"
    fi
    
    read -p "$(echo -e "${YELLOW_BOLD}Adja meg a szerver nyilvános IP címét [$ip]: ${RESET}")" custom_ip
    [[ -n "$custom_ip" ]] && ip="$custom_ip"

    # Protokoll választás
    read -p "$(echo -e "${YELLOW_BOLD}Protokoll (udp/tcp) [$DEFAULT_PROTOCOL]: ${RESET}")" protocol_input
    protocol=${protocol_input,,}
    [[ -z "$protocol" ]] && protocol="$DEFAULT_PROTOCOL"
    
    until [[ "$protocol" == "udp" || "$protocol" == "tcp" ]]; do
        echo -e "${RED_BOLD}❌ Csak 'udp' vagy 'tcp' lehet!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Protokoll (udp/tcp) [$DEFAULT_PROTOCOL]: ${RESET}")" protocol_input
        protocol=${protocol_input,,}
        [[ -z "$protocol" ]] && protocol="$DEFAULT_PROTOCOL"
    done
    
    # Port ellenőrzéssel
    while true; do
        read -p "$(echo -e "${YELLOW_BOLD}Port [$DEFAULT_PORT]: ${RESET}")" port_input
        local current_port="${port_input:-$DEFAULT_PORT}"
        
        if [[ "$current_port" =~ ^[0-9]+$ && "$current_port" -le 65535 && "$current_port" -ge 1 ]]; then
            if check_port_availability "$current_port" "$protocol"; then
                port="$current_port"
                break
            else
                echo -e "${YELLOW_BOLD}Próbáljon másik portot!${RESET}"
            fi
        else
            echo -e "${RED_BOLD}❌ Érvénytelen port szám (1-65535)${RESET}"
        fi
    done
    
    echo
    echo -e "${WHITE_NORMAL}--- DNS Beállítás ---${RESET}"
    echo -e "Válasszon DNS szolgáltatót:"
    echo -e "  1) Aktuális rendszer DNS"
    echo -e "  2) Google DNS (8.8.8.8, 8.8.4.4)"
    echo -e "  3) Cloudflare DNS (1.1.1.1, 1.0.0.1)"
    echo -e "  4) OpenDNS (208.67.222.222, 208.67.220.220)"
    echo -e "  5) Quad9 DNS (9.9.9.9, 149.112.112.112)"
    echo -e "  6) Egyéni DNS megadása (pl. Active Directory)"
    read -p "$(echo -e "${YELLOW_BOLD}DNS választás [1-6] [$DEFAULT_DNS]: ${RESET}")" dns
    [[ -z "$dns" ]] && dns="$DEFAULT_DNS"
    until [[ "$dns" =~ ^[1-6]$ ]]; do
        echo -e "${RED_BOLD}❌ Érvénytelen választás!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}DNS választás [1-6] [$DEFAULT_DNS]: ${RESET}")" dns
        [[ -z "$dns" ]] && dns="$DEFAULT_DNS"
    done

    if [[ "$dns" = "6" ]]; then
        while true; do
            read -p "$(echo -e "${YELLOW_BOLD}Adja meg az elsődleges DNS-t: ${RESET}")" dns_server_1
            if [[ "$dns_server_1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
                break
            else
                echo -e "${RED_BOLD}❌ Érvénytelen IP cím!${RESET}"
            fi
        done
        
        read -p "$(echo -e "${YELLOW_BOLD}Adja meg a másodlagos DNS-t (opcionális): ${RESET}")" dns_server_2
        if [[ -n "$dns_server_2" ]] && ! [[ "$dns_server_2" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
            echo -e "${YELLOW_BOLD}⚠️ A másodlagos DNS IP cím érvénytelennek tűnik, figyelmen kívül hagyva.${RESET}"
            dns_server_2=""
        fi
    fi
    
    echo
    read -p "$(echo -e "${YELLOW_BOLD}Első kliens neve [$DEFAULT_CLIENT_NAME]: ${RESET}")" unsanitized_client
    [[ -z "$unsanitized_client" ]] && unsanitized_client="$DEFAULT_CLIENT_NAME"
    client=$(sanitize_client_name "$unsanitized_client")
}

# Tűzfal beállítása
configure_firewall() {
    local INTERFACE
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

    execute_command "echo \"net.ipv4.ip_forward=1\" > /etc/sysctl.d/99-openvpn-forward.conf" "IP továbbítás engedélyezése (sysctl)"
    execute_command "sysctl -q -p /etc/sysctl.d/99-openvpn-forward.conf" "Sysctl beállítás alkalmazása"
    
    if command -v firewalld >/dev/null 2>&1; then
        echo -e "${WHITE_NORMAL}⚙️ Firewalld konfigurálása...${RESET}"
        execute_command "firewall-cmd --add-masquerade --permanent" "Masquerade engedélyezése"
        execute_command "firewall-cmd --zone=public --add-port=$port/$protocol --permanent" "OpenVPN port engedélyezése"
        execute_command "firewall-cmd --reload" "Firewalld újratöltése"
    elif command -v ufw >/dev/null 2>&1; then
        echo -e "${WHITE_NORMAL}⚙️ UFW konfigurálása...${RESET}"
        # UFW NAT beállítás - /etc/ufw/before.rules módosítása
        local ufw_nat_config="# START OPENVPN RULES
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s $VPN_NETWORK_CIDR -o $INTERFACE -j MASQUERADE
COMMIT
# END OPENVPN RULES"
        
        if ! grep -q "# START OPENVPN RULES" /etc/ufw/before.rules; then
            execute_command "sed -i '/^:POSTROUTING ACCEPT \[0:0\]/a\\$ufw_nat_config' /etc/ufw/before.rules" "UFW NAT (masquerade) szabály hozzáadása"
            execute_command "ufw allow $port/$protocol" "UFW port engedélyezése"
            execute_command "ufw reload" "UFW újratöltése"
        else
            echo -e "${YELLOW_BOLD}⚠️ UFW NAT szabályok már léteznek, kihagyva a beállítást.${RESET}"
            execute_command "ufw allow $port/$protocol" "UFW port engedélyezése"
        fi
    else 
        echo -e "${WHITE_NORMAL}⚙️ Iptables/Netfilter-persistent konfigurálása...${RESET}"
        # Masquerade (NAT) a VPN hálózat számára
        execute_command "iptables -t nat -A POSTROUTING -s $VPN_NETWORK_CIDR -o $INTERFACE -j MASQUERADE" "NAT/Masquerade szabály"
        # OpenVPN port engedélyezése
        execute_command "iptables -A INPUT -p $protocol --dport $port -j ACCEPT" "Port engedélyezése (INPUT)"
        # Forgalom továbbítás (Routing) a TUN interface-en keresztül
        execute_command "iptables -A FORWARD -s $VPN_NETWORK_CIDR -j ACCEPT" "VPN hálózat továbbítása (FORWARD)"
        execute_command "iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" "Kapcsolatok engedélyezése (FORWARD)"
        
        if command -v netfilter-persistent >/dev/null 2>&1; then
            execute_command "netfilter-persistent save" "Iptables szabályok mentése"
        fi
    fi
}

# client-common.txt létrehozása
get_default_client_common() {
    echo "client
dev tun
proto $protocol
remote $ip $port
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
block-outside-dns
verb 3" > /etc/openvpn/server/client-common.txt
}

# Szerver konfiguráció létrehozása
create_server_config() {
    echo "# OpenVPN 2.6 Server Configuration
local $ip
port $port
proto $protocol
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-crypt tc.key
topology subnet
server $VPN_NETWORK_BASE 255.255.255.0
ifconfig-pool-persist ipp.txt
push \"redirect-gateway def1 bypass-dhcp\"" > /etc/openvpn/server/server.conf

    # DNS beállítások
    add_dns_config
    
    # Lokális hálózat
    if [[ -n "$local_network_route" ]]; then
        echo "push \"route $local_network_route\"" >> /etc/openvpn/server/server.conf
    fi

    # Egyéb beállítások
    echo "
user nobody
group $group_name
cipher AES-256-GCM
persist-key
persist-tun
status openvpn-status.log
verb 3
crl-verify crl.pem" >> /etc/openvpn/server/server.conf
    
    # CRL generálása
    cd /etc/openvpn/server/easy-rsa/
    execute_command "EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl" "CRL generálása"
    execute_command "cp pki/crl.pem /etc/openvpn/server/crl.pem" "CRL másolása"
    execute_command "chmod 644 /etc/openvpn/server/crl.pem" "CRL jogosultságok beállítása"
    
    return 0
}

# Első kliens létrehozása (telepítés végén)
create_first_client() {
    cd /etc/openvpn/server/easy-rsa/
    
    execute_command "./easyrsa --batch gen-req \"$client\" nopass" "Első kliens tanúsítvány kérése"
    execute_command "./easyrsa --batch sign-req client \"$client\"" "Kliens tanúsítvány aláírása"
    
    execute_command "mkdir -p /etc/openvpn/server/easy-rsa/pki/inline/private/" "Inline mappa létrehozása"
    
    # Inline konfiguráció
    {
        echo "<ca>"
        cat /etc/openvpn/server/easy-rsa/pki/ca.crt
        echo "</ca>"
        echo "<cert>"
        sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt
        echo "</cert>"
        echo "<key>"
        cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key
        echo "</key>"
        echo "<tls-crypt>"
        sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
        echo "</tls-crypt>"
    } > /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline

    # .ovpn fájl létrehozása
    if grep -vh '^#' /etc/openvpn/server/client-common.txt /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline > "$ovpn_dir"/"$client".ovpn 2>/dev/null; then
        echo -e "${GREEN_BOLD}✅ Kliens konfiguráció létrehozva: $ovpn_dir/$client.ovpn${RESET}"
    else
        echo -e "${RED_BOLD}❌ Kliens .ovpn fájl létrehozása sikertelen${RESET}"
        return 1
    fi
}

# Sikeres telepítés üzenet
show_success_message() {
    echo
    echo -e "${GREEN_BOLD}=========================================="
    echo -e "🎉 OPENVPN SIKERESEN TELEPÍTVE!"
    echo -e "=========================================="
    echo -e "${WHITE_NORMAL}📡 Szerver: $ip:$port ($protocol)"
    echo -e "🌐 VPN Hálózat: $VPN_NETWORK_CIDR"
    echo -e "👤 Első kliens: $client"
    echo -e "📁 Konfiguráció: $ovpn_dir/$client.ovpn"
    echo -e "${GREEN_BOLD}==========================================${RESET}"
    echo
    echo -e "${WHITE_NORMAL}Következő lépések:"
    echo -e "1. Másolja a .ovpn fájlt a kliensre"
    echo -e "2. Telepítse az OpenVPN kliens szoftvert"
    echo -e "3. Importálja a .ovpn fájlt"
    echo -e "4. Kapcsolódjon a VPN-hez${RESET}"
}

# Kliens hozzáadása
add_client() {
    echo
    echo -e "${WHITE_NORMAL}--- ➕ Új Kliens Hozzáadása ---${RESET}"
    
    if [[ -z "$ovpn_dir" ]]; then
        read -p "$(echo -e "${YELLOW_BOLD}Adja meg a mappát, ahová a .ovpn fájlok kerüljenek [$DEFAULT_OVPN_DIR]: ${RESET}")" ovpn_dir_input
        [[ -z "$ovpn_dir_input" ]] && ovpn_dir="$DEFAULT_OVPN_DIR" || ovpn_dir="$ovpn_dir_input"
        mkdir -p "$ovpn_dir" 2>/dev/null
    fi
    
    if [[ ! -d "$ovpn_dir" ]]; then
        echo -e "${RED_BOLD}❌ Hiba: Nem tudtam létrehozni a mappát: $ovpn_dir${RESET}"
        return 1
    fi
    
    read -p "$(echo -e "${YELLOW_BOLD}Adja meg az új kliens nevét: ${RESET}")" unsanitized_client
    until [[ -n "$unsanitized_client" ]]; do
        echo -e "${RED_BOLD}❌ A kliens név nem lehet üres!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Adja meg az új kliens nevét: ${RESET}")" unsanitized_client
    done
    client=$(sanitize_client_name "$unsanitized_client")
    
    if [[ -e "/etc/openvpn/server/easy-rsa/pki/issued/$client.crt" ]]; then
        echo -e "${RED_BOLD}❌ A '$client' kliens már létezik!${RESET}"
        return 1
    fi
    
    cd /etc/openvpn/server/easy-rsa/
    execute_command "./easyrsa --batch gen-req \"$client\" nopass" "Kliens tanúsítvány kérésének generálása"
    execute_command "./easyrsa --batch sign-req client \"$client\"" "Kliens tanúsítvány aláírása"
    
    mkdir -p /etc/openvpn/server/easy-rsa/pki/inline/private/
    # Inline konfiguráció generálása
    {
        echo "<ca>"
        cat /etc/openvpn/server/easy-rsa/pki/ca.crt
        echo "</ca>"
        echo "<cert>"
        sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt
        echo "</cert>"
        echo "<key>"
        cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key
        echo "</key>"
        echo "<tls-crypt>"
        sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
        echo "</tls-crypt>"
    } > /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline
    
    # .ovpn fájl létrehozása
    if grep -vh '^#' /etc/openvpn/server/client-common.txt /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline > "$ovpn_dir"/"$client".ovpn 2>/dev/null; then
        echo
        echo -e "${GREEN_BOLD}✅ **$client** kliens hozzáadva!${RESET}"
        echo -e "${GREEN_BOLD}📁 Konfigurációs fájl (kliens számára): ➡️ $ovpn_dir/$client.ovpn${RESET}"
    else
        echo -e "${RED_BOLD}❌ .ovpn fájl létrehozása sikertelen. Ellenőrizze a jogosultságokat!${RESET}"
    fi
}

# Kliensek listázása
list_clients() {
    echo
    echo -e "${WHITE_NORMAL}--- 📋 OpenVPN Kliensek Listája ---${RESET}"
    
    if [[ ! -f /etc/openvpn/server/easy-rsa/pki/index.txt ]]; then
        echo -e "${RED_BOLD}❌ Nincsenek kliensek vagy az OpenVPN nincs telepítve.${RESET}"
        return 1
    fi
    
    NUMBER_OF_CLIENTS=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
    if [[ "$NUMBER_OF_CLIENTS" = '0' ]]; then
        echo -e "${YELLOW_BOLD}ℹ️ Nincsenek aktív kliensek.${RESET}"
        return 0
    fi
    
    echo -e "${WHITE_NORMAL}📊 Aktív kliensek (érvényes tanúsítvánnyal):${RESET}"
    tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
    
    # Visszavont kliensek
    REVOKED_CLIENTS=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^R")
    if [[ "$REVOKED_CLIENTS" -gt 0 ]]; then
        echo
        echo -e "${RED_BOLD}🚫 Visszavont kliensek:${RESET}"
        tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^R" | cut -d '=' -f 2 | nl -s ') '
    fi
    
    # Kapcsolódott kliensek
    if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
        echo
        echo -e "${WHITE_NORMAL}🔗 Kapcsolódási státusz (utolsó log alapján):${RESET}"
        CURRENT_VPN_NETWORK_BASE=$(grep '^server ' /etc/openvpn/server/server.conf | awk '{print $2}' 2>/dev/null || echo "10.8.0.0")
        
        CONNECTED_CLIENTS=$(grep "$CURRENT_VPN_NETWORK_BASE" /etc/openvpn/server/openvpn-status.log 2>/dev/null | wc -l || echo 0)
        
        if [[ "$CONNECTED_CLIENTS" -gt 0 ]]; then
            # Megjeleníti a kliens nevet és a hozzárendelt VPN IP-t
            grep "$CURRENT_VPN_NETWORK_BASE" /etc/openvpn/server/openvpn-status.log 2>/dev/null | awk '{print "  ➡️ " $2 " (" $3 ")"}'
        else
            echo -e "${YELLOW_BOLD}  Nincsenek aktív kapcsolatok.${RESET}"
        fi
    fi
}

# Kliens visszavonása
revoke_client() {
    echo
    echo -e "${WHITE_NORMAL}--- 🚫 Kliens Visszavonása ---${RESET}"
    
    NUMBER_OF_CLIENTS=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
    if [[ "$NUMBER_OF_CLIENTS" = '0' ]]; then
        echo -e "${RED_BOLD}❌ Nincsenek érvényes kliensek!${RESET}"
        return 1
    fi
    
    echo -e "${WHITE_NORMAL}Elérhető kliensek:${RESET}"
    tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
    
    read -p "$(echo -e "${YELLOW_BOLD}Válassza ki a visszavonandó klienst: ${RESET}")" CLIENT_NUMBER
    until [[ "$CLIENT_NUMBER" =~ ^[0-9]+$ && "$CLIENT_NUMBER" -le "$NUMBER_OF_CLIENTS" ]]; do
        echo -e "${RED_BOLD}❌ Érvénytelen választás!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Válassza ki a visszavonandó klienst: ${RESET}")" CLIENT_NUMBER
    done
    
    CLIENT=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENT_NUMBER"p)
    
    cd /etc/openvpn/server/easy-rsa/
    execute_command "./easyrsa --batch revoke \"$CLIENT\"" "Tanúsítvány visszavonása"
    execute_command "EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl" "CRL lista frissítése"
    rm -f /etc/openvpn/server/crl.pem
    execute_command "cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem" "CRL másolása a szerver mappába"
    chmod 644 /etc/openvpn/server/crl.pem
    
    execute_command "systemctl restart openvpn-server@server.service" "OpenVPN szolgáltatás újraindítása (a CRL miatt)"
    
    echo
    echo -e "${GREEN_BOLD}✅ **$CLIENT** kliens visszavonva! (Hozzáférés tiltva a CRL-listán)${RESET}"
}

# Kliens teljes törlése
delete_client() {
    echo
    echo -e "${WHITE_NORMAL}--- 🗑️ Kliens Teljes Törlése ---${RESET}"
    
    NUMBER_OF_CLIENTS=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
    if [[ "$NUMBER_OF_CLIENTS" = '0' ]]; then
        echo -e "${RED_BOLD}❌ Nincsenek érvényes kliensek a törléshez!${RESET}"
        return 1
    fi
    
    echo -e "${WHITE_NORMAL}Elérhető kliensek (akiknek van érvényes tanúsítványa):${RESET}"
    tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
    
    read -p "$(echo -e "${YELLOW_BOLD}Válassza ki a törölni kívánt klienst: ${RESET}")" CLIENT_NUMBER
    until [[ "$CLIENT_NUMBER" =~ ^[0-9]+$ && "$CLIENT_NUMBER" -le "$NUMBER_OF_CLIENTS" ]]; do
        echo -e "${RED_BOLD}❌ Érvénytelen választás!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Válassza ki a törölni kívánt klienst: ${RESET}")" CLIENT_NUMBER
    done
    
    CLIENT=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENT_NUMBER"p)
    
    # Megerősítés
    echo
    read -p "$(echo -e "${RED_BOLD}⚠️ Biztos, hogy törölni szeretné a(z) '$CLIENT' klienst? (A művelet nem visszavonható!) [i/N]: ${RESET}")" confirm_delete
    if [[ ! "$confirm_delete" =~ ^[iI]$ ]]; then
        echo -e "${WHITE_NORMAL}ℹ️ Törlés megszakítva.${RESET}"
        return 0
    fi
    
    cd /etc/openvpn/server/easy-rsa/
    
    # 1. Kliens visszavonása (fontos lépés)
    execute_command "./easyrsa --batch revoke \"$CLIENT\"" "Kliens tanúsítványának visszavonása"
    execute_command "EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl" "CRL lista frissítése"
    rm -f /etc/openvpn/server/crl.pem
    cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
    chmod 644 /etc/openvpn/server/crl.pem
    
    # 2. Tanúsítvány fájlok törlése
    echo -e "${WHITE_NORMAL}🗑️ Tanúsítvány fájlok törlése...${RESET}"
    rm -f /etc/openvpn/server/easy-rsa/pki/reqs/"$CLIENT".req 2>/dev/null
    rm -f /etc/openvpn/server/easy-rsa/pki/private/"$CLIENT".key 2>/dev/null
    rm -f /etc/openvpn/server/easy-rsa/pki/issued/"$CLIENT".crt 2>/dev/null
    rm -f /etc/openvpn/server/easy-rsa/pki/inline/private/"$CLIENT".inline 2>/dev/null
    
    # 3. .ovpn fájl keresése és törlése (gyökér/home/megadott mappákban)
    echo -e "${WHITE_NORMAL}🔍 .ovpn fájl keresése és törlése...${RESET}"
    OVPN_FILES=$(find /home /root /tmp "$ovpn_dir" -name "$CLIENT.ovpn" 2>/dev/null)
    if [[ -n "$OVPN_FILES" ]]; then
        for ovpn_file in $OVPN_FILES; do
            echo -e "  🗑️ Törölve: $ovpn_file"
            rm -f "$ovpn_file"
        done
    else
        echo -e "${YELLOW_BOLD}ℹ️ Nem található .ovpn fájl a klienshez a standard mappákban.${RESET}"
    fi
    
    execute_command "systemctl restart openvpn-server@server.service" "OpenVPN szolgáltatás újraindítása"
    
    echo
    echo -e "${GREEN_BOLD}✅ **$CLIENT** kliens teljesen törölve!${RESET}"
}

# OpenVPN eltávolítása
remove_openvpn() {
    echo
    echo -e "${WHITE_NORMAL}--- 🗑️ OpenVPN Eltávolítása ---${RESET}"
    read -p "$(echo -e "${RED_BOLD}⚠️ Biztos, hogy eltávolítja az OpenVPN-t és minden konfigurációs fájlt? [i/N]: ${RESET}")" remove
    if [[ "$remove" =~ ^[iI]$ ]]; then
        # Konfiguráció kinyerése a tűzfal törléshez
        port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2 2>/dev/null || echo "$DEFAULT_PORT")
        protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2 2>/dev/null || echo "$DEFAULT_PROTOCOL")
        VPN_NETWORK_CIDR=$(grep '^server ' /etc/openvpn/server/server.conf | awk '{print $2 "/24"}' 2>/dev/null || echo "$VPN_NETWORK_CIDR")

        execute_command "systemctl stop openvpn-server@server" "OpenVPN szolgáltatás leállítása"
        execute_command "systemctl disable openvpn-server@server" "OpenVPN szolgáltatás letiltása"
        
        # Fájlok törlése
        execute_command "rm -rf /etc/openvpn/server" "OpenVPN konfigurációs mappa törlése"
        execute_command "rm -f /etc/sysctl.d/99-openvpn-forward.conf" "Sysctl fájl törlése"
        execute_command "sysctl -q -p /etc/sysctl.conf" "Sysctl beállítások visszaállítása"
        
        # Tűzfal szabályok törlése
        local INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        if command -v firewalld >/dev/null 2>&1; then
            execute_command "firewall-cmd --remove-masquerade --permanent" "Firewalld Masquerade eltávolítása"
            execute_command "firewall-cmd --zone=public --remove-port=$port/$protocol --permanent" "Firewalld port eltávolítása"
            execute_command "firewall-cmd --reload" "Firewalld újratöltése"
        elif command -v ufw >/dev/null 2>&1; then
            execute_command "ufw delete allow $port/$protocol" "UFW port eltávolítása"
            # NAT szabályok törlése (csak ha tartalmazza a jelölőket)
            if grep -q "# START OPENVPN RULES" /etc/ufw/before.rules; then
                execute_command "sed -i '/# START OPENVPN RULES/,/# END OPENVPN RULES/d' /etc/ufw/before.rules" "UFW NAT szabályok eltávolítása"
                execute_command "ufw reload" "UFW újratöltése"
            fi
        else
            # Iptables szabályok törlése (csak ha léteznek)
            execute_command "iptables -t nat -D POSTROUTING -s $VPN_NETWORK_CIDR -o $INTERFACE -j MASQUERADE 2>/dev/null" "NAT/Masquerade szabály törlése"
            execute_command "iptables -D INPUT -p $protocol --dport $port -j ACCEPT 2>/dev/null" "Port engedélyezés (INPUT) törlése"
            execute_command "iptables -D FORWARD -s $VPN_NETWORK_CIDR -j ACCEPT 2>/dev/null" "VPN hálózat továbbítás (FORWARD) törlése"
            execute_command "iptables -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null" "Kapcsolatok engedélyezése (FORWARD) törlése"
            if command -v netfilter-persistent >/dev/null 2>&1; then
                execute_command "netfilter-persistent save" "Iptables szabályok mentése"
            fi
        fi

        # Szoftver eltávolítása
        if [[ "$os" =~ (ubuntu|debian) ]]; then
            execute_command "apt-get remove --purge -y openvpn" "OpenVPN eltávolítása"
            execute_command "apt-get autoremove -y" "Felesleges függőségek törlése"
        elif [[ "$os" == 'centos' ]]; then
            execute_command "yum remove -y openvpn || dnf remove -y openvpn" "OpenVPN eltávolítása"
        fi
        
        echo
        echo -e "${GREEN_BOLD}✅ OpenVPN sikeresen eltávolítva!${RESET}"
    else
        echo
        echo -e "${WHITE_NORMAL}ℹ️ Eltávolítás megszakítva.${RESET}"
    fi
}

# OpenVPN telepítés (javított, jobb hibakezeléssel)
install_openvpn() {
    detect_os
    
    echo
    echo -e "${GREEN_BOLD}--- 🛡️ OpenVPN Telepítés Előkészítése ---${RESET}"
    
    # Rendszer ellenőrzés
    if ! system_health_check; then
        echo -e "${RED_BOLD}❌ A rendszer nem felel meg a minimális követelményeknek${RESET}"
        exit 1
    fi
    
    # Hálózati ellenőrzés
    check_network_connectivity

    # Konfigurációs mappa
    echo
    echo -e "${WHITE_NORMAL}--- 📁 Kliensfájl helye (.ovpn) ---${RESET}"
    read -p "$(echo -e "${YELLOW_BOLD}Adja meg a mappát, ahová a .ovpn fájlok kerüljenek [$DEFAULT_OVPN_DIR]: ${RESET}")" ovpn_dir_input
    [[ -z "$ovpn_dir_input" ]] && ovpn_dir="$DEFAULT_OVPN_DIR" || ovpn_dir="$ovpn_dir_input"
    
    if ! mkdir -p "$ovpn_dir" 2>/dev/null; then
        echo -e "${RED_BOLD}❌ Nem sikerült létrehozni a mappát: $ovpn_dir${RESET}"
        exit 1
    fi

    # Beállítások gyűjtése
    setup_vpn_network
    get_network_settings
    get_local_network_route  
    
    echo
    echo -e "${GREEN_BOLD}✅ OpenVPN telepítés kezdete.${RESET}"
    read -n1 -r -p "$(echo -e "${YELLOW_BOLD}Nyomjon meg egy gombot a folytatáshoz...${RESET}")"
	echo

    # --- TELEPÍTÉSI LÉPÉSEK ---
    
    # Csomagok telepítése
    if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
        execute_command "apt-get update" "Csomaglista frissítése"
        execute_command "apt-get install -y --no-install-recommends openvpn openssl ca-certificates iptables netfilter-persistent wget curl" "OpenVPN és függőségek telepítése"
    elif [[ "$os" = "centos" ]]; then
        execute_command "dnf install -y epel-release" "EPEL repository hozzáadása"
        execute_command "dnf install -y openvpn openssl ca-certificates tar firewalld wget curl" "OpenVPN és függőségek telepítése"
    fi

    # EasyRSA telepítése
    execute_command "mkdir -p /etc/openvpn/server/easy-rsa" "EasyRSA mappa létrehozása"
    cd /etc/openvpn/server/easy-rsa
    
    if execute_command "wget -O easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v$EASYRSA_VER/EasyRSA-$EASYRSA_VER.tgz" "EasyRSA letöltése"; then
        execute_command "tar xzf easy-rsa.tgz --strip-components=1 && rm -f easy-rsa.tgz" "EasyRSA kicsomagolása"
    else
        echo -e "${RED_BOLD}❌ EasyRSA letöltése sikertelen${RESET}"
        exit 1
    fi

    # PKI inicializálás
    execute_command "./easyrsa init-pki" "PKI inicializálása"
    execute_command "./easyrsa --batch build-ca nopass" "CA tanúsítvány létrehozása"
    execute_command "./easyrsa --batch gen-req server nopass" "Szerver tanúsítvány kérelem"
    execute_command "./easyrsa --batch sign-req server server" "Szerver tanúsítvány aláírása"
    
    # DH paraméterek generálása (háttérben, mivel lassú lehet)
    echo -e "${WHITE_NORMAL}⏳ Diffie-Hellman paraméterek generálása (ez eltarthat pár percig)...${RESET}"
    ./easyrsa --batch gen-dh > /dev/null 2>&1 &
    local dh_pid=$!
    local dh_attempts=0
    
    while [[ ! -f pki/dh.pem && $dh_attempts -lt 30 ]]; do
        sleep 5
        ((dh_attempts++))
        # echo -e "${WHITE_NORMAL}⏳ DH paraméterek generálása... ($(($dh_attempts * 5)) mp)${RESET}"
    done
    
    if [[ -f pki/dh.pem ]]; then
        execute_command "cp pki/dh.pem /etc/openvpn/server/" "DH paraméterek másolása"
    else
        echo -e "${RED_BOLD}❌ DH paraméterek generálása időtúllépés!${RESET}"
        exit 1
    fi

    # Tanúsítványok másolása
    execute_command "cp pki/ca.crt /etc/openvpn/server/" "CA tanúsítvány másolása"
    execute_command "cp pki/private/server.key /etc/openvpn/server/" "Szerver kulcs másolása"
    execute_command "cp pki/issued/server.crt /etc/openvpn/server/" "Szerver tanúsítvány másolása"

    # TLS kulcs generálása
    execute_command "openvpn --genkey secret /etc/openvpn/server/tc.key" "TLS kulcs generálása"

    # Konfigurációs fájlok létrehozása
    get_default_client_common
    
    # server.conf generálása
    if create_server_config; then
        echo -e "${GREEN_BOLD}✅ Szerver konfiguráció létrehozva${RESET}"
    else
        echo -e "${RED_BOLD}❌ Szerver konfiguráció hibás${RESET}"
        exit 1
    fi
    
    # Tűzfal konfigurálása
    configure_firewall

    # Első kliens létrehozása
    create_first_client

    # Szolgáltatás indítása
    execute_command "systemctl daemon-reload" "Systemd daemon reload"
    execute_command "systemctl enable --now openvpn-server@server.service" "OpenVPN szolgáltatás indítása"

    # Végső ellenőrzés
    if validate_openvpn_config && systemctl is-active --quiet openvpn-server@server.service; then
        show_success_message
    else
        echo -e "${RED_BOLD}⚠️ OpenVPN telepítve, de a szolgáltatás nem fut${RESET}"
        echo -e "${WHITE_NORMAL}Hibakeresés: systemctl status openvpn-server@server.service${RESET}"
    fi
}

# Főmenü
main_menu() {
    clear
    
    # Aktuális konfiguráció kinyerése
    if [[ -f /etc/openvpn/server/server.conf ]]; then
        port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2 2>/dev/null || echo "$DEFAULT_PORT")
        protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2 2>/dev/null || echo "$DEFAULT_PROTOCOL")
        ip=$(grep '^local ' /etc/openvpn/server/server.conf | cut -d " " -f 2 2>/dev/null || ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n1)
        VPN_NETWORK_BASE=$(grep '^server ' /etc/openvpn/server/server.conf | awk '{print $2}' 2>/dev/null || echo "$VPN_NETWORK_BASE")
        VPN_NETWORK_CIDR="$VPN_NETWORK_BASE/24"
    fi
    
    echo -e "${GREEN_BOLD}=========================================="
    echo -e "      🛡️ OpenVPN Kezelő Menü (v1.1)"
    echo -e "=========================================="
    echo -e "    Szerver: $ip ($port/$protocol)"
    echo -e "    VPN Hálózat: $VPN_NETWORK_CIDR"
    echo -e "==========================================${RESET}"
    echo
    echo -e "${WHITE_NORMAL}Válasszon egy opciót:${RESET}"
    echo -e "${WHITE_NORMAL}    1) ➕ Új kliens hozzáadása${RESET}"
    echo -e "${WHITE_NORMAL}    2) 📋 Kliensek listázása (Státusz)${RESET}"
    echo -e "${WHITE_NORMAL}    3) 🚫 Kliens visszavonása (Hozzáf. tiltás)${RESET}"
    echo -e "${WHITE_NORMAL}    4) 🗑️ Kliens teljes törlése${RESET}"
    echo -e "${WHITE_NORMAL}    5) 🔧 OpenVPN eltávolítása a rendszerről${RESET}"
    echo -e "${WHITE_NORMAL}    6) 🚪 Kilépés${RESET}"
    echo
    read -p "$(echo -e "${YELLOW_BOLD}Opció: ${RESET}")" option
    until [[ "$option" =~ ^[1-6]$ ]]; do
        echo -e "${RED_BOLD}❌ Érvénytelen választás!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Opció: ${RESET}")" option
    done
    
    case "$option" in
        1) add_client ;;
        2)  
            list_clients
            echo
            read -p "$(echo -e "${WHITE_NORMAL}Nyomjon Enter-t a folytatáshoz...${RESET}")"
            ;;
        3) revoke_client ;;
        4) delete_client ;;
        5) remove_openvpn ;;
        6)  
            echo
            echo -e "${GREEN_BOLD}👋 Viszlát!${RESET}"
            exit 0
            ;;
    esac
    
    echo
    read -p "$(echo -e "${WHITE_NORMAL}Nyomjon Enter-t a főmenühöz való visszatéréshez...${RESET}")"
    main_menu
}

# --- SZKRIPT FUTTATÁSA ---

# Főprogram
main() {
    # Naplózás inicializálása
    mkdir -p /var/log 2>/dev/null
    touch /var/log/openvpn-installer.log 2>/dev/null
    chmod 600 /var/log/openvpn-installer.log 2>/dev/null
    
    log_message "INFO" "OpenVPN installer started (v1.1)"
    
    detect_os
    if [[ ! -e /etc/openvpn/server/server.conf ]]; then
        clear
        echo -e "${GREEN_BOLD}👋 Üdvözöljük az OpenVPN Telepítőben! (v1.1)${RESET}"
        echo -e "${WHITE_NORMAL}Ez a szkript interaktívan beállítja az OpenVPN szervert.${RESET}"
        install_openvpn
        
        echo
        read -p "$(echo -e "${WHITE_NORMAL}Nyomjon Enter-t a főmenühöz való továbblépéshez...${RESET}")"
        main_menu
    else
        main_menu
    fi
}

main "$@"
