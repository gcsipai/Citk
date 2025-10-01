#!/usr/bin/env bash
# ==============================================================================
# MariaDB Telepítő és Kezelő Szkript
# Készült: Debian 12/13 és Ubuntu 22.04+ rendszerekhez
# Verzió: 4.2 Citk 2025 (Apache2-specifikus, adatbázis-mentéssel)
#
# Főbb bővítések:
#   - MariaDB telepítés és konfiguráció.
#   - Root jelszókezelés beépítve.
#   - Apache2 támogatás a phpMyAdmin-hoz.
#   - Dedikált adatbázis-mentési/visszaállítási menü WDB formátumban.
# ==============================================================================
# --- Globális Változók és Beállítások ---
set -o pipefail

# Színek a jobb olvashatóságért
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

MARIADB_CONFIG="/etc/mysql/mariadb.conf.d/50-server.cnf"
BACKUP_DIR_BASE="/var/backups/mariadb"
MARIADB_ROOT_PASSWORD="" # Globális változó a jelszó tárolására

# --- Segédfüggvények ---
function print_msg() { local color="$1"; local message="$2"; echo -e "${color}${message}${C_RESET}"; }
function press_enter_to_continue() { echo; read -rp "Nyomjon ENTER-t a folytatáshoz..."; }
function command_exists() { command -v "$1" &>/dev/null; }

function check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_msg "$C_RED" "❌ Hiba: Ez a szkript csak root (vagy sudo) jogosultsággal futtatható."
        exit 1
    fi
}

function get_root_password_if_needed() {
    # Csak akkor kérjük be a jelszót, ha még nincs beállítva
    if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
        print_msg "$C_YELLOW" "⚠️ Kérem, adja meg a MariaDB root jelszavát."
        read -rsp "MariaDB root jelszó: " MARIADB_ROOT_PASSWORD
        echo

        # Gyors teszt a jelszóval, mielőtt visszatérnénk
        if ! mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "quit" 2>/dev/null; then
            print_msg "$C_RED" "❌ Érvénytelen MariaDB root jelszó. Kérem, próbálja újra."
            MARIADB_ROOT_PASSWORD="" # Töröljük a rossz jelszót
            return 1
        fi
        return 0
    fi
    return 0
}

# --------------------------------------------------------------------------------------------------

