# Debian 13 "Swiss Army Knife" Konfigurációs Szkript

## 🔪 Áttekintés

Ez a szkript egy igazi **"svájci bicska"** a **Debian 13 (Trixie)** alapbeállításokhoz. Célja, hogy jelentősen **időt takarítson meg** és **egységesítse** a szerverek telepítés utáni konfigurálását, automatizálva a leggyakoribb rendszeradminisztrációs feladatokat.

---

## 🎯 Fő funkciók és Előnyök

### 📦 Csomagkezelés és Rendszerfrissítés
* **Források beállítása**: Automatikusan konfigurálja a hivatalos Debian 13 tárolókat (beleértve a `main`, `contrib`, `non-free` és `non-free-firmware` részeket).
* **Teljes rendszerfrissítés**: Egyetlen menüopcióval elvégzi a teljes rendszerfrissítést.
* **Alapcsomagok telepítése**: Telepíti a legfontosabb eszközöket, mint az `mc` (Midnight Commander), `htop`/`bpytop`, `curl`, `unzip`, és `zip`.

### 🌐 Hálózat konfigurálása (Modernizálás!)
* **Modern hálózatkezelés**: Telepíti a **NetworkManager-t** és letiltja a régi `ifupdown` rendszert a konfliktusok elkerülése végett.
* **Könnyű kezelés**: Telepíti az **`nmtui`** (menüalapú) és **`nmcli`** (parancssoros) eszközöket a hálózat egyszerű konfigurálásához (Wi-Fi, Ethernet, IP-címek, stb.).
* **⚠️ Fontos figyelmeztetés**: A NetworkManager telepítése a szkript használata során **rendszer-újraindítást igényel!**

### ⚙️ Rendszer alapbeállítások
* **Hostnév módosítása**: Kényelmes, interaktív felület a gép nevének megváltoztatásához.
* **Felhasználókezelés**: Lehetőség új felhasználó létrehozására `sudo` jogosultsággal, vagy meglévők törlésére.

### 🛡️ Biztonság és Távoli Karbantartás
* **SSH beállítás**: Lehetővé teszi a root bejelentkezést (a szkript figyelmeztet a biztonsági kockázatokra) és testre szabható bejelentkező szöveg (`banner`) hozzáadása.
* **Cockpit telepítése**: Telepíti a Cockpit webalapú felügyeleti felületet, amelyen keresztül böngészőből (9090-es port) kezelheted a szervert.

### 📊 Információgyűjtés
* Egy helyen gyűjti össze és jeleníti meg a legfontosabb rendszerinformációkat (hostname, kernel verzió, CPU architektúra, stb.).

---

## ✨ Változások az 1.2-es Frissítésben

A szkript új verziója a funkcionalitás megőrzése mellett még **logikusabb és felhasználóbarátabb** lett:

* **Egyszerűbb menüstruktúra**: A funkciók logikusabb csoportosításba kerültek.
* **Hálózati menü**: Minden hálózattal kapcsolatos funkció egy helyre került, beleértve a NetworkManager hibajavítását is.
* **Általános menü**: A főmenüben csak a legfontosabb rendszerbeállítási opciók maradtak, növelve az átláthatóságot.

---

## 🚀 Hogyan használd?

A szkript futtatásához kövesd az alábbi egyszerű lépéseket:

1.  **Mentés**: Mentsd el a szkript kódját egy fájlba, például: `deb13conf.sh`.
2.  **Futtathatóvá tétel**: Tedd futtathatóvá a fájlt a `chmod +x deb13conf.sh` paranccsal.
3.  **Futtatás**: Futtasd a szkriptet **root jogosultsággal** a következő paranccsal:
    ```bash
    sudo ./deb13conf.sh
    ```
