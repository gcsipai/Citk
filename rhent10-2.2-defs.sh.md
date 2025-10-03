# Enterprise Linux 10 Konfigurációs Szkript 2.2

## 📋 Áttekintés

Ez egy **átfogó rendszerkonfigurációs szkript**, amelyet kifejezetten **CentOS 10**, **RHEL 10**, **Rocky Linux 10** és **AlmaLinux 10** disztribúciókhoz fejlesztettek ki.

A szkript célja, hogy egyszerű és gyors módot biztosítson a legfontosabb rendszerbeállítások kezelésére egy **egységes menürendszeren** keresztül. Ideális választás minden olyan felhasználó számára, aki hatékonyan és biztonságosan szeretné kezelni Enterprise Linux alapú rendszereit anélkül, hogy mélyen elmerülne a parancssori eszközök használatában.

---

## 🎯 Fő célok

* **Gyors rendszerbeállítás**: Minden alapvető konfiguráció egy helyen.
* **Időmegtakarítás**: Manuális parancsok begépelése helyett menüalapú kezelés.
* **Hibatűrő működés**: Automatikus hibakezelés és érvényesítés.
* **Enterprise kompatibilitás**: Kifejezetten vállalati Linux disztribúciókhoz optimalizálva.

---

## 🚀 Főbb funkciók

| Kategória | Funkciók |
| :--- | :--- |
| **Csomagkezelés** | Rendszer frissítések (`dnf update/upgrade`), Alapvető alkalmazások telepítése, Monitorozó eszközök (htop, glances, iotop, stb.) telepítése. |
| **Hálózati konfiguráció** | NetworkManager alapú hálózatkezelés, Statikus IP beállítás, Hálózati diagnosztika és hibakezelés. |
| **Biztonsági beállítások** | Tűzfal konfiguráció (FirewallD), SELinux beállítások, SSH biztonság (root login tiltása, port változtatás). |
| **Rendszeradminisztráció** | Felhasználókezelés (létrehozás, törlés, sudo jogok), Hostnév beállítás, Cockpit webes felület telepítése. |
| **Monitorozás és diagnosztika** | Rendszerinformációk megjelenítése, Hálózati állapot ellenőrzés, Szolgáltatások kezelése. |

---

## 🛠️ Technikai előnyök

* **Automata disztribúció felismerés**: Érzékeli a telepített Linux disztribúciót.
* **EPEL repo automatikus kezelése**: Szükség esetén telepíti és konfigurálja az EPEL tárolót.
* **Hibakezelés**: Ellenőrzi a parancsok sikerességét és megfelelő visszajelzést ad.
* **Kompatibilitás**: Bizonyítottan működik minden major Enterprise Linux disztribúcióval.
* **Moduláris szerkezet**: Minden funkció külön, jól kezelhető modulban található.

---

## 📁 Használati területek

### 🏢 Vállalati környezet
* Gyors szerver beállítás és üzembe helyezés.
* Standardizált és konzisztens konfigurációk biztosítása.
* Központi felügyelet előkészítése.

### 🎓 Oktatás és gyakorlás
* Linux tanulás és gyakorlás rendszermérnöki feladatokhoz.
* Rendszeradminisztrációs feladatok szimulációja.

### 🔧 IT Support
* Gyors hibaelhárítás és rendszer optimalizálás.

---

## 🔒 Biztonsági és Egyedi Jellemzők

* **Root jogosultság ellenőrzés**: Csak megfelelő jogosultsággal futtatható.
* **Biztonsági mentések**: Kritikus beállítások mentése a változtatások előtt.
* **Naplózás**: Minden művelet nyomon követhető.
* **Interaktív menürendszer**: Felhasználóbarát kezelőfelület és reszponzív design.

---

## 📊 Teljesítmény és Skálázhatóság

* **Gyors telepítés**: Percék alatt beállítható egy teljes szerver.
* **Megbízható működés**: Enterprise szintű stabilitás.
* **Skálázhatóság**: Alkalmas egy vagy akár több szerver konfigurálására is.
