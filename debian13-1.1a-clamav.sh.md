# ClamAV Telepítő és Kezelő Eszköz (Bash Szkript)

## 🎯 Áttekintés

Ez a szkript egy **interaktív Bash program**, amelyet a **ClamAV** víruskereső telepítésére, kezelésére és futtatására terveztek **Debian/Ubuntu-alapú rendszereken**. A szkript célja, hogy megkönnyítse a víruskereső használatát és karbantartását egy átlátható menürendszeren keresztül.

A szkript a felhasználói visszajelzések alapján lett finomítva, különös hangsúlyt fektetve a **folyamatjelzésre** és a **hibatűrő adatbázis-frissítésre**.

---

## 🚀 Főbb Funkciók és Működés

| Funkció | Leírás | Előny/Jellemző |
| :--- | :--- | :--- |
| **Telepítés** | Egyszerű, menüből indítható, **automatizált telepítési folyamat**. | Kezeli a függőségeket, a konfigurációt és a szolgáltatások indítását (0. menüpont). |
| **Fejlett Vizsgálat** | Kétféle vizsgálat: **teljes rendszer** vagy **adott mappa** átvizsgálása. | Interaktív kérdés a talált fertőzött fájlok **karanténba helyezéséről** (`/var/lib/clamav/quarantine`). |
| **Folyamatjelzés** | Hosszú vizsgálatok alatt egy **vizuális folyamatjelző** (ún. "spinner") forog a képernyőn. | Megakadályozza, hogy a felhasználó azt higgye, a program lefagyott. |
| **Adatbázis Frissítés** | Egyetlen paranccsal frissíti a vírusadatbázist (`freshclam`). | Automatikusan **kezeli a gyakori naplófájl-zárolási hibákat** a szolgáltatás leállításával/újraindításával. |
| **Szolgáltatások Leállítása** | Lehetővé teszi a ClamAV háttérfolyamatainak biztonságos leállítását. | Karbantartáshoz vagy ideiglenes szüneteltetéshez hasznos (nem távolítja el a programot). |

---

## 🛠️ Részletes Technikai Működés

### 1. Előfeltételek és Ellenőrzések

* **Kompatibilitás**: Ellenőrzi az **`apt`** csomagkezelő meglétét. Ha nem találja, hibával leáll.
* **Jogosultság**: Megköveteli a **root (sudo) jogok** használatát a rendszer szintű módosításokhoz.

### 2. Telepítés és Konfigurálás (0. Menüpont)

A telepítés menüpontja több kritikus lépést hajt végre:

* Frissíti a rendszer csomaglistáját.
* Telepíti a `clamav` csomagot.
* **Automatikus konfiguráció**: Beállítja a `clamd.conf` (démon) és `freshclam.conf` (frissítő) fájlokat.
* Beállítja a napló- és konfigurációs fájlok megfelelő jogosultságait.
* Elindítja és engedélyezi a ClamAV szolgáltatásokat a **rendszerindításkor**.
* Végrehajtja az első, **hibamentes** vírusadatbázis-frissítést.

### 3. Víruskeresési Funkciók (1. és 2. Menüpont)

A `perform_scan` funkció felel a vizsgálatokért:

* **Karantén**: Ha a felhasználó kéri, létrehoz egy `quarantine` mappát a `/var/lib/clamav/` könyvtárban, ahová a fertőzött fájlokat helyezi.
* **Naplózás**: A vizsgálat teljes eredménye a **`/var/log/clamav/clamav.log`** fájlba kerül.
* **Visszajelzés**: A vizsgálat befejezésekor a szkript **összegzést** ad a talált fertőzésekről.

### 4. Adatbázis Frissítése (3. Menüpont)

A szkript garantálja, hogy a **`freshclam`** parancs ne ütközzön zárolási hibába:
1.  **Leállítja** a háttérben futó automatikus frissítő szolgáltatást (`clamav-freshclam.service`).
2.  Végrehajtja a frissítést.
3.  **Újraindítja** a szolgáltatást a sikeres futás után.

---

## 🚀 A Szkript Használata

1.  **Mentés**: Mentsd el a szkriptet egy fájlba, pl. `clamav_menu.sh` néven.
2.  **Futtathatóvá tétel**:
    ```bash
    chmod +x clamav_menu.sh
    ```
3.  **Futtatás (Root jogosultsággal)**:
    ```bash
    sudo ./clamav_menu.sh
    ```
