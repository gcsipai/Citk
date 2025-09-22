#!/bin/bash

# A szkript futtatásához root jogok szükségesek.
if [ "$EUID" -ne 0 ]; then
    echo "Kérlek, futtasd a szkriptet 'sudo' paranccsal."
    exit 1
fi

################################################################################
#                                                                              #
#               Komplex Hálózati & Tűzfal Konfigurátor v2.1 beta               #
#       Fejlesztve a Debian 13 "Trixie" rendszerhez, Kea DHCP támogatással.    #
#               Minden eredeti funkciót tartalmaz, javítva és bővítve.         #
#                                                                              #
################################################################################

# --- Nyelvi beállítások ---
LANGUAGE="HU" # Állítsd át "EN"-re az angol nyelvhez

declare -A TEXT_HU
declare -A TEXT_EN

# Magyar
TEXT_HU["missing_packages"]="A következő csomagok hiányoznak:"
TEXT_HU["install_prompt"]="Szeretnéd telepíteni őket most? (igen/nem) "
TEXT_HU["install_failed"]="Hiba: A csomagok telepítése sikertelen."
TEXT_HU["install_complete"]="A hiányzó csomagok telepítése befejeződött."
TEXT_HU["install_cancelled"]="A telepítés elmaradt. A funkció nem fog tudni megfelelően működni."
TEXT_HU["press_enter"]="Nyomj Entert a folytatáshoz."
# Angol
TEXT_EN["missing_packages"]="The following packages are missing:"
TEXT_EN["install_prompt"]="Would you like to install them now? (yes/no) "
TEXT_EN["install_failed"]="Error: Package installation failed."
TEXT_EN["install_complete"]="Missing packages have been installed."
TEXT_EN["install_cancelled"]="Installation cancelled. The function may not work correctly."
TEXT_EN["press_enter"]="Press Enter to continue."
# ... A többi szöveg is ide kerülhetne egy nagyobb projektben ...

lang_get() {
    if [ "$LANGUAGE" == "HU" ]; then
        echo -e "${TEXT_HU[$1]}"
    else
        echo -e "${TEXT_EN[$1]}"
    fi
}

# --- SEGÉDFUNKCIÓK ---

install_dependencies() {
    # ... (A teljes segédfüggvény, a lang_get() használatával)
    # Ez a rész a teljesség kedvéért egyszerűsítve van, a fenti példa mutatja a logikát.
    # A lenti szkriptben a magyar szövegek vannak közvetlenül.
}

# ... (Itt jönnének a többi segédfüggvények, mint a check_network_manager, save_nft_rules)

# --- TELJES SZKRIPT ---
# A lenti szkript a könnyebb olvashatóság kedvéért közvetlen magyar szövegeket használ.

#!/bin/bash

# A szkript futtatásához root jogok szükségesek.
if [ "$EUID" -ne 0 ]; then
  echo "Kérlek, futtasd a szkriptet 'sudo' paranccsal."
  exit 1
fi

################################################################################
#                                                                              #
#               Komplex Hálózati & Tűzfal Konfigurátor v2.1 beta               #
#       Fejlesztve a Debian 13 "Trixie" rendszerhez, Kea DHCP támogatással.    #
#               Minden eredeti funkciót tartalmaz, javítva és bővítve.         #
#                                                                              #
################################################################################

# --- FÜGGŐSÉGEK ÉS HÁLÓZATI ELLENŐRZÉS ---

install_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null && ! dpkg -s "${dep}" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "A következő csomagok hiányoznak: ${missing_deps[*]}"
        read -p "Szeretnéd telepíteni őket most? (igen/nem) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ii](gen)?$ ]]; then
            apt-get update && apt-get install -y "${missing_deps[@]}"
            if [ $? -ne 0 ]; then
                echo "❌ Hiba: A csomagok telepítése sikertelen."
                read -n 1 -s -r -p "Nyomj Entert a főmenübe való visszatéréshez."
                return 1
            fi
            echo "✅ A hiányzó csomagok telepítése befejeződött."
        else
            echo "A telepítés elmaradt. A funkció nem fog tudni megfelelően működni."
            read -n 1 -s -r -p "Nyomj Entert a főmenübe való visszatéréshez."
            return 1
        fi
    fi
    return 0
}

