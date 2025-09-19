#!/bin/bash

# A szkript futtatásához root jogok szükségesek.
if [ "$EUID" -ne 0 ]; then
    echo "Kérlek, futtasd a szkriptet 'sudo' paranccsal."
    exit 1
fi

# --- FÜGGŐSÉGEK ÉS HÁLÓZATI ELLENŐRZÉS ---

# Függőségek ellenőrzése és telepítése
install_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "A következő csomagok hiányoznak a funkció futtatásához: ${missing_deps[*]}"
        read -p "Szeretnéd telepíteni őket most? (igen/nem) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ii]gen$ ]]; then
            sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"
            if [ $? -ne 0 ]; then
                echo "Hiba: A csomagok telepítése sikertelen."
                read -n 1 -s -r -p "Nyomj Entert a főmenübe való visszatéréshez."
                return 1
            fi
            echo "A hiányzó csomagok telepítése befejeződött."
        else
            echo "A telepítés elmaradt. A funkció nem fog tudni megfelelően működni."
            read -n 1 -s -r -p "Nyomj Entert a főmenübe való visszatéréshez."
            return 1
        fi
    fi
    return 0
}

# Ellenőrzi és figyelmeztet, ha a NetworkManager fut
check_network_manager() {
    if systemctl is-active --quiet NetworkManager; then
        echo "⚠️  Figyelem: A NetworkManager szolgáltatás aktív."
        echo "Egyes manuális hálózati beállítások konfliktusba kerülhetnek a NetworkManager-rel."
        echo "Ajánlott átmenetileg leállítani a művelet végrehajtása alatt."
        read -p "Szeretnéd átmenetileg leállítani a NetworkManager-t? (igen/nem) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ii]gen$ ]]; then
            sudo systemctl stop NetworkManager
            echo "✅ A NetworkManager átmenetileg leállítva."
            echo "Figyelem: A NetworkManager a rendszer újraindításakor újra elindul."
        else
            echo "⏭️  A NetworkManager futása megtartva. A konfliktusok lehetőségét vedd figyelembe."
        fi
    fi
    return 0
}

# --- FŐ MENÜ ---
main_menu() {
    while true; do
        clear
        echo "---------------------------------------------------"
        echo "Komplex hálózati és tűzfal konfigurátor Complex IT Group @ Kispest 2025 Béta!!!"
        echo "---------------------------------------------------"
        echo "1. Egyszerű tűzfal beállítás (Filtering)"
        echo "2. Komplett tűzfal (NAT, Port Forwarding, stb.)"
        echo "3. L2TP/IPsec VPN konfiguráció"
        echo "4. DHCP Szerver beállítások"
        echo "5. Squid és SquidGuard beállítások"
        echo "6. Webmin telepítése"
        echo "0. Kilépés"
        echo "---------------------------------------------------"
        read -p "Választás: " choice
        case $choice in
            1) simple_firewall_menu ;;
            2) complex_firewall_menu ;;
            3) l2tp_vpn_menu ;;
            4) dhcp_server_menu ;;
            5) squid_menu ;;
            6) install_webmin_menu ;;
            0) echo "👋  Kilépés. Viszlát!"; exit 0 ;;
            *) echo "Érvénytelen választás. Nyomj Entert a folytatáshoz."; read -n 1 -s -r -p "" ;;
        esac
    done
}

