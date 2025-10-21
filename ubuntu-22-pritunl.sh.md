# Pritunl VPN Szerver Telepítő 🛡️

## `ubuntu-22-pritunl.sh`

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Shell](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Ubuntu Supported](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-orange)](https://ubuntu.com/)

---

## 💡 Áttekintés

Ez a Bash szkript automatizálja a **Pritunl** (VPN szerver), a **MongoDB** (adatbázis) és a **WireGuard** telepítését Ubuntu 22.04 és 24.04 rendszereken.

A szkript kiemelt figyelmet fordít a **biztonságra** azáltal, hogy szigorú **GPG kulcs ellenőrzéseket** hajt végre a csomagok hitelességének garantálása érdekében, és tartalmaz egy **rollback mechanizmust** a hibakezeléshez.

**Verzió:** `v3.2 (Super-Secured)`

---

## ✨ Funkcionális Leírás és Biztonság

| Funkció Kategória | Kulcsfunkciók | Biztonság / Megbízhatóság |
| :--- | :--- | :--- |
| **GPG Kulcs Ellenőrzés** | `download_and_verify_key` | Kriptográfiailag ellenőrzi a MongoDB, OpenVPN és Pritunl tárolók **40 karakteres SHA ujjlenyomatát**. |
| **Hibakezelés** | `rollback_installation` | A `trap ERR` segítségével aktiválódik: hiba esetén automatikusan visszaállítja az **/etc/apt/sources.list.d** és **/etc/ufw** konfigurációs fájlokat. |
| **Tűzfal Konfiguráció** | `configure_ufw` | Beállítja az **UFW**-t, és csak a szükséges portokat engedélyezi: **443/tcp (WebUI)**, **1194/udp (OpenVPN)**, **51820/udp (WireGuard)**, **9700:9800/tcp (Pritunl)** és **SSH**. |
| **Naplózás** | `setup_logging` | Részletes naplózást biztosít a `/var/log/pritunl_install_*.log` fájlba. |
| **Állapot Ellenőrzés** | `check_status` | Telepítés után ellenőrzi a **`pritunl`** és **`mongod`** szolgáltatások futási állapotát és a szükséges portok figyelését. |

---

## 🚀 Használat

### 1. Előkészítés

Feltételezve, hogy a szkript már **`ubuntu-22-pritunl.sh`** néven létezik a rendszereden:

```bash
# Adjon futtatási jogosultságot
sudo chmod +x ubuntu-22-pritunl.sh