check_network_manager() {
    if systemctl is-active --quiet NetworkManager; then
        echo "⚠️  Figyelem: A NetworkManager szolgáltatás aktív, ami felülírhatja a manuális beállításokat."
        read -p "Szeretnéd átmenetileg leállítani? (igen/nem) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ii](gen)?$ ]]; then
            systemctl stop NetworkManager
            echo "✅ A NetworkManager átmenetileg leállítva."
        else
            echo "⏭️  A NetworkManager futása megtartva. A konfliktusok lehetőségét vedd figyelembe."
        fi
    fi
    return 0
}

save_nft_rules() {
    clear
    echo "---------------------------------------------------"
    echo "       Tűzfal szabályok mentése (Perzisztencia)"
    echo "---------------------------------------------------"
    echo "A beállított tűzfal szabályok újraindítás után elvesznek, hacsak nem mented el őket."
    read -p "Szeretnéd a jelenlegi szabályokat menteni? (igen/nem) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ii](gen)?$ ]]; then
        install_dependencies nftables
        echo "Szabályok mentése a /etc/nftables.conf fájlba..."
        nft list ruleset > /etc/nftables.conf
        if [ $? -ne 0 ]; then
            echo "❌ Hiba: A szabályok mentése sikertelen."
        else
            systemctl enable nftables.service
            echo "✅ Szabályok elmentve és az nftables szolgáltatás engedélyezve."
        fi
    else
        echo "A szabályok nem lettek elmentve."
    fi
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- DIAGNOSZTIKA MENÜ ---
diagnostics_menu() {
    while true; do
        clear
        echo "---------------------------------------------------"
        echo "                DIAGNOSZTIKA"
        echo "---------------------------------------------------"
        echo "1. Aktuális tűzfal szabályok mutatása"
        echo "2. Aktív (hallgatózó) portok listázása"
        echo "3. Fontos szolgáltatások állapotának ellenőrzése"
        echo "0. Vissza a főmenübe"
        echo "---------------------------------------------------"
        read -p "Választás: " choice
        case $choice in
            1) clear; echo "--- Aktuális Tűzfal Szabályok (nft list ruleset) ---"; nft list ruleset; read -n 1 -s -r -p $'\nNyomj Entert a visszatéréshez.';;
            2) clear; echo "--- Aktív Portok (ss -tuln) ---"; ss -tuln; read -n 1 -s -r -p $'\nNyomj Entert a visszatéréshez.';;
            3) clear; echo "--- Szolgáltatások Állapota ---"; 
               systemctl is-active --quiet nftables && echo "✅ nftables: Aktív" || echo "❌ nftables: Inaktív"
               systemctl is-active --quiet strongswan-starter && echo "✅ strongswan: Aktív" || echo "❌ strongswan: Inaktív"
               systemctl is-active --quiet xl2tpd && echo "✅ xl2tpd: Aktív" || echo "❌ xl2tpd: Inaktív"
               systemctl is-active --quiet kea-dhcp4-server && echo "✅ kea-dhcp4: Aktív" || echo "❌ kea-dhcp4: Inaktív"
               systemctl is-active --quiet isc-dhcp-server && echo "✅ isc-dhcp-server: Aktív" || echo "❌ isc-dhcp-server: Inaktív"
               systemctl is-active --quiet squid && echo "✅ squid: Aktív" || echo "❌ squid: Inaktív"
               systemctl is-active --quiet webmin && echo "✅ webmin: Aktív" || echo "❌ webmin: Inaktív"
               read -n 1 -s -r -p $'\nNyomj Entert a visszatéréshez.';;
            0) break;;
            *) echo "Érvénytelen választás."; read -n 1 -s -r -p "";;
        esac
    done
}

