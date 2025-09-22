#!/bin/sh
#
# FreeBSD 14 Beállító Szkript - V3.0 (Javított és Optimalizált)
# Teljesen újraírt verzió FreeBSD 12 változattból

# Ellenőrizzük, hogy a szkript root felhasználóként fut-e
if [ "$(id -u)" -ne 0 ]; then
    echo "⚠️ Ez a szkript root jogosultságokat igényel. Kérjük, futtassa 'su' használatával."
    exit 1
fi

# --- Segédfunkciók ---

# Ellenőrzi és beállítja a pkg-t
check_pkg() {
    if ! command -v pkg > /dev/null 2>&1; then
        echo "📦 A pkg csomagkezelő nem található. Telepítjük..."
        if ! env ASSUME_ALWAYS_YES=YES pkg bootstrap; then
            echo "❌ Hiba a pkg bootstrap során"
            exit 1
        fi
        echo "✅ A pkg telepítése sikeres."
    fi
    
    # Csomaglisták frissítése
    echo "🔄 Csomaglisták frissítése..."
    pkg update -f
}

# Hibaellenőrző függvény
error_check() {
    if [ $? -ne 0 ]; then
        echo "❌ Hiba történt a művelet során"
        read -p "Nyomj Entert a folytatáshoz..."
        return 1
    fi
    return 0
}

# NTP szolgáltatás állapotának ellenőrzése
check_ntp_status() {
    if service ntpd onestatus > /dev/null 2>&1; then
        echo "✅ NTP szolgáltatás fut"
        return 0
    else
        echo "❌ NTP szolgáltatás nem fut"
        return 1
    fi
}

# --- Főmenü ---
show_main_menu() {
    clear
    echo "========================================="
    echo "FreeBSD 14 Beállító Szkript V0.3 beta Complex IT Group @ Kispest 2025"
    echo "========================================="
    echo "1.  Csomaglista frissítése és rendszer frissítése"
    echo "2.  Alapvető alkalmazások telepítése"
    echo "3.  Hálózati beállítások"
    echo "4.  Hostnév és FQDN beállítása"
    echo "5.  Felhasználókezelés"
    echo "6.  SSH beállítások"
    echo "7.  Időszinkronizálás beállítása (NTP)"
    echo "8.  Rendszeradatok listázása"
    echo "9.  Webmin telepítése"
    echo "10. SSH bejelentkező szöveg szerkesztése"
    echo "11. Kilépés"
    echo "========================================="
    printf "Válassz egy opciót [1-11]: "
    read choice
}

# --- Csomagkezelési és telepítési funkciók ---

update_system() {
    check_pkg
    echo "🔄 Rendszer frissítése..."
    if pkg upgrade -y; then
        echo "✅ A rendszer naprakész."
    else
        echo "❌ Hiba történt a frissítés során"
    fi
    read -p "Nyomj Entert a folytatáshoz..."
}

