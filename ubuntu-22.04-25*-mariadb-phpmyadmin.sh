#!/usr/bin/env bash
# ==============================================================================
# MariaDB Telepítő és Kezelő Szkript
# Készült: Ubuntu 22.04 LTS és újabb, Debian 12/13 rendszerekhez
# Verzió: 4.4 Ubuntu Edition 2025 (Apache2 + phpMyAdmin + Beállítástároló fix)
#
# Főbb bővítések és javítások:
#   - Ubuntu 22.04 LTS kompatibilitás biztosítva
#   - MariaDB repository automatikus javítása
#   - phpMyAdmin beállítástároló automatikus konfigurálása
#   - PHP 8.1 támogatás Ubuntu 22.04-hez
#   - Hozzáférési hibák javítása
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
C_ORANGE='\033[0;33m'

# Ubuntu-specifikus elérési utak
if grep -q "Ubuntu" /etc/os-release; then
    MARIADB_CONFIG="/etc/mysql/mariadb.conf.d/50-server.cnf"
    PHP_VERSION="8.1"
    # Ubuntu verzió detektálása
    if command -v lsb_release >/dev/null; then
        UBUNTU_CODENAME=$(lsb_release -sc)
        UBUNTU_VERSION=$(lsb_release -sr)
    else
        UBUNTU_CODENAME="jammy"
        UBUNTU_VERSION="22.04"
    fi
else
    MARIADB_CONFIG="/etc/mysql/mariadb.conf.d/50-server.cnf"
    PHP_VERSION="8.2"
    UBUNTU_CODENAME="bookworm"
    UBUNTU_VERSION="12"
fi

BACKUP_DIR_BASE="/var/backups/mariadb"
MARIADB_ROOT_PASSWORD=""
PHPMYADMIN_CONFIG="/etc/phpmyadmin/config.inc.php"

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

function get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
}

function get_root_password_if_needed() {
    if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
        print_msg "$C_YELLOW" "⚠️ Kérem, adja meg a MariaDB root jelszavát."
        read -rsp "MariaDB root jelszó: " MARIADB_ROOT_PASSWORD
        echo

        if ! mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "quit" 2>/dev/null; then
            print_msg "$C_RED" "❌ Érvénytelen MariaDB root jelszó. Kérem, próbálja újra."
            MARIADB_ROOT_PASSWORD=""
            return 1
        fi
        return 0
    fi
    return 0
}

function fix_mariadb_repository() {
    print_msg "$C_CYAN" "🔧 MariaDB repository problémák javítása..."
    
    # Repository fájl ellenőrzése
    local repo_file="/etc/apt/sources.list.d/mariadb.list"
    
    if [ -f "$repo_file" ]; then
        print_msg "$C_YELLOW" "📝 MariaDB repository fájl található: $repo_file"
        
        # Helytelen codename keresése és javítása
        if grep -q "plucky" "$repo_file"; then
            print_msg "$C_YELLOW" "🔄 'plucky' helyettesítése '$UBUNTU_CODENAME'-re..."
            sed -i "s/plucky/$UBUNTU_CODENAME/g" "$repo_file"
            print_msg "$C_GREEN" "✅ Repository fájl javítva."
        fi
        
        # Tartalom megjelenítése
        echo -e "\n📄 Repository tartalma:"
        cat "$repo_file"
    else
        print_msg "$C_YELLOW" "ℹ️  Nincs MariaDB repository fájl."
    fi
    
    # Apt források modernizálása (ha szükséges)
    if apt update 2>&1 | grep -q "modernize-sources"; then
        print_msg "$C_CYAN" "🔄 Apt források modernizálása..."
        apt modernize-sources -y
    fi
    
    # Frissítés
    print_msg "$C_CYAN" "📦 Csomaglisták frissítése..."
    if apt update; then
        print_msg "$C_GREEN" "✅ Repository problémák javítva és csomaglisták frissítve."
    else
        print_msg "$C_RED" "❌ Hiba a frissítés során. Kérem, ellenőrizze a repository beállításokat."
        return 1
    fi
}