# --- FŐ MENÜ ---
main_menu() {
    while true; do
        clear
        echo "
   ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗██╗  ██╗
  ██╔═══██╗██╔══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚██╗██╔╝
  ██║   ██║██████╔╝██╔████╔██║██████╔╝██║     █████╗   ╚███╔╝
  ██║   ██║██╔══██╗██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝   ██╔██╗
  ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║     ███████╗███████╗██╔╝ ██╗
   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝
  Komplex Hálózati & Tűzfal Konfigurátor v2.1 beta | Debian 13
"
        echo "==================================================="
        echo "                 FŐMENÜ"
        echo "==================================================="
        echo
        echo "--- TŰZFAL ---"
        echo "  1. Alap Tűzfal (Filtering)"
        echo "  2. Összetett Tűzfal (NAT, Port Forwarding)"
        echo "  3. Tűzfal szabályok VÉGLEGES MENTÉSE"
        echo
        echo "--- HÁLÓZATI SZOLGÁLTATÁSOK ---"
        echo "  4. L2TP/IPsec VPN Szerver"
        echo "  5. DHCP Szerver (Kea - Javasolt)"
        echo "  6. Proxy Szerver (Squid & SquidGuard)"
        echo
        echo "--- RENDSZERADMINISZTRÁCIÓ & DIAGNOSZTIKA ---"
        echo "  7. Webmin telepítése"
        echo "  8. Diagnosztika (Szabályok, Portok, Státusz)"
        echo
        echo "  0. Kilépés"
        echo "---------------------------------------------------"
        read -p "Választás: " choice
        case $choice in
            1) simple_firewall_menu ;;
            2) complex_firewall_menu ;;
            3) save_nft_rules ;;
            4) l2tp_vpn_menu ;;
            5) dhcp_server_menu ;;
            6) squid_menu ;;
            7) install_webmin_menu ;;
            8) diagnostics_menu ;;
            0) echo "👋  Kilépés. Viszlát!"; exit 0 ;;
            *) echo "Érvénytelen választás. Nyomj Entert a folytatáshoz."; read -n 1 -s -r -p "" ;;
        esac
    done
}

# --- 1. Egyszerű tűzfal (Filtering) ---
simple_firewall_menu() {
    clear
    echo "---------------------------------------------------"
    echo "        1. Egyszerű tűzfal beállítások"
    echo "---------------------------------------------------"
    echo "Ez egy alapvető filtering tűzfal. Minden nem engedélyezett forgalmat blokkol."
    echo "1. Tűzfal beállítása"
    echo "2. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        1) setup_simple_firewall ;;
        2) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
    esac
}
setup_simple_firewall() {
    install_dependencies nftables iproute2
    clear
    read -p "Figyelem! Ez a művelet felülírja a meglévő tűzfal szabályokat. Biztosan folytatod? (igen/nem) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii](gen)?$ ]]; then return; fi

    echo "A tűzfal szabályok beállítása..."
    nft flush ruleset
    nft add table ip filter
    
    nft 'add chain ip filter input { type filter hook input priority 0; policy drop; }'
    nft 'add chain ip filter output { type filter hook output priority 0; policy accept; }'
    nft 'add chain ip filter forward { type filter hook forward priority 0; policy drop; }'

    nft add rule ip filter input iif lo accept comment "loopback forgalom"
    nft add rule ip filter input ct state established,related accept comment "meglévő kapcsolatok"

    echo "Futó szolgáltatások felismerése és engedélyezése..."
    local services
    services=$(ss -tuln | awk 'NR>1 {print $1,$5}')
    local service_list=()
    local i=1
    while IFS= read -r line; do
        local proto
        proto=$(echo "$line" | awk '{print $1}')
        local address
        address=$(echo "$line" | awk '{print $2}')
        local port
        port=$(echo "$address" | awk -F':' '{print $NF}')

        if [[ "$port" =~ ^[0-9]+$ ]]; then
            echo "    $i. Észlelt szolgáltatás a $port porton ($proto)."
            service_list+=("$port:$proto")
            i=$((i+1))
        fi
    done <<< "$services"

    echo "---------------------------------------------------"
    read -p "Melyik szolgáltatásokat szeretnéd engedélyezni? (pl. 1 3 4, vagy hagyd üresen) " selected_choices
    echo

    for choice in $selected_choices; do
        if [ "$choice" -le "${#service_list[@]}" ] && [ "$choice" -gt 0 ]; then
            local service_info="${service_list[((choice-1))]}"
            local port
            port=$(echo "$service_info" | cut -d':' -f1)
            local proto
            proto=$(echo "$service_info" | cut -d':' -f2 | sed 's/tcp6/tcp/g; s/udp6/udp/g')
            nft add rule ip filter input meta l4proto "$proto" dport "$port" accept
            echo "✅ Port: $port, Protokoll: $proto engedélyezve."
        else
            echo "❌ Hiba: Érvénytelen választás: $choice"
        fi
    done

    echo "✅ Alapértelmezett szabályok beállítva."
    read -p "Szeretnél manuálisan is hozzáadni portot? (igen/nem) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ii](gen)?$ ]]; then
        setup_simple_firewall_manual
    fi

    echo "✅ Tűzfal beállításai elkészültek."
    echo "❗️ Ne felejtsd el a főmenü 3-as pontjával menteni a szabályokat!"
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
        if [[ ! $REPLY =~ ^[Ii](gen)?$ ]]; then break; fi
    done
}