install_basic_apps() {
    check_pkg
    echo "🚀 Alapvető alkalmazások telepítése..."
    echo "Ez eltarthat néhány percig..."
    
    # Python és alapfüggőségek MC-hez
    echo "🐍 Python és függőségek telepítése..."
    pkg install -y python3 py39-pip
    
    # 📁 Fájlkezelők és szerkesztők (MC-vel együtt a függőségei)
    echo "📁 Fájlkezelők és szerkesztők telepítése..."
    pkg install -y mc nano vim-console
    
    # 📊 Rendszer monitorozás
    echo "📊 Rendszer monitorozás telepítése..."
    pkg install -y htop bashtop glances
    
    # 🌐 Hálózati eszközök
    echo "🌐 Hálózati eszközök telepítése..."
    pkg install -y curl wget lynx nmap tcpdump mtr iftop iperf3
    
    # 📦 Archívumkezelés
    echo "📦 Archívumkezelés telepítése..."
    pkg install -y unzip zip p7zip unrar gzip bzip2 xz
    
    # 🔧 Egyéb alapvető eszközök
    echo "🔧 Egyéb alapvető eszközök..."
    pkg install -y git sudo tmux tree lsof ripgrep bat exa
    
    if error_check; then
        echo ""
        echo "✅ Minden alkalmazás sikeresen telepítve!"
        echo ""
        echo "📖 Gyors használati tippek:"
        echo "============================"
        echo "mc          - Fájlkezelő (F10 kilépés)"
        echo "htop        - Folyamatkezelő"
        echo "nmap        - Hálózat vizsgálat"
        echo "bat         - Fájl megjelenítő"
    fi
    
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Hálózati funkciók ---
show_network_menu() {
    while true; do
        clear
        echo "--- Hálózati Beállítások ---"
        echo "1. Hálózati interfészek listázása"
        echo "2. Statikus IP beállítása"
        echo "3. DHCP beállítása"
        echo "4. DNS szerverek beállítása"
        echo "5. Hálózati szolgáltatások újraindítása"
        echo "6. Vissza a főmenübe"
        echo "---------------------------"
        printf "Válassz egy opciót [1-6]: "
        read net_choice

        case $net_choice in
            1)
                echo "--- Hálózati interfészek ---"
                ifconfig
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            2)
                printf "Interfész neve (pl. vtnet0, em0): "
                read interface_name
                
                if ! ifconfig "$interface_name" > /dev/null 2>&1; then
                    echo "❌ Nem létező interfész: $interface_name"
                    read -p "Nyomj Entert a folytatáshoz..."
                    continue
                fi
                
                printf "IP cím (pl. 192.168.1.100/24): "
                read ip_address
                printf "Átjáró (pl. 192.168.1.1): "
                read gateway
                
                # IP formátum ellenőrzése
                if ! echo "$ip_address" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'; then
                    echo "❌ Érvénytelen IP formátum"
                    read -p "Nyomj Entert a folytatáshoz..."
                    continue
                fi
                
                # RC.conf-be írás
                sysrc ifconfig_${interface_name}="inet ${ip_address}"
                sysrc defaultrouter="${gateway}"
                
                # Alkalmazás
                service netif restart "$interface_name"
                echo "✅ Statikus IP beállítva"
                ifconfig "$interface_name"
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            3)
                printf "Interfész neve (pl. vtnet0, em0): "
                read interface_name
                
                if ! ifconfig "$interface_name" > /dev/null 2>&1; then
                    echo "❌ Nem létező interfész: $interface_name"
                    read -p "Nyomj Entert a folytatáshoz..."
                    continue
                fi
                
                sysrc ifconfig_${interface_name}="DHCP"
                service netif restart "$interface_name"
                echo "✅ DHCP beállítva"
                ifconfig "$interface_name"
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            4)
                printf "Első DNS szerver (pl. 8.8.8.8): "
                read dns1
                printf "Második DNS szerver (pl. 1.1.1.1): "
                read dns2
                
                # DNS ellenőrzése
                if ! echo "$dns1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || \
                   ! echo "$dns2" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
                    echo "❌ Érvénytelen DNS cím"
                    read -p "Nyomj Entert a folytatáshoz..."
                    continue
                fi
                
                echo "# FreeBSD DNS konfiguráció" > /etc/resolv.conf
                echo "nameserver $dns1" >> /etc/resolv.conf
                echo "nameserver $dns2" >> /etc/resolv.conf
                echo "✅ DNS beállítva:"
                cat /etc/resolv.conf
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            5)
                echo "🔄 Hálózati szolgáltatások újraindítása..."
                service netif restart && service routing restart
                echo "✅ Hálózat újraindítva"
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            6) break ;;
            *) echo "❌ Érvénytelen választás"; read -p "Nyomj Entert a folytatáshoz..." ;;
        esac
    done
}

