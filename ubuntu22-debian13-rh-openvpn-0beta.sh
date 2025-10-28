#!/bin/bash
## OpenVPN telepítő (Hibajavított, teljes, MAGYAR változat, Zöld színekkel)
# Alap: Nyr https://github.com/Nyr/openvpn-install
# Továbbfejlesztette: Gcsipai https://github.com/gcsipai
# Kompatibilitás: Ubuntu 22.04/24.04 LTS, Debian 12/13, RHEL-alapúak
# FIX: Kézi VPN hálózat bevitele és server.conf generálási hiba javítása.

# --- SZÍNKÓDOK (Zöld/Fehér) ---
GREEN_BOLD='\033[1;32m'  # Fő címek, sikeres műveletek
WHITE_NORMAL='\033[0;37m' # Információk, alcímek
YELLOW_BOLD='\033[1;33m' # Figyelmeztetések, input kérdések
RED_BOLD='\033[1;31m'   # Hibaüzenetek, kritikus figyelmeztetések
RESET='\033[0m'         # Alapértelmezett szín visszaállítása

# --- ALAPÉRTELMEZETT BEÁLLÍTÁSOK ---
DEFAULT_PORT="1194"
DEFAULT_PROTOCOL="udp"
DEFAULT_DNS="2" 
DEFAULT_CLIENT_NAME="kliens"
DEFAULT_OVPN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
VPN_NETWORK_CIDR="10.8.0.0/24"
VPN_NETWORK_BASE="10.8.0.0"
EASYRSA_VER="3.2.4" 

# --- GLOBÁLIS VÁLTOZÓK DEKLARÁLÁSA ---
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

# --- SEGÉDFÜGGVÉNYEK ÉS ELLENŐRZÉSEK ---

# 0. pont: Operációs rendszer detektálása
detect_os() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED_BOLD}⚠️ Ezt a telepítőt rendszergazdai (root) jogosultságokkal kell futtatni. Használja a 'sudo bash $0' parancsot.${RESET}"
        exit 1
    fi
    if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
        echo -e "${RED_BOLD}❌ A TUN eszköz nem elérhető a rendszeren. Engedélyezni kell a futtatás előtt.${RESET}"
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
}

