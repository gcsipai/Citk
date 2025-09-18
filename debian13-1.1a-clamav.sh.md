Ez a szkript egy interaktív Bash program, amelyet a ClamAV víruskereső telepítésére, kezelésére és futtatására terveztek Debian/Ubuntu-alapú rendszereken. A szkript számos funkcióval rendelkezik, amelyek megkönnyítik a víruskereső használatát és karbantartását.

Főbb funkciók és működés
A szkript a következő főbb funkciókat látja el, amelyek mind a felhasználó visszajelzései és javítási kérései alapján lettek finomítva:

Telepítés menüből: Egyszerű és automatizált telepítési folyamat, amely kezeli a függőségeket, a konfigurációt és a szolgáltatások indítását.

Fejlett víruskeresés: Kétféle vizsgálat közül választhatsz: a teljes rendszer vagy egy adott mappa átvizsgálása. A szkript rákérdez, hogy a talált fertőzött fájlokat karanténba helyezze-e egy külön mappába.

Folyamatjelzés: Mivel a víruskeresés sokáig tarthat, a szkript egy vizuális folyamatjelzőt (ún. "spinnert") jelenít meg a képernyőn, hogy a felhasználó lássa, a szkript nem fagyott le.

Adatbázis frissítés: A szkript egyetlen paranccsal frissíti a vírusadatbázist, és automatikusan kezeli a gyakran előforduló naplófájl-zárolási hibákat is.

Szolgáltatások leállítása: Lehetővé teszi a ClamAV háttérfolyamatainak biztonságos leállítását, anélkül, hogy a teljes programot eltávolítaná.

Részletes leírás
1. Kompatibilitás ellenőrzése
A szkript futtatásakor elsőként ellenőrzi, hogy a rendszer a népszerű apt csomagkezelőt használja-e. Ha nem, hibával leáll, megelőzve ezzel a kompatibilitási problémákat. Továbbá megköveteli a root jogokat (sudo), ami elengedhetetlen a rendszer szintű változtatásokhoz.

2. Főmenü és navigáció
A szkript indítása után egy letisztult, számozott menü jelenik meg, amely a fő funkciókat kínálja. A navigáció egyszerű, a kívánt opció számának beírásával történik. A visszajelzésekhez a szkript vizuális piktogramokat használ (pl. ✅, 🚫), de maga a menü egyszerű szöveges formátumú.

3. Telepítés és konfigurálás
A 0. menüpont kiválasztásával a szkript elvégzi az alábbi lépéseket:

Frissíti a rendszer csomaglistáját.

Telepíti a clamav csomagot.

Automatikusan konfigurálja a ClamAV démon (clamd.conf) és a frissítő (freshclam.conf) fájljait.

Beállítja a napló- és konfigurációs fájlok megfelelő jogosultságait.

Elindítja és engedélyezi a ClamAV szolgáltatásokat a rendszerindításkor.

Automatikus vírusadatbázis-frissítést hajt végre, megoldva a korábbi, manuális frissítés során fellépő zárolási hibákat.

4. Víruskeresési funkciók
A 1. és 2. menüpontok a vizsgálatokhoz tartoznak. Mindkét opció a perform_scan funkciót hívja meg, amely a következőket teszi:

Megkérdezi a felhasználót, hogy a fertőzött fájlokat helyezze-e karanténba. Ha igen a válasz, a szkript létrehoz egy quarantine mappát a /var/lib/clamav/ könyvtárban, és oda mozgatja a talált vírusokat.

A vizsgálat futása alatt egy folyamatjelző ("spinner") forog a terminálban, megakadályozva, hogy a felhasználó azt higgye, a program lefagyott.

A vizsgálat befejezésekor összegzést ad a talált fertőzésekről.

Fontos: A vizsgálat teljes eredménye a /var/log/clamav/clamav.log fájlba kerül, ahol minden részlet megtalálható.

5. Vírusadatbázis frissítése
A 3. menüpont a vírusdefiníciók frissítésére szolgál. A szkript a freshclam parancsot használja, de mielőtt futtatná, leállítja a háttérben futó automatikus frissítő szolgáltatást (clamav-freshclam.service). Ez garantálja, hogy ne lépjen fel zárolási hiba, majd a sikeres frissítés után újraindítja a szolgáltatást.

6. ClamAV szolgáltatások leállítása
Az 5. menüpont lehetővé teszi, hogy leállítsd a háttérben futó ClamAV démonokat (clamav-daemon és clamav-freshclam). Ez akkor lehet hasznos, ha karbantartást szeretnél végezni, vagy valamilyen okból ideiglenesen szüneteltetnéd a víruskereső működését. Ez a funkció nem távolítja el a programot, csak leállítja a futó folyamatokat.

A szkript használata
Mentsd el a szkriptet egy fájlba, pl. debian13-1.1a-clamav.sh néven.

Tedd futtathatóvá a fájlt a következő paranccsal:

Bash

chmod +x clamav_menu.sh
Futtasd a szkriptet rendszergazdai (root) jogosultságokkal:

Bash

sudo ./debian13-1.1a-clamav.sh