# --- Hostnév és FQDN beállítás ---
configure_hostname() {
    printf "Add meg a hosztnevet (pl. szerver): "
    read hostname
    printf "Add meg a domain nevet (pl. helyi.lan): "
    read domain
    
    if [ -z "$hostname" ] || [ -z "$domain" ]; then
        echo "❌ Hosztnév és domain nem lehet üres"
        read -p "Nyomj Entert a folytatáshoz..."
        return
    fi
    
    full_hostname="${hostname}.${domain}"
    
    # /etc/rc.conf-be írás
    sysrc hostname="$full_hostname"
    
    # /etc/hosts-be írás
    current_ip=$(ifconfig | grep -E 'inet [0-9]' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    if [ -n "$current_ip" ]; then
        # Eltávolítjuk a régi bejegyzéseket
        grep -v "$current_ip" /etc/hosts > /tmp/hosts.tmp
        mv /tmp/hosts.tmp /etc/hosts
        
        # Hozzáadjuk az újat
        echo "$current_ip    $full_hostname $hostname" >> /etc/hosts
    fi
    
    # Alkalmazás
    hostname "$full_hostname"
    
    echo "✅ Hostnév beállítva: $full_hostname"
    echo "🌐 FQDN: $full_hostname"
    echo "📡 IP cím: ${current_ip:-'ismeretlen'}"
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Felhasználókezelés ---
manage_users() {
    while true; do
        clear
        echo "--- Felhasználókezelés ---"
        echo "1. Új felhasználó hozzáadása"
        echo "2. Felhasználók listázása"
        echo "3. Jelszó megváltoztatása"
        echo "4. Felhasználó törlése"
        echo "5. Sudo jogok beállítása"
        echo "6. Vissza a főmenübe"
        echo "---------------------------"
        printf "Válassz opciót [1-6]: "
        read user_choice
        
        case $user_choice in
            1) 
                printf "Új felhasználó neve: "
                read new_user
                
                if [ -z "$new_user" ]; then
                    echo "❌ Név nem lehet üres"
                    read -p "Nyomj Entert a folytatáshoz..."
                    continue
                fi
                
                if pw usershow "$new_user" > /dev/null 2>&1; then
                    echo "❌ Létező felhasználó: $new_user"
                    read -p "Nyomj Entert a folytatáshoz..."
                    continue
                fi
                
                if pw useradd -n "$new_user" -m -s /bin/tcsh; then
                    echo "✅ Felhasználó létrehozva: $new_user"
                    printf "Jelszó beállítása? (i/n): "
                    read set_pass
                    if [ "$set_pass" = "i" ] || [ "$set_pass" = "I" ]; then
                        passwd "$new_user"
                    fi
                fi
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            2)
                echo "--- Felhasználók ---"
                cut -d: -f1 /etc/passwd | sort
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            3)
                printf "Felhasználó neve: "
                read username
                if pw usershow "$username" > /dev/null 2>&1; then
                    passwd "$username"
                else
                    echo "❌ Nem létező felhasználó: $username"
                fi
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            4) 
                printf "Törlendő felhasználó: "
                read user_to_delete
                
                if ! pw usershow "$user_to_delete" > /dev/null 2>&1; then
                    echo "❌ Nem létező felhasználó: $user_to_delete"
                    read -p "Nyomj Entert a folytatáshoz..."
                    continue
                fi
                
                printf "⚠️ Biztos törlöd '%s' felhasználót? (i/n): " "$user_to_delete"
                read confirm_delete
                if [ "$confirm_delete" = "i" ] || [ "$confirm_delete" = "I" ]; then
                    pw userdel -n "$user_to_delete" -r
                    echo "✅ Felhasználó törölve: $user_to_delete"
                else
                    echo "❌ Törlés megszakítva"
                fi
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            5)
                echo "🔧 Sudo beállítása..."
                pkg install -y sudo
                if ! grep -q "^%wheel" /usr/local/etc/sudoers 2>/dev/null; then
                    echo "%wheel ALL=(ALL) ALL" >> /usr/local/etc/sudoers
                    echo "✅ Wheel csoport hozzáadva a sudoers-hez"
                else
                    echo "✅ Wheel csoport már rendelkezik sudo jogokkal"
                fi
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
            6) break ;;
            *) echo "❌ Érvénytelen választás"; read -p "Nyomj Entert a folytatáshoz..." ;;
        esac
    done
}