# --- 1. Egyszerű tűzfal (Filtering) ---
simple_firewall_menu() {
    clear
    echo "---------------------------------------------------"
    echo "       1. Egyszerű tűzfal beállítások"
    echo "---------------------------------------------------"
    echo "Ez egy alapvető filtering tűzfal. Minden nem engedélyezett forgalmat blokkol."
    echo "0. Függőségek telepítése (nft, ss)"
    echo "1. Tűzfal beállítása"
    echo "2. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        0) install_dependencies "nft" "ss"; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
        1) setup_simple_firewall ;;
        2) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
    esac
}
setup_simple_firewall() {
    if ! install_dependencies "nft" "ss"; then return; fi
    clear
    read -p "Figyelem! Ez a művelet felülírja a meglévő tűzfal szabályokat. Biztosan folytatod? (igen/nem) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then return; fi

    echo "A tűzfal szabályok beállítása..."
    nft flush ruleset
    nft add table ip filter
    
    # JAVÍTOTT SOROK - idézőjelek használata a kapcsos zárójelek körül
    nft 'add chain ip filter input { type filter hook input priority 0; policy drop; }'
    nft 'add chain ip filter output { type filter hook output priority 0; policy accept; }'
    nft 'add chain ip filter forward { type filter hook forward priority 0; policy drop; }'

    nft add rule ip filter input iif lo accept comment "loopback"
    nft add rule ip filter input ct state established,related accept comment "meglévő kapcsolatok"

    echo "Futó szolgáltatások felismerése és engedélyezése..."
    local services=$(ss -tuln | awk 'NR>1 {print $1,$5}')
    local service_list=()
    local i=1
    while IFS= read -r line; do
        local proto=$(echo "$line" | awk '{print $1}')
        local address=$(echo "$line" | awk '{print $2}')
        local port=$(echo "$address" | awk -F':' '{print $NF}')

        if [[ "$port" =~ ^[0-9]+$ ]]; then
            echo "    $i. Észlelt szolgáltatás a $port porton ($proto)."
            service_list+=("$port:$proto")
            i=$((i+1))
        fi
    done <<< "$services"

    echo "---------------------------------------------------"
    read -p "Melyik szolgáltatásokat szeretnéd engedélyezni? (pl. 1 3 4) " selected_choices
    echo

    for choice in $selected_choices; do
        if [ "$choice" -le "${#service_list[@]}" ] && [ "$choice" -gt 0 ]; then
            local service_info="${service_list[((choice-1))]}"
            local port=$(echo "$service_info" | cut -d':' -f1)
            local proto=$(echo "$service_info" | cut -d':' -f2)
            nft add rule ip filter input meta l4proto "$proto" dport "$port" accept
            echo "✅ Port: $port, Protokoll: $proto engedélyezve."
        else
            echo "❌ Hiba: Érvénytelen választás: $choice"
        fi
    done

    echo "✅ Alapértelmezett szabályok beállítva."
    read -p "Szeretnél manuálisan is hozzáadni portot? (igen/nem) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ii]gen$ ]]; then
        setup_simple_firewall_manual
    fi

    echo "✅ Tűzfal beállításai elkészültek."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_simple_firewall_manual() {
    while true; do
        read -p "Add meg a portszámot (pl. 80, 443): " port_number
        if ! [[ "$port_number" =~ ^[0-9]+$ ]]; then echo "Érvénytelen portszám."; continue; fi

        read -p "Melyik protokollt (tcp/udp/mind)? " protocol
        case $protocol in
            "tcp"|"TCP") nft add rule ip filter input tcp dport "$port_number" accept; echo "✅ TCP port $port_number engedélyezve." ;;
            "udp"|"UDP") nft add rule ip filter input udp dport "$port_number" accept; echo "✅ UDP port $port_number engedélyezve." ;;
            "mind"|"MIND") nft add rule ip filter input tcp dport "$port_number" accept; nft add rule ip filter input udp dport "$port_number" accept; echo "✅ TCP és UDP $port_number engedélyezve." ;;
            *) echo "❌ Érvénytelen protokoll."; continue ;;
        esac

        read -p "Szeretnél még portot hozzáadni? (igen/nem) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then break; fi
    done
}

