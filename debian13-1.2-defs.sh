#!/bin/bash

# Ellenőrizzük, hogy a szkript root felhasználóként fut-e
if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Ez a szkript root jogosultságokat igényel. Kérjük, futtassa 'sudo' vagy 'su' használatával."
  exit 1
fi

# A szkript interaktív menüjének megjelenítése
show_main_menu() {
    clear
    echo "========================================="
    echo " Debian 13 Beállító Szkript 1.2 Complex IT Group @ Kispest 2025 "
    echo "========================================="
    echo "1. Csomagforrások konfigurálása"
    echo "2. Rendszer frissítése (apt update & upgrade)"
    echo "3. Alapvető alkalmazások telepítése"
    echo "4. Hálózati beállítások"
    echo "5. Hostnév és FQDN beállítása"
    echo "6. Felhasználókezelés"
    echo "7. SSH root bejelentkezés engedélyezése"
    echo "8. Rendszeradatok listázása"
    echo "9. Cockpit telepítése és beállítása"
    echo "10. SSH bejelentkező szöveg szerkesztése"
    echo "11. Kilépés"
    echo "========================================="
    read -p "Válassz egy opciót: " choice
}

# --- Segédfunkciók ---

# Ellenőrzi és hozzáadja a trixie repókat
check_and_configure_trixie_repos() {
    if ! grep -q "trixie main" /etc/apt/sources.list; then
        echo "⚙️ A sources.list fájl hiányos vagy hibás. Hozzáadjuk a 'trixie' repókat a teljes funkcionalitás érdekében."
        configure_repos
        echo "Csomaglista frissítése..."
        apt update
        echo "✅ A csomaglista frissítése sikeres."
    fi
}

# --- Csomagkezelési és telepítési funkciók ---

# Csomagforrások konfigurálása
configure_repos() {
    echo "⚙️ Csomagforrások konfigurálása..."
    
    # Eltávolítjuk a régi repókat, és hozzáadjuk a Debian 13 "trixie" repókat
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free non-free-firmware
EOF
    
    echo "✅ Csomagforrások sikeresen konfigurálva 'trixie'-re."
    echo "Most frissíteni kell a csomaglistát az új beállítások érvénybelépéséhez."
    read -p "Nyomj Entert a folytatáshoz..."
}

# Rendszer frissítése
update_system() {
    check_and_configure_trixie_repos
    echo "🔄 Rendszer frissítése..."
    apt update
    apt upgrade -y
    echo "✅ A rendszer naprakész."
    read -p "Nyomj Entert a folytatáshoz..."
}

# Alapvető alkalmazások telepítése
install_basic_apps() {
    check_and_configure_trixie_repos
    echo "🚀 Alapvető alkalmazások telepítése: mc, unzip, zip, htop, bpytop, curl..."
    apt update
    if ! apt install -y mc unzip zip htop bpytop curl; then
        echo "❌ Hiba az alapvető alkalmazások telepítése során."
        read -p "Nyomj Entert a folytatáshoz..."
        return
    fi
    echo "✅ Az alkalmazások sikeresen telepítve."
    read -p "Nyomj Entert a folytatáshoz..."
}

# --- Hálózati funkciók ---

install_network_dependencies() {
    check_and_configure_trixie_repos
    
    echo "🚀 A szükséges hálózati függőségek telepítése: network-manager, net-tools, ifenslave, vlan..."
    apt update
    if ! apt install -y network-manager net-tools ifenslave vlan; then
        echo "❌ Hiba a hálózati csomagok telepítése során."
        read -p "Nyomj Entert a folytatáshoz..."
        return
    fi
    
    echo "🔄 A hagyományos 'ifupdown' rendszer letiltása a konfliktusok elkerülése érdekében..."
    systemctl stop networking 2>/dev/null || true
    systemctl disable networking 2>/dev/null || true
    systemctl mask networking
    
    echo "✅ A NetworkManager engedélyezése és indítása..."
    systemctl unmask NetworkManager
    systemctl enable --now NetworkManager
    
    # NetworkManager konfiguráció javítása
    echo "⚙️ NetworkManager konfiguráció beállítása..."
    if [ -f "/etc/NetworkManager/NetworkManager.conf" ]; then
        # Ellenőrizzük, hogy a managed=true be van-e állítva
        if ! grep -q "managed=true" /etc/NetworkManager/NetworkManager.conf; then
            sed -i '/\[ifupdown\]/,/managed/ s/^#//' /etc/NetworkManager/NetworkManager.conf
            sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
            echo "✅ NetworkManager konfiguráció frissítve: managed=true"
        fi
    fi
    
    # Globális managed devices konfiguráció létrehozása
    echo "⚙️ Globális eszközkezelés beállítása..."
    mkdir -p /etc/NetworkManager/conf.d/
    cat <<EOF > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
# Ez a fájl biztosítja, hogy az összes eszköz managed legyen
[keyfile]
unmanaged-devices=none
EOF
    
    echo "✅ A hálózati függőségek sikeresen telepítve és a rendszer beállítva NetworkManagerre."
    read -p "Nyomj Entert a folytatáshoz..."
}