# --- SSH beállítások ---
configure_ssh() {
    while true; do
        clear
        echo "--- SSH Beállítások ---"
        echo "1. Root bejelentkezés engedélyezése"
        echo "2. Root bejelentkezés letiltása"
        echo "3. Jelszó hitelesítés bekapcsolása"
        echo "4. Jelszó hitelesítés kikapcsolása"
        echo "5. SSH szolgáltatás újraindítása"
        echo "6. Vissza a főmenübe"
        echo "---------------------------"
        printf "Válassz opciót [1-6]: "
        read ssh_choice

        case $ssh_choice in
            1)
                echo "⚠️ Root SSH bejelentkezés engedélyezése..."
                sed -i '' 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
                echo "✅ Root bejelentkezés engedélyezve"
                ;;
            2)
                sed -i '' 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
                echo "✅ Root bejelentkezés letiltva"
                ;;
            3)
                sed -i '' 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
                echo "✅ Jelszó hitelesítés engedélyezve"
                ;;
            4)
                sed -i '' 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                echo "✅ Jelszó hitelesítés letiltva"
                ;;
            5)
                service sshd restart
                echo "✅ SSH szolgáltatás újraindítva"
                ;;
            6) break ;;
            *) echo "❌ Érvénytelen választás" ;;
        esac
        
        if [ "$ssh_choice" -ge 1 ] && [ "$ssh_choice" -le 4 ]; then
            service sshd restart
        fi
        
        read -p "Nyomj Entert a folytatáshoz..."
    done
}

# --- Időszinkronizálás (NTP) - Javított verzió ---
configure_ntp() {
    while true; do
        clear
        echo "--- Időszinkronizálás (NTP) ---"
        echo "1. NTP telepítése magyar szerverekkel"
        echo "2. Alapértelmezett NTP szerverek"
        echo "3. NTP szolgáltatás indítása"
        echo "4. NTP szolgáltatás leállítása"
        echo "5. Idő és dátum beállítása"
        echo "6. Időzóna beállítása (Budapest)"
        echo "7. NTP állapot ellenőrzése"
        echo "8. Vissza a főmenübe"
        echo "-------------------------------"
        
        # Aktuális idő megjelenítése
        echo "🕐 Aktuális idő: $(date)"
        echo "🌍 Időzóna: $(readlink /etc/localtime 2>/dev/null || echo 'Nincs beállítva')"
        check_ntp_status
        echo "-------------------------------"
        printf "Válassz opciót [1-8]: "
        read ntp_choice

        case $ntp_choice in
            1)
                echo "🇭🇺 NTP telepítése magyar szerverekkel..."
                pkg install -y ntpd
                
                # Magyar NTP szerverek
                cat > /etc/ntp.conf << 'EOF'
# Magyar NTP szerverek
server 0.hu.pool.ntp.org iburst
server 1.hu.pool.ntp.org iburst
server 2.hu.pool.ntp.org iburst
server 3.hu.pool.ntp.org iburst

# Biztonsági beállítások
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict ::1

driftfile /var/db/ntpd.drift
EOF
                echo "✅ Magyar NTP szerverek beállítva"
                ;;
            2)
                echo "🌍 Alapértelmezett NTP szerverek..."
                pkg install -y ntpd
                
                cat > /etc/ntp.conf << 'EOF'
# FreeBSD alapértelmezett NTP
server 0.freebsd.pool.ntp.org iburst
server 1.freebsd.pool.ntp.org iburst
server 2.freebsd.pool.ntp.org iburst

restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict ::1

