#!/bin/bash

# Enterprise Linux 10 Configuration Script 2.2
# Optimized for CentOS 10, RHEL 10, Rocky Linux 10, AlmaLinux 10
# Citk 2025

# Ellenőrizzük, hogy a szkript root felhasználóként fut-e
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Ez a szkript root jogosultságokat igényel. Kérjük, futtassa 'sudo' vagy 'su' használatával."
    exit 1
fi

# Distro detection
detect_distro() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            centos) echo "centos" ;;
            rhel) echo "rhel" ;;
            rocky) echo "rocky" ;;
            almalinux) echo "alma" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
DISTRO_VERSION=$(grep -oP 'VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null || echo "10")

# Package manager functions
pkg_update() {
    echo "🔄 Csomaglisták frissítése..."
    dnf check-update --refresh
}

pkg_upgrade() {
    echo "🔄 Rendszer frissítése..."
    dnf upgrade -y
}

pkg_install() {
    dnf install -y "$@"
}

# EPEL repo ellenőrzése és telepítése
setup_epel() {
    if ! dnf repolist | grep -q "epel"; then
        echo "📦 EPEL tároló telepítése..."
        pkg_install epel-release
        dnf config-manager --set-enabled epel
    fi
}

# HTOP telepítése
install_htop() {
    if ! command -v htop &> /dev/null; then
        echo "📦 HTOP telepítése..."
        setup_epel
        pkg_install htop
        echo "✅ HTOP telepítve."
    else
        echo "✅ HTOP már telepítve van."
    fi
}

# Monitorozó eszközök telepítése
install_monitoring_tools() {
    echo "🚀 Monitorozó eszközök telepítése..."
    
    install_htop
    
    # Glances telepítése
    if ! command -v glances &> /dev/null; then
        echo "📦 Glances telepítése..."
        setup_epel
        pkg_install glances
        echo "✅ Glances telepítve."
    else
        echo "✅ Glances már telepítve van."
    fi
    
    # További hasznos monitorozó eszközök
    pkg_install iotop nmon dstat sysstat
    
    echo "✅ Monitorozó eszközök telepítve."
}

# Repo ellenőrzés
check_repos() {
    echo "🔍 Csomagtárak ellenőrzése..."
    
    # Alap repo-k engedélyezése
    case $DISTRO in
        centos|rocky|alma)
            dnf config-manager --set-enabled appstream baseos extras
            ;;
        rhel)
            echo "🔍 RHEL tárak ellenőrzése..."
            if command -v subscription-manager &> /dev/null; then
                subscription-manager repos --list-enabled
            fi
            ;;
    esac
    
    setup_epel
    echo "✅ Csomagtárak ellenőrzése kész."
}

# A szkript interaktív menüjének megjelenítése
show_main_menu() {
    clear
    echo "========================================="
    echo "    Enterprise Linux 10 Config Script 2.2"
    echo "    Optimized for: $DISTRO $DISTRO_VERSION"
    echo "    Citk 2025"
    echo "========================================="
    echo "1.  Rendszer frissítése (dnf update & upgrade)"
    echo "2.  Alapvető alkalmazások telepítése"
    echo "3.  Monitorozó eszközök (htop, glances)"
    echo "4.  Hálózati beállítások"
    echo "5.  Hostnév és FQDN beállítása"
    echo "6.  Felhasználókezelés"
    echo "7.  SSH beállítások"
    echo "8.  Rendszeradatok listázása"
    echo "9.  Cockpit telepítése"
    echo "10. Tűzfal beállítások (FirewallD)"
    echo "11. SELinux beállítások"
    echo "12. Kilépés"
    echo "========================================="
    read -p "Válassz egy opciót: " choice
}

# --- Csomagkezelési és telepítési funkciók ---

# Rendszer frissítése
update_system() {
    check_repos
    pkg_update
    pkg_upgrade
    echo "✅ A rendszer naprakész."
    read -p "Nyomj Entert a folytatáshoz..."
}

