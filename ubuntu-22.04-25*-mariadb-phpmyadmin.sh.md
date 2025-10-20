# 💾 MariaDB Telepítő és Kezelő Szkript (Ubuntu/Debian)

## 📄 Áttekintés
Ez a shell szkript (Bash) a **MariaDB adatbázis-kezelő**, az **Apache2 webszerver** és a **phpMyAdmin** webes felület gyors és optimalizált telepítésére és konfigurálására szolgál. Kifejezetten a MariaDB repository és a phpMyAdmin beállítástároló (configuration storage) problémáinak automatikus javítására lett kifejlesztve, különös tekintettel az **Ubuntu 22.04 LTS** verzióra.

**Fájlnév:** `ubuntu-22.04-25*-mariadb-phpmyadmin.sh`

### 💡 Főbb Jellemzők

* **Kompatibilitás:** Ubuntu 22.04 LTS és újabb, Debian 12/13.
* **MariaDB Repository Fix:** Automatikus javítás a hibás MariaDB forráslistákhoz (`plucky` helyettesítése megfelelő kódnévvel).
* **phpMyAdmin Beállítástároló Fix:** A phpMyAdmin konfigurációs tároló adatbázisának és a dedikált `pma` felhasználó automatikus beállítása, kiküszöbölve a gyakori hibaüzeneteket.
* **Root Hozzáférés Kezelés:** MariaDB root jelszó beállítása és távoli hozzáférés engedélyezése.
* **Adatbázis Karbantartás:** Teljes adatbázis mentési és visszaállítási funkciók.

***

## 🚀 Használat

A szkriptet **root** jogosultsággal kell futtatni.

### 1. Letöltés és Futtatási Jog

```bash
# Tegyük fel, hogy a fájlt letöltötted a nevére
chmod +x ubuntu-22.04-25*-mariadb-phpmyadmin.sh
sudo ./ubuntu-22.04-25*-mariadb-phpmyadmin.sh