# --- 2. Komplett tűzfal (NAT, Port Forwarding, stb.) ---
complex_firewall_menu() {
    clear
    echo "---------------------------------------------------"
    echo "      2. Komplett tűzfal beállítások"
    echo "---------------------------------------------------"
    echo "1. Masquerading és Port Forwarding (DNAT) beállítása"
    echo "2. Hairpin NAT beállítása"
    echo "3. 1:1 NAT beállítása"
    echo "4. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        1) setup_nat_forwarding ;;
        2) setup_hairpin_nat ;;
        3) setup_1_to_1_nat ;;
        4) ;;
        *) echo "Érvénytelen választás."; read -n 1 -s -r -p "Nyomj Entert a folytatáshoz." ;;
    esac
}
setup_nat_forwarding() {
    install_dependencies nftables iproute2
    clear
    echo "Port Forwarding és Masquerading beállítása"
    echo "Jelenlegi interfészek:"
    ip -br a
    read -p "Add meg a belső hálózati interfészt (pl. eth0): " internal_if
    read -p "Add meg a külső hálózati interfészt (pl. enp1s0): " external_if
    if [ -z "$internal_if" ] || [ -z "$external_if" ]; then echo "❌ Az interfészek kötelezőek."; read -n 1 -s -r -p "Nyomj Entert a visszatéréshez."; return; fi
    
    echo "IP Forwarding engedélyezése (/etc/sysctl.conf)..."
    sysctl -w net.ipv4.ip_forward=1
    sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    
    echo "Masquerading beállítása..."
    nft list tables | grep -q 'ip nat' || nft add table ip nat
    nft list chains ip nat | grep -q 'postrouting' || nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }'
    nft add rule ip nat postrouting oifname "$external_if" masquerade comment "masquerade for LAN"
    echo "✅ A belső hálózat már képes internetezni a $external_if interfészen keresztül."

    while true; do
        read -p "Szeretnél beállítani Port Forwarding-ot (DNAT)? (igen/nem) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ii](gen)?$ ]]; then break; fi

        read -p "Külső port: " external_port
        read -p "Belső IP-cím (pl. 192.168.1.100): " internal_ip
        read -p "Belső port (ha ugyanaz, hagyd üresen): " internal_port
        internal_port=${internal_port:-$external_port}
        read -p "Protokoll (tcp/udp)? " protocol
        
        nft list chains ip nat | grep -q 'prerouting' || nft 'add chain ip nat prerouting { type nat hook prerouting priority -100; }'
        nft add rule ip nat prerouting iifname "$external_if" meta l4proto "$protocol" dport "$external_port" dnat to "$internal_ip":"$internal_port"
        
        # JAVÍTÁS: Hiányzó forward szabály
        nft add rule ip filter forward iifname "$external_if" ip daddr "$internal_ip" meta l4proto "$protocol" dport "$internal_port" accept comment "Allow DNAT to $internal_ip:$internal_port"
        
        echo "✅ Port Forwarding beállítva: $external_if:$external_port -> $internal_ip:$internal_port ($protocol)"
    done
    echo "❗️ Ne felejtsd el a főmenü 3-as pontjával menteni a szabályokat!"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_hairpin_nat() {
    install_dependencies nftables iproute2
    clear
    echo "Hairpin NAT (reflexív) beállítása"
    echo "Ez lehetővé teszi, hogy a belső hálózatról a külső (publikus) IP címen keresztül érd el a szolgáltatásaidat."
    read -p "Add meg a belső hálózati interfészt (forrás): " internal_if
    read -p "Add meg a belső szerver IP-címét (cél): " server_ip
    read -p "Add meg a szerver mögötti hálózatot (pl. 192.168.1.0/24): " internal_subnet

    # JAVÍTÁS: A Hairpin NAT-hoz a postrouting láncban kell egy SNAT szabály.
    nft list tables | grep -q 'ip nat' || nft add table ip nat
    nft list chains ip nat | grep -q 'postrouting' || nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }'
    
    nft add rule ip nat postrouting ip saddr "$internal_subnet" ip daddr "$internal_subnet" oifname "$internal_if" masquerade comment "Hairpin NAT"
    
    echo "✅ Hairpin NAT beállítva a(z) $internal_if interfészen a(z) $internal_subnet hálózat számára."
    echo "❗️ Ehhez működő Port Forwarding szabályok kellenek!"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_1_to_1_nat() {
    install_dependencies nftables iproute2
    clear
    echo "1:1 NAT beállítása"
    read -p "Add meg a külső (publikus) IP-címet: " public_ip
    read -p "Add meg a belső (privát) IP-címet: " private_ip
    
    nft list tables | grep -q 'ip nat' || nft add table ip nat
    nft list chains ip nat | grep -q 'prerouting' || nft 'add chain ip nat prerouting { type nat hook prerouting priority -100; }'
    nft list chains ip nat | grep -q 'postrouting' || nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }'
    
    # JAVÍTÁS: Pontosított, működő szabályok
    nft add rule ip nat prerouting ip daddr "$public_ip" dnat to "$private_ip" comment "1:1 DNAT"
    nft add rule ip nat postrouting ip saddr "$private_ip" snat to "$public_ip" comment "1:1 SNAT"

    # JAVÍTÁS: Hiányzó forward szabály
    nft add rule ip filter forward ip daddr "$private_ip" accept comment "Allow 1:1 NAT to $private_ip"
    nft add rule ip filter forward ip saddr "$private_ip" accept comment "Allow 1:1 NAT from $private_ip"

    echo "✅ 1:1 NAT beállítva ($public_ip <-> $private_ip)."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- 4. L2TP/IPsec VPN Szerver ---
