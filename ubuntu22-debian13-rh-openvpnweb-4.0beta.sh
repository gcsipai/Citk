#!/bin/bash
# --------------------------------------------------------------------------------
# OpenVPN Kliens Webes Elérés Telepítő Szkript - VÉGLEGES TISZTA VERZIÓ (v4.0)
# Jellemzők: Interaktív, Jogosultság-javítás, Világos, Letisztult Design (ikonok nélkül), VPN Státusz Ellenőrzés.
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
# --- KONFIGURÁCIÓS BEÁLLÍTÁSOK ---
# --------------------------------------------------------------------------------

DEFAULT_OVPN_SOURCE_DIR="/etc/openvpn/server/ovpn_clients" 
WWW_ROOT="/var/www/html"
DOWNLOAD_SUBDIR="ovpn_downloads"
TARGET_DIR="$WWW_ROOT/$DOWNLOAD_SUBDIR"
WWW_USER="www-data" 
VPN_SERVICE_NAME="openvpn-server@server" 

# --- SZÍNEK ÉS ELŐKÉSZÜLETEK ---
GREEN_BOLD='\033[1;32m'
RED_BOLD='\033[1;31m'
YELLOW_BOLD='\033[1;33m'
RESET='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED_BOLD}⚠️ Ezt a szkriptet root (sudo) joggal kell futtatni.${RESET}"
   exit 1
fi

echo -e "${GREEN_BOLD}--- 🌐 OpenVPN Webes Interfész Telepítése (v4.0 - Tiszta Design) ---${RESET}"

# --------------------------------------------------------------------------------
# LÉPÉS 0: Interaktív Bekérdezések és Fájltisztítás
# --------------------------------------------------------------------------------
echo -e "${YELLOW_BOLD}\n[0/6] Interaktív beállítások és fájltisztítás...${RESET}"

# 0.1 Régi index.html törlése
if [[ -f "$WWW_ROOT/index.html" ]]; then
    rm "$WWW_ROOT/index.html"
    echo -e "${GREEN_BOLD}✅ Régi index.html fájl törölve.${RESET}"
fi

# 0.2 Forráskönyvtár bekérése
read -rp "1. Adja meg az OVPN fájlok könyvtárát (Alapértelmezett: $DEFAULT_OVPN_SOURCE_DIR): " OVPN_SOURCE_DIR_INPUT
OVPN_SOURCE_DIR="${OVPN_SOURCE_DIR_INPUT:-$DEFAULT_OVPN_SOURCE_DIR}"
if [[ ! -d "$OVPN_SOURCE_DIR" ]]; then
    echo -e "${YELLOW_BOLD}ℹ️ A forrásmappa ($OVPN_SOURCE_DIR) nem létezik. Létrehozom.${RESET}"
    mkdir -p "$OVPN_SOURCE_DIR"
fi

# 0.3 Jelszó bekérése
read -rp "2. Adja meg a weboldalhoz használandó JELSZÓT: " VPN_DOWNLOAD_PASSWORD
if [[ -z "$VPN_DOWNLOAD_PASSWORD" ]]; then
    echo -e "${RED_BOLD}❌ Hiba: A jelszó nem lehet üres. Lépjen ki, és próbálja újra.${RESET}"
    exit 1
fi

# --------------------------------------------------------------------------------
# LÉPÉS 1: Jogosultságok Beállítása (CRITIKUS: /home mappa javítása)
# --------------------------------------------------------------------------------
echo -e "${YELLOW_BOLD}\n[1/6] Jogosultságok beállítása (ACL)...${RESET}"

if ! command -v setfacl &> /dev/null; then
    echo -e "ℹ️ Telepítem az 'acl' csomagot."
    apt update && apt install -y acl
fi

