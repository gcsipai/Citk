# MariaDB Telepítő és Kezelő Eszköz (Bash Szkript v4.2)

## 🎯 Áttekintés

Ez a Bash szkript egy átfogó, **menüvezérelt parancssori eszköz** a **MariaDB** adatbázis-szerver és a hozzá tartozó **phpMyAdmin** webes felület telepítésére, konfigurálására és napi adminisztrációjára (mentés/visszaállítás).

Kifejezetten **Debian 12/13** és **Ubuntu 22.04+** rendszerekhez készült, a célja pedig az adatszerver környezet beállításának és karbantartásának teljes automatizálása.

---

## 🚀 Főbb Funkciók

A szkript két fő kategóriába sorolható, összesen nyolc funkcióval:

### I. Telepítés és Konfiguráció

| Menüpont | Funkció | Célja |
| :--- | :--- | :--- |
| **Apache Telepítése** | `setup_apache` | Telepíti az **Apache2** webszervert, engedélyezi a szükséges modulokat (`rewrite`), beállítja a szolgáltatás indítását, és megnyitja a szükséges HTTP/HTTPS portokat a tűzfalon (UFW esetén). |
| **MariaDB Telepítése** | `install_mariadb` | Telepíti a MariaDB adatbázis-szervert, elindítja és engedélyezi a szolgáltatást. |
| **Hozzáférés Konfigurálása** | `configure_access` | Kritikus lépések: beállítja a MariaDB **root jelszavát**, kezeli a **távoli hozzáférés** engedélyezését (`0.0.0.0 bind`), és megnyitja a **3306-os portot** a tűzfalon. |
| **phpMyAdmin Telepítése** | `install_phpmyadmin_apache` | Telepíti a phpMyAdmin webes felületet, beállítja az Apache2-höz, és automatikusan konfigurálja a MariaDB root jelszavával. |

### II. Adatbázis Kezelés és Mentés

| Menüpont | Funkció | Célja |
| :--- | :--- | :--- |
| **Adatbázis Mentése** | `backup_database` | Teljes adatbázis-mentést készít (`mysqldump --all-databases`) egy **időbélyeggel ellátott könyvtárba** a `/var/backups/mariadb` alá. A mentés garantálja a **tranzakciós konzisztenciát** (`--single-transaction`). |
| **Adatbázis Visszaállítása** | `restore_database` | Listázza az elérhető mentéseket, és a felhasználó választása alapján visszaállítja az összes adatbázist a kiválasztott mentésből. |
| **Mentések Kezelése** | `manage_backups` | Lehetővé teszi a mentési fájlok listázását, valamint a **7 napnál régebbi mentési könyvtárak automatikus törlését** a lemezterület felszabadítására. |
| **Felhasználókezelés** | `user_management` | Belépést biztosít a MariaDB parancssori kliensbe a root jelszó megadásával a manuális felhasználó- és jogosultságkezeléshez. |

---

## 🔑 Kulcsfontosságú Jellemzők

* **Jelszókezelés**: A `get_root_password_if_needed` segédfüggvény biztosítja, hogy a root jelszó csak egyszer kerüljön bekérésre, és tárolásra kerüljön a `$MARIADB_ROOT_PASSWORD` globális változóban, garantálva a további műveletek sikerét.
* **Apache2 Exkluzivitás**: A szkript **kizárólag Apache2-t** használ a phpMyAdmin kiszolgálására.
* **Konzisztens Mentés**: A mentési logika szimbolikus linket tart fenn a **legutóbbi mentéshez** (`/var/backups/mariadb/latest`) a gyors hozzáférés érdekében.
* **Biztonsági Ellenőrzések**: Minden kritikus művelethez (mentés, visszaállítás, phpMyAdmin telepítés) szükséges a **MariaDB root jelszó érvényességének** ellenőrzése.