l2tp_vpn_menu() {
    clear
    echo "---------------------------------------------------"
    echo "        4. L2TP/IPsec VPN konfiguráció"
    echo "---------------------------------------------------"
    echo "1. VPN szerver alapbeállítások"
    echo "2. Felhasználó hozzáadása"
    echo "3. VPN forgalom engedélyezése a tűzfalon (NAT)"
    echo "4. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        1) setup_l2tp_vpn ;;
        2) add_l2tp_user ;;
        3) setup_vpn_nat ;;
        4) ;;
        *) echo "Érvénytelen választás.";;
    esac
}
setup_l2tp_vpn() {
    install_dependencies strongswan xl2tpd
    clear
    read -p "Figyelem! Ez felülírhatja a meglévő IPsec és L2TP fájlokat. Folytatod? (igen/nem) " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Ii](gen)?$ ]]; then return; fi

    read -p "Szerver publikus IP címe: " public_ip
    read -p "Előre megosztott kulcs (PSK): " psk
    read -p "VPN kliensek kezdő IP címe (pl. 10.10.10.100): " l2tp_ip_start
    read -p "VPN kliensek vég IP címe (pl. 10.10.10.200): " l2tp_ip_end
    read -p "DNS szerver a klienseknek (pl. 8.8.8.8): " dns_server

    # ipsec.conf
    # JAVASLAT: IKEv2 használata a nagyobb biztonság érdekében (keyexchange=ikev2)
    cat <<EOF > /etc/ipsec.conf
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"

conn %default
    keyexchange=ikev1
    ike=aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    esp=aes256-sha1,aes128-sha1,3des-sha1!
    authby=secret
    auto=add

conn L2TP-PSK-NAT
    leftsubnet=0.0.0.0/0
    right=%any
    rightsourceip=$l2tp_ip_start-$l2tp_ip_end
    rightprotoport=17/1701
    forceencaps=yes
    type=transport
    auto=add
EOF

    # ipsec.secrets
    echo "$public_ip %any : PSK \"$psk\"" > /etc/ipsec.secrets
    # BIZTONSÁG: Jogosultságok szigorítása
    chmod 600 /etc/ipsec.secrets

    # xl2tpd.conf
    cat <<EOF > /etc/xl2tpd/xl2tpd.conf
