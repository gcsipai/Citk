# Pi-hole Automatikus Telepítő 🛡️

## `ubuntu22-debian13-pihole.sh`

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Shell](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.x-5A7A97?logo=pihole&logoColor=white)](https://pi-hole.net/)

---

## 💡 Áttekintés

Ez a Bash szkript automatizálja a teljes **Pi-hole** DNS alapú hirdetés- és nyomkövető blokkoló telepítését **Ubuntu 22.04+** és **Debian 13** rendszereken.

A szkript a Pi-hole hivatalos, **nem interaktív** telepítési módját (`--unattended`) használja. Kiemelt hangsúlyt fektet a **stabilitásra** és **biztonságra** azáltal, hogy fejlett **hibakezelést** (APT/DPKG zárolások) és automatikus **tűzfal konfigurációt** (UFW) tartalmaz.

**Verzió:** `v1.0 (Final-Secured & Documented)`

---

## 💻 Támogatott Platformok és Alkalmazások

| Kategória | Alkalmazás | Verzió / Ikon | Szerep |
| :--- | :--- | :--- | :--- |
| **Operációs Rendszer** | Ubuntu | [![Ubuntu Supported](https://img.shields.io/badge/Ubuntu-22.04%2B-orange)](https://ubuntu.com/) | Célplatform |
| **Operációs Rendszer** | Debian | [![Debian Supported](https://img.shields.io/badge/Debian-11%20%7C%2012%20%7C%2013-red)](https://www.debian.org/) | Célplatform |
| **Futtatókörnyezet** | Bash | `🐚` | A telepítő szkript motorja |
| **Alkalmazás** | Pi-hole Core | `🚫` | DNS alapú hirdetésblokkolás |
| **Alkalmazás** | Pi-hole FTL | `🚀` | DNS motor és statisztikai backend |
| **Alkalmazás** | Lighttpd | `🌐` | Webkiszolgáló a Pi-hole admin felületéhez |
| **Alkalmazás** | UFW | `🔥` | Tűzfal: a Pi-hole portjainak engedélyezése |

---

## ✨ Funkcionális Leírás és Biztonság

| Funkció Kategória | Kulcsfunkciók | Biztonság / Megbízhatóság |
| :--- | :--- | :--- |
| **Tűzfal Konfiguráció** | `check_firewall` | Telepíti az **UFW**-t, és ha fut, engedélyezi a Pi-hole portokat: **53/udp, 53/tcp (DNS)** és **80/tcp (Web Admin)**. Figyelmeztet az inaktív tűzfalra. |
| **Hibakezelés (Lock)** | `handle_locks` | Ellenőrzi az APT/DPKG zárolásokat. Ha a 60 mp-es várakozás sikertelen, **erőszakkal feloldja** a zárolásokat a telepítés zavartalan folytatásához. |
| **Interfész és Jelszó** | Automatikus detektálás | Automatikusan megkeresi az alapértelmezett hálózati interfészt, és **erős jelszót** generál a webes admin felülethez. |
| **Interakció** | Jóváhagyás kérések | Két kritikus ponton is **jóváhagyást** kér a felhasználótól a telepítés elindítása előtt. |

---

## 🚀 Használat

### 1. Előkészítés

Győződjön meg róla, hogy a szkript **`ubuntu22-debian13-pihole.sh`** néven létezik a rendszereden, és **statikus IP-címet** állított be a Pi-hole szerverhez!

```bash
# Adjon futtatási jogosultságot
sudo chmod +x ubuntu22-debian13-pihole.sh
