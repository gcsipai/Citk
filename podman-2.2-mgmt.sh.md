# PODMAN KONZOL MENEDZSER SZKRIPT

## Fájlnév
podman-2.2-mgmt.sh

## Verzió
2.2 Citk 2025

## Célja
Ez a Bash szkript a Podman konténerek parancssori menedzselését teszi interaktívvá és gyorssá. Fő célja, hogy a felhasználók könnyedén és gyorsan beléphessenek az AKTÍV konténereik (mind a root, mind a rootless) konzoljába (shell-jébe) anélkül, hogy manuálisan be kellene írniuk a konténer ID-t vagy a teljes `podman exec` parancsot.

## Főbb Jellemzők

* **Egységes Menü:** Letisztult, számozott menürendszer.
* **Root/Rootless Támogatás:** Egyaránt listázza és kezeli a root (rendszer szintű) és a rootless (normál felhasználói) környezetben futó konténereket.
* **Interaktív Választás:** A konténerek egy számozott listában jelennek meg, és a felhasználó sorszám alapján választhat. Ez a módszer sokkal gyorsabb, mint a manuális ID-másolás.
* **Automatikus Shell Keresés:** A szkript automatikusan megkeresi és használja a konténerben elérhető shellt (`/bin/bash` vagy `/bin/sh`).
* **Felhasználóváltás (sudo):** Ha rootként futtatják, a szkript a megadott normál felhasználó nevében hajtja végre a rootless műveleteket (`sudo -u felhasználónév`).

## 💾 Telepítés és Futtatás

1.  **Mentés:** Mentsd el a szkriptet **`podman-2.2-mgmt.sh`** néven.
2.  **Futtathatóvá tétel:** Adj futtatási jogosultságot:
    ```bash
    chmod +x podman-2.2-mgmt.sh
    ```
3.  **Futtatás:**
    * **Normál felhasználóként:** Ha csak a saját (rootless) konténereidet akarod kezelni:
        ```bash
        ./podman-2.2-mgmt.sh
        ```
    * **Rootként (ajánlott) a teljes áttekintéshez:** Ez látja a root és rootless konténereket is. A szkript elkéri a normál felhasználónevet a rootless konténerek eléréséhez.
        ```bash
        sudo ./podman-2.2-mgmt.sh
        ```

## 📋 Menüpontok Leírása

A szkript a felhasználónév megadása után a következő menüt jeleníti meg:

| Opció | Funkció | Leírás |
| :---: | :--- | :--- |
| **1** | **Belépés aktív konténer konzoljába (EXEC)** | A fő funkció. Listázza az összes **aktív** (root és rootless) konténert. Kéri a konténer sorszámát, majd belép a shelljébe. |
| **2** | **Frissítés és Belépési Lista Megjelenítése** | Frissíti az aktív konténerek listáját és újra megjeleníti azt. Ez hasznos, ha új konténert indítottál a szkript futása közben. |
| **3** | **Kilépés** | Befejezi a szkript futását. |

## 🛠️ Előfeltételek és Követelmények

1.  **Podman:** A Podman konténer motor telepítve és működőképes legyen a rendszeren.
2.  **Sudo:** A szkript rootless konténerek kezeléséhez a `sudo` parancsot használja a felhasználóváltásra. Ennek engedélyezve kell lennie a normál felhasználó számára.
3.  **Aktív Konténerek:** A szkript kizárólag azokat a konténereket listázza, amelyek **futnak** (`podman ps` kimenet).