# NetworkManager problémák javítása
fix_network_manager_issues() {
    echo "🔧 NetworkManager problémák diagnosztizálása és javítása..."
    
    # 1. NetworkManager szolgáltatás állapotának ellenőrzése
    echo "1. NetworkManager szolgáltatás ellenőrzése..."
    systemctl status NetworkManager --no-pager -l
    
    # 2. Interfészek állapotának ellenőrzése
    echo -e "\n2. Hálózati interfészek állapota:"
    nmcli device status
    
    # 3. /etc/network/interfaces fájl ellenőrzése
    echo -e "\n3. /etc/network/interfaces fájl ellenőrzése:"
    if [ -f "/etc/network/interfaces" ]; then
        cat /etc/network/interfaces
        echo "⚠️ Ha nem loopback interfészek vannak itt definiálva, az megakadályozhatja a NetworkManager működését."
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
            echo "✅ interfaces fájl megtisztítva"
        fi
    fi
    
    # 4. NetworkManager konfiguráció ellenőrzése
    echo -e "\n4. NetworkManager konfiguráció ellenőrzése:"
    if [ -f "/etc/NetworkManager/NetworkManager.conf" ]; then
        cat /etc/NetworkManager/NetworkManager.conf
        # Ellenőrizzük, hogy a managed=true be van-e állítva
        if ! grep -q "managed=true" /etc/NetworkManager/NetworkManager.conf; then
            echo "⚠️ NetworkManager nincs managed módban"
            read -p "Szeretnéd beállítani managed=true-ra? (y/n): " set_managed
            if [[ "$set_managed" == "y" || "$set_managed" == "Y" ]]; then
                sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
                echo "✅ NetworkManager beállítva managed=true-ra"
            fi
        fi
    fi
    
    # 5. Unmanaged eszközök kezelése
    echo -e "\n5. Unmanaged eszközök kezelése..."
    unmanaged_devices=$(nmcli -t -f DEVICE,STATE device | grep "unmanaged" | cut -d: -f1)
    if [ -n "$unmanaged_devices" ]; then
        echo "Unmanaged eszközök: $unmanaged_devices"
        for device in $unmanaged_devices; do
            read -p "Szeretnéd beállítani a(z) $device eszközt managed-re? (y/n): " manage_device
            if [[ "$manage_device" == "y" || "$manage_device" == "Y" ]]; then
                nmcli device set "$device" managed yes
                echo "✅ $device eszköz beállítva managed-re"
            fi
        done
    else
        echo "✅ Nincsenek unmanaged eszközök"
    fi
    
    # 6. NetworkManager újraindítása
    echo -e "\n6. NetworkManager újraindítása..."
    systemctl restart NetworkManager
    sleep 3
    
    # 7. Végleges állapot ellenőrzése
    echo -e "\n7. Végleges állapot ellenőrzése:"
    nmcli device status
    
    echo -e "\n✅ NetworkManager problémajavítás befejezve"
    echo "Ha továbbra sem működik, próbáld meg az 'nmtui' parancsot újra"
    read -p "Nyomj Entert a folytatáshoz..."
}

show_network_menu() {
    clear
    echo "--- Hálózati Beállítások ---"
    echo "0. Hálózati függőségek telepítése (Ezzel kell kezdeni!)"
    echo "1. Hálózati beállítás grafikus karakteres felületen (nmtui)"
    echo "2. NetworkManager problémák javítása"
    echo "3. Hálózati interfészek listázása (nmcli)"
    echo "4. Vissza a főmenübe"
    echo "----------------------------------------------"
    read -p "Válassz egy hálózati opciót: " net_choice

    case $net_choice in
        0) install_network_dependencies ;;
        1) 
            if command -v nmtui &> /dev/null; then
                nmtui
            else
                echo "❌ Az nmtui nincs telepítve. Először telepítsd a hálózati függőségeket (0. opció)."
                read -p "Nyomj Entert a folytatáshoz..."
            fi
            ;;
        2) fix_network_manager_issues ;;
        3) 
            echo "--- Hálózati interfészek állapota ---"
            nmcli device status
            echo -e "\n--- Részletes interfész információk ---"
            ip addr show
            read -p "Nyomj Entert a folytatáshoz..."
            ;;
        4) return ;;
        *) echo "Érvénytelen választás."; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
}

