# 📄 Dokumentáció: `ubuntu24-cloudpanel-mailcow-install-beta.sh`

## Cél

Ez a szkript egy **univerzális, interaktív telepítő** CloudPanel és Mailcow szolgáltatások egyetlen Ubuntu szerveren történő automatizált telepítésére. A szkript célja a komplex telepítési konfliktusok (főleg a 80-as és 443-as portok ütközése) kezelése, miközben támogatja a KVM/VPS és az AWS/Cloud környezeteket is.

## 💾 Kompatibilitás és Követelmények

| Kategória | Részletek | Megjegyzés |
| :--- | :--- | :--- |
| **Támogatott OS** | Ubuntu **22.04 LTS** és **24.04 LTS**. | A szkript tartalmaz egy figyelmeztetést/megerősítést a nem LTS verziókon (pl. 25.04) történő futtatáshoz. |
| **Hardver** | Minimum **4 GB RAM** (ajánlott 6 GB), minimum **10 GB** szabad lemezterület. | A CloudPanel és a Docker-alapú Mailcow erőforrásigényes. |
| **Hálózat** | Szükséges publikus IP-cím és a Mailcow számára beállított DNS **A rekord**. |

## ⚙️ Fő funkciók és Konfliktuskezelés

A szkript kritikus funkciója a **portkonfliktus** megelőzése a két vezérlőpult között:

1.  **CloudPanel:** Hagyományosan a 80-as (HTTP) és 443-as (HTTPS) portokat használja a telepített **weboldalak** kiszolgálására.
    * **Admin Felület Portja:** CloudPanel admin felülete a megszokott **8443**-as porton fut.
2.  **Mailcow:** A webes felülete (SOGo, Admin UI) **egyedi portokra** kerül átirányításra (alapértelmezett beállítás a szkriptben: **8081/HTTP** és **8444/HTTPS**), így a 80-as és 443-as portok szabadon maradnak a CloudPanel számára.

| Szolgáltatás | Funkció | Port | Szolgáltatás |
| :--- | :--- | :--- | :--- |
| CloudPanel | Weboldalak (HTTP) | **80** | NGINX |
| CloudPanel | Weboldalak (HTTPS) | **443** | NGINX |
| CloudPanel | Admin UI | **8443** | CloudPanel Admin |
| Mailcow | Admin UI (HTTPS) | **8444** (testre szabható) | Docker |
| Mailcow | Levelezés | **25, 587, 143, 993, stb.** | Docker |

***

## 🔄 Lépésről-lépésre haladó folyamat

A szkript interaktívan vezeti végig a felhasználót a 7 fő lépésen, magyarázatokkal:

### 1. Rendszer Előkészületek
* **Logolás:** Az összes kimenet naplózása a `/var/log/cloudpanel-mailcow-install.log` fájlba.
* **Backup (7. lépés):** Kritikus konfigurációs fájlok mentése (`/root/pre-install-backup-*.tar.gz`).
* **Függőség Ellenőrzés (2. lépés):** Ellenőrzi az Ubuntu verzióját, a RAM és a szabad lemezterületet.

### 2. Tűzfal Kezelés (UFW)
* **Tűzfal KIkapcsolása:** Az UFW (Uncomplicated Firewall) ideiglenes kikapcsolása a telepítés előtt, elkerülve az előzetes szabályok miatti telepítési hibákat.
* **Adatbekérés:** Interaktív adatbekérés a Mailcow domain névre (`MAILCOW_HOSTNAME`) és az egyedi Mailcow portokra.

### 3. CloudPanel Telepítése
* Futtatja a hivatalos CloudPanel telepítőt.
* Ellenőrzi, hogy a CloudPanel NGINX szolgáltatása megfelelően elindult-e.

### 4. Mailcow Telepítése
* Telepíti a Dockert és a Docker Compose-t.
* Letölti a Mailcow forráskódját.
* **Automatizált Konfiguráció (4. lépés):** Automatikusan generálja a `mailcow.conf` fájlt, beállítva a megadott domain nevet és az **egyedi webes portokat** (pl. 8444).
* Elindítja a Mailcow Docker konténereket (`docker compose up -d`).

### 5. Tűzfal Végleges Bekapcsolása
* **Tűzfal BEkapcsolása:** Véglegesen aktiválja az UFW-t.
* **Protokoll Engedélyezés:** Engedélyezi az összes szükséges portot:
    * **CloudPanel:** 22, 80, 443, 8443.
    * **Mailcow:** Egyedi HTTP/HTTPS portok (pl. 8081/8444) és az összes levelezési protokoll port (25, 587, 143, 993, stb.).

### 6. Szolgáltatás Ellenőrzés és Tesztmenü
* **Szolgáltatás Verifikáció (5. lépés):** Ellenőrzi a CloudPanel fő szolgáltatásait (NGINX, MariaDB, PHP-FPM) és a Mailcow Docker konténerek állapotát.
* **Tesztmenü (6. lépés):** A telepítés befejeztével egy interaktív menü jelenik meg:
    * **Port teszt:** Külső portok elérhetőségének ellenőrzése.
    * **AWS/DNS Összegzés:** Tájékoztatás a felhő környezetről és a DNS beállításokról.
    * **Mailcow Konzol:** Közvetlen Bash Shell belépés a Mailcow Docker konténerbe fejlett adminisztrációhoz (`docker compose exec dovecot-mailcow bash`).