# Beállítja a www-data felhasználó olvasási jogát
setfacl -m u:$WWW_USER:rx "$OVPN_SOURCE_DIR"
setfacl -m d:u:$WWW_USER:rx "$OVPN_SOURCE_DIR"
chmod g+r "$OVPN_SOURCE_DIR"/*.ovpn 2>/dev/null 
chown -R root:"$WWW_USER" "$OVPN_SOURCE_DIR" 2>/dev/null

echo -e "${GREEN_BOLD}✅ Jogosultságok beállítva a $WWW_USER számára.${RESET}"

# --------------------------------------------------------------------------------
# LÉPÉS 2: Webszerver (Apache2) és PHP Telepítése
# --------------------------------------------------------------------------------
echo -e "${YELLOW_BOLD}\n[2/6] Webszerver telepítése: Apache2 és PHP...${RESET}"
apt install -y apache2 php libapache2-mod-php php-cli

if [ $? -ne 0 ]; then
    echo -e "${RED_BOLD}❌ Hiba: Az Apache2/PHP telepítése sikertelen.${RESET}"
    exit 1
fi
echo -e "${GREEN_BOLD}✅ Apache2 és PHP sikeresen telepítve.${RESET}"

# --------------------------------------------------------------------------------
# LÉPÉS 3: Mappa Struktúra és Apache Konfiguráció
# --------------------------------------------------------------------------------
echo -e "${YELLOW_BOLD}\n[3/6] Mappa struktúra és Apache konfigurálása...${RESET}"
mkdir -p "$TARGET_DIR"

chown -R www-data:www-data "$WWW_ROOT"
chmod 755 "$WWW_ROOT"

if ! grep -q "FollowSymLinks" /etc/apache2/apache2.conf; then
    cat >> /etc/apache2/apache2.conf << EOF

<Directory /var/www/html/ovpn_downloads>
    Options FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
EOF
    echo -e "${GREEN_BOLD}✅ Apache konfiguráció frissítve.${RESET}"
fi

systemctl restart apache2
echo -e "${GREEN_BOLD}✅ Apache2 újraindítva.${RESET}"

# --------------------------------------------------------------------------------
# LÉPÉS 4: VPN Státusz Ellenőrző Script (PHP/Bash)
# --------------------------------------------------------------------------------
echo -e "${YELLOW_BOLD}\n[4/6] VPN Státusz ellenőrző fájl generálása...${RESET}"

# A PHP script lefuttatja a systemctl parancsot és kiírja az eredményt (Fut vagy Nem fut)
cat > "$WWW_ROOT/vpn_status.php" << EOL
<?php
// Ellenőrzi az OpenVPN szolgáltatás állapotát a szerveren
\$service_name = "$VPN_SERVICE_NAME";
\$output = shell_exec("systemctl is-active \$service_name 2>&1");
\$status = trim(\$output);

if (\$status === 'active') {
    echo '<span class="badge text-bg-success">FUT</span>';
} elseif (\$status === 'inactive') {
    echo '<span class="badge text-bg-warning">NEM FUT</span>';
} elseif (\$status === 'failed') {
    echo '<span class="badge text-bg-danger">HIBA</span>';
} else {
    echo '<span class="badge text-bg-secondary">ISMERETLEN</span>';
}
?>
EOL
chmod 755 "$WWW_ROOT/vpn_status.php" # Futtatási jog a PHP számára

# --------------------------------------------------------------------------------
# LÉPÉS 5: Webes Kód Generálása (Világos, Ikonok Nélkül)
# --------------------------------------------------------------------------------
echo -e "${YELLOW_BOLD}\n[5/6] Webes kód (Letisztult Design) generálása...${RESET}"

# config.php létrehozása 
cat > "$WWW_ROOT/config.php" << EOL
<?php
\$PASSWORD = "$VPN_DOWNLOAD_PASSWORD"; 
\$DOWNLOAD_DIR = "$DOWNLOAD_SUBDIR/";
\$MIN_FILE_SIZE = 1000;
?>
EOL
chmod 644 "$WWW_ROOT/config.php"

# index.php létrehozása (Letisztult, világos téma, ikonok nélkül)
cat > "$WWW_ROOT/index.php" << 'EOL'
<?php
session_start();
include 'config.php';

$error = '';
$is_authenticated = false;

if (isset($_POST['password'])) {
    if ($_POST['password'] === $PASSWORD) {
        $_SESSION['authenticated'] = true;
        $is_authenticated = true;
    } else {
        $error = "Helytelen jelszó!";
    }
} elseif (isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true) {
    $is_authenticated = true;
}

if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: index.php");
    exit();
}
?>
<!DOCTYPE html>
<html lang="hu">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenVPN Kliens Letöltő</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        /* Világos háttér gradiens */
        body { background: linear-gradient(135deg, #f0f8ff 0%, #e0eafc 100%); min-height: 100vh; padding: 40px 20px; }
        /* Kártya stílus */
        .app-card { background: white; border-radius: 12px; box-shadow: 0 5px 20px rgba(0, 0, 0, 0.1); overflow: hidden; }
        /* Tiszta kék fejléc */
        .app-header { background: #007bff; color: white; padding: 20px; text-align: center; }
        .alert-danger { background-color: #f8d7da; color: #721c24; border-color: #f5c6cb; }
        .file-item { border-left: 3px solid #007bff; margin-bottom: 8px; }
    </style>
</head>
<body>
<div class="container">
    <div class="row justify-content-center">
        <div class="col-md-7">
            <div class="app-card">
                <div class="app-header">
                    <h4 class="mb-0">OpenVPN Kliens Elérés</h4>
                    <small>Belső hálózati letöltő</small>
                </div>
                <div class="card-body p-4">
                    <?php if (!$is_authenticated): ?>
                        <h5 class="card-title text-center mb-4 text-muted">Belépés</h5>
                        <?php if ($error): ?>
                            <div class="alert alert-danger" role="alert"><?= $error ?></div>
                        <?php endif; ?>
                        <form method="POST">
                            <div class="mb-3">
                                <input type="password" class="form-control form-control-lg" name="password" placeholder="Jelszó" required>
                            </div>
                            <button type="submit" class="btn btn-primary btn-lg w-100">Belépés</button>
                        </form>
                    <?php else: ?>
                        <div class="d-flex justify-content-between align-items-center mb-4 pb-2 border-bottom">
                            <h5 class="card-title mb-0 text-primary">Elérhető Kliens Fájlok</h5>
                            <a href="?logout=1" class="btn btn-outline-secondary btn-sm">Kilépés</a>
                        </div>
                        
                        <div class="alert alert-light py-2 mb-4 d-flex justify-content-between align-items-center border">
                            <strong>VPN Szerver Státusz:</strong>
                            <?php include 'vpn_status.php'; ?>
                        </div>
                        
                        <div class="list-group">
                            <?php
                            $files = glob($DOWNLOAD_DIR . '*.ovpn');
                            if (count($files) > 0) {
                                foreach ($files as $file) {
                                    $filename = basename($file);
                                    $filesize = filesize($file);
                                    
                                    if ($filesize > 1000) {
                                        echo '<div class="list-group-item d-flex justify-content-between align-items-center file-item">';
                                        echo '<div>';
                                        echo '<strong>' . htmlspecialchars($filename) . '</strong>';
                                        echo '<br><small class="text-muted">Méret: ' . round($filesize/1024, 2) . ' KB</small>';
                                        echo '</div>';
                                        echo '<a href="' . $DOWNLOAD_DIR . htmlspecialchars($filename) . '" class="btn btn-primary btn-sm" download>Letöltés</a>';
                                        echo '</div>';
                                    }
                                }
                            } else {
                                echo '<div class="alert alert-warning text-center">Nincs elérhető .ovpn fájl.</div>';
                            }
                            ?>
                        </div>
                        
                    <?php endif; ?>
                </div>
                <div class="card-footer text-center text-muted small bg-light">
                    Készítette: Gcsipai 2025
                </div>
            </div>
        </div>
    </div>
</div>
</body>
</html>
EOL
echo -e "${GREEN_BOLD}✅ Webes kód (Letisztult Designnal) generálva.${RESET}"

# --------------------------------------------------------------------------------
# LÉPÉS 6: Symlinkek Létrehozása és Tűzfal Konfiguráció
# --------------------------------------------------------------------------------
echo -e "${YELLOW_BOLD}\n[6/6] Symlinkek frissítése és Tűzfal ellenőrzése...${RESET}"

find "$TARGET_DIR" -type l -delete 2>/dev/null
echo "ℹ️ Meglévő symlinkek törölve."

for file in "$OVPN_SOURCE_DIR"/*.ovpn; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        ln -sf "$file" "$TARGET_DIR/$filename"
        echo "   ✅ Linkelve: $filename"
    fi
done

if command -v ufw &> /dev/null; then
    ufw allow 80/tcp comment 'Allow HTTP for OpenVPN Web Downloader (Internal Network)' 2>/dev/null
    ufw reload 2>/dev/null
    echo -e "${GREEN_BOLD}✅ Tűzfal (UFW) szabály frissítve a 80-as portra.${RESET}"
fi

# --------------------------------------------------------------------------------
# BEFEJEZÉS
# --------------------------------------------------------------------------------
echo -e "${GREEN_BOLD}\n🎉 TELEPÍTÉS KÉSZ! Az új, letisztult felület aktív.${RESET}"
echo -e "${GREEN_BOLD}==================================================${RESET}"
echo -e "🌐 **Elérési út:** http://$(hostname -I | awk '{print $1}')"
echo -e "🔑 **Jelszó:** ${RED_BOLD}$VPN_DOWNLOAD_PASSWORD${RESET}"
echo -e "📂 **Forrásmappa:** $OVPN_SOURCE_DIR"
echo -e "${GREEN_BOLD}==================================================${RESET}"