# --- 2. Komplett tűzfal (NAT, Port Forwarding, stb.) ---
complex_firewall_menu() {
    clear
    echo "---------------------------------------------------"
    echo "      2. Komplett tűzfal beállítások"
    echo "---------------------------------------------------"
    echo "0. Függőségek telepítése (nft, ip)"
    echo "1. Egyszerű filtering tűzfal"
    echo "2. Masquerading és Port Forwarding (DNAT) beállítása"
    echo "3. Hairpin NAT beállítása"
    echo "4. 1:1 NAT beállítása"
    echo "5. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        0) install_dependencies "nft" "ip"; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
        1) setup_simple_firewall ;;
        2) setup_nat_forwarding ;;
        3) setup_hairpin_nat ;;
        4) setup_1_to_1_nat ;;
        5) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
    esac
}
setup_nat_forwarding() {
    if ! install_dependencies "nft" "ip"; then return; fi
    clear
    echo "Port Forwarding és Masquerading beállítása"
    echo "Jelenlegi interfészek:"
    ip -br a
    read -p "Add meg a belső hálózati interfészt (pl. eth0): " internal_if
    read -p "Add meg a külső hálózati interfészt (pl. enp1s0): " external_if
    if [ -z "$internal_if" ] || [ -z "$external_if" ]; then echo "❌ Az interfészek kötelezőek."; read -n 1 -s -r -p "Nyomj Entert a visszatéréshez."; return; fi
    
    # Masquerading (SNAT) beállítása
    echo "Masquerading beállítása..."
    nft add table ip nat 2>/dev/null
    nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }' 2>/dev/null
    nft add rule ip nat postrouting oif "$external_if" masquerade comment "masquerade"
    echo "✅ A belső hálózat már képes internetezni a $external_if interfészen keresztül."

    # Port Forwarding (DNAT) beállítása
    while true; do
        read -p "Szeretnél beállítani Port Forwarding-ot (DNAT)? (igen/nem) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then break; fi

        read -p "Külső port: " external_port
        read -p "Belső IP-cím (pl. 192.168.1.100): " internal_ip
        read -p "Belső port: " internal_port
        read -p "Protokoll (tcp/udp)? " protocol
        
        echo "Példa: a külső $external_port portra érkező forgalmat a belső $internal_ip cím $internal_port portjára irányítjuk át."
        nft add table ip nat 2>/dev/null
        nft 'add chain ip nat prerouting { type nat hook prerouting priority -100; }' 2>/dev/null
        nft add rule ip nat prerouting iif "$external_if" meta l4proto "$protocol" dport "$external_port" dnat to "$internal_ip":"$internal_port"
        echo "✅ Port Forwarding beállítva."
    done
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_hairpin_nat() {
    if ! install_dependencies "nft" "ip"; then return; fi
    clear
    echo "Hairpin NAT (reflexív) beállítása"
    read -p "Add meg a külső IP-címed (publikus IP): " public_ip
    read -p "Add meg a belső hálózati interfészed: " internal_if
    read -p "Add meg a belső szerver IP-címét: " server_ip
    echo "Magyarázat: A belső hálózatról a külső IP címen keresztül is eléred a szolgáltatásaidat."
    nft add table ip nat 2>/dev/null
    nft 'add chain ip nat prerouting { type nat hook prerouting priority -100; }' 2>/dev/null
    nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }' 2>/dev/null
    nft add rule ip nat prerouting iif "$internal_if" ip daddr "$public_ip" dnat to "$server_ip"
    nft add rule ip nat postrouting iif "$internal_if" ip daddr "$server_ip" masquerade
    echo "✅ Hairpin NAT beállítva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_1_to_1_nat() {
    if ! install_dependencies "nft" "ip"; then return; fi
    clear
    echo "1:1 NAT beállítása"
    read -p "Add meg a külső (publikus) IP-címet: " public_ip
    read -p "Add meg a belső (privát) IP-címet: " private_ip
    echo "Példa: A külső $public_ip cím minden forgalma a belső $private_ip címre lesz átirányítva."
    nft add table ip nat 2>/dev/null
    nft 'add chain ip nat prerouting { type nat hook prerouting priority -100; }' 2>/dev/null
    nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }' 2>/dev/null
    nft add rule ip nat prerouting dnat to "$private_ip"
    nft add rule ip nat postrouting snat to "$public_ip"
    echo "✅ 1:1 NAT beállítva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- 3. L2TP/IPsec VPN konfiguráció ---
