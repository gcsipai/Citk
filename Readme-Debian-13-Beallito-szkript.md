Debian 13 Beállító Szkript egy Army kés a Debian szerverek alapbeállításához, amely sok időt megspórol és egységesítési lehetőséget kínál. Network Manager telepítése Debian 13 alatt újraindítást igényel! ⚠️

📦 1. Csomagkezelés és Rendszerfrissítés
Források beállítása: Automatikusan konfigurálja a Debian 13 (Trixie) hivatalos csomagtárait (main, contrib, non-free, non-free-firmware).
Rendszerfrissítés: Egy parancsot kiadva teljes rendszerfrissítést végez (apt update && apt upgrade).
Alapcsomagok telepítése: Telepíti az alapvető, hasznos eszközöket, mint pl.:
mc (Midnight Commander - fájlkezelő)
htop / bpytop (fejlett erőforrás-figyelő)
curl (webes adatátvitel)
unzip, zip (archívumkezelés)
🌐 2. Hálózat konfigurálása (A legfontosabb része a szkriptnek)
Modern hálózatkezelésre vált: Telepíti a NetworkManager-t és letiltja a régi ifupdown (/etc/network/interfaces) rendszert, ezzel elkerülve a konfliktusokat.
Szükséges eszközök: Telepíti a nmtui (grafikus, menüalapú konfigurátor), nmcli (parancssoros konfigurátor) és egyéb segédcsomagokat (net-tools, vlan).
Könnyű kezelés: A menüből elindíthatod az nmtui-t, ahol egyszerűen beállíthatod a Wi-Fi-t, Ethernet kapcsolatokat, IP-címeket stb.
🖥️ 3. Rendszer alapbeállítások
Hostnév módosítása: Megváltoztatja a gép nevét és frissíti a /etc/hosts fájlt.
Felhasználókezelés:
Új felhasználó létrehozása automatikus sudo jogosultsággal.
Meglévő felhasználók listázása.
Felhasználók törlése a home könyvtárral együtt.
🔒 4. Biztonsági és távoli karbantartás
SSH beállítás:
Root bejelentkezés engedélyezése (figyelmeztetéssel a biztonsági kockázatra).
Egyedi bejelentkező szöveg (Banner) szerkesztése a /etc/issue.net fájlban.
Cockpit telepítése: Installálja a Cockpit webalapú felügyeleti felületet, amelyet egy böngészőből (9090-es porton) elérve grafikusan kezelheted a szervert (szolgáltatások, tároló, hálózat, logok stb.).
ℹ️ 5. Információgyűjtés
Rendszerinformációk megjelenítése: Egy helyen összegyűjti és kiírja a legfontosabb adatokat:
Hostnév és operációs rendszer info (hostnamectl, lsb_release -a)
Kernel verzió (uname -a)
CPU architektúra (lscpu)

1.2 Update

🎨 Esztétikai változtatások:
A főmenü visszaállítva a tiszta, eredeti kinézetre (11 opció)
NetworkManager problémajavítás áthelyezve a hálózati menübe (2. opció)
Logikusabb menüstruktúra - minden hálózati funkció egy helyen
Főmenü egyszerűsítve - csak a legfontosabb általános opciók maradtak
Így a szkript sokkal logikusabb és áttekinthetőbb:
Főmenü: Általános rendszerbeállítások
Hálózati menü: Minden hálózattal kapcsolatos funkció (telepítés, konfiguráció, hibajavítás)
A funkcionalitás ugyanaz maradt, csak az elrendezés lett professzionálisabb és felhasználóbarátabb!

Használat:

A szkriptet a következőképpen kell használni:
Mentse el a kódot egy fájlba, deb13conf.sh.
Tegye futtathatóvá a fájlt a chmod +x deb13conf.sh paranccsal.
Futtassa a szkriptet sudo ./deb13conf.sh paranccsal. A szkript root jogosultságot igényel.
