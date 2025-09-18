#!/bin/bash

# --- A szkript automatikus leállítása hiba esetén ---
set -e

# Ellenőrzi, hogy a szkript root jogokkal fut-e
if [[ $EUID -ne 0 ]]; then
   echo "🚫 A szkriptet rendszergazdai (root) jogokkal kell futtatni! Használd a 'sudo' parancsot."
   exit 1
fi

# --- Kompatibilitás ellenőrzése ---
check_compatibility() {
    echo "⚙️  Kompatibilitás ellenőrzése..."
    if ! command -v apt &> /dev/null; then
        echo "❌ Hiba: Az 'apt' csomagkezelő nem található. A szkript csak Debian/Ubuntu-alapú rendszereken működik."
        exit 1
    fi
    echo "✅ Kompatibilis rendszer."
    sleep 1
}

# --- Főmenü funkció ---
main_menu() {
    clear
    echo "✨ Üdvözöllek a ClamAV menüjében! ✨"
    echo "---"
    echo "Kérlek, válassz egy opciót:"
    echo "0. ClamAV telepítése (ha még nincs telepítve)"
    echo "1. Teljes rendszer vizsgálata"
    echo "2. Adott mappa vizsgálata"
    echo "3. Vírusadatbázis frissítése"
    echo "4. ClamAV szolgáltatások leállítása"
    echo "5. Kilépés"
    echo "---"
    read -p "Választásod (0-5): " choice
    echo "---"

    case "$choice" in
        0)
            install_clamav
            ;;
        1)
            full_scan
            ;;
        2)
            custom_scan
            ;;
        3)
            update_definitions
            ;;
        4)
            stop_clamav_services
            read -p "Nyomj Enter-t a folytatáshoz..."
            main_menu
            ;;
        5)
            echo "👋 Kilépés. Viszlát!"
            exit 0
            ;;
        *)
            echo "❌ Érvénytelen választás. Kérlek, 0-tól 5-ig adj meg egy számot."
            sleep 2
            main_menu
            ;;
    esac
}