# Kliens nevének tisztítása
sanitize_client_name() {
	unsanitized_client="$1"
	client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
	if [[ -z "$client" ]]; then
		client="$DEFAULT_CLIENT_NAME"
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
    
    local_networks=$(ip -4 route show | grep -v 'default' | awk '{print $1}' | grep -vE '^(127|169|172\.17)' | grep /)
    
    for net in $local_networks; do
        if ip route get "$check_base" 2>/dev/null | grep -q "$net"; then
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

    # 2. Kézi felülírás opció (MINDIG MEGJELENIK)
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

# Lokális hálózat felismerése és bekérése (Javítva a CIDR kinyerése)
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
            
            # Kiszámítja a hálózati címet (pl. 10.168.0.25/24 -> 10.168.0.0/24)
            if [[ -n "$IP" && -n "$MASK" && "$MASK" -le 32 ]]; then
                # Megbízható hálózati cím számítás /24 esetén
                if [[ "$MASK" -eq 24 ]]; then
                    local_network_only=$(echo "$IP" | cut -d '.' -f 1-3)".0/$MASK"
                else
                    # Ha nem /24, a teljes CIDR-t használjuk
                    local_network_only="$local_network_cidr_raw"
                fi
                
                # Ezt a tiszta CIDR-t használjuk a push route parancshoz
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

# Hálózati beállítások bekérése
get_network_settings() {
    echo
    echo -e "${WHITE_NORMAL}--- 🌐 Hálózati Beállítások ---${RESET}"
    
    ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "")
    if [[ -z "$ip" ]]; then
        ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n1)
    fi
    
    read -p "$(echo -e "${YELLOW_BOLD}Adja meg a szerver nyilvános IP címét [$ip]: ${RESET}")" custom_ip
    [[ -n "$custom_ip" ]] && ip="$custom_ip"
    
    read -p "$(echo -e "${YELLOW_BOLD}Protokoll (udp/tcp) [$DEFAULT_PROTOCOL]: ${RESET}")" protocol_input
    protocol=${protocol_input,,}
    [[ -z "$protocol" ]] && protocol="$DEFAULT_PROTOCOL"
    until [[ "$protocol" == "udp" || "$protocol" == "tcp" ]]; do
        echo -e "${RED_BOLD}❌ Csak 'udp' vagy 'tcp' lehet!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Protokoll (udp/tcp) [$DEFAULT_PROTOCOL]: ${RESET}")" protocol_input
        protocol=${protocol_input,,}
        [[ -z "$protocol" ]] && protocol="$DEFAULT_PROTOCOL"
    done
    
    read -p "$(echo -e "${YELLOW_BOLD}Port [$DEFAULT_PORT]: ${RESET}")" port
    [[ -z "$port" ]] && port="$DEFAULT_PORT"
    until [[ "$port" =~ ^[0-9]+$ && "$port" -le 65535 ]]; do
        echo -e "${RED_BOLD}❌ Érvénytelen port szám!${RESET}"
        read -p "$(echo -e "${YELLOW_BOLD}Port [$DEFAULT_PORT]: ${RESET}")" port
        [[ -z "$port" ]] && port="$DEFAULT_PORT"
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
        read -p "$(echo -e "${YELLOW_BOLD}Adja meg az elsődleges DNS-t: ${RESET}")" dns_server_1
        until [[ "$dns_server_1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; do
            echo -e "${RED_BOLD}❌ Érvénytelen IP cím!${RESET}"
            read -p "$(echo -e "${YELLOW_BOLD}Adja meg az elsődleges DNS-t: ${RESET}")" dns_server_1
        done
        read -p "$(echo -e "${YELLOW_BOLD}Adja meg a másodlagos DNS-t (opcionális): ${RESET}")" dns_server_2
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

    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn-forward.conf
    sysctl -q -p /etc/sysctl.d/99-openvpn-forward.conf
    
    if command -v firewalld >/dev/null 2>&1; then
        echo -e "${WHITE_NORMAL}⚙️ Firewalld konfigurálása...${RESET}"
        # Masquerade engedélyezése
        firewall-cmd --add-masquerade --permanent
        # OpenVPN port engedélyezése a public zónában
        firewall-cmd --zone=public --add-port="$port/$protocol" --permanent
        firewall-cmd --reload
    else 
        echo -e "${WHITE_NORMAL}⚙️ Iptables/Netfilter-persistent konfigurálása...${RESET}"
        # Masquerade (NAT) a VPN hálózat számára
        iptables -t nat -A POSTROUTING -s "$VPN_NETWORK_CIDR" -j MASQUERADE
        # OpenVPN port engedélyezése
        iptables -A INPUT -p "$protocol" --dport "$port" -j ACCEPT
        # Forgalom továbbítás (Routing) a TUN interface-en keresztül
        iptables -A FORWARD -s "$VPN_NETWORK_CIDR" -j ACCEPT
        iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        
        if command -v netfilter-persistent >/dev/null 2>&1; then
            netfilter-persistent save
        fi
        
        if command -v ufw >/dev/null 2>&1; then
             ufw allow "$port/$protocol"
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
    ./easyrsa --batch gen-req "$client" nopass
    ./easyrsa --batch sign-req client "$client"
    
    mkdir -p /etc/openvpn/server/easy-rsa/pki/inline/private/
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
    
    grep -vh '^#' /etc/openvpn/server/client-common.txt /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline > "$ovpn_dir"/"$client".ovpn
    
    echo
    echo -e "${GREEN_BOLD}✅ **$client** kliens hozzáadva!${RESET}"
    echo -e "${GREEN_BOLD}📁 Konfigurációs fájl (kliens számára): ➡️ $ovpn_dir/$client.ovpn${RESET}"
}

# OpenVPN telepítés (server.conf generálás javítva)
install_openvpn() {
	detect_os
	
    echo
    echo -e "${WHITE_NORMAL}--- 📁 Kliensfájl helye (.ovpn) ---${RESET}"
    read -p "$(echo -e "${YELLOW_BOLD}Adja meg a mappát, ahová a .ovpn fájlok kerüljenek [$DEFAULT_OVPN_DIR]: ${RESET}")" ovpn_dir_input
    [[ -z "$ovpn_dir_input" ]] && ovpn_dir="$DEFAULT_OVPN_DIR" || ovpn_dir="$ovpn_dir_input"
    mkdir -p "$ovpn_dir" 2>/dev/null
    
    setup_vpn_network
    get_network_settings
    get_local_network_route 
    
	echo
	echo -e "${GREEN_BOLD}✅ OpenVPN telepítés kezdete.${RESET}"
	read -n1 -r -p "$(echo -e "${YELLOW_BOLD}Nyomjon meg egy gombot a folytatáshoz...${RESET}")"

	# --- TELEPÍTÉSI LÉPÉSEK ---
    
    if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
		apt-get update
		apt-get install -y --no-install-recommends openvpn openssl ca-certificates iptables netfilter-persistent wget
	elif [[ "$os" = "centos" ]]; then
		dnf install -y epel-release
		dnf install -y openvpn openssl ca-certificates tar firewalld wget
	fi

    mkdir -p /etc/openvpn/server/easy-rsa
    cd /etc/openvpn/server/easy-rsa
    wget -O easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v"$EASYRSA_VER"/EasyRSA-"$EASYRSA_VER".tgz
    tar xzf easy-rsa.tgz --strip-components=1
    rm -f easy-rsa.tgz
    
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    ./easyrsa --batch gen-req server nopass
    ./easyrsa --batch sign-req server server
    ./easyrsa --batch gen-dh 2>/dev/null
    
    cp pki/ca.crt /etc/openvpn/server/
    cp pki/private/server.key /etc/openvpn/server/
    cp pki/issued/server.crt /etc/openvpn/server/
    cp pki/dh.pem /etc/openvpn/server/
    
    openvpn --genkey secret /etc/openvpn/server/tc.key
    get_default_client_common
    
    # server.conf generálása (alap)
    echo "# OpenVPN 2.6 Server Configuration generated by custom script
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

# Kliens beállítások
push \"redirect-gateway def1 bypass-dhcp\"
" > /etc/openvpn/server/server.conf
	
    # DNS beállítások hozzáadása
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

    # Lokális hálózat push hozzáadása (a most már biztosan érvényes CIDR-rel)
    if [[ -n "$local_network_route" ]]; then
        echo "push \"route $local_network_route\"" >> /etc/openvpn/server/server.conf
    fi

    # Továbbá a server.conf-hoz
    echo "
user nobody
group $group_name
cipher AES-256-GCM
persist-key
persist-tun
status openvpn-status.log
verb 3" >> /etc/openvpn/server/server.conf
    
    configure_firewall
    
    # Első kliens létrehozása a telepítés végén
    cd /etc/openvpn/server/easy-rsa/
    ./easyrsa --batch gen-req "$client" nopass
    ./easyrsa --batch sign-req client "$client"
    
    mkdir -p /etc/openvpn/server/easy-rsa/pki/inline/private/
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
    
    grep -vh '^#' /etc/openvpn/server/client-common.txt /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline > "$ovpn_dir"/"$client".ovpn

    # CRL generálása
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
    chmod 644 /etc/openvpn/server/crl.pem
    echo "crl-verify crl.pem" >> /etc/openvpn/server/server.conf
    
    # Szolgáltatás indítása
    systemctl daemon-reload
    systemctl enable --now openvpn-server@server.service
    
    # Ellenőrizze a státuszt
    if systemctl is-active --quiet openvpn-server@server.service; then
        echo -e "${GREEN_BOLD}🎉 A telepítés KÉSZ! Az OpenVPN szerver sikeresen fut!${RESET}"
    else
        echo -e "${RED_BOLD}⚠️ A telepítés befejeződött, de az OpenVPN szerver nem indult el!${RESET}"
        echo -e "${RED_BOLD}Kérem ellenőrizze a logot: 'systemctl status openvpn-server@server.service'${RESET}"
    fi
    echo -e "${GREEN_BOLD}A konfigurációs fájl itt található: ➡️ $ovpn_dir/$client.ovpn${RESET}"
}

# --- FŐ MENÜ RENDSZER (klienskezelés) ---

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
        # VPN_NETWORK_BASE használata (a szerver.conf-ból kinyerve, vagy alapértelmezett)
        CURRENT_VPN_NETWORK_BASE=$(grep '^server ' /etc/openvpn/server/server.conf | awk '{print $2}' 2>/dev/null || echo "10.8.0.0")
        
        CONNECTED_CLIENTS=$(grep "$CURRENT_VPN_NETWORK_BASE" /etc/openvpn/server/openvpn-status.log 2>/dev/null | wc -l || echo 0)
        
        if [[ "$CONNECTED_CLIENTS" -gt 0 ]]; then
            grep "$CURRENT_VPN_NETWORK_BASE" /etc/openvpn/server/openvpn-status.log 2>/dev/null | awk '{print "  ➡️ " $2 " (" $3 ")"}'
        else
            echo -e "${YELLOW_BOLD}   Nincsenek aktív kapcsolatok.${RESET}"
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
    ./easyrsa --batch revoke "$CLIENT"
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    rm -f /etc/openvpn/server/crl.pem
    cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
    chmod 644 /etc/openvpn/server/crl.pem
    
    systemctl restart openvpn-server@server.service 2>/dev/null
    
    echo
    echo -e "${GREEN_BOLD}✅ **$CLIENT** kliens visszavonva! (Hozzáférés tiltva a CRL-listán)${RESET}"
}

