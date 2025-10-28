# 🛡️ OpenVPN Telepítő és Kezelő Szkript

## `ubuntu22-debian13-rh-openvpn-0beta.sh` (Nyr/Gcsipai Fork)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Shell](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![OpenVPN](https://img.shields.io/badge/OpenVPN-2.6%2B-5A7A97?logo=openvpn&logoColor=white)](https://openvpn.net/)
[![Security](https://img.shields.io/badge/Encryption-AES256--GCM-9cf?logo=openssl&logoColor=white)](https://www.openssl.org/)
[![OS Support](https://img.shields.io/badge/OS%20Support-Debian%2FUbuntu%2FRHEL-red)](https://www.debian.org/)

---
**Készítette:** [Nyr](https://github.com/Nyr/openvpn-install) | **Továbbfejlesztette:** [Gcsipai](https://github.com/gcsipai)
---

## 💡 Áttekintés

Ez a Bash szkript automatizálja az **OpenVPN** szerver telepítését és teljes körű kezelését (kliensek hozzáadása/visszavonása/törlése). Az eredeti, széles körben használt **Nyr** szkriptre épül, de **Gcsipai** által továbbfejlesztett, hibajavított és magyar nyelvű verzió.

A szkript kiemelt hangsúlyt fektet a telepítési folyamat automatizálására, a biztonságos titkosítási beállításokra (**AES-256-GCM**, SHA512), a stabil tűzfal konfigurációra és a hibás VPN hálózat (**alhálózati ütközések**) kezelésére.

**Verzió:** `v2.0 (Továbbfejlesztett Magyar Kezelő)`

---

## 💻 Támogatott Platformok és Technológiák

| Kategória | Alkalmazás / Funkció | Verzió / Ikon | Szerep |
| :--- | :--- | :--- | :--- |
| **Operációs Rendszer** | Ubuntu/Debian | 🐧 | Fő Célplatform |
| **Operációs Rendszer** | RHEL-alapúak (CentOS, Alma, Rocky) | 🐘 | Alternatív Célplatform |
| **VPN Szerver** | OpenVPN | `🔑` / 🟢 | Titkosított VPN-kapcsolat |
| **Titkosítás** | AES-256-GCM / SHA512 | 🔒 / 🛡️ | Adatforgalom biztonsága és integritása |
| **Tanúsítványkezelés** | Easy-RSA | 📜 / 🛠️ | CA, szerver/kliens tanúsítványok generálása |
| **Tűzfal** | Iptables / Firewalld | `🔥` / 🧱 | NAT (Masquerade) és portnyitás beállítása |
| **Hálózati réteg** | TUN / IPv4 Továbbítás | 🌐 / 📡 | A VPN-hez szükséges kernel-szintű támogatás |

---

## ✨ Funkcionális Leírás és Biztonság

| Funkció Kategória | Kulcsfunkciók | Biztonság / Megbízhatóság | Ikonok |
| :--- | :--- | :--- | :--- |
| **Hálózatkezelés (FIX)** | `setup_vpn_network` | **Kijavított** VPN hálózati ütközés vizsgálat, javasolt nem ütköző alhálózatot (pl. 10.x.0.0/24) az automatikus telepítéshez. | 🚦 🔄 |
| **Kliens Menedzsment** | Kezelő Menü | Interaktív menü az új kliensek gyors hozzáadásához és a meglévők **visszavonásához (CRL)** vagy **teljes törléséhez**. | ➕ 🚫 🗑️ |
| **Titkosítás** | TLS-Crypt, Cipher | **AES-256-GCM** alapértelmezett titkosítás és `tls-crypt` a metadata elrejtéshez és DoS védelemhez. | 🔐 🤫 |
| **DNS Támogatás** | Több opció | Választható DNS szolgáltatók (Google, Cloudflare, stb.) vagy **egyéni DNS** megadása a kliensek számára. | ☁️ ⚙️ |
| **Lokális Útvonal** | Opcionális Route | Képes `push` útvonalat beállítani a klienseknek a szerver **lokális hálózatához** való hozzáféréshez. | 🗺️ 🏠 |

---

## 🚀 Használat

### 1. Előkészítés

Győződjön meg róla, hogy a szkript **`ubuntu22-debian13-rh-openvpn-0beta.sh`** néven létezik a rendszereden, és a szerver rendelkezik **nyilvános IP-címmel** és **TUN** eszközzel (`/dev/net/tun`).

```bash
# Adjon futtatási jogosultságot
sudo chmod +x ubuntu22-debian13-rh-openvpn-0beta.sh