# --- Folyamatjelző funkció ---
spinner() {
    local pid="$1"
    local delay=0.1
    local spinstr='|/-\'
    while [ -d /proc/$pid ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# --- Vizsgálat végrehajtása funkció ---
perform_scan() {
    local scan_path="$1"
    local scan_type="$2"

    echo "---"
    read -p "Szeretnéd a fertőzött fájlokat karanténba helyezni? (y/n) " quarantine_choice
    echo "---"

    local clamscan_options="-r --exclude-dir=^/sys|^/proc|^/dev"
    local infected_found=false
    QUARANTINE_DIR="/var/lib/clamav/quarantine"

    if [[ "$quarantine_choice" == "y" || "$quarantine_choice" == "Y" ]]; then
        mkdir -p "$QUARANTINE_DIR"
        clamscan_options+=" --move=$QUARANTINE_DIR"
        echo "⚠️  Vigyázat: A talált fertőzött fájlok a(z) '$QUARANTINE_DIR' mappába kerülnek át. Javasolt később átvizsgálni őket."
        sleep 3
    fi

    echo "🔎 Elindult a $scan_type vizsgálat a(z) '$scan_path' útvonalon. Ez eltarthat egy ideig..."
    echo "Folyamatban..."

    # A clamscan futtatása a háttérben
    sudo clamscan $clamscan_options "$scan_path" &
    local clamscan_pid=$!
    
    spinner "$clamscan_pid"
    wait "$clamscan_pid"
    
    clamscan_output=$(tail -n 100 /var/log/clamav/clamav.log)

    if [[ "$clamscan_output" == *"Infected files: 0"* ]]; then
        echo "✅ A vizsgálat befejeződött. Nem találtam fertőzött fájlokat."
    else
        infected_found=true
        echo "🚨 FERTŐZÉS ÉSZLELVE! A vizsgálati eredményekért lásd a /var/log/clamav/clamav.log fájlt."
        if [[ "$quarantine_choice" == "y" || "$quarantine_choice" == "Y" ]]; then
            echo "➡️  A fertőzött fájlok sikeresen karanténba helyezve: '$QUARANTINE_DIR'"
        fi
    fi
    
    echo "✅ A vizsgálat befejeződött."
}

# --- Teljes rendszer vizsgálata ---
full_scan() {
    if ! command -v clamscan &> /dev/null; then
        echo "🚫 A ClamAV nincs telepítve. Kérlek, előbb válaszd a '0' opciót a telepítéshez."
        read -p "Nyomj Enter-t a folytatáshoz..."
        main_menu
        return
    fi
    perform_scan "/" "teljes rendszer"
    read -p "Nyomj Enter-t a folytatáshoz..."
    main_menu
}

# --- Adott mappa vizsgálata ---
custom_scan() {
    if ! command -v clamscan &> /dev/null; then
        echo "🚫 A ClamAV nincs telepítve. Kérlek, előbb válaszd a '0' opciót a telepítéshez."
        read -p "Nyomj Enter-t a folytatáshoz..."
        main_menu
        return
    fi
    read -p "📂 Add meg a vizsgálandó mappa teljes útvonalát: " scan_path
    if [[ -d "$scan_path" ]]; then
        perform_scan "$scan_path" "egyéni mappa"
    else
        echo "❌ Hiba: A megadott mappa nem létezik. Kérlek, ellenőrizd az útvonalat."
    fi
    read -p "Nyomj Enter-t a folytatáshoz..."
    main_menu
}

# --- Vírusadatbázis frissítése ---
update_definitions() {
    if ! command -v freshclam &> /dev/null; then
        echo "🚫 A ClamAV nincs telepítve. Kérlek, előbb válaszd a '0' opciót a telepítéshez."
        read -p "Nyomj Enter-t a folytatáshoz..."
        main_menu
        return
    fi
    echo "🔄 Vírusadatbázis frissítése a freshclam segítségével..."

    # Állapot ellenőrzése és szolgáltatás leállítása a manuális frissítéshez
    if sudo systemctl is-active --quiet clamav-freshclam.service; then
        echo "ℹ️  A háttérben futó frissítő szolgáltatás leállítása..."
        sudo systemctl stop clamav-freshclam.service
    fi

    # Manuális frissítés futtatása
    sudo freshclam
    
    # Szolgáltatás újraindítása
    echo "✅ A vírusadatbázis frissítve. A szolgáltatás újraindítása..."
    sudo systemctl start clamav-freshclam.service

    read -p "Nyomj Enter-t a folytatáshoz..."
    main_menu
}

# --- ClamAV telepítő funkció ---
install_clamav() {
    if command -v clamscan &> /dev/null; then
        echo "ℹ️ A ClamAV már telepítve van. Nincs szükség újratelepítésre."
        read -p "Nyomj Enter-t a folytatáshoz..."
        main_menu
        return
    fi
    echo "📦 ClamAV telepítése és konfigurálása..."
    echo "---"
    sleep 2
    
    echo "🔄 Csomaglisták frissítése..."
    sudo apt update -y
    echo "✅ Kész."
    echo "---"
    sleep 1

    echo "📦 ClamAV telepítése..."
    sudo apt install clamav -y
    echo "✅ ClamAV telepítve."
    echo "---"
    sleep 1

    echo "⚙️ Konfigurációs fájlok beállítása..."
    # Biztosítja, hogy a clamd.conf fájl olvasható legyen a megfelelő felhasználó számára
    echo "ℹ️  A konfigurációs fájl jogosultságainak beállítása..."
    sudo chown clamav:clamav /var/lib/clamav/ -R
    sudo chmod 755 /var/lib/clamav/
    sudo chmod 644 /etc/clamav/clamd.conf
    
    sudo sed -i 's/^Example/#Example/' /etc/clamav/clamd.conf
    sudo sed -i 's/^#LocalSocket/LocalSocket/' /etc/clamav/clamd.conf
    sudo sed -i 's/^Example/#Example/' /etc/clamav/freshclam.conf
    echo "✅ A konfiguráció sikeresen befejeződött."
    echo "---"
    sleep 1

    echo "🚀 ClamAV szolgáltatások indítása és engedélyezése a rendszerindításkor..."
    sudo systemctl restart clamav-daemon.service
    sudo systemctl enable clamav-daemon.service
    sudo systemctl restart clamav-freshclam.service
    sudo systemctl enable clamav-freshclam.service
    echo "✅ Szolgáltatások elindítva és engedélyezve."
    echo "---"
    sleep 2

    # Manuális frissítés a telepítés után
    echo "ℹ️  Vírusadatbázis első frissítése..."
    sudo systemctl stop clamav-freshclam.service
    sudo freshclam
    sudo systemctl start clamav-freshclam.service

    echo "🎉 A ClamAV telepítése és konfigurálása sikeresen befejeződött!"
    read -p "Szeretnél azonnal teljes rendszer-víruskeresést futtatni? (y/n) " scan_choice
    echo "---"
    if [[ "$scan_choice" == "y" || "$scan_choice" == "Y" ]]; then
        full_scan
    else
        echo "ℹ️  A víruskeresés kihagyva."
        read -p "Nyomj Enter-t a folytatáshoz..."
        main_menu
    fi
}

# --- ClamAV szolgáltatás leállító funkció ---
stop_clamav_services() {
    echo "⏹️  ClamAV szolgáltatások leállítása..."
    if sudo systemctl is-active --quiet clamav-daemon.service; then
        sudo systemctl stop clamav-daemon.service
        echo "   - clamav-daemon leállítva."
    else
        echo "   - clamav-daemon már le van állítva."
    fi

    if sudo systemctl is-active --quiet clamav-freshclam.service; then
        sudo systemctl stop clamav-freshclam.service
        echo "   - clamav-freshclam leállítva."
    else
        echo "   - clamav-freshclam már le van állítva."
    fi
    echo "✅ A ClamAV szolgáltatások sikeresen leállítva."
}

# --- Futtatás indítása ---
check_compatibility
main_menu