# Kliens teljes törlése (ÚJ FUNKCIÓ)
delete_client() {
    echo
    echo -e "${WHITE_NORMAL}--- 🗑️ Kliens Teljes Törlése ---${RESET}"
    
    NUMBER_OF_CLIENTS=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
    if [[ "$NUMBER_OF_CLIENTS" = '0' ]]; then
        echo -e "${RED_BOLD}❌ Nincsenek kliensek a törléshez!${RESET}"
        return 1
    fi
    
    echo -e "${WHITE_NORMAL}Elérhető kliensek:${RESET}"
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
    
    # 1. Kliens visszavonása
    echo -e "${WHITE_NORMAL}🔐 Kliens visszavonása...${RESET}"
    ./easyrsa --batch revoke "$CLIENT"
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    rm -f /etc/openvpn/server/crl.pem
    cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
    chmod 644 /etc/openvpn/server/crl.pem
    
    # 2. Tanúsítvány fájlok törlése
    echo -e "${WHITE_NORMAL}🗑️ Tanúsítvány fájlok törlése...${RESET}"
    rm -f /etc/openvpn/server/easy-rsa/pki/reqs/"$CLIENT".req 2>/dev/null
    rm -f /etc/openvpn/server/easy-rsa/pki/private/"$CLIENT".key 2>/dev/null
    rm -f /etc/openvpn/server/easy-rsa/pki/issued/"$CLIENT".crt 2>/dev/null
    rm -f /etc/openvpn/server/easy-rsa/pki/inline/private/"$CLIENT".inline 2>/dev/null
    
    # 3. .ovpn fájl keresése és törlése
    echo -e "${WHITE_NORMAL}🔍 .ovpn fájl keresése...${RESET}"
    OVPN_FILES=$(find /home /root "$DEFAULT_OVPN_DIR" -name "$CLIENT.ovpn" 2>/dev/null)
    if [[ -n "$OVPN_FILES" ]]; then
        echo -e "${WHITE_NORMAL}📁 .ovpn fájlok törlése:${RESET}"
        for ovpn_file in $OVPN_FILES; do
            echo -e "  🗑️ $ovpn_file"
            rm -f "$ovpn_file"
        done
    else
        echo -e "${YELLOW_BOLD}ℹ️ Nem található .ovpn fájl a klienshez.${RESET}"
    fi
    
    systemctl restart openvpn-server@server.service 2>/dev/null
    
    echo
    echo -e "${GREEN_BOLD}✅ **$CLIENT** kliens teljesen törölve!${RESET}"
    echo -e "${WHITE_NORMAL}  - Visszavonva a hozzáférés${RESET}"
    echo -e "${WHITE_NORMAL}  - Tanúsítványok törölve${RESET}"
    echo -e "${WHITE_NORMAL}  - Konfigurációs fájlok törölve${RESET}"
}

