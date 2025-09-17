A szkriptet a következő lépésekkel használhatod a Debian 13 rendszereden:

1. A szkript elmentése
Másold ki a teljes szkriptkódot, amit korábban adtam, és illeszd be egy szövegszerkesztőbe. Mentsd el a fájlt a gépeden, például debian13-1.0a-syslog.sh néven.

2. A szkript futtathatóvá tétele
Alapértelmezés szerint az újonnan létrehozott fájlok nem futtathatók. Meg kell adnod a futtatási jogosultságot a következő paranccsal a terminálban:

Bash

chmod +x debian13-1.0a-syslog.sh
Ez a parancs lehetővé teszi a rendszer számára, hogy parancsként hajtsa végre a szkriptet.

3. A szkript futtatása
Mivel a szkript rendszerszintű változtatásokat hajt végre (telepít, konfigurációs fájlokat módosít), root jogosultságra van szüksége. A sudo paranccsal kell futtatnod:

Bash

sudo ./rsyslog_setup.sh
4. A szkript használata a menün keresztül
A fenti parancs futtatása után egy egyszerű, szöveges menü jelenik meg a terminálban, amely a következő opciókat kínálja:

1. Rsyslog telepítése (ha nincs telepítve): Ezt az opciót érdemes választanod, ha még nem biztos, hogy az rsyslog telepítve van-e a rendszereden. A szkript ellenőrzi, és ha szükséges, telepíti azt.

2. Helyi log konfiguráció megtekintése: Ez az opció nem hajt végre módosítást, csupán megjeleníti az aktuális rsyslog beállításaidat.

3. Beállítás syslog szerverként: Válaszd ezt, ha a gépedet központi loggyűjtő ponttá akarod tenni. A szkript megkérdezi, mely IP-címekről vagy hálózatokról szeretnél logokat fogadni, és beállítja a rsyslog.conf fájlt ennek megfelelően.

4. Beállítás syslog kliensként: Ezzel az opcióval a géped logjait tudod elküldeni egy távoli syslog szervernek. A szkript megkérdezi a szerver IP-címét vagy tartománynevét, és hozzáadja a szükséges konfigurációt.

5. Kilépés: Ezzel a menüből kiléphetsz és befejezheted a szkript futtatását.

Válaszd ki a kívánt opciót a szám begépelésével, majd nyomd meg az Enter gombot. A szkript ezután elvégzi a kért feladatot, és tájékoztat a folyamatról. A befejezés után a menü újra megjelenik, amíg ki nem lépsz.