## 1. APACHE2 TELEPÍTÉS ÉS BEÁLLÍTÁS
function setup_apache() {
    print_msg "$C_BLUE" "## 1. Apache2 webszerver telepítése és konfigurálása ##"
    
    # Apache2 telepítése
    if dpkg -s apache2 &>/dev/null; then
        print_msg "$C_GREEN" "✅ Az Apache2 már telepítve van."
    else
        print_msg "$C_CYAN" "📦 Apache2 telepítése..."
        apt-get update
        if ! apt-get install -y apache2; then
            print_msg "$C_RED" "❌ Hiba történt az Apache2 telepítése során."
            return 1
        fi
        print_msg "$C_GREEN" "✅ Apache2 sikeresen telepítve."
    fi
    
    # Apache2 modulok bekapcsolása
    print_msg "$C_CYAN" "⚙️  Apache2 modulok aktiválása..."
    a2enmod rewrite &>/dev/null
    systemctl restart apache2
    systemctl enable apache2 &>/dev/null
    
    # Tűzfal beállítása (ha aktív)
    if command_exists ufw && ufw status | grep -q "active"; then
        ufw allow 'Apache Full' &>/dev/null
        print_msg "$C_GREEN" "✅ Tűzfalszabály hozzáadva a HTTP/HTTPS forgalomhoz."
    fi
    
    print_msg "$C_GREEN" "✅ Apache2 sikeresen konfigurálva és elindítva."
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 3. MARIADB SZERVER TELEPÍTÉSE 
function install_mariadb() {
    print_msg "$C_BLUE" "## 3. MariaDB szerver telepítése és alapkonfiguráció ##"

    # Csomaglisták frissítése
    print_msg "$C_CYAN" "📦 Csomaglisták frissítése..."
    if ! apt-get update -y; then
        print_msg "$C_RED" "❌ Hiba történt a csomaglisták frissítése során."
        return 1
    fi

    # MariaDB szerver telepítése
    print_msg "$C_CYAN" "📦 MariaDB szerver telepítése..."
    # 'mariadb-server' telepítése, ha még nincs telepítve
    if ! dpkg -s mariadb-server &>/dev/null; then
        if ! apt-get install -y mariadb-server; then
            print_msg "$C_RED" "❌ Hiba történt a MariaDB telepítése során."
            return 1
        fi
    else
        print_msg "$C_GREEN" "✅ MariaDB már telepítve van."
    fi

    # A szolgáltatás elindítása és engedélyezése
    print_msg "$C_CYAN" "🚀 MariaDB szolgáltatás indítása..."
    if ! systemctl start mariadb.service; then
        print_msg "$C_RED" "❌ Nem sikerült elindítani a MariaDB szolgáltatást."
        return 1
    fi
    systemctl enable mariadb.service &>/dev/null

    # Alapvető biztonsági konfiguráció (opcionális, mert a jelszóbeállítás következik)
    # A debian/ubuntu socket autentikációja miatt ezt manuálisan kezeljük

    # A szolgáltatás állapotának ellenőrzése
    if systemctl is-active --quiet mariadb.service; then
        print_msg "$C_GREEN" "✅ A MariaDB sikeresen telepítve és fut."
    else
        print_msg "$C_RED" "❌ A MariaDB telepítése sikeres, de a szolgáltatás nem fut."
        return 1
    fi

    print_msg "$C_YELLOW" "⚠️  Kérem, a 4. menüpontban állítsa be a root jelszót és a hozzáférést!"
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 4. HOZZÁFÉRÉS BEÁLLÍTÁSA 
function configure_access() {
    print_msg "$C_BLUE" "## 4. MariaDB Hozzáférés Beállítása ##"
    
    print_msg "$C_CYAN" "🔐 MariaDB Root Jelszó Beállítása..."
    local new_root_password
    read -rsp "Új MariaDB Root Jelszó (hagyja üresen a kihagyáshoz): " new_root_password
    echo

    if [ -n "$new_root_password" ]; then
        # Jelszó beállítása a unix_socket pluginnal való autentikációval
        mysql -u root <<EOF 2>/dev/null
ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_root_password}';
FLUSH PRIVILEGES;
EOF
        if [ $? -eq 0 ]; then
            MARIADB_ROOT_PASSWORD="$new_root_password" # Globális változó frissítése
            print_msg "$C_GREEN" "✅ Root jelszó sikeresen beállítva."
        else
            print_msg "$C_RED" "❌ Hiba történt a jelszó beállítása során. Lehet, hogy már be van állítva és nem a 'root' felhasználóval kell a műveletet végrehajtani."
        fi
    else
        print_msg "$C_YELLOW" "ℹ️  Root jelszó beállítása kihagyva."
    fi
    
    read -rp "Engedélyezi a távoli root hozzáférést? (i/n): " remote_access
    if [[ "$remote_access" =~ ^[iI](gen)?$ ]]; then
        if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
            print_msg "$C_RED" "❌ A távoli hozzáféréshez be kell állítani a root jelszót előbb!"
        else
            print_msg "$C_CYAN" "🌐 Távoli hozzáférés beállítása..."
            # Létrehozzuk a root felhasználót bármely hostról
            mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF 2>/dev/null
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
            
            # MariaDB konfiguráció módosítása, hogy engedje a távoli kapcsolatokat
            if grep -q "bind-address" "$MARIADB_CONFIG"; then
                sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' "$MARIADB_CONFIG"
            else
                echo -e "\n[mysqld]\nbind-address = 0.0.0.0" >> "$MARIADB_CONFIG"
            fi
            
            systemctl restart mariadb.service
            
            # Tűzfal beállítása (ha aktív)
            if command_exists ufw && ufw status | grep -q "active"; then
                ufw allow 3306/tcp &>/dev/null
                print_msg "$C_GREEN" "✅ Tűzfalszabály hozzáadva a 3306-os porthoz."
            fi
            
            print_msg "$C_GREEN" "✅ Távoli hozzáférés engedélyezve. (MariaDB újraindítva)"
        fi
    else
        print_msg "$C_YELLOW" "ℹ️  Távoli hozzáférés tiltva (alapértelmezett)."
    fi

    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 2. JAVÍTOTT PHPMYADMIN TELEPÍTÉS (CSAK APACHE2)
function install_phpmyadmin_apache() {
    print_msg "$C_BLUE" "## 2. phpMyAdmin Telepítése (Apache2-hez) ##"
    
    # Kérjük be a root jelszót, mert a phpMyAdmin-hoz kell!
    get_root_password_if_needed
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nincs MariaDB root jelszó. A phpMyAdmin telepítése megszakítva."
        return 1
    fi

    # PHP és szükséges bővítmények telepítése
    print_msg "$C_CYAN" "📦 PHP és szükséges modulok telepítése..."
    if ! apt-get install -y php php-mysql php-mbstring php-curl php-zip php-gd; then
        print_msg "$C_RED" "❌ Hiba történt a PHP modulok telepítése során."
        return 1
    fi
    
    # phpMyAdmin telepítése nem interaktív módon
    print_msg "$C_CYAN" "📦 phpMyAdmin telepítése..."
    export DEBIAN_FRONTEND=noninteractive
    
    # Válaszok beállítása: adatbázis konfigurálás IGEN, webszerver Apache2
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    
    # Root és App jelszó beállítása
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MARIADB_ROOT_PASSWORD" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $MARIADB_ROOT_PASSWORD" | debconf-set-selections
    
    if ! apt-get install -yq phpmyadmin; then
        print_msg "$C_RED" "❌ Hiba a phpMyAdmin telepítése során."
        return 1
    fi
    
    # Apache konfiguráció aktiválása
    print_msg "$C_CYAN" "⚙️  Apache2 konfigurálása a phpMyAdmin-hoz..."
    a2enconf phpmyadmin &>/dev/null
    systemctl reload apache2
    
    print_msg "$C_GREEN" "✅ A phpMyAdmin sikeresen telepítve és konfigurálva."
    print_msg "$C_CYAN" "🌐 Elérhető itt: http://$(hostname -I | awk '{print $1}')/phpmyadmin"
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 5. FELHASZNÁLÓ- ÉS JOGOSULTSÁGKEZELÉS (Egyszerűsítve)
function user_management() {
    print_msg "$C_BLUE" "## 5. Felhasználó- és Jogosultságkezelés (MariaDB) ##"
    
    get_root_password_if_needed
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nincs root jelszó megadva. Művelet megszakítva."
        return 1
    fi

    print_msg "$C_CYAN" "ℹ️  Jelenleg csak a MariaDB parancssor érhető el. A teljes funkcionalitásért használja a phpMyAdmin-t!"
    print_msg "$C_CYAN" "▶️  Belépés a MariaDB parancssori kliensbe:"
    
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}"

    print_msg "$C_CYAN" "↩️  Visszatérés a főmenübe."
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 6. ADATBÁZIS MENTÉSE
function backup_database() {
    print_msg "$C_BLUE" "## 6. Adatbázis mentése (WDB formátum) ##"
    
    # Root jelszó bekérése
    get_root_password_if_needed
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nincs root jelszó megadva. A mentés megszakítva."
        return 1
    fi
    
    # Mentési könyvtár ellenőrzése/létrehozása
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="${BACKUP_DIR_BASE}/backup_${timestamp}"
    local backup_file="${backup_dir}/database_backup.wdb"
    
    mkdir -p "$backup_dir"
    
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nem sikerült létrehozni a mentési könyvtárat: $backup_dir"
        return 1
    fi
    
    print_msg "$C_CYAN" "💾 Adatbázis mentése folyamatban: $backup_file"
    
    # Adatbázis mentése mysqldump segítségével
    # A --single-transaction garantálja a konzisztenciát!
    if ! mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases --single-transaction > "$backup_file" 2>/dev/null; then
        print_msg "$C_RED" "❌ Hiba történt az adatbázis mentése során. (Lehet, hogy rossz a jelszó)"
        # Mentési könyvtár takarítása
        rm -rf "$backup_dir"
        return 1
    fi
    
    # Sikeres mentés utáni teendők
    local file_size=$(du -h "$backup_file" | cut -f1)
    print_msg "$C_GREEN" "✅ Adatbázis sikeresen mentve!"
    print_msg "$C_CYAN" "📁 Fájl helye: $backup_file"
    print_msg "$C_CYAN" "📏 Fájl méret: $file_size"
    
    # Biztonsági másolat a legutóbbi mentésről
    local latest_backup="${BACKUP_DIR_BASE}/latest"
    # Szimbolikus link létrehozása (f: erőltetett, n: nem követi a linket)
    ln -sfn "$backup_dir" "$latest_backup"
    print_msg "$C_CYAN" "🔗 Legutóbbi mentés linkje frissítve: $latest_backup -> $backup_dir"

    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 7. ADATBÁZIS VISSZAÁLLÍTÁSI FUNKCIÓ
function restore_database() {
    print_msg "$C_BLUE" "## 7. Adatbázis visszaállítása ##"
    
    # Mentések listázása
    if [ ! -d "$BACKUP_DIR_BASE" ]; then
        print_msg "$C_RED" "❌ Nincsenek mentések a $BACKUP_DIR_BASE könyvtárban."
        return 1
    fi
    
    # Mentési fájlok gyűjtése, beleértve a könyvtár nevét is, majd dátum szerint fordított sorrendben
    # A könyvtár nevéből kell a timestamp-et kinyerni, mert az a pontos időpont
    local backups_temp=($(find "$BACKUP_DIR_BASE" -type d -name "backup_*" | sort -r))
    local backups=()

    for dir in "${backups_temp[@]}"; do
        local file="$dir/database_backup.wdb"
        if [ -f "$file" ]; then
            backups+=("$file")
        fi
    done

    if [ ${#backups[@]} -eq 0 ]; then
        print_msg "$C_RED" "❌ Nem található WDB mentési fájl."
        return 1
    fi
    
    print_msg "$C_CYAN" "📋 Elérhető mentések (legújabb elöl):"
    local i=1
    for backup in "${backups[@]}"; do
        local size=$(du -h "$backup" | cut -f1)
        # Az időbélyeg kinyerése a könyvtárnévből
        local timestamp_part=$(basename "$(dirname "$backup")" | sed 's/backup_//')
        local date_part=$(echo "$timestamp_part" | cut -d'_' -f1)
        local time_part=$(echo "$timestamp_part" | cut -d'_' -f2 | sed 's/\(..\)/\1:/g; s/:$//')
        echo "  $i) $backup (Méret: $size, Dátum: $date_part $time_part)"
        ((i++))
    done
    
    read -rp "Válassza ki a visszaállítandó mentés sorszámát: " restore_choice
    
    if ! [[ "$restore_choice" =~ ^[0-9]+$ ]] || [ "$restore_choice" -lt 1 ] || [ "$restore_choice" -gt ${#backups[@]} ]; then
        print_msg "$C_RED" "❌ Érvénytelen választás."
        return 1
    fi
    
    local selected_backup="${backups[$((restore_choice-1))]}"
    
    print_msg "$C_YELLOW" "⚠️  FIGYELEM: A **${selected_backup}** mentés felülírja az ÖSSZES adatbázist!"
    read -rp "Biztosan folytatja? (i/n): " confirm_restore
    
    if [[ "$confirm_restore" =~ ^[iI](gen)?$ ]]; then
        get_root_password_if_needed
        if [ $? -ne 0 ]; then
            print_msg "$C_RED" "❌ Nincs root jelszó megadva. A visszaállítás megszakítva."
            return 1
        fi
        
        print_msg "$C_CYAN" "🔄 Adatbázis visszaállítása folyamatban: $selected_backup"
        # --force opció szükséges, ha a fájl tartalmazza a DROP DATABASE parancsot
        if mysql -u root -p"${MARIADB_ROOT_PASSWORD}" --force < "$selected_backup" 2>/dev/null; then
            print_msg "$C_GREEN" "✅ Adatbázis sikeresen visszaállítva!"
        else
            print_msg "$C_RED" "❌ Hiba történt a visszaállítás során. (Ellenőrizze a naplókat és a jelszót)"
        fi
    else
        print_msg "$C_YELLOW" "ℹ️  Visszaállítás megszakítva."
    fi
    
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 8. MENTÉSEK KEZELÉSE
function manage_backups() {
    print_msg "$C_BLUE" "## 8. Mentések kezelése ##"
    
    while true; do
        echo -e "\n--- Mentések Kezelése Almenü ---"
        echo "1. Mentések listázása"
        echo "2. Régi mentési könyvtárak törlése (7 napnál régebbiek)"
        echo "3. Vissza a főmenübe"
        read -rp "Választás (1-3): " backup_choice

        case $backup_choice in
            1)
                if [ -d "$BACKUP_DIR_BASE" ]; then
                    echo -e "\n📋 Mentések listája ($BACKUP_DIR_BASE):"
                    # Csak a backup_* könyvtárakat listázzuk
                    find "$BACKUP_DIR_BASE" -type d -name "backup_*" -prune -exec du -sh {} \; | sort -r | while read line; do
                        local size=$(echo "$line" | awk '{print $1}')
                        local dir_path=$(echo "$line" | awk '{print $2}')
                        local dir_name=$(basename "$dir_path")
                        local timestamp_part=$(echo "$dir_name" | sed 's/backup_//')
                        local date_part=$(echo "$timestamp_part" | cut -d'_' -f1)
                        local time_part=$(echo "$timestamp_part" | cut -d'_' -f2 | sed 's/\(..\)/\1:/g; s/:$//')
                        echo "📍 $dir_path (Méret: $size, Dátum: $date_part $time_part)"
                    done
                else
                    print_msg "$C_YELLOW" "ℹ️  Nincsenek mentések."
                fi
                press_enter_to_continue
                ;;
            2)
                print_msg "$C_YELLOW" "🗑️  7 napnál régebbi mentési könyvtárak törlése ($BACKUP_DIR_BASE)..."
                # Csak a 'backup_*' nevű könyvtárakat töröljük, amelyek 7 napnál régebbiek
                find "$BACKUP_DIR_BASE" -type d -name "backup_*" -mtime +7 -exec rm -rf {} \;
                print_msg "$C_GREEN" "✅ Régi mentések törlése befejeződött."
                press_enter_to_continue
                ;;
            3) break ;;
            *) print_msg "$C_RED" "❌ Érvénytelen választás." ;;
        esac
    done
}

# --------------------------------------------------------------------------------------------------

## FŐMENÜ
function main_menu() {
    while true; do
        clear
        echo -e "${C_BLUE}====================================================="
        echo -e "      MariaDB Telepítő és Kezelő Script (v4.2)"
        echo -e "         APACHE2 SPECIFIKUS + ADATBÁZIS MENTÉS"
        echo -e "=====================================================${C_RESET}"
        echo -e "${C_YELLOW}--- Telepítés és Konfiguráció ---${C_RESET}"
        echo "1. Apache2 webszerver telepítése"
        echo "2. phpMyAdmin Telepítése (Apache2-hez)"
        echo "3. MariaDB szerver telepítése"
        echo "4. Hozzáférés Beállítása (Root jelszó, Távoli elérés, Tűzfal)"
        echo -e "${C_YELLOW}--- Adatbázis Kezelés ---${C_RESET}"
        echo "5. Felhasználó- és Jogosultságkezelés"
        echo "6. Adatbázis mentése (WDB formátum) - ÚJ"
        echo "7. Adatbázis visszaállítása - ÚJ"
        echo "8. Mentések kezelése - ÚJ"
        echo -e "${C_YELLOW}--- Egyéb ---${C_RESET}"
        echo "9. Kilépés"
        echo -e "${C_BLUE}=====================================================${C_RESET}"
        read -rp "Választás (1-9): " choice

        case $choice in
            1) setup_apache ;;
            2) install_phpmyadmin_apache ;;
            3) install_mariadb ;;
            4) configure_access ;;
            5) user_management ;;
            6) backup_database ;;
            7) restore_database ;;
            8) manage_backups ;;
            9) echo -e "${C_GREEN}Viszlát! 👋${C_RESET}"; exit 0 ;;
            *) print_msg "$C_RED" "❌ Érvénytelen választás."; press_enter_to_continue ;;
        esac
    done
}

# --- Szkript indítása ---
check_root
main_menu