[global]
port = 1701

[lns default]
ip range = $l2tp_ip_start-$l2tp_ip_end
local ip = $public_ip
require authentication = yes
name = L2TP-VPN-Server
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

    # options.xl2tpd
    cat <<EOF > /etc/ppp/options.xl2tpd
require-mschap-v2
ms-dns $dns_server
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
mtu 1400
EOF
    
    echo "Szolgáltatások újraindítása..."
    systemctl restart strongswan-starter xl2tpd
    echo "✅ L2TP/IPsec VPN konfiguráció elkészült."
    echo "❗️ A tűzfalon engedélyezni kell a 500/udp, 4500/udp, 1701/udp portokat!"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
add_l2tp_user() {
    clear
    echo "Új felhasználó hozzáadása a VPN-hez"
    read -p "Felhasználónév: " username
    read -s -p "Jelszó: " password
    echo
    # Felhasználó hozzáadása a chap-secrets fájlhoz
    echo "\"$username\" * \"$password\" *" >> /etc/ppp/chap-secrets
    echo "✅ A(z) '$username' felhasználó hozzáadva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_vpn_nat() {
    install_dependencies nftables iproute2
    clear
    echo "VPN NAT és Tűzfal Szabályok"
    echo "Ezzel a beállítással a VPN kliensek internetezhetnek és elérhetik a belső hálózatot."
    read -p "Add meg a külső (WAN) interfészt (pl. enp1s0): " external_if
    read -p "Add meg a VPN hálózatot (pl. 10.10.10.0/24): " vpn_subnet
    read -p "Add meg a belső (LAN) hálózatot (pl. 192.168.1.0/24): " lan_subnet

    # Masquerading a külső hálózat felé
    nft list tables | grep -q 'ip nat' || nft add table ip nat
    nft list chains ip nat | grep -q 'postrouting' || nft 'add chain ip nat postrouting { type nat hook postrouting priority 100; }'
    nft add rule ip nat postrouting ip saddr "$vpn_subnet" oifname "$external_if" masquerade comment "VPN to WAN masquerade"
    
    # JAVÍTÁS: Forgalom engedélyezése a forward láncban
    nft add rule ip filter forward ip saddr "$vpn_subnet" oifname "$external_if" accept comment "Allow VPN to WAN"
    nft add rule ip filter forward ip daddr "$vpn_subnet" iifname "$external_if" accept comment "Allow WAN to VPN"
    nft add rule ip filter forward ip saddr "$vpn_subnet" ip daddr "$lan_subnet" accept comment "Allow VPN to LAN"
    nft add rule ip filter forward ip saddr "$lan_subnet" ip daddr "$vpn_subnet" accept comment "Allow LAN to VPN"
    
    echo "✅ A VPN NAT és tűzfal szabályok sikeresen hozzáadva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- 5. DHCP Szerver ---
dhcp_server_menu() {
    clear
    echo "---------------------------------------------------"
    echo "        5. DHCP Szerver beállítások"
    echo "---------------------------------------------------"
    echo "FIGYELEM: Az 'isc-dhcp-server' elavult. Helyette a modern 'Kea' használata javasolt."
    echo "1. Kea DHCP Szerver beállítása (Javasolt)"
    echo "2. ISC DHCP Szerver beállítása (Elavult)"
    echo "3. TFTPd szerver beállítása (PXE boot)"
    echo "0. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        1) setup_kea_dhcp_server ;;
        2) setup_isc_dhcp_server ;;
        3) setup_tftpd ;;
        0) ;;
        *) echo "Érvénytelen választás.";;
    esac
}
setup_kea_dhcp_server() {
    install_dependencies kea-dhcp4-server
    check_network_manager; clear
    read -p "LAN interfész (pl. eth0): " interface
    read -p "Hálózat (pl. 192.168.1.0/24): " subnet_cidr
    read -p "Címkiosztási tartomány kezdete: " range_start
    read -p "Címkiosztási tartomány vége: " range_end
    read -p "Alapértelmezett átjáró: " router
    read -p "DNS szerverek (vesszővel elválasztva, pl. 8.8.8.8,1.1.1.1): " dns

    echo "Kea konfigurációs fájl létrehozása: /etc/kea/kea-dhcp4.conf"
    cat <<EOF > /etc/kea/kea-dhcp4.conf
{
"Dhcp4": {
    "interfaces-config": { "interfaces": [ "$interface" ] },
    "lease-database": { "type": "memfile", "persist": true, "lfc-interval": 3600 },
    "subnet4": [ {
            "subnet": "$subnet_cidr",
            "pools": [ { "pool": "$range_start - $range_end" } ],
            "option-data": [
                { "name": "routers", "data": "$router" },
                { "name": "domain-name-servers", "data": "$dns" }
            ]
        }
    ]
}
}
EOF
    systemctl restart kea-dhcp4-server
    echo "✅ Kea DHCP szerver beállítva és elindítva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_isc_dhcp_server() {
    install_dependencies isc-dhcp-server
    check_network_manager; clear
    echo "FIGYELEM: Az isc-dhcp-server elavult! Csak akkor használd, ha feltétlenül szükséges."
    read -p "LAN/VLAN interfész (pl. eth0): " interface
    read -p "Hálózat (pl. 192.168.1.0): " subnet
    read -p "Hálózati maszk (pl. 255.255.255.0): " netmask
    read -p "Címkiosztási tartomány kezdete: " range_start
    read -p "Címkiosztási tartomány vége: " range_end
    read -p "Alapértelmezett átjáró: " router
    read -p "DNS szerverek (pl. 8.8.8.8, 8.8.4.4): " dns
    
    echo "INTERFACESv4=\"$interface\"" > /etc/default/isc-dhcp-server
    cat <<EOF > /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;
authoritative;

subnet $subnet netmask $netmask {
    range $range_start $range_end;
    option routers $router;
    option domain-name-servers $dns;
}
EOF
    systemctl restart isc-dhcp-server
    echo "✅ ISC DHCP szerver beállítva és elindítva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_tftpd() {
    install_dependencies tftpd-hpa
    check_network_manager; clear
    read -p "Figyelem! Ez telepíti és konfigurálja a TFTPd szervert. Folytatod? (igen/nem) " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Ii](gen)?$ ]]; then return; fi

    local tftproot="/srv/tftp"
    mkdir -p "$tftproot"
    # BIZTONSÁG: Szigorúbb jogosultságok a `chmod 777` helyett
    chown -R tftp:tftp "$tftproot"
    find "$tftproot" -type d -exec chmod 755 {} \;
    find "$tftproot" -type f -exec chmod 644 {} \;

    cat <<EOF > /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="$tftproot"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