driftfile /var/db/ntpd.drift
EOF
                echo "✅ Alapértelmezett NTP szerverek beállítva"
                ;;
            3)
                sysrc ntpd_enable="YES"
                service ntpd start
                echo "✅ NTP szolgáltatás indítva és engedélyezve"
                ;;
            4)
                service ntpd stop
                sysrc -x ntpd_enable 2>/dev/null
                echo "✅ NTP szolgáltatás leállítva és letiltva"
                ;;
            5)
                printf "Új dátum (ÉÉÉÉ-HH-NN, pl. 2024-01-15): "
                read new_date
                printf "Új idő (ÓÓ:PP:MM, pl. 14:30:00): "
                read new_time
                
                if date "$(echo "${new_date} ${new_time}" | sed 's/[-:]/ /g')" 2>/dev/null; then
                    # Hardware óra frissítése
                    hwclock --systohc
                    echo "✅ Idő beállítva: ${new_date} ${new_time}"
                else
                    echo "❌ Érvénytelen dátum/idő formátum"
                fi
                ;;
            6)
                echo "🇭🇺 Időzóna beállítása Budapestre..."
                cp /usr/share/zoneinfo/Europe/Budapest /etc/localtime
                sysrc localtime="/usr/share/zoneinfo/Europe/Budapest"
                echo "✅ Időzóna beállítva: Europe/Budapest"
                ;;
            7)
                echo "📊 NTP állapot:"
                if check_ntp_status; then
                    ntpq -p
                else
                    echo "NTP nem fut"
                fi
                ;;
            8) break ;;
            *) echo "❌ Érvénytelen választás" ;;
        esac
        
        read -p "Nyomj Entert a folytatáshoz..."
    done
}

# --- Rendszeradatok listázása - Javított verzió ---
list_system_info() {
    echo "--- Rendszerinformációk ---"
    echo "🖥️  Hostnév: $(hostname)"
    echo "🌐 FQDN: $(hostname -f 2>/dev/null || echo 'Nincs beállítva')"
    echo "🔧 FreeBSD verzió: $(freebsd-version)"
    echo "💾 Kernel: $(uname -v)"
    echo "🕐 Rendszeridő: $(date)"
    echo "🌍 Időzóna: $(readlink /etc/localtime 2>/dev/null || echo 'Nincs beállítva')"
    echo ""
    
    echo "--- Processzor ---"
    dmesg | grep -i cpu | head -5
    echo ""
    
    echo "--- Memória ---"
    grep -E '^(Mem|Swap)' /var/run/dmesg.boot 2>/dev/null || echo "Memória információ nem elérhető"
    echo ""
    
    echo "--- Lemezek ---"
    df -h
    echo ""
    
    echo "--- Hálózati interfészek ---"
    ifconfig | grep -E '^[a-z]' | grep -v lo0 | cut -d: -f1
    echo ""
    
    echo "--- Szolgáltatások ---"
    service -l
    echo ""
    
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Webmin telepítése ---
install_webmin() {
    check_pkg
    echo "🌐 Webmin telepítése..."
    printf "Telepítsem a Webmin-t? (i/n): "
    read install_choice
    if [ "$install_choice" = "i" ] || [ "$install_choice" = "I" ]; then
        if pkg install -y webmin; then
            sysrc webmin_enable="YES"
            service webmin start
            echo "✅ Webmin telepítve és indítva"
            echo "🌍 Elérés: https://$(hostname):10000"
        else
            echo "❌ Hiba a Webmin telepítése során"
        fi
    else
        echo "❌ Telepítés megszakítva"
    fi
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- MOTD szerkesztése ---
edit_ssh_banner() {
    echo "✍️ SSH bejelentkező szöveg szerkesztése"
    pkg install -y nano
    
    if [ ! -f /etc/motd ]; then
        touch /etc/motd
    fi
    
    nano /etc/motd
    echo "✅ MOTD szerkesztve"
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Fő program ---
main() {
    while true; do
        show_main_menu
        case $choice in
            1) update_system ;;
            2) install_basic_apps ;;
            3) show_network_menu ;;
            4) configure_hostname ;;
            5) manage_users ;;
            6) configure_ssh ;;
            7) configure_ntp ;;
            8) list_system_info ;;
            9) install_webmin ;;
            10) edit_ssh_banner ;;
            11) 
                echo "👋 Viszlát!"
                exit 0 
                ;;
            *) 
                echo "❌ Érvénytelen választás: $choice"
                read -p "Nyomj Entert a folytatáshoz..."
                ;;
        esac
    done
}

# Program indítása
main