l2tp_vpn_menu() {
    clear
    echo "---------------------------------------------------"
    echo "       3. L2TP/IPsec VPN konfiguráció"
    echo "---------------------------------------------------"
    echo "0. Függőségek telepítése (strongswan, xl2tpd, nft)"
    echo "1. VPN szerver beállítások (IPsec és L2TP)"
    echo "2. Felhasználók hozzáadása"
    echo "3. VPN NAT és belső hálózati forgalom beállítása"
    echo "4. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        0) install_dependencies "strongswan" "xl2tpd" "nft"; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
        1) setup_l2tp_vpn ;;
        2) add_l2tp_user ;;
        3) setup_vpn_nat ;;
        4) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "" ;;
    esac
}
setup_l2tp_vpn() {
    if ! install_dependencies "strongswan" "xl2tpd"; then return; fi
    clear
    read -p "Figyelem! Ez felülírhatja a meglévő IPsec és L2TP konfigurációs fájlokat. Biztosan folytatod? (igen/nem) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then return; fi

    echo "L2TP/IPsec VPN beállítások"
    read -p "Szerver publikus IP címe: " public_ip
    read -p "Előre megosztott kulcs (PSK): " psk
    read -p "VPN kliensek IP tartománya (pl. 10.0.1.1-10.0.1.254): " l2tp_ip_range
    read -p "DNS szerverek (pl. 8.8.8.8, 8.8.4.4): " dns_servers

    # ipsec.conf
    cat <<EOF > /etc/ipsec.conf
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"
conn L2TP-IPsec
    left=%defaultroute
    leftsubnet=0.0.0.0/0
    leftauth=psk
    right=%any
    rightsubnet=10.0.1.0/24
    rightauth=psk
    ike=aes256-sha256-modp2048
    esp=aes256-sha256
    auto=add
    keyexchange=ikev1
    dpdaction=restart
    dpdtimeout=180s
    forceencaps=yes
EOF
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült létrehozni az /etc/ipsec.conf fájlt."; return; fi

    # ipsec.secrets
    echo "$public_ip %any : PSK \"$psk\"" > /etc/ipsec.secrets
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült létrehozni az /etc/ipsec.secrets fájlt."; return; fi

    # xl2tpd.conf
    cat <<EOF > /etc/xl2tpd/xl2tpd.conf
[global]
    port = 1701
[lns default]
    ip range = $l2tp_ip_range
    local ip = $public_ip
    require authentication = yes
    name = L2TP-IPsec-VPN
    ppp debug = yes
    pppoptfile = /etc/ppp/options.xl2tpd
EOF
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült létrehozni az /etc/xl2tpd/xl2tpd.conf fájlt."; return; fi

    # options.xl2tpd
    cat <<EOF > /etc/ppp/options.xl2tpd
ipcp-accept-local
ipcp-accept-remote
ms-dns $dns_servers
asyncmap 0
auth
crtscts
lock
proxyarp
debug
nodefaultroute
mtu 1400
connect-delay 5000
EOF
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült létrehozni az /etc/ppp/options.xl2tpd fájlt."; return; fi

    echo "✅ L2TP/IPsec VPN konfiguráció elkészült."
    echo "Példa: A VPN kliensek a $l2tp_ip_range tartományból kapnak IP-t."
    echo "A szükséges portok: 500 (IKE), 4500 (IPsec NAT-T), 1701 (L2TP)"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
add_l2tp_user() {
    clear
    echo "Új felhasználó hozzáadása a VPN-hez"
    read -p "Felhasználónév: " username
    read -p "Jelszó: " password
    echo "\"$username\" * \"$password\" *" >> /etc/ppp/chap-secrets
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült a felhasználót hozzáadni."; return; fi
    echo "✅ A felhasználó hozzáadva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_vpn_nat() {
    if ! install_dependencies "nft" "ip"; then return; fi
    clear
    echo "VPN NAT beállítása"
    echo "Ezzel a beállítással a VPN kliensek internetezhetnek és elérhetik a belső hálózatot."
    echo "Jelenlegi interfészek:"
    ip -br a
    read -p "Add meg a belső (LAN) hálózati interfészt (pl. eth0): " internal_if
    read -p "Add meg a külső (WAN) hálózati interfészt (pl. enp1s0): " external_if
    read -p "Add meg a VPN hálózatot (pl. 10.0.1.0/24): " vpn_subnet

    if [ -z "$internal_if" ] || [ -z "$external_if" ] || [ -z "$vpn_subnet" ]; then
        echo "❌ Hiba: Az összes mező kitöltése kötelező."
        read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
        return
    fi
    
    # Masquerading a külső hálózat felé
    nft add table ip nat 2>/dev/null
    nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }' 2>/dev/null
    nft add rule ip nat postrouting ip saddr "$vpn_subnet" oifname "$external_if" masquerade
    if [ $? -ne 0 ]; then echo "❌ Hiba: A külső NAT szabály hozzáadása sikertelen."; return; fi
    
    # Masquerading a belső hálózat felé már nem kell
    #nft add rule ip nat postrouting ip saddr "$vpn_subnet" oifname "$internal_if" masquerade
    echo "✅ A VPN NAT szabályok sikeresen hozzáadva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- 4. DHCP szerver beállítások ---
dhcp_server_menu() {
    clear
    echo "---------------------------------------------------"
    echo "       4. DHCP Szerver beállítások"
    echo "---------------------------------------------------"
    echo "0. Függőségek telepítése (isc-dhcp-server, tftpd-hpa, vlan)"
    echo "1. DHCP szerver beállítása (LAN/VLAN)"
    echo "2. Statikus IP cím hozzáadása MAC cím alapján"
    echo "3. TFTPd szerver beállítása (PXE boot)"
    echo "4. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        0) install_dependencies "isc-dhcp-server" "tftpd-hpa" "vlan"; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
        1) setup_dhcp_server ;;
        2) add_static_ip ;;
        3) setup_tftpd ;;
        4) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "" ;;
    esac
}
setup_dhcp_server() {
    if ! install_dependencies "isc-dhcp-server" "vlan"; then return; fi
    check_network_manager
    clear
    read -p "Figyelem! Ez felülírhatja a meglévő DHCP konfigurációt. Biztosan folytatod? (igen/nem) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then return; fi

    echo "DHCP szerver beállítása"
    read -p "LAN/VLAN interfész (pl. eth0 vagy eth0.10): " interface
    read -p "Hálózat (pl. 192.168.1.0): " subnet
    read -p "Hálózati maszk (pl. 255.255.255.0): " netmask
    read -p "Címkiosztási tartomány kezdete (pl. 192.168.1.100): " range_start
    read -p "Címkiosztási tartomány vége (pl. 192.168.1.200): " range_end
    read -p "Alapértelmezett átjáró: " router
    read -p "DNS szerverek (pl. 8.8.8.8, 8.8.4.4): " dns
    read -p "Bérleti idő (másodpercben, pl. 600): " lease_time

    echo "INTERFACESv4=\"$interface\"" > /etc/default/isc-dhcp-server
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült az interfész beállítása."; return; fi

    cat <<EOF > /etc/dhcp/dhcpd.conf
subnet $subnet netmask $netmask {
    range $range_start $range_end;
    option routers $router;
    option domain-name-servers $dns;
    default-lease-time $lease_time;
    max-lease-time $((lease_time * 2));
}
EOF
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült a dhcpd.conf fájl létrehozása."; return; fi
    systemctl restart isc-dhcp-server
    if [ $? -ne 0 ]; then echo "❌ Hiba: a szolgáltatás újraindítása sikertelen."; return; fi

    echo "✅ DHCP szerver beállítva a(z) $interface interfészen."
    echo "A DHCP szerver portja: 67 (UDP)"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
add_static_ip() {
    if ! install_dependencies "isc-dhcp-server"; then return; fi
    clear
    echo "Statikus IP cím hozzáadása MAC cím alapján"
    echo "Ez a beállítás hozzáad egy új 'host' bejegyzést a dhcpd.conf fájlhoz."
    read -p "Gépnév (hostname): " hostname
    read -p "MAC cím (pl. 01:23:45:67:89:ab): " mac
    read -p "Statikus IP cím: " ip

    echo "host $hostname { hardware ethernet $mac; fixed-address $ip; }" >> /etc/dhcp/dhcpd.conf
    if [ $? -ne 0 ]; then echo "❌ Hiba: nem sikerült a statikus IP hozzáadása."; return; fi
    
    echo "✅ A statikus IP bejegyzés hozzáadva."
    # A DHCP szerver újraindítása a módosítások életbe lépéséhez
    sudo systemctl restart isc-dhcp-server
    if [ $? -ne 0 ]; then echo "❌ Hiba: a szolgáltatás újraindítása sikertelen."; return; fi
    echo "✅ DHCP szolgáltatás újraindítva."

    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_tftpd() {
    if ! install_dependencies "tftpd-hpa"; then return; fi
    check_network_manager
    clear
    read -p "Figyelem! Ez a művelet telepíti és konfigurálja a TFTPd szervert a PXE boot-hoz. Biztosan folytatod? (igen/nem) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then return; fi

    echo "TFTPd szerver beállítása"
    local tftproot="/srv/tftp"
    echo "A TFTP gyökérkönyvtára: $tftproot"

    mkdir -p "$tftproot"
    chown -R tftpd:tftpd "$tftproot"
    chmod -R 777 "$tftproot"

    # TFTPd konfiguráció
    cat <<EOF > /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="$tftproot"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
RUN_DAEMON="yes"
EOF

    echo "✅ A TFTPd szerver beállítva."
    echo "A TFTP szerver portja: 69 (UDP)"
    
    sudo systemctl restart tftpd-hpa
    if [ $? -ne 0 ]; then echo "❌ Hiba: a TFTPd szolgáltatás újraindítása sikertelen."; return; fi
    echo "✅ A TFTPd szerver beállítva és újraindítva."
    
    read -p "Szeretnél PXE beállításokat is hozzáadni a DHCP szerverhez? (igen/nem) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ii]gen$ ]]; then
        read -p "PXE boot fájl neve (pl. pxelinux.0): " pxe_filename
        read -p "A TFTP szerver IP címe: " next_server_ip
        
        echo "next-server $next_server_ip;" >> /etc/dhcp/dhcpd.conf
        echo "filename \"$pxe_filename\";" >> /etc/dhcp/dhcpd.conf
        
        # A DHCP szerver újraindítása a módosítások életbe lépéséhez
        sudo systemctl restart isc-dhcp-server
        if [ $? -ne 0 ]; then echo "❌ Hiba: a DHCP szolgáltatás újraindítása sikertelen."; return; fi
        echo "✅ DHCP szolgáltatás újraindítva."
    fi
    
    echo "✅ A TFTPd és DHCP beállítások elkészültek."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- 5. Squid és SquidGuard ---
squid_menu() {
    clear
    echo "---------------------------------------------------"
    echo "       5. Squid és SquidGuard beállítások"
    echo "---------------------------------------------------"
    echo "0. Függőségek telepítése (squid, squidguard, curl, gnupg)"
    echo "1. Átlátszó proxy beállítása (Transparent Proxy)"
    echo "2. Proxy Auto-Configuration (PAC) fájl létrehozása"
    echo "3. Tartalom filter beállítása (SquidGuard)"
    echo "4. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        0) install_dependencies "squid" "squidguard" "curl" "gnupg"; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
        1) setup_transparent_proxy ;;
        2) create_pac_file ;;
        3) setup_squidguard ;;
        4) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
    esac
}
setup_transparent_proxy() {
    if ! install_dependencies "nft"; then return; fi
    clear
    read -p "Figyelem! Ez átirányítja a belső hálózat 80-as és 443-as forgalmát a Squid proxyra. Biztosan folytatod? (igen/nem) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then return; fi

    echo "Átlátszó proxy (Transparent Proxy) beállítása"
    read -p "Add meg a belső hálózati interfészt (pl. eth0): " internal_if
    read -p "Add meg a Squid proxy portját (alapértelmezett: 3128): " squid_port
    squid_port=${squid_port:-3128}
    
    nft add table ip nat 2>/dev/null
    nft 'add chain ip nat prerouting { type nat hook prerouting priority -100; }' 2>/dev/null
    nft add rule ip nat prerouting iif "$internal_if" tcp dport 80 redirect to "$squid_port" comment "HTTP forgalom átirányítása"
    echo "✅ HTTP forgalom átirányítva a Squid proxyra."
    echo "A Squid proxy portja: **$squid_port** (TCP)"
    echo "Megjegyzés: A HTTPS forgalomhoz külön Squid beállítás szükséges a tanúsítványok miatt."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
create_pac_file() {
    if ! install_dependencies "squid"; then return; fi
    clear
    echo "Proxy Auto-Configuration (PAC) fájl létrehozása"
    read -p "Proxy szerver IP címe vagy hostname-je: " proxy_ip
    read -p "Proxy portja (alapértelmezett: 3128): " proxy_port
    proxy_port=${proxy_port:-3128}

    local pac_content="function FindProxyForURL(url, host) {
    return \"PROXY $proxy_ip:$proxy_port; DIRECT\";
}"
    
    echo "$pac_content" > /var/www/html/proxy.pac
    if [ $? -ne 0 ]; then echo "❌ Hiba: A PAC fájl létrehozása sikertelen."; return; fi

    echo "✅ A PAC fájl létrehozva a /var/www/html/proxy.pac útvonalon."
    echo "Web szerver szükséges a PAC fájl futtatásához (pl. Apache2)."
    echo "A kliens beállításoknál add meg a PAC fájl URL-jét: http://$proxy_ip/proxy.pac"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_squidguard() {
    if ! install_dependencies "squidguard"; then return; fi
    clear
    echo "Tartalom filter (SquidGuard) beállítása"
    echo "Ez a beállítás a Squid proxy-val együttműködve szűri a weboldalakat."
    echo "1. Blacklist letöltése"
    echo "2. SquidGuard konfiguráció"
    echo "3. Vissza a Squid menübe"
    read -p "Választás: " choice
    case $choice in
        1) read -p "A Shalla's Blacklists letöltése és kicsomagolása. Folytatod? (igen/nem) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ii]gen$ ]]; then
                wget -c http://www.shallalist.de/Downloads/shallalist.tar.gz -O /tmp/shallalist.tar.gz
                if [ $? -ne 0 ]; then echo "❌ Hiba: A blacklist letöltése sikertelen."; return; fi
                tar -xvzf /tmp/shallalist.tar.gz -C /var/lib/squidguard/db/
                if [ $? -ne 0 ]; then echo "❌ Hiba: A blacklist kicsomagolása sikertelen."; return; fi
                echo "✅ A blacklist letöltve."
            fi
            ;;
        2)
            echo "A /etc/squidguard/squidGuard.conf fájl manuális szerkesztést igényel."
            echo "Példa a beállításra:"
            echo 'acl {'
            echo '    default {'
            echo '        pass !phishing !porno !gambling all'
            echo '    }'
            echo '}'
            read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
            ;;
        3) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
    esac
}

