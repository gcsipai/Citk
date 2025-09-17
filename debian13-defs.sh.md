Debian 13 "Swiss Army Knife" Beállító Szkript
Szeretnénk bemutatni egy új, hasznos eszközt, a Debian 13 Beállító Szkriptet, amely egy igazi "svájci bicska" a Debian 13 alapbeállításokhoz. Ez a szkript jelentősen időt takarít meg és egységesíti a szerverek konfigurálását.

Miben segít?
A szkript fő célja, hogy leegyszerűsítse a Debian 13 (Trixie) szerverek telepítés utáni beállításait, és segítsen a leggyakoribb feladatok automatizálásában.

⚠️ Fontos figyelmeztetés: A NetworkManager telepítése a szkript használata során újraindítást igényel!

1. Csomagkezelés és Rendszerfrissítés

Források beállítása: Automatikusan konfigurálja a hivatalos Debian 13 tárolókat (main, contrib, non-free, non-free-firmware).

Rendszerfrissítés: Egyetlen paranccsal elvégez egy teljes rendszerfrissítést.

Alapcsomagok telepítése: Telepíti a legfontosabb eszközöket, mint az mc (Midnight Commander), htop/bpytop, curl, unzip, zip.

2. Hálózat konfigurálása (a legfontosabb rész!)

Modern hálózatkezelés: Telepíti a NetworkManager-t és letiltja a régi ifupdown rendszert, elkerülve a konfliktusokat.

Könnyű kezelés: Telepíti a nmtui (menüalapú) és nmcli (parancssoros) eszközöket a hálózat egyszerű konfigurálásához (Wi-Fi, Ethernet, IP-címek stb.).

3. Rendszer alapbeállítások

Hostnév módosítása: Kényelmesen megváltoztathatod a gép nevét.

Felhasználókezelés: Létrehozhatsz új felhasználót sudo jogosultsággal, vagy törölhetsz meglévőket.

4. Biztonság és távoli karbantartás

SSH beállítás: Lehetővé teszi a root bejelentkezést (figyelmeztet a biztonsági kockázatokra) és testre szabható bejelentkező szöveget (banner) adhatsz hozzá.

Cockpit telepítése: Telepíti a Cockpit webalapú felügyeleti felületet, amelyen keresztül böngészőből (9090-es port) kezelheted a szervert.

5. Információgyűjtés

Egy helyen gyűjti össze és jeleníti meg a legfontosabb rendszerinformációkat (hostname, kernel verzió, CPU architektúra stb.).

Változások az 1.2-es frissítésben
A szkript új verziója még logikusabb és felhasználóbarátabb lett!

Egyszerűbb menüstruktúra: A funkciók logikusabb csoportosításba kerültek.

Hálózati menü: Minden hálózattal kapcsolatos funkció egy helyre került, beleértve a NetworkManager hibajavítását is.

Általános menü: A főmenüben csak a legfontosabb rendszerbeállítási opciók maradtak.

A funkcionalitás nem változott, csak az elrendezés lett sokkal átláthatóbb és professzionálisabb!

Hogyan használd?
Mentsd el a kódot egy fájlba, például deb13conf.sh.

Tedd futtathatóvá a fájlt a chmod +x deb13conf.sh paranccsal.

Futtasd a szkriptet sudo ./deb13conf.sh paranccsal (root jogosultság szükséges).