# Alapvető alkalmazások telepítése
install_basic_apps() {
    check_repos
    echo "🚀 Alapvető alkalmazások telepítése..."
    
    pkg_install mc unzip zip curl wget vim nano tree tmux git bash-completion
    pkg_install net-tools bind-utils traceroute nmap tcpdump
    
    echo "✅ Az alapvető alkalmazások sikeresen telepítve."
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Optimalizált hálózati kezelés ---

show_network_status() {
    echo "--- Hálózati állapot ---"
    echo "1. NetworkManager szolgáltatás állapota:"
    systemctl is-active NetworkManager
    
    echo -e "\n2. Hálózati interfészek:"
    nmcli device status
    
    echo -e "\n3. Kapcsolatok:"
    nmcli connection show
    
    echo -e "\n4. Részletes interfész információk:"
    ip addr show
}

configure_static_ip() {
    echo "🔧 Statikus IP beállítása..."
    
    show_network_status
    
    read -p "Add meg a konfigurálandó interfész nevét: " interface_name
    read -p "Add meg a kapcsolat nevét: " connection_name
    
    # Meglévő kapcsolat ellenőrzése
    if nmcli connection show | grep -q "$connection_name"; then
        echo "⚠️ A kapcsolat már létezik, törlöm..."
        nmcli connection delete "$connection_name"
    fi
    
    # Új kapcsolat létrehozása
    nmcli connection add type ethernet con-name "$connection_name" ifname "$interface_name"
    
    # IP beállítások
    read -p "IPv4 cím (pl. 192.168.1.100/24): " ip_address
    read -p "Átjáró (pl. 192.168.1.1): " gateway
    read -p "DNS szerverek (pl. 8.8.8.8,8.8.4.4): " dns_servers
    
    nmcli connection modify "$connection_name" ipv4.method manual 
    nmcli connection modify "$connection_name" ipv4.addresses "$ip_address"
    nmcli connection modify "$connection_name" ipv4.gateway "$gateway"
    nmcli connection modify "$connection_name" ipv4.dns "$dns_servers"
    
    # Kapcsolat aktiválása
    nmcli connection up "$connection_name"
    
    echo "✅ Statikus IP beállítva."
    ip addr show "$interface_name"
    read -p "Nyomj Entert a folytatáshoz..."
}

restart_network() {
    echo "🔧 Hálózati szolgáltatások újraindítása..."
    systemctl restart NetworkManager
    sleep 3
    echo "✅ Hálózat újraindítva."
    show_network_status
    read -p "Nyomj Entert a folytatáshoz..."
}

show_network_menu() {
    clear
    echo "--- Hálózati Beállítások (NetworkManager) ---"
    echo "1. Hálózati állapot megjelenítése"
    echo "2. Statikus IP beállítása"
    echo "3. Grafikus konfiguráció (nmtui)"
    echo "4. Hálózati szolgáltatás újraindítása"
    echo "5. Hálózati naplók megjelenítése"
    echo "6. Vissza a főmenübe"
    read -p "Válassz opciót: " net_choice

    case $net_choice in
        1) 
            show_network_status
            read -p "Nyomj Entert a folytatáshoz..."
            ;;
        2) 
            configure_static_ip
            ;;
        3) 
            if command -v nmtui &> /dev/null; then
                nmtui
            else
                echo "❌ nmtui nincs telepítve. Telepítsd az alap csomagokkal."
                read -p "Nyomj Entert a folytatáshoz..."
            fi
            ;;
        4) 
            restart_network
            ;;
        5) 
            journalctl -u NetworkManager -n 30 --no-pager
            read -p "Nyomj Entert a folytatáshoz..."
            ;;
        6) return ;;
        *) echo "❌ Érvénytelen választás."; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
}

# --- Felhasználókezelés ---

add_user_with_sudo() {
    read -p "Add meg az új felhasználó nevét: " new_user
    
    # Felhasználó létrehozása
    useradd -m -s /bin/bash "$new_user"
    passwd "$new_user"
    
    # Sudo jogok beállítása
    usermod -aG wheel "$new_user"
    
    echo "✅ Felhasználó létrehozva: $new_user"
    echo "✅ Sudo jogok megadva a 'wheel' csoporton keresztül"
}