# --- Felhasználókezelési funkciók ---

list_users() {
    echo "--- Felhasználók listája ---"
    awk -F':' '{ print $1}' /etc/passwd | grep -v 'nologin' | grep -v 'false' | grep -v 'sync'
    read -p "Nyomj Entert a folytatáshoz..."
}

delete_user() {
    read -p "Add meg a törölni kívánt felhasználó nevét: " user_to_delete
    read -p "⚠️ Biztosan törölni szeretnéd a(z) '$user_to_delete' felhasználót és a home könyvtárát? (y/n): " confirm_delete
    if [[ "$confirm_delete" == "y" || "$confirm_delete" == "Y" ]]; then
        /usr/sbin/userdel -r "$user_to_delete"
        echo "✅ A(z) '$user_to_delete' felhasználó sikeresen törölve."
    else
        echo "❌ Felhasználó törlése megszakítva."
    fi
    read -p "Nyomj Entert a folytatáshoz..."
}

manage_users() {
    clear
    echo "--- Felhasználókezelés ---"
    echo "1. Új felhasználó hozzáadása és sudo beállítása"
    echo "2. Felhasználók listázása"
    echo "3. Felhasználó törlése"
    echo "4. Vissza a főmenübe"
    echo "---------------------------"
    read -p "Válassz egy felhasználókezelési opciót: " user_choice
    case $user_choice in
        1) add_user_sudo ;;
        2) list_users ;;
        3) delete_user ;;
        4) return ;;
        *) echo "Érvénytelen választás."; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
}

add_user_sudo() {
    read -p "Add meg az új felhasználó nevét: " new_user
    /usr/sbin/adduser "$new_user"
    /usr/sbin/usermod -aG sudo "$new_user"
    echo "✅ A(z) '$new_user' felhasználó hozzáadva és a 'sudo' csoporthoz rendelve."
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
        echo -e "127.1.0.1\t$new_hostname.local\t$new_hostname" | tee -a /etc/hosts > /dev/null
    fi
    echo "✅ Hostnév beállítva: $new_hostname"
    read -p "Nyomj Entert a folytatáshoz..."
}

# SSH root bejelentkezés engedélyezése
enable_ssh_root() {
    echo "⚠️ FIGYELEM: A root bejelentkezés engedélyezése biztonsági kockázatot jelent."
    read -p "Biztosan folytatod? (y/n): " ssh_choice
    if [[ "$ssh_choice" == "y" || "$ssh_choice" == "Y" ]]; then
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl restart sshd
        echo "✅ SSH root bejelentkezés engedélyezve."
    else
        echo "❌ Művelet megszakítva."
    fi
    read -p "Nyomj Entert a folytatáshoz..."
}

# Rendszeradatok listázása
list_system_info() {
    echo "--- Rendszerinformációk ---"
    hostnamectl
    echo "--- OS információ ---"
    lsb_release -a
    echo "--- Kernel információ ---"
    uname -a
    echo "--- CPU információ ---"
    lscpu
    read -p "Nyomj Entert a folytatáshoz..."
}

# Cockpit telepítése és beállítása
install_cockpit() {
    check_and_configure_trixie_repos
    echo "🚀 Cockpit telepítése..."
    apt update
    apt install -y cockpit
    systemctl enable --now cockpit.socket
    echo "✅ Cockpit telepítve és fut."
    echo "A webes felület a következő címen érhető el: https://<your-server-ip>:9090"
    read -p "Nyomj Entert a folytatáshoz..."
}

# SSH bejelentkező szöveg szerkesztése
edit_ssh_banner() {
    echo "✍️ SSH bejelentkező szöveg szerkesztése."
    
    if ! command -v nano &> /dev/null; then
        echo "A 'nano' szerkesztő nincs telepítve. Telepítjük..."
        apt update && apt install -y nano
    fi
    
    nano /etc/issue.net
    
    sed -i '/^Banner/d' /etc/ssh/sshd_config
    echo "Banner /etc/issue.net" | tee -a /etc/ssh/sshd_config > /dev/null
    systemctl restart sshd
    echo "✅ SSH bejelentkező szöveg elmentve és beállítva."
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
        5) configure_hostname ;;
        6) manage_users ;;
        7) enable_ssh_root ;;
        8) list_system_info ;;
        9) install_cockpit ;;
        10) edit_ssh_banner ;;
        11) echo "👋 Viszlát!"; exit 0 ;;
        *) echo "Érvénytelen választás. Kérlek, próbáld újra."; read -p "Nyomj Entert a folytatáshoz..." ;;
    esac
done
