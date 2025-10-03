# Kétnyelvű SNMP Beállító Szkript (Bash)

## 🎯 Célkitűzés

Ez egy kétnyelvű (**angol és magyar**) **Bash szkript**, amely leegyszerűsíti az **SNMP (Simple Network Management Protocol)** telepítését és beállítását. A fő cél, hogy a szervereket gyorsan és hibamentesen **monitorozhatóvá** tegyük olyan hálózati megfigyelő eszközök számára, mint az **Observium** és a **LibreNMS**. A szkript funkciói egy tiszta, interaktív menürendszeren keresztül érhetők el.

---

## ⚙️ Főbb Funkciók és Jellemzők

### 🗣️ Dinamikus Nyelvválasztás
A szkript indításakor a felhasználó **választhat az angol és a magyar nyelv** között. Ez a funkció dinamikusan beállítja az összes szöveges üzenetet (menüpontok, promptok, hibaüzenetek) a kiválasztott nyelvre, rendkívül felhasználóbaráttá téve a nemzetközi környezetben is.

### 🛡️ Root Jogosultság Ellenőrzés
A kritikus rendszer szintű változtatások (csomagtelepítés, konfigurációs fájl módosítása) miatt a szkript indításakor ellenőrzi a **root jogosultságot**. Ha a szkriptet nem root felhasználó futtatja, azonnal leáll, hibaüzenettel.

### 🛠️ Telepítés és Konfiguráció

| Funkció | Leírás |
| :--- | :--- |
| **`install_snmp()`** | Frissíti az `apt` csomaglistát, majd telepíti az `snmpd` (SNMP démon) és az `snmp` (parancssori eszközök) csomagokat. Hibakezeléssel jelzi a sikertelenséget. |
| **`configure_snmp()`** | Interaktívan bekérdez **monitorozó szerver IP-címét**, **közösségi sztringet (community string)**, szerver fizikai helyét és a rendszergazda e-mail címét. |
| **Konfigurációs Műveletek** | Létrehoz egy biztonsági mentést az eredeti konfigurációs fájlról (`/etc/snmp/snmpd.conf.bak`), majd generál egy **új, egyedi konfigurációs fájlt** az SNMP-hez. |
| **Szolgáltatáskezelés** | A konfiguráció befejeztével újraindítja az SNMP szolgáltatást, és engedélyezi az **automatikus rendszerindításkor** való indulást. |

### ✅ Tesztelési és Hibaelhárítási Eszközök

| Opció | Cél |
| :--- | :--- |
| **Helyi Teszt (`test_snmp_local`)** | Végrehajt egy helyi tesztet az `snmpwalk` paranccsal, hogy ellenőrizze, az SNMP ügynök megfelelően válaszol-e a szerverről érkező kérésekre. |
| **Távoli Tesztelési Útmutató (`explain_remote_test`)** | Nem futtat parancsot, hanem **részletes útmutatást** ad arról, hogyan lehet tesztelni a kapcsolatot a külső monitorozó szerverről. Felhívja a figyelmet a lehetséges **tűzfal problémákra (UDP 161-es port)**. |

---

## 🖱️ Interaktív Főmenü (`main_menu`)

A szkript központi eleme egy tiszta, konzol alapú menü, amely a következő opciókat kínálja:

1.  **Teljes telepítés és konfigurálás (ajánlott)**: Végrehajtja a teljes folyamatot a csomagok telepítésétől a konfigurációig.
2.  **SNMP konfigurálása (ha már telepítve van)**: Csak a konfigurációs lépést hajtja végre.
3.  **Helyi SNMP teszt**: Ellenőrzi a helyi ügynök válaszát.
4.  **Távoli tesztelési útmutató**: Megjeleníti a távoli teszteléshez szükséges útmutatót.
5.  **Kilépés**: Kilép a szkriptből.

A szkript logikus felépítése és kétnyelvű támogatása segíti a felhasználókat a hibamentes és hatékony SNMP beállításban.