# --- 6. Webmin telepítése ---
install_webmin_menu() {
    clear
    echo "---------------------------------------------------"
    echo "       6. Webmin telepítése"
    echo "---------------------------------------------------"
    echo "A Webmin egy web alapú interfész a rendszeradminisztrációhoz. A telepítéshez root jogok szükségesek."
    echo "1. Webmin telepítése"
    echo "2. Vissza a főmenübe"
    read -p "Választás: " choice
    case $choice in
        1) install_webmin ;;
        2) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
    esac
}
install_webmin() {
    if ! install_dependencies "gnupg2" "wget" "curl"; then return; fi
    clear
    read -p "Figyelem! A Webmin telepítése további tárolók hozzáadását igényli. Biztosan folytatod? (igen/nem) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]gen$ ]]; then return; fi

    echo "Webmin telepítése..."
    
    # GPG kulcs letöltése a megfelelő helyre (MODERN MÓDSZER)
    sudo mkdir -p /usr/share/keyrings
    sudo wget -q -O /usr/share/keyrings/webmin.gpg http://www.webmin.com/jcameron-key.asc
    if [ $? -ne 0 ]; then echo "❌ Hiba: GPG kulcs letöltése sikertelen."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."; return; fi
    echo "✅ GPG kulcs letöltve."

    # Webmin tároló hozzáadása a kulccsal
    echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] http://download.webmin.com/download/repository sarge contrib" | sudo tee /etc/apt/sources.list.d/webmin.list
    if [ $? -ne 0 ]; then echo "❌ Hiba: Webmin tároló hozzáadása sikertelen."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."; return; fi
    echo "✅ Webmin tároló hozzáadva."

    sudo apt-get update
    if [ $? -ne 0 ]; then echo "❌ Hiba: apt frissítése sikertelen."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."; return; fi

    sudo apt-get install -y webmin
    if [ $? -ne 0 ]; then echo "❌ Hiba: Webmin telepítése sikertelen."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."; return; fi
    
    echo "✅ Webmin telepítve!"
    echo "A Webmin a következő porton érhető el: 10000 (TCP)"
    echo "A webes felület eléréséhez nyisd meg a böngészőben: https://$(hostname -I | awk '{print $1}'):10000"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- A szkript elindítása ---
main_menu
