# Podman Kezelő Szkript (debian13-2.1.podman.sh)

**Verzió:** 2.1
**Cél:** Egyszerűsített telepítés, konfiguráció, és menedzsment a **Podman** konténer motorhoz, kiemelt figyelemmel a **rootless** (jogosultság nélküli) beállításokra és a **Docker kompatibilitásra** Debian 13 (Trixie) rendszereken.

## 🚀 Főbb Jellemzők

* **Robusztus Rootless Beállítás:** Automatikusan konfigurálja a `systemd --user` környezetet és a `podman.socket`-et, elkerülve a gyakori DBus/jogosultsági hibákat.
* **Docker Kompatibilitás:** Beállítja a `docker` és `docker-compose` aliasokat, valamint a szükséges `DOCKER_HOST` környezeti változót.
* **Cockpit Integráció:** Telepíti a Cockpit webes adminisztrációs felületet és a Podman plugint.
* **Diagnosztika és Javítás:** Dedikált menüpont a Docker kompatibilitás ellenőrzésére és a hiányzó socket automatikus indítására.

---

## ⚙️ Előfeltételek

A szkript futtatásához **Root** jogosultság szükséges (`sudo`).

A szkript a **normál felhasználó** nevében állítja be a rootless funkciókat. Ezt a felhasználónevet a szkript kéri el a futtatás során (vagy automatikusan felismeri a `sudo` felhasználót).

---

## 💾 Telepítés és Futtatás

1.  **Mentés:** Mentsd el a szkriptet egy fájlba (pl. `debian13-2.1.podman.sh`).
2.  **Futtathatóvá tétel:** Adj futtatási jogosultságot a fájlnak:
    ```bash
    chmod +x debian13-2.1.podman.sh
    ```
3.  **Futtatás:** Indítsd el a szkriptet root jogosultsággal:
    ```bash
    sudo ./debian13-2.1.podman.sh
    ```

---

## 📋 Menüpontok Részletes Leírása

A szkript indítása után egy interaktív menü fogadja a felhasználót.

### TELEPÍTÉS & ALAPOK

| Opció | Funkció | Leírás |
| :---: | :--- | :--- |
| **1** | **Podman Telepítés és Rootless Beállítás** | Ez a fő telepítő funkció. Telepíti a szükséges csomagokat (`podman`, `podman-compose`, `uidmap`, stb.), beállítja a konténer registry-ket, hozzáadja a **Docker aliasokat** (`.bashrc`-hez), engedélyezi a **linger**-t, és elindítja a **rootless Podman socket**-et. Teszt futtatása a végén. |
| **2** | **Cockpit és Podman Komponens Telepítése** | Telepíti a `cockpit`, `cockpit-podman` és `cockpit-storaged` csomagokat. Engedélyezi a Cockpit webes szolgáltatást és beállítja a tűzfalat (amennyiben `ufw` telepítve van). |

### KEZELÉS & KARBANTARTÁS

| Opció | Funkció | Leírás |
| :---: | :--- | :--- |
| **3** | **Konténerek Listázása** | Futtatja a `podman ps -a` parancsot a **root** konténerek és a megadott **normál felhasználó** rootless konténereinek listázásához. |
| **4** | **Rendszer Karbantartás (prune)** | Futtatja a **`podman system prune -f`** parancsot a normál felhasználó környezetében. Figyelem: **Visszavonhatatlanul** eltávolítja az összes nem használt konténer adatot, képet és kötetet. |

### DIAGNOSZTIKA & SEGÉDLETEK

| Opció | Funkció | Leírás |
| :---: | :--- | :--- |
| **5** | **Aliasok/Socket Aktíválás Útmutató** | Utasításokat ad a beállítások érvényesítéséhez (`source ~/.bashrc`) és megmutatja a `podman.socket` aktuális állapotát a felhasználói környezetben. |
| **6** | **Docker Kompatibilitás Ellenőrzése és Javítása** | **Diagnosztikai funkció.** Ellenőrzi: 1. A Docker aliasok és a `DOCKER_HOST` változó meglétét. 2. A `podman.socket` állapotát, és automatikusan megkísérli az indítását, ha inaktív. 3. Végül egy API tesztet futtat a socket működésének ellenőrzésére. |
| **7** | **Rendszer Állapot Jelentés** | Összefoglaló jelentést ad a Podman verzióról, a `linger` beállításról, a Cockpit állapotáról és az összesített konténer számokról. |

### KILÉPÉS

| Opció | Funkció | Leírás |
| :---: | :--- | :--- |
| **8** | **Kilépés** | Kilép a szkriptből. |

---

## 💡 Fontos Megjegyzés

A telepítési opció futtatása után (1. pont) a beállítások (aliasok, DOCKER\_HOST) csak egy **új terminál indításával** válnak érvényessé a normál felhasználó számára, vagy a következő parancs futtatásával:

```bash
source /home/FELHASZNÁLÓNÉV/.bashrc
