Bash Szkript Leírása: MariaDB Telepítő és Kezelő Eszköz (v4.2)
Ez a Bash szkript egy átfogó, menüvezérelt parancssori eszköz a MariaDB adatbázis-szerver és a hozzá tartozó webes felület, a phpMyAdmin, telepítésére, konfigurálására és napi adminisztrációjára (mentés/visszaállítás). Kifejezetten Debian 12/13 és Ubuntu 22.04+ rendszerekhez készült.

A szkript célja az adatszerver környezet beállításának és karbantartásának automatizálása.

🚀 Főbb Funkciók
A szkript nyolc fő funkciót kínál, amelyek két kategóriába sorolhatók:

I. Telepítés és Konfiguráció
Menüpont	Függvény	Célja
1.	setup_apache	Telepíti az Apache2 webszervert, engedélyezi a szükséges modulokat (rewrite), beállítja a szolgáltatás indítását, és megnyitja a szükséges HTTP/HTTPS portokat a tűzfalon (UFW esetén).
3.	install_mariadb	Telepíti a MariaDB adatbázis-szervert, elindítja és engedélyezi a szolgáltatást.
4.	configure_access	Kritikus konfigurációs lépések: beállítja a MariaDB root jelszavát (szükséges a külső eléréshez), kezeli a távoli hozzáférés engedélyezését (0.0.0.0 bind) és megnyitja a 3306-os portot a tűzfalon.
2.	install_phpmyadmin_apache	Telepíti a phpMyAdmin grafikus webes felületet, beállítja az Apache2-höz, és automatikusan konfigurálja a MariaDB root jelszavával.

Exportálás Táblázatok-fájlba
II. Adatbázis Kezelés és Mentés
Menüpont	Függvény	Célja
6.	backup_database	Teljes adatbázis-mentést készít (mysqldump --all-databases) egy időbélyeggel ellátott könyvtárba a /var/backups/mariadb alá. A mentés garantálja a tranzakciós konzisztenciát (--single-transaction).
7.	restore_database	Listázza az elérhető mentéseket, és a felhasználó választása alapján visszaállítja az összes adatbázist a kiválasztott mentésből.
8.	manage_backups	Lehetővé teszi a mentési fájlok listázását, valamint a 7 napnál régebbi mentési könyvtárak automatikus törlését a lemezterület felszabadítására.
5.	user_management	Belépést biztosít a MariaDB parancssori kliensbe a root jelszó megadásával a manuális felhasználó- és jogosultságkezeléshez.

Exportálás Táblázatok-fájlba
🔑 Kulcsfontosságú Jellemzők
Jelszókezelés: A get_root_password_if_needed segédfüggvény biztosítja, hogy a root jelszó csak egyszer kerüljön bekérésre, és tárolásra kerüljön a $MARIADB_ROOT_PASSWORD globális változóban, garantálva a további műveletek (mentés, konfiguráció) sikerét.

Apache2 Exkluzivitás: A szkript kizárólag Apache2-t használ a phpMyAdmin kiszolgálására.

Konzisztens Mentés: A mentési logika szimbolikus linket tart fenn a legutóbbi mentéshez (/var/backups/mariadb/latest) a gyors hozzáférés érdekében.

Biztonsági Ellenőrzések: Minden kritikus művelethez (mentés, visszaállítás, phpMyAdmin telepítés) szükséges a MariaDB root jelszó érvényességének ellenőrzése.