# OpenVPN eltávolítása
remove_openvpn() {
    echo
    echo -e "${WHITE_NORMAL}--- 🗑️ OpenVPN Eltávolítása ---${RESET}"
    read -p "$(echo -e "${RED_BOLD}⚠️ Biztos, hogy eltávolítja az OpenVPN-t? [i/N]: ${RESET}")" remove
    if [[ "$remove" =~ ^[iI]$ ]]; then
        port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2 2>/dev/null || echo "$DEFAULT_PORT")
        protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2 2>/dev/null || echo "$DEFAULT_PROTOCOL")
        
        systemctl stop openvpn-server@server 2>/dev/null
        systemctl disable openvpn-server@server 2>/dev/null
        
        rm -rf /etc/openvpn/server
        rm -f /etc/sysctl.d/99-openvpn-forward.conf 2>/dev/null
        
        # Tűzfal szabályok törlése
        if command -v ufw >/dev/null 2>&1; then
            ufw delete allow "$port/$protocol" 2>/dev/null
        fi
        
        if [[ "$os" =~ (ubuntu|debian) ]]; then
            apt-get remove --purge -y openvpn 2>/dev/null
            apt-get autoremove -y 2>/dev/null
        elif [[ "$os" == 'centos' ]]; then
            yum remove -y openvpn 2>/dev/null || dnf remove -y openvpn 2>/dev/null
        fi
        
        echo
        echo -e "${GREEN_BOLD}✅ OpenVPN sikeresen eltávolítva!${RESET}"
    else
        echo
        echo -e "${WHITE_NORMAL}ℹ️ Eltávolítás megszakítva.${RESET}"
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
    echo -e "        🛡️ OpenVPN Kezelő Menü"
    echo -e "=========================================="
    echo -e "   Szerver: $ip ($port/$protocol)"
    echo -e "   VPN Hálózat: $VPN_NETWORK_CIDR"
    echo -e "==========================================${RESET}"
    echo
    echo -e "${WHITE_NORMAL}Válasszon egy opciót:${RESET}"
    echo -e "${WHITE_NORMAL}   1) ➕ Új kliens hozzáadása${RESET}"
    echo -e "${WHITE_NORMAL}   2) 📋 Kliensek listázása (Státusz)${RESET}"
    echo -e "${WHITE_NORMAL}   3) 🚫 Kliens visszavonása (Hozzáf. tiltás)${RESET}"
    echo -e "${WHITE_NORMAL}   4) 🗑️ Kliens teljes törlése${RESET}"
    echo -e "${WHITE_NORMAL}   5) 🔧 OpenVPN eltávolítása a rendszerről${RESET}"
    echo -e "${WHITE_NORMAL}   6) 🚪 Kilépés${RESET}"
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

detect_os 
if [[ ! -e /etc/openvpn/server/server.conf ]]; then
	clear
	echo -e "${GREEN_BOLD}👋 Üdvözöljük az OpenVPN Telepítőben!${RESET}"
    echo -e "${WHITE_NORMAL}Ez a szkript interaktívan beállítja az OpenVPN szervert.${RESET}"
	install_openvpn
    
    echo
    read -p "$(echo -e "${WHITE_NORMAL}Nyomjon Enter-t a főmenühöz való továbblépéshez...${RESET}")"
    main_menu
else
    main_menu
fi