manage_sudo_access() {
    echo "--- Sudo jogok kezelése ---"
    echo "1. Felhasználó hozzáadása a wheel csoporthoz"
    echo "2. Felhasználó eltávolítása a wheel csoportból"
    echo "3. Wheel csoport tagjainak listázása"
    echo "4. Vissza"
    read -p "Válassz opciót: " sudo_choice
    
    case $sudo_choice in
        1)
            read -p "Felhasználónév: " user_name
            usermod -aG wheel "$user_name"
            echo "✅ $user_name hozzáadva a wheel csoporthoz"
            ;;
        2)
            read -p "Felhasználónév: " user_name
            gpasswd -d "$user_name" wheel
            echo "✅ $user_name eltávolítva a wheel csoportból"
            ;;
        3)
            echo "--- Wheel csoport tagjai ---"
            grep wheel /etc/group | cut -d: -f4 | tr ',' '\n'
            ;;
        4) return ;;
        *) echo "❌ Érvénytelen választás." ;;
    esac
}

manage_users() {
    clear
    echo "--- Felhasználókezelés ---"
    echo "1. Új felhasználó hozzáadása (sudo jogokkal)"
    echo "2. Felhasználók listázása"
    echo "3. Felhasználó törlése"
    echo "4. Jelszó megváltoztatása"
    echo "5. Sudo jogok kezelése"
    echo "6. Vissza a főmenübe"
    read -p "Válassz opciót: " user_choice
    
    case $user_choice in
        1) 
            add_user_with_sudo
            ;;
        2)
            echo "--- Felhasználók listája ---"
            cut -d: -f1 /etc/passwd | grep -v -E '(nologin|false|sync)' | sort
            ;;
        3)
            read -p "Törlendő felhasználó: " del_user
            if id "$del_user" &>/dev/null; then
                read -p "Biztosan törlöd $del_user felhasználót? (y/n): " confirm
                if [ "$confirm" = "y" ]; then
                    userdel -r "$del_user"
                    echo "✅ Felhasználó törölve."
                fi
            else
                echo "❌ A felhasználó nem létezik."
            fi
            ;;
        4)
            read -p "Felhasználónév: " pass_user
            if id "$pass_user" &>/dev/null; then
                passwd "$pass_user"
            else
                echo "❌ A felhasználó nem létezik."
            fi
            ;;
        5)
            manage_sudo_access
            ;;
        6) return ;;
        *) echo "❌ Érvénytelen választás." ;;
    esac
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Hostnév és SSH beállítások ---

configure_hostname() {
    read -p "Új hosztnév: " new_hostname
    hostnamectl set-hostname "$new_hostname"
    
    # /etc/hosts frissítése
    sed -i "/^127.0.1.1/d" /etc/hosts
    echo "127.0.1.1 $new_hostname" >> /etc/hosts
    
    echo "✅ Hosztnév beállítva: $new_hostname"
    read -p "Nyomj Entert a folytatáshoz..."
}

manage_ssh_settings() {
    clear
    echo "--- SSH beállítások ---"
    echo "1. Root bejelentkezés engedélyezése"
    echo "2. SSH banner szerkesztése"
    echo "3. SSH port megváltoztatása"
    echo "4. SSH szolgáltatás újraindítása"
    echo "5. Vissza"
    read -p "Válassz opciót: " ssh_choice
    
    case $ssh_choice in
        1)
            echo "⚠️ Root SSH bejelentkezés engedélyezése..."
            read -p "Biztosan folytatod? (y/n): " confirm
            if [ "$confirm" = "y" ]; then
                sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
                sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
                systemctl restart sshd
                echo "✅ Root SSH bejelentkezés engedélyezve."
            fi
            ;;
        2)
            nano /etc/issue.net
            sed -i '/^Banner/d' /etc/ssh/sshd_config
            echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
            systemctl restart sshd
            echo "✅ SSH banner frissítve."
            ;;
        3)
            read -p "Új SSH port: " ssh_port
            sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
            firewall-cmd --add-port=$ssh_port/tcp --permanent
            firewall-cmd --remove-service=ssh --permanent
            firewall-cmd --reload
            systemctl restart sshd
            echo "✅ SSH port módosítva: $ssh_port"
            ;;
        4)
            systemctl restart sshd
            echo "✅ SSH szolgáltatás újraindítva."
            ;;
        5) return ;;
        *) echo "❌ Érvénytelen választás." ;;
    esac
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Cockpit telepítés ---