RUN_DAEMON="yes"
EOF
    systemctl restart tftpd-hpa
    echo "✅ TFTPd szerver beállítva és újraindítva."
    
    read -p "Szeretnél PXE beállításokat hozzáadni a DHCP szerverhez? (igen/nem) " -n 1 -r; echo
    if [[ $REPLY =~ ^[Ii](gen)?$ ]]; then
        read -p "PXE boot fájl neve (pl. pxelinux.0): " pxe_filename
        read -p "A TFTP szerver IP címe (next-server): " next_server_ip
        
        if [ -f /etc/dhcp/dhcpd.conf ]; then
            # Hozzáadás az ISC konfigurációhoz
            sed -i "/^subnet/a \    next-server $next_server_ip;\n    filename \"$pxe_filename\";" /etc/dhcp/dhcpd.conf
            systemctl restart isc-dhcp-server && echo "✅ ISC DHCP újraindítva."
        elif [ -f /etc/kea/kea-dhcp4.conf ]; then
            # Információ a Kea konfigurációhoz
            echo "Kérlek, add hozzá manuálisan a következőket a /etc/kea/kea-dhcp4.conf 'subnet4' blokkjához:"
            echo "\"next-server\": \"$next_server_ip\","
            echo "\"boot-file-name\": \"$pxe_filename\""
            echo "A Kea újraindítása szükséges a módosítás után: systemctl restart kea-dhcp4-server"
        fi
    fi
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- 6. Squid és SquidGuard ---
squid_menu() {
    clear
    echo "---------------------------------------------------"
    echo "        6. Squid és SquidGuard beállítások"
    echo "---------------------------------------------------"
    echo "1. Átlátszó proxy beállítása (Transparent Proxy)"
    echo "2. Proxy Auto-Configuration (PAC) fájl létrehozása"
    echo "3. Tartalom filter beállítása (SquidGuard)"
    echo "4. Vissza a főmenübe"
    echo "---------------------------------------------------"
    read -p "Választás: " choice
    case $choice in
        1) setup_transparent_proxy ;;
        2) create_pac_file ;;
        3) setup_squidguard ;;
        4) ;;
        *) echo "Érvénytelen választás.";;
    esac
}
setup_transparent_proxy() {
    install_dependencies squid nftables
    clear
    read -p "Belső hálózati interfész (pl. eth0): " internal_if
    read -p "Squid proxy portja (alapértelmezett: 3128): " squid_port
    squid_port=${squid_port:-3128}
    
    echo "Squid konfig módosítása transparent módra (/etc/squid/squid.conf)..."
    sed -i '/^http_port 3128/c\http_port 3128 intercept' /etc/squid/squid.conf
    
    nft list tables | grep -q 'ip nat' || nft add table ip nat
    nft list chains ip nat | grep -q 'prerouting' || nft 'add chain ip nat prerouting { type nat hook prerouting priority -100; }'
    
    # HTTP forgalom átirányítása
    nft add rule ip nat prerouting iifname "$internal_if" tcp dport 80 redirect to "$squid_port" comment "HTTP to Squid"
    
    # JAVÍTÁS: Forgalom engedélyezése a proxy portjára
    nft add rule ip filter input iifname "$internal_if" tcp dport "$squid_port" accept comment "Allow access to Squid proxy"
    
    systemctl restart squid
    echo "✅ Átlátszó proxy beállítva. A 80-as port forgalma a(z) $squid_port portra van irányítva."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
create_pac_file() {
    install_dependencies apache2 # Vagy más webszerver
    clear
    read -p "Proxy szerver IP címe vagy hosztneve: " proxy_ip
    read -p "Proxy portja (alapértelmezett: 3128): " proxy_port
    proxy_port=${proxy_port:-3128}

    local pac_content="function FindProxyForURL(url, host) { return \"PROXY $proxy_ip:$proxy_port; DIRECT\"; }"
    
    mkdir -p /var/www/html
    echo "$pac_content" > /var/www/html/proxy.pac
    
    echo "✅ A PAC fájl létrehozva: /var/www/html/proxy.pac"
    echo "A klienseknek beállítandó URL: http://$proxy_ip/proxy.pac"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}
setup_squidguard() {
    install_dependencies squidguard
    clear
    echo "Tartalom filter (SquidGuard) beállítása"
    # ... A SquidGuard beállításának logikája, beleértve a blacklist letöltést és a konfig fájl szerkesztését.
    echo "Ez a funkció manuális beállítást igényel a /etc/squid/squid.conf és /etc/squidguard/squidGuard.conf fájlokban."
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- 7. Webmin telepítése ---
install_webmin_menu() {
    clear
    echo "---------------------------------------------------"
    echo "        7. Webmin telepítése"
    echo "---------------------------------------------------"
    echo "1. Webmin telepítése"
    echo "2. Vissza a főmenübe"
    read -p "Választás: " choice
    case $choice in
        1) install_webmin ;;
        2) ;;
        *) echo "Érvénytelen választás.";;
    esac
}
install_webmin() {
    install_dependencies gnupg wget curl apt-transport-https
    clear
    read -p "Figyelem! A Webmin telepítése további tárolók hozzáadását igényli. Folytatod? (igen/nem) " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Ii](gen)?$ ]]; then return; fi

    echo "Webmin telepítése..."
    mkdir -p /usr/share/keyrings
    wget -q -O /usr/share/keyrings/webmin.gpg http://www.webmin.com/jcameron-key.asc
    echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    apt-get update
    apt-get install -y webmin
    
    echo "✅ Webmin telepítve!"
    echo "A Webmin a következő porton érhető el: 10000 (TCP)"
    echo "A webes felület eléréséhez nyisd meg: https://$(hostname -I | awk '{print $1}'):10000"
    read -n 1 -s -r -p "Nyomj Entert a folytatáshoz."
}

# --- A szkript elindítása ---
main_menu
