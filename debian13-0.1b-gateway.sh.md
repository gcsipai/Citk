Komplex Hálózati és Tűzfal Konfigurátor
📖 Áttekintés
Ez a bash szkript egy átfogó eszköz a Linux alapú szerverek hálózati és tűzfal konfigurációjához. Célja, hogy egy egyszerű, menüvezérelt felületen keresztül tegye lehetővé komplex hálózati beállítások elvégzését.  A szkript a következő funkciókat kínálja:

Tűzfal konfiguráció: Alapvető és haladó tűzfal szabályok beállítása, beleértve a NAT-ot és a Port Forwarding-ot.

VPN-szerver: L2TP/IPsec VPN szerver gyors üzembe helyezése.

Hálózati szolgáltatások: DHCP és TFTP szerverek egyszerű konfigurálása.

Proxy beállítások: Squid proxy és SquidGuard tartalomfilter telepítése és beállítása.

Webes adminisztráció: Webmin telepítése a távoli szerverkezelés megkönnyítésére.

⚠️ FIGYELEM: BÉTA ÁLLAPOT ⚠️

A szkript jelenleg béta fázisban van. Bár alaposan teszteltük, előfordulhatnak hibák vagy váratlan viselkedés. Használata saját felelősségre történik, különösen éles környezetben. A szkript futtatása előtt mindig készíts biztonsági másolatot a fontos konfigurációs fájlokról!

🚀 Használat
A szkript futtatásához kövesd az alábbi lépéseket:

Töltsd le a szkriptet: Mentsd el a kódot egy fájlba (pl. config.sh).

Add meg a futtatási jogosultságot: Nyisd meg a terminált, és futtasd az alábbi parancsot, hogy futtathatóvá tedd a fájlt.

Bash

chmod +x config.sh
Futtasd a szkriptet: Indítsd el a szkriptet sudo paranccsal, mivel a hálózati beállítások root jogosultságot igényelnek.

Bash

sudo ./config.sh
A szkript egy interaktív menüt jelenít meg, amely végigvezet a konfigurációs lépéseken.

🛠️ Funkciók részletesen
1. Egyszerű tűzfal beállítás (Filtering)
Ez a menü egy alapvető tűzfalat hoz létre az nftables segítségével. Alapértelmezés szerint minden bejövő forgalmat blokkol, kivéve a helyi forgalmat (loopback) és a meglévő kapcsolatokat. Képes automatikusan felismerni a futó hálózati szolgáltatásokat és engedélyezni a hozzájuk tartozó portokat.

2. Komplett tűzfal
Ez a rész a haladó nftables funkciókat tartalmazza, a hálózati címfordítás (NAT) különböző típusait:

Masquerading és Port Forwarding (DNAT): Lehetővé teszi, hogy a belső hálózat egyetlen publikus IP-címmel internetezzen, és átirányítja a külső portokra érkező forgalmat a belső szerverekre.

Hairpin NAT: Ezzel a beállítással a belső hálózatról is a publikus IP-címen keresztül érheted el a saját szervereidet.

1:1 NAT: Minden bejövő és kimenő forgalmat egy publikus IP-címről egy privát IP-címre fordít, és fordítva.

3. L2TP/IPsec VPN konfiguráció
A szkript automatizálja egy VPN-szerver beállítását Strongswan és xl2tpd használatával. Hozzáadhatsz felhasználókat, és a szkript gondoskodik a szükséges NAT szabályokról is, hogy a VPN-kliensek hozzáférjenek a hálózati erőforrásokhoz.

4. DHCP szerver beállítások
Ezek a funkciók egy ISC DHCP szerver konfigurálását segítik elő. Beállíthatod a címtartományt, az átjárót és a DNS szervereket. Lehetőséged van statikus IP-címek hozzáadására is MAC-cím alapján. A menü emellett támogatja egy TFTP szerver telepítését és beállítását a hálózati bootoláshoz (PXE).

5. Squid és SquidGuard beállítások
Ezek a funkciók egy proxy szerver és tartalomfilter beállítását teszik lehetővé. A szkript képes beállítani egy átlátszó proxyt a HTTP forgalomhoz, és segíti a SquidGuard tartalomfilter konfigurációját a weboldalak blokkolásához.

6. Webmin telepítése
A Webmin egy népszerű webes felület, amellyel a szerveradminisztráció a böngészőből is végezhető. A szkript a modern, biztonságos signed-by metódussal telepíti a Webmint, majd megadja a hozzáféréshez szükséges URL-t.

⚙️ Kritikus Megjegyzések
NetworkManager: A szkript most már biztonságosabban kezeli a NetworkManager szolgáltatást. Nem tiltja le automatikusan, hanem megkérdezi, hogy a konfiguráció idejére leállítsa-e. Ez megakadályozza a hálózati kapcsolatok végleges megszakadását újraindítás után.

Konfigurációs fájlok: Mivel a szkript konfigurációs fájlokat ír felül (pl. /etc/dhcp/dhcpd.conf), mindig győződj meg róla, hogy a módosítások a kívántaknak felelnek-e meg.

Internetkapcsolat: A szkriptnek szüksége van aktív internetkapcsolatra a függőségek telepítéséhez.
