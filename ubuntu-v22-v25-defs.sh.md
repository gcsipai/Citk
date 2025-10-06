# 🚀 Ubuntu Server Gyorsbeállító Szkript

## 📜 `ubuntu-22-25-defs.sh` (v2.1)

Ez a Bash szkript célja az Ubuntu Server (22.04 Jammy és újabb) gyors és interaktív konfigurálása. Segítségével egyszerűen kezelhető a csomagkezelés, a hálózati beállítások (Netplan és NetworkManager), a felhasználók és az alapvető rendszerkonfiguráció.

### 💡 Fontos frissítés (v2.1)

A **NetworkManager telepítés** mostantól **robosztusabb**. A szkript először a kritikus `network-manager` alapcsomagot telepíti. Csak ezután próbálja telepíteni az opcionális, szöveges kezelőfelületet (TUI), ellenőrizve az **`nmtui`** és a **`network-manager-tui`** csomagokat is. Ha a TUI nem található, a NetworkManager alapfunkciója akkor is működni fog (`nmcli` paranccsal).

---

## 🛠️ Főmenü Opciók

| Sorszám | Funkció | Leírás |
| :---: | :--- | :--- |
| **1.** | Csomagforrások konfigurálása | Ellenőrzi, menti, és beállítja az Ubuntu **fő, frissítési és biztonsági tárolóit** a detektált rendszer kódneve (pl. `jammy`) alapján. Frissíti a csomaglistát (`apt update`). |
| **2.** | Rendszer frissítése | Végrehajtja az `apt update` és **`apt upgrade -y`** parancsokat a teljes rendszer naprakésszé tételéhez. |
| **3.** | Alapvető alkalmazások telepítése | Telepíti a leggyakoribb és legszükségesebb csomagokat, mint pl. **`mc`** (Midnight Commander), **`htop`**, **`nano`**, **`net-tools`**, **`curl`** és **`wget`**. |
| **4.** | **NetworkManager Telepítés és Hálózati Beállítások** | Megnyitja a hálózati almenüt, ahol beállítható a NetworkManager vagy a Netplan. |
| **5.** | Hostnév és FQDN beállítása | Lehetővé teszi a rendszer **hosztnevének megváltoztatását**, és frissíti a `/etc/hosts` fájlt. |
| **6.** | Felhasználókezelés | Megnyitja a Felhasználókezelés almenüt: új felhasználó **hozzáadása `sudo` jogosultsággal**, felhasználók listázása, felhasználó törlése. |
| **7.** | SSH root bejelentkezés engedélyezése | **Figyelem! Biztonsági kockázat!** Engedélyezi a root felhasználónak az SSH-n keresztüli bejelentkezést. |
| **8.** | Rendszeradatok listázása | Megjeleníti az alapvető rendszerinformációkat (**OS, kernel, memória, lemezhasználat, uptime**). |
| **9.** | Cockpit telepítése és beállítása | Telepíti a **Cockpit** webes felügyeleti eszközt és engedélyezi a szolgáltatást. Elérhetőség: `https://[IP-cím]:9090`. |
| **10.**| SSH bejelentkező szöveg szerkesztése | Lehetővé teszi a bejelentkezés előtti üzenet szerkesztését (`/etc/issue.net`) és beállítja az SSH szervert a banner használatára. |
| **11.**| Kilépés | Kilép a szkriptből. |

---

## 🌐 Hálózati Konfiguráció Kezelése (4. menü)

Ez az almenü kulcsfontosságú a hálózati beállításokhoz. Kezeli a **NetworkManager** bevezetését, vagy a hagyományos **Netplan** konfiguráció finomhangolását.

### I. NetworkManager Kezelés

| Sorszám | Funkció | Leírás |
| :---: | :--- | :--- |
| 1. | **NetworkManager Telepítése és Konfigurálása** | Telepíti a fő `network-manager` csomagot, majd kísérletet tesz az `nmtui` TUI telepítésére (tartalékkal együtt). Engedélyezi és elindítja a szolgáltatást. |
| 2. | Átváltás NetworkManager-re (Netplan módosítása) | Módosítja a Netplan YAML fájlt, hogy a **`renderer: NetworkManager`**-t használja. Ez a lépés átadja a hálózati beállítások teljes irányítását a NetworkManagernek. |
| 3. | NetworkManager menü (**NMTUI/NMCLI**) | Lehetővé teszi az **NMTUI** (szöveges menü) használatát (ha telepítve van), vagy az **`nmcli`** paranccsal listázza az aktuális hálózati állapotot és kapcsolatokat. |

### II. Netplan Beállítások

| Sorszám | Funkció | Leírás |
| :---: | :--- | :--- |
| 4. | Netplan konfigurációs fájl szerkesztése (nano) | Elindítja a **`nano`** szerkesztőt a Netplan YAML fájlon. Szerkesztés után elvégzi a biztonságos **`netplan try`** tesztet. |
| 5. | Hálózati interfészek listázása | Megjeleníti az interfészek aktuális IP-címeit (`ip addr show`). |
| 6. | Hálózati naplók megjelenítése | Gyűjteményes nézetet biztosít a legfontosabb hálózati naplókról (`systemd-networkd`, `NetworkManager`) és az aktuális beállításokról (IP, útvonalak, DNS). |