install_cockpit() {
    check_repos
    echo "🚀 Cockpit telepítése..."
    
    # Alap cockpit csomag
    pkg_install cockpit
    
    # Tűzfal beállítás
    firewall-cmd --add-service=cockpit --permanent
    firewall-cmd --reload
    
    # Szolgáltatás indítása
    systemctl enable --now cockpit.socket
    systemctl start cockpit
    
    echo "✅ Cockpit telepítve."
    echo "🌐 Elérés: https://$(hostname -I | awk '{print $1}'):9090"
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Tűzfal és SELinux ---

configure_firewall() {
    clear
    echo "--- Tűzfal beállítások ---"
    echo "1. Tűzfal állapot megjelenítése"
    echo "2. HTTP/HTTPS engedélyezése"
    echo "3. Egyéni port engedélyezése"
    echo "4. Vissza"
    read -p "Válassz: " fw_choice
    
    case $fw_choice in
        1) 
            firewall-cmd --list-all
            ;;
        2)
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent
            firewall-cmd --reload
            echo "✅ HTTP/HTTPS engedélyezve"
            ;;
        3)
            read -p "Port szám: " custom_port
            firewall-cmd --add-port=$custom_port/tcp --permanent
            firewall-cmd --reload
            echo "✅ Port engedélyezve: $custom_port"
            ;;
        4) return ;;
        *) echo "❌ Érvénytelen választás." ;;
    esac
    read -p "Nyomj Entert a folytatáshoz..."
}

configure_selinux() {
    clear
    echo "--- SELinux beállítások ---"
    echo "1. SELinux állapot megjelenítése"
    echo "2. Mód váltása (Enforcing/Permissive/Disabled)"
    echo "3. Vissza"
    read -p "Válassz: " sel_choice
    
    case $sel_choice in
        1) 
            sestatus
            ;;
        2)
            echo "1. Enforcing (szigorú)"
            echo "2. Permissive (megengedő)" 
            echo "3. Disabled (kikapcsolt)"
            read -p "Válassz módot: " mode
            case $mode in
                1) 
                    setenforce 1
                    sed -i 's/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
                    echo "✅ SELinux mód: Enforcing"
                    ;;
                2) 
                    setenforce 0
                    sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
                    echo "✅ SELinux mód: Permissive"
                    ;;
                3) 
                    setenforce 0
                    sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
                    echo "✅ SELinux mód: Disabled"
                    ;;
                *) echo "❌ Érvénytelen választás." ;;
            esac
            ;;
        3) return ;;
        *) echo "❌ Érvénytelen választás." ;;
    esac
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Rendszer információk ---

list_system_info() {
    echo "--- Rendszerinformációk ---"
    echo "Disztribúció: $DISTRO $DISTRO_VERSION"
    hostnamectl
    echo -e "\n--- Hardver információk ---"
    lscpu | grep -E "(Model name|CPU\(s\)|Thread|Core)"
    free -h
    echo -e "\n--- Lemez információk ---"
    df -h / /home /var
    echo -e "\n--- Hálózati információk ---"
    ip addr show | grep -E "(inet |ether )"
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Fő program ---

while true; do
    show_main_menu
    case $choice in
        1) update_system ;;
        2) install_basic_apps ;;
        3) install_monitoring_tools ;;
        4) show_network_menu ;;
        5) configure_hostname ;;
        6) manage_users ;;
        7) manage_ssh_settings ;;
        8) list_system_info ;;
        9) install_cockpit ;;
        10) configure_firewall ;;
        11) configure_selinux ;;
        12) echo "👋 Viszlát!"; exit 0 ;;
        *) echo "❌ Érvénytelen választás."; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
done