function add_mariadb_repository() {
    print_msg "$C_CYAN" "📦 MariaDB hivatalos repository hozzáadása..."
    
    # Régi repository-k eltávolítása
    if [ -f "/etc/apt/sources.list.d/mariadb.list" ]; then
        rm -f /etc/apt/sources.list.d/mariadb.list
    fi
    
    # Függőségek telepítése
    apt-get install -y apt-transport-https curl
    
    # MariaDB GPG kulcs hozzáadása
    curl -o /etc/apt/trusted.gpg.d/mariadb_repo_signing_key.asc 'https://mariadb.org/mariadb_release_signing_key.asc'
    
    # Helyes repository hozzáadása
    sh -c "echo 'deb [arch=amd64,arm64,ppc64el] https://mirrors.gigenet.com/mariadb/repo/10.11/ubuntu $UBUNTU_CODENAME main' > /etc/apt/sources.list.d/mariadb.list"
    
    # Frissítés
    apt-get update
}

# --------------------------------------------------------------------------------------------------

## 1. APACHE2 TELEPÍTÉS ÉS BEÁLLÍTÁS
function setup_apache() {
    print_msg "$C_BLUE" "## 1. Apache2 webszerver telepítése és konfigurálása ##"
    
    get_os_info
    print_msg "$C_CYAN" "🔍 Operációs rendszer: $OS_NAME $OS_VERSION"
    
    # Repository problémák javítása
    fix_mariadb_repository
    
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
    a2enmod ssl &>/dev/null
    
    # Apache2 szolgáltatás kezelése
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

## 2. JAVÍTOTT PHPMYADMIN TELEPÍTÉS - Beállítástároló fix-szel
function install_phpmyadmin_apache() {
    print_msg "$C_BLUE" "## 2. phpMyAdmin Telepítése (Beállítástároló fix-szel) ##"
    
    get_os_info
    print_msg "$C_CYAN" "🔍 Operációs rendszer: $OS_NAME $OS_VERSION"
    
    # Root jelszó ellenőrzése
    get_root_password_if_needed
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nincs MariaDB root jelszó. A phpMyAdmin telepítése megszakítva."
        return 1
    fi

    # PHP és szükséges bővítmények telepítése
    print_msg "$C_CYAN" "📦 PHP és szükséges modulok telepítése..."
    
    # PHP verzió detektálása Ubuntu alapján
    if grep -q "Ubuntu 22.04" /etc/os-release; then
        PHP_PACKAGES="php8.1 php8.1-mysql php8.1-mbstring php8.1-curl php8.1-zip php8.1-gd php8.1-xml"
    else
        PHP_PACKAGES="php php-mysql php-mbstring php-curl php-zip php-gd php-xml"
    fi
    
    if ! apt-get install -y $PHP_PACKAGES; then
        print_msg "$C_RED" "❌ Hiba történt a PHP modulok telepítése során."
        return 1
    fi
    
    # phpMyAdmin telepítése nem interaktív módon
    print_msg "$C_CYAN" "📦 phpMyAdmin telepítése..."
    export DEBIAN_FRONTEND=noninteractive
    
    # Előző phpMyAdmin konfigurációk eltávolítása (ha vannak)
    if dpkg -s phpmyadmin &>/dev/null; then
        apt-get remove --purge -y phpmyadmin
    fi
    
    # Válaszok beállítása
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MARIADB_ROOT_PASSWORD" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $MARIADB_ROOT_PASSWORD" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $MARIADB_ROOT_PASSWORD" | debconf-set-selections
    
    if ! apt-get install -yq phpmyadmin; then
        print_msg "$C_RED" "❌ Hiba a phpMyAdmin telepítése során."
        return 1
    fi
    
    # Beállítástároló konfigurálása
    configure_phpmyadmin_storage
    
    # Apache konfiguráció aktiválása
    print_msg "$C_CYAN" "⚙️  Apache2 konfigurálása a phpMyAdmin-hoz..."
    a2enconf phpmyadmin &>/dev/null
    
    # PHP memória limit növelése
    if [ -f "/etc/php/8.1/apache2/php.ini" ]; then
        sed -i 's/^memory_limit = .*/memory_limit = 256M/' /etc/php/8.1/apache2/php.ini
    fi
    
    systemctl reload apache2
    
    print_msg "$C_GREEN" "✅ A phpMyAdmin sikeresen telepítve és konfigurálva."
    print_msg "$C_CYAN" "🌐 Elérhető itt: http://$(hostname -I | awk '{print $1}')/phpmyadmin"
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## PHPMYADMIN BEÁLLÍTÁSTÁROLÓ KONFIGURÁLÁSA
function configure_phpmyadmin_storage() {
    print_msg "$C_CYAN" "🔧 phpMyAdmin beállítástároló konfigurálása..."
    
    get_root_password_if_needed
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nincs root jelszó. A beállítástároló konfigurálása kihagyva."
        return 1
    fi
    
    # 1. Adatbázis és táblák létrehozása
    print_msg "$C_CYAN" "📦 Beállítástároló adatbázis létrehozása..."
    
    # SQL fájl keresése
    local sql_file=""
    if [ -f "/usr/share/phpmyadmin/sql/create_tables.sql" ]; then
        sql_file="/usr/share/phpmyadmin/sql/create_tables.sql"
    elif [ -f "/usr/share/doc/phpmyadmin/sql/create_tables.sql" ]; then
        sql_file="/usr/share/doc/phpmyadmin/sql/create_tables.sql"
    else
        print_msg "$C_YELLOW" "⚠️  create_tables.sql fájl nem található. Kérem, telepítse manuálisan."
        return 1
    fi
    
    # Adatbázis létrehozása
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" < "$sql_file" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Hiba a beállítástároló adatbázis létrehozásakor."
        return 1
    fi
    
    # 2. Dedikált felhasználó létrehozása
    print_msg "$C_CYAN" "👤 Dedikált felhasználó létrehozása a beállítástárolóhoz..."
    
    local pma_password=$(openssl rand -base64 16)
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF 2>/dev/null
CREATE USER IF NOT EXISTS 'pma'@'localhost' IDENTIFIED BY '${pma_password}';
GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'pma'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # 3. Konfigurációs fájl módosítása
    print_msg "$C_CYAN" "⚙️  Konfigurációs fájl frissítése..."
    
    if [ -f "$PHPMYADMIN_CONFIG" ]; then
        # Biztonsági mentés
        cp "$PHPMYADMIN_CONFIG" "${PHPMYADMIN_CONFIG}.backup"
        
        # Konfiguráció hozzáadása
        cat >> "$PHPMYADMIN_CONFIG" <<EOF

/* phpMyAdmin konfigurációs tároló beállításai - Automatikus beállítás */
\$cfg['Servers'][\$i]['controlhost'] = 'localhost';
\$cfg['Servers'][\$i]['controluser'] = 'pma';
\$cfg['Servers'][\$i]['controlpass'] = '${pma_password}';
\$cfg['Servers'][\$i]['pmadb'] = 'phpmyadmin';
\$cfg['Servers'][\$i]['bookmarktable'] = 'pma__bookmark';
\$cfg['Servers'][\$i]['relation'] = 'pma__relation';
\$cfg['Servers'][\$i]['table_info'] = 'pma__table_info';
\$cfg['Servers'][\$i]['table_coords'] = 'pma__table_coords';
\$cfg['Servers'][\$i]['pdf_pages'] = 'pma__pdf_pages';
\$cfg['Servers'][\$i]['column_info'] = 'pma__column_info';
\$cfg['Servers'][\$i]['history'] = 'pma__history';
\$cfg['Servers'][\$i]['table_uiprefs'] = 'pma__table_uiprefs';
\$cfg['Servers'][\$i]['tracking'] = 'pma__tracking';
\$cfg['Servers'][\$i]['userconfig'] = 'pma__userconfig';
\$cfg['Servers'][\$i]['recent'] = 'pma__recent';
\$cfg['Servers'][\$i]['favorite'] = 'pma__favorite';
\$cfg['Servers'][\$i]['users'] = 'pma__users';
\$cfg['Servers'][\$i]['usergroups'] = 'pma__usergroups';
\$cfg['Servers'][\$i]['navigationhiding'] = 'pma__navigationhiding';
\$cfg['Servers'][\$i]['savedsearches'] = 'pma__savedsearches';
\$cfg['Servers'][\$i]['central_columns'] = 'pma__central_columns';
\$cfg['Servers'][\$i]['designer_settings'] = 'pma__designer_settings';
\$cfg['Servers'][\$i]['export_templates'] = 'pma__export_templates';
EOF
        
        print_msg "$C_GREEN" "✅ Beállítástároló sikeresen konfigurálva."
        print_msg "$C_CYAN" "📝 Felhasználó: pma, Jelszó: ${pma_password}"
    else
        print_msg "$C_RED" "❌ phpMyAdmin konfigurációs fájl nem található: $PHPMYADMIN_CONFIG"
        return 1
    fi
}

# --------------------------------------------------------------------------------------------------

## 3. MARIADB SZERVER TELEPÍTÉSE - Ubuntu optimalizált
function install_mariadb() {
    print_msg "$C_BLUE" "## 3. MariaDB szerver telepítése (Ubuntu optimalizált) ##"

    get_os_info
    print_msg "$C_CYAN" "🔍 Operációs rendszer: $OS_NAME $OS_VERSION"

    # Repository problémák javítása
    fix_mariadb_repository

    # Csomaglisták frissítése
    print_msg "$C_CYAN" "📦 Csomaglisták frissítése..."
    if ! apt-get update -y; then
        print_msg "$C_RED" "❌ Hiba történt a csomaglisták frissítése során."
        return 1
    fi

    # MariaDB repository hozzáadása (opcionális - csak ha nincs)
    read -rp "Szeretné hozzáadni a hivatalos MariaDB repository-t a legújabb verzióhoz? (i/n): " add_repo
    if [[ "$add_repo" =~ ^[iI](gen)?$ ]]; then
        add_mariadb_repository
    fi

    # MariaDB szerver telepítése
    print_msg "$C_CYAN" "📦 MariaDB szerver telepítése..."
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

    # Ubuntu-specifikus biztonsági beállítások
    if grep -q "Ubuntu" /etc/os-release; then
        print_msg "$C_CYAN" "🔒 Ubuntu-specifikus biztonsági beállítások..."
        # Biztonságos telepítési script futtatása
        if command -v mysql_secure_installation &>/dev/null; then
            print_msg "$C_YELLOW" "⚠️  Futtassa manuálisan a 'mysql_secure_installation' parancsot a biztonsági beállításokhoz."
        fi
    fi

    # A szolgáltatás állapotának ellenőrzése
    if systemctl is-active --quiet mariadb.service; then
        print_msg "$C_GREEN" "✅ A MariaDB sikeresen telepítve és fut."
        print_msg "$C_CYAN" "📊 MariaDB verzió: $(mysqld --version 2>/dev/null | cut -d' ' -f2-4)"
    else
        print_msg "$C_RED" "❌ A MariaDB telepítése sikeres, de a szolgáltatás nem fut."
        return 1
    fi

    print_msg "$C_YELLOW" "⚠️  Kérem, a 4. menüpontban állítsa be a root jelszót és a hozzáférést!"
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 4. HOZZÁFÉRÉS BEÁLLÍTÁSA - Ubuntu kompatibilis
function configure_access() {
    print_msg "$C_BLUE" "## 4. MariaDB Hozzáférés Beállítása ##"
    
    # Először ellenőrizzük, hogy fut-e a MariaDB
    if ! systemctl is-active --quiet mariadb.service; then
        print_msg "$C_RED" "❌ A MariaDB szolgáltatás nem fut. Először indítsa el!"
        systemctl start mariadb.service
    fi
    
    print_msg "$C_CYAN" "🔐 MariaDB Root Jelszó Beállítása..."
    local new_root_password
    local confirm_password
    
    while true; do
        read -rsp "Új MariaDB Root Jelszó: " new_root_password
        echo
        read -rsp "Jelszó megerősítése: " confirm_password
        echo
        
        if [ -z "$new_root_password" ]; then
            print_msg "$C_RED" "❌ A jelszó nem lehet üres!"
            continue
        fi
        
        if [ "$new_root_password" != "$confirm_password" ]; then
            print_msg "$C_RED" "❌ A jelszavak nem egyeznek!"
            continue
        fi
        break
    done

    # Jelszó beállítása Ubuntu/Debian kompatibilis módon
    print_msg "$C_CYAN" "⚙️  Root jelszó beállítása..."
    
    # MySQL/MariaDB szolgáltatás újraindítása biztonsági okokból
    systemctl restart mariadb.service
    
    # Jelszó beállítása alternatív módszerrel
    mysql -u root <<EOF 2>/dev/null
ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_root_password}';
FLUSH PRIVILEGES;
EOF

    if [ $? -eq 0 ]; then
        MARIADB_ROOT_PASSWORD="$new_root_password"
        print_msg "$C_GREEN" "✅ Root jelszó sikeresen beállítva."
    else
        # Alternatív módszer socket autentikációval
        sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${new_root_password}'; FLUSH PRIVILEGES;" 2>/dev/null
        if [ $? -eq 0 ]; then
            MARIADB_ROOT_PASSWORD="$new_root_password"
            print_msg "$C_GREEN" "✅ Root jelszó sikeresen beállítva (socket auth)."
        else
            print_msg "$C_RED" "❌ Hiba történt a jelszó beállítása során."
            return 1
        fi
    fi
    
    # Távoli hozzáférés beállítása
    read -rp "Engedélyezi a távoli root hozzáférést? (i/n): " remote_access
    if [[ "$remote_access" =~ ^[iI](gen)?$ ]]; then
        print_msg "$C_CYAN" "🌐 Távoli hozzáférés beállítása..."
        
        # Root felhasználó létrehozása minden hostról
        mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF 2>/dev/null
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
        
        # MariaDB konfiguráció módosítása
        if [ -f "$MARIADB_CONFIG" ]; then
            sed -i 's/^bind-address\s*=\s*127.0.0.1/#bind-address = 127.0.0.1\nbind-address = 0.0.0.0/' "$MARIADB_CONFIG"
        else
            print_msg "$C_YELLOW" "⚠️  MariaDB konfigurációs fájl nem található: $MARIADB_CONFIG"
        fi
        
        systemctl restart mariadb.service
        
        # Tűzfal beállítása
        if command_exists ufw && ufw status | grep -q "active"; then
            ufw allow 3306/tcp &>/dev/null
            print_msg "$C_GREEN" "✅ Tűzfalszabály hozzáadva a 3306-os porthoz."
        fi
        
        print_msg "$C_GREEN" "✅ Távoli hozzáférés engedélyezve."
    else
        print_msg "$C_YELLOW" "ℹ️  Távoli hozzáférés tiltva (alapértelmezett)."
    fi

    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 5. FELHASZNÁLÓ- ÉS JOGOSULTSÁGKEZELÉS
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

## 6. ADATBÁZIS MENTÉSE - Ubuntu kompatibilis
function backup_database() {
    print_msg "$C_BLUE" "## 6. Adatbázis mentése (WDB formátum) ##"
    
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
    if ! mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases --single-transaction --routines --events > "$backup_file" 2>/dev/null; then
        print_msg "$C_RED" "❌ Hiba történt az adatbázis mentése során."
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
    ln -sfn "$backup_dir" "$latest_backup"
    print_msg "$C_CYAN" "🔗 Legutóbbi mentés linkje frissítve: $latest_backup"

    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 7. ADATBÁZIS VISSZAÁLLÍTÁSI FUNKCIÓ
function restore_database() {
    print_msg "$C_BLUE" "## 7. Adatbázis visszaállítása ##"
    
    if [ ! -d "$BACKUP_DIR_BASE" ]; then
        print_msg "$C_RED" "❌ Nincsenek mentések a $BACKUP_DIR_BASE könyvtárban."
        return 1
    fi
    
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
        if mysql -u root -p"${MARIADB_ROOT_PASSWORD}" --force < "$selected_backup" 2>/dev/null; then
            print_msg "$C_GREEN" "✅ Adatbázis sikeresen visszaállítva!"
        else
            print_msg "$C_RED" "❌ Hiba történt a visszaállítás során."
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

## 9. RENDSZER INFORMÁCIÓK
function system_info() {
    print_msg "$C_BLUE" "## 9. Rendszer információk ##"
    
    get_os_info
    echo -e "\n📊 Alapvető információk:"
    echo "  Operációs rendszer: $OS_NAME $OS_VERSION"
    echo "  Hostnév: $(hostname)"
    echo "  IP cím: $(hostname -I | awk '{print $1}')"
    
    echo -e "\n🔧 Szolgáltatások állapota:"
    systemctl is-active --quiet apache2 && echo "  ✅ Apache2: fut" || echo "  ❌ Apache2: nem fut"
    systemctl is-active --quiet mariadb && echo "  ✅ MariaDB: fut" || echo "  ❌ MariaDB: nem fut"
    
    echo -e "\n💾 Adatbázis információk:"
    if command_exists mysql && systemctl is-active --quiet mariadb; then
        get_root_password_if_needed
        if [ $? -eq 0 ]; then
            echo "  MariaDB verzió: $(mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT VERSION();" 2>/dev/null | tail -1)"
        fi
    fi
    
    echo -e "\n📁 Mentések helye: $BACKUP_DIR_BASE"
    if [ -d "$BACKUP_DIR_BASE" ]; then
        local backup_count=$(find "$BACKUP_DIR_BASE" -type d -name "backup_*" | wc -l)
        echo "  Mentések száma: $backup_count"
    else
        echo "  Mentések száma: 0"
    fi
    
    # phpMyAdmin állapot
    echo -e "\n🌐 phpMyAdmin állapot:"
    if [ -d "/usr/share/phpmyadmin" ]; then
        echo "  ✅ phpMyAdmin: telepítve"
        if [ -f "$PHPMYADMIN_CONFIG" ]; then
            echo "  ✅ Konfiguráció: OK"
        else
            echo "  ⚠️  Konfiguráció: hiányzó"
        fi
    else
        echo "  ❌ phpMyAdmin: nincs telepítve"
    fi
    
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 10. PHPMYADMIN BEÁLLÍTÁSTÁROLÓ JAVÍTÁS
function fix_phpmyadmin_storage() {
    print_msg "$C_BLUE" "## 10. phpMyAdmin Beállítástároló Javítása ##"
    
    get_root_password_if_needed
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nincs root jelszó. A javítás megszakítva."
        return 1
    fi
    
    print_msg "$C_CYAN" "🔧 phpMyAdmin beállítástároló konfigurálása..."
    configure_phpmyadmin_storage
    
    # Apache újraindítása
    systemctl restart apache2
    print_msg "$C_GREEN" "✅ phpMyAdmin beállítástároló javítva és Apache újraindítva."
    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## 11. PHPMYADMIN HOZZÁFÉRÉSI HIBA AZONNALI JAVÍTÁSA
function fix_phpmyadmin_access() {
    print_msg "$C_ORANGE" "## 11. phpMyAdmin Hozzáférési Hiba Azonnali Javítása ##"
    print_msg "$C_ORANGE" "   (Access denied for user 'phpmyadmin'@'localhost') ##"
    
    # Root jelszó ellenőrzése
    get_root_password_if_needed
    if [ $? -ne 0 ]; then
        print_msg "$C_RED" "❌ Nincs root jelszó. A javítás megszakítva."
        return 1
    fi

    print_msg "$C_ORANGE" "🔧 phpMyAdmin hozzáférési probléma javítása..."
    
    # 1. Kapcsolódási teszt
    print_msg "$C_CYAN" "🔍 Kapcsolódás tesztelése..."
    if ! mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null; then
        print_msg "$C_RED" "❌ Nem sikerült csatlakozni a MariaDB-hez a megadott jelszóval."
        return 1
    fi

    print_msg "$C_GREEN" "✅ Sikeres kapcsolódás a MariaDB-hez."

    # 2. phpmyadmin felhasználó javítása
    print_msg "$C_CYAN" "👤 phpmyadmin felhasználó javítása..."

    # Ellenőrizzük, hogy létezik-e a felhasználó
    USER_EXISTS=$(mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -sN -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = 'phpmyadmin' AND host = 'localhost');")

    if [ "$USER_EXISTS" -eq 1 ]; then
        print_msg "$C_YELLOW" "ℹ️  phpmyadmin felhasználó már létezik, jelszó visszaállítása..."
        mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF
ALTER USER 'phpmyadmin'@'localhost' IDENTIFIED BY 'phpmyadmin';
FLUSH PRIVILEGES;
EOF
    else
        print_msg "$C_YELLOW" "ℹ️  phpmyadmin felhasználó létrehozása..."
        mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF
CREATE USER 'phpmyadmin'@'localhost' IDENTIFIED BY 'phpmyadmin';
GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    fi

    # 3. Konfigurációs fájl javítása
    print_msg "$C_CYAN" "⚙️  Konfigurációs fájl javítása..."

    if [ -f "$PHPMYADMIN_CONFIG" ]; then
        # Biztonsági mentés
        cp "$PHPMYADMIN_CONFIG" "${PHPMYADMIN_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Control user beállítások hozzáadása/módosítása
        if grep -q "controluser" "$PHPMYADMIN_CONFIG"; then
            sed -i "s/\$cfg\['Servers'\]\[\$i\]\['controluser'\].*/\$cfg\['Servers'\]\[\$i\]\['controluser'\] = 'phpmyadmin';/" "$PHPMYADMIN_CONFIG"
            sed -i "s/\$cfg\['Servers'\]\[\$i\]\['controlpass'\].*/\$cfg\['Servers'\]\[\$i\]\['controlpass'\] = 'phpmyadmin';/" "$PHPMYADMIN_CONFIG"
        else
            cat >> "$PHPMYADMIN_CONFIG" <<'EOF'

/* phpMyAdmin hozzáférési hiba javítás - Automatikus beállítás */
$cfg['Servers'][$i]['controlhost'] = 'localhost';
$cfg['Servers'][$i]['controluser'] = 'phpmyadmin';
$cfg['Servers'][$i]['controlpass'] = 'phpmyadmin';
EOF
        fi
        print_msg "$C_GREEN" "✅ Konfigurációs fájl javítva."
    else
        print_msg "$C_RED" "❌ phpMyAdmin konfigurációs fájl nem található."
    fi

    # 4. Jogosultságok beállítása
    print_msg "$C_CYAN" "🔐 Jogosultságok beállítása..."
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<EOF
GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin'@'localhost';
FLUSH PRIVILEGES;
EOF

    print_msg "$C_GREEN" "✅ Jogosultságok beállítva."

    # 5. Apache újraindítása
    print_msg "$C_CYAN" "🔄 Apache újraindítása..."
    systemctl restart apache2

    print_msg "$C_GREEN" "✅ Apache újraindítva."

    # 6. Végeredmény
    echo
    print_msg "$C_ORANGE" "================================================="
    print_msg "$C_GREEN" "✅ HOZZÁFÉRÉSI HIBA JAVÍTVA!"
    print_msg "$C_CYAN" "📋 Elvégzett műveletek:"
    print_msg "$C_CYAN" "   ✓ phpmyadmin felhasználó létrehozva/javítva"
    print_msg "$C_CYAN" "   ✓ Jelszó beállítva: 'phpmyadmin'"
    print_msg "$C_CYAN" "   ✓ Konfigurációs fájl frissítve"
    print_msg "$C_CYAN" "   ✓ Jogosultságok beállítva"
    print_msg "$C_CYAN" "   ✓ Apache újraindítva"
    print_msg "$C_ORANGE" "================================================="
    echo
    print_msg "$C_YELLOW" "🌐 Most próbálja meg újra megnyitni a phpMyAdmin-t:"
    print_msg "$C_CYAN" "   http://$(hostname -I | awk '{print $1}')/phpmyadmin"
    echo
    print_msg "$C_YELLOW" "🔐 Bejelentkezési adatok:"
    print_msg "$C_CYAN" "   Felhasználónév: phpmyadmin"
    print_msg "$C_CYAN" "   Jelszó: phpmyadmin"
    echo
    print_msg "$C_RED" "⚠️  FONTOS: Biztonsági okokból változtassa meg a jelszót!"
    print_msg "$C_ORANGE" "================================================="

    press_enter_to_continue
}

# --------------------------------------------------------------------------------------------------

## FŐMENÜ - Ubuntu Edition
function main_menu() {
    while true; do
        clear
        get_os_info
        echo -e "${C_BLUE}====================================================="
        echo -e "      MariaDB Telepítő és Kezelő Script (v4.4)"
        echo -e "            UBUNTU EDITION - $OS_NAME $OS_VERSION"
        echo -e "          (Beállítástároló + Hozzáférési fix)"
        echo -e "=====================================================${C_RESET}"
        echo -e "${C_YELLOW}--- Telepítés és Konfiguráció ---${C_RESET}"
        echo "1. Apache2 webszerver telepítése"
        echo "2. phpMyAdmin Telepítése (Beállítástároló fix-szel)"
        echo "3. MariaDB szerver telepítése"
        echo "4. Hozzáférés Beállítása (Root jelszó, Távoli elérés, Tűzfal)"
        echo -e "${C_YELLOW}--- Adatbázis Kezelés ---${C_RESET}"
        echo "5. Felhasználó- és Jogosultságkezelés"
        echo "6. Adatbázis mentése (WDB formátum)"
        echo "7. Adatbázis visszaállítása"
        echo "8. Mentések kezelése"
        echo -e "${C_ORANGE}--- Javítások és Ellenőrzések ---${C_RESET}"
        echo "9. Rendszer információk"
        echo "10. phpMyAdmin beállítástároló javítása"
        echo "11. 🚨 phpMyAdmin hozzáférési hiba javítása"
        echo -e "${C_YELLOW}--- Egyéb ---${C_RESET}"
        echo "0. Kilépés"
        echo -e "${C_BLUE}=====================================================${C_RESET}"
        read -rp "Választás (0-11): " choice

        case $choice in
            1) setup_apache ;;
            2) install_phpmyadmin_apache ;;
            3) install_mariadb ;;
            4) configure_access ;;
            5) user_management ;;
            6) backup_database ;;
            7) restore_database ;;
            8) manage_backups ;;
            9) system_info ;;
            10) fix_phpmyadmin_storage ;;
            11) fix_phpmyadmin_access ;;
            0) echo -e "${C_GREEN}Viszlát! 👋${C_RESET}"; exit 0 ;;
            *) print_msg "$C_RED" "❌ Érvénytelen választás."; press_enter_to_continue ;;
        esac
    done
}

# --- Szkript indítása ---
check_root

# Repository problémák ellenőrzése induláskor
print_msg "$C_CYAN" "🔍 Repository problémák ellenőrzése..."
fix_mariadb_repository

main_menu
