# Technitium DNS Server Telepítő és Konfiguráló Szkript ⚙️

## `ubuntu22-debian13-technitium-3.1.sh`

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Shell](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Debian | Ubuntu](https://img.shields.io/badge/Supported_OS-Debian%20%7C%20Ubuntu-orange)](https://www.debian.org/)
[![Author: DevOFALL](https://img.shields.io/badge/Author-DevOFALL-lightgrey)](https://github.com/gcsipai)

---

## 💡 Áttekintés

Ez a Bash szkript automatizálja a **Technitium DNS Server** telepítését és a szükséges előkonfigurációkat modern Debian-alapú rendszereken (**Ubuntu 22.04+** és **Debian 13+**).

A szkript fő fókuszában a DNS szolgáltatás (53-as port) ütközéseinek elhárítása áll a beépített **`systemd-resolved`** szolgáltatással szemben. A telepítés magában foglalja a Technitium hivatalos telepítőjének futtatását, amely gondoskodik a szükséges **.NET Runtime** telepítéséről.

**Készítette:** `DevOFALL`

---

## ✨ Funkcionális Leírás és Szolgáltatások

| Funkció Kategória | Kulcsfunkciók | Használt Szolgáltatások / Portok |
| :--- | :--- | :--- |
| **Rendszer & Függőségek** | `check_system`, `install_dependencies` | ![APT](https://img.shields.io/badge/Package_Manager-APT-0077B6?style=flat-square) ![tput](https://img.shields.io/badge/Terminal_Colors-tput-757575?style=flat-square) |
| **Port & Ütközés Vizsgálat** | `run_port_check` | ![Port 53](https://img.shields.io/badge/Port-53-4CAF50?style=flat-square) ![Port 5380](https://img.shields.io/badge/Port-5380-00BCD4?style=flat-square) |
| **DNS Ütközés Elhárítás** | `stop_and_mask_resolved` | ![systemd-resolved](https://img.shields.io/badge/Service-systemd--resolved-E53935?style=flat-square) ![DNS](https://img.shields.io/badge/Config-/etc/resolv.conf-FFD54F?style=flat-square) |
| **Fő Telepítés** | `install_technitium` | ![Technitium](https://img.shields.io/badge/DNS_Server-Technitium-9C27B0?style=flat-square) ![NET](https://img.shields.io/badge/Runtime-.NET_Core-673AB7?style=flat-square) |
| **DNS Visszaállítás** | `restore_resolved` | ![systemd-resolved](https://img.shields.io/badge/Service-systemd--resolved-3F51B5?style=flat-square) |

---

## ⚠️ Kritikus Megjegyzések

1.  **systemd-resolved (Port 53):** A telepítés előtt a menü **`3) systemd-resolved LEÁLLÍTÁSA`** opciójának futtatása **kötelező**, ha a 53-as port foglalt.
2.  **Jelszó Váltás:** A telepítés után **azonnal** lépj be a Web UI-ba (`http://<IP_cím>:5380/`) és változtasd meg az alapértelmezett **`admin/admin`** jelszót.
3.  **Tűzfal:** Ne feledd engedélyezni a portokat a szerver külső eléréséhez: **53** (DNS) és **5380** (Web UI).
4.  **Eltávolítás:** Ha a DNS szervert el akarod távolítani, a megszokott hálózati működés visszaállításához **mindig** futtasd a menü **`4) systemd-resolved VISSZAÁLLÍTÁSA`** opcióját!

---

## 🚀 Használat

### 1. Futtatás

Feltételezve, hogy a szkript már a rendszereden van:

```bash
# Adjon futtatási jogosultságot
sudo chmod +x ubuntu22-debian13-technitium-3.1.sh

# Futtatás
sudo ./ubuntu22-debian13-technitium-3.1.sh
