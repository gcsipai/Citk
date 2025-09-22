#-----------------------------------------------------------------------------------------------------------------------
# Konfigurációs változók
#-----------------------------------------------------------------------------------------------------------------------
# LDAP szerver cím és hitelesítő adatok a fallback módszerhez
$ldapServer = "domaincontroller.yourdomain.local" # Helyettesítsd a szerver IP-címével vagy nevével
$ldapPort = 389
$domain = "yourdomain.local" # Helyettesítsd a domain neveddel
$username = "ldap_read_user" # Helyettesítsd a felhasználónévvel
$password = "yourpassword" # Helyettesítsd a jelszóval
$baseDN = "DC=yourdomain,DC=local" # Helyettesítsd a domain DN-jével

# A kimeneti fájl helye
$desktopPath = [Environment]::GetFolderPath("Desktop")
$exportPath = Join-Path $desktopPath "AD_Felhasznalok_OU_kent.csv"

#-----------------------------------------------------------------------------------------------------------------------
# Függvények
#-----------------------------------------------------------------------------------------------------------------------

# Fő exportáló függvény, amely eldönti, melyik módszert használja
function Export-UsersToCsv {
    param (
        [string]$OutputPath
    )
    
    # Automatikus felismerés: Van-e ActiveDirectory modul?
    if (Get-Module -ListAvailable -Name ActiveDirectory) {
        Write-Host "Active Directory modul észlelése. A PowerShell beépített parancsmagjait használom." -ForegroundColor Green
        Export-UsersWithADModule -OutputPath $OutputPath
    } else {
        Write-Host "Active Directory modul nem észlelhető. Az LDAP alapú C# metódust használom." -ForegroundColor Yellow
        Export-UsersWithLdap -OutputPath $OutputPath
    }
}

# 1. módszer: PowerShell ActiveDirectory modullal (ha elérhető)
function Export-UsersWithADModule {
    param (
        [string]$OutputPath
    )

    try {
        # Active Directory modul betöltése
        Import-Module ActiveDirectory

        # CSV fájl létrehozása fejlécekkel
        "SzervezetiEgyseg;OU_DN;BejelentkezesiNev;TeljesNev;Engedelyezve" | Out-File -FilePath $OutputPath -Encoding UTF8

        $allOUs = Get-ADOrganizationalUnit -Filter * | Sort-Object Name
        foreach ($ou in $allOUs) {
            Write-Host "`nFeldolgozás alatt: $($ou.Name)" -ForegroundColor Green
            $users = Get-ADUser -Filter * -SearchBase $ou.DistinguishedName -Properties Enabled, DisplayName
            
            if ($users) {
                Write-Host "  Találat: $($users.Count) felhasználó" -ForegroundColor Cyan
                foreach ($user in $users) {
                    $enabledText = if ($user.Enabled) { "IGEN" } else { "NEM" }
                    $line = "$($ou.Name);$($ou.DistinguishedName);$($user.SamAccountName);$($user.DisplayName);$enabledText"
                    $line | Out-File -FilePath $OutputPath -Append -Encoding UTF8
                }
            } else {
                Write-Host "  Nincsenek felhasználók" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "`nHiba történt az AD modul futtatása közben: $_" -ForegroundColor Red
        return $false
    }
    return $true
}

# 2. módszer: LDAP alapú C# kóddal (ha az AD modul nem érhető el)
function Export-UsersWithLdap {
    param (
        [string]$OutputPath
    )
    
    # C# típusok betöltése a .NET-ből
    Add-Type -AssemblyName System.DirectoryServices
    
    # Hitelesítési adatok beállítása
    $dirEntry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$ldapServer/$baseDN", "$username@$domain", $password, "Secure")

    try {
        $ouSearcher = New-Object System.DirectoryServices.DirectorySearcher($dirEntry, "(objectCategory=organizationalUnit)")
        $ouSearcher.PropertiesToLoad.Add("ou")
        $ouSearcher.PropertiesToLoad.Add("distinguishedName")
        $ouResults = $ouSearcher.FindAll()

        "SzervezetiEgyseg;OU_DN;BejelentkezesiNev;TeljesNev;Engedelyezve" | Out-File -FilePath $OutputPath -Encoding UTF8

        foreach ($ouResult in $ouResults) {
            $ouName = $ouResult.Properties["ou"][0]
            $ouDN = $ouResult.Properties["distinguishedName"][0]

            Write-Host "`nFeldolgozás alatt: $ouName ($ouDN)" -ForegroundColor Green
            $userSearcher = New-Object System.DirectoryServices.DirectorySearcher($dirEntry, "(&(objectCategory=person)(objectClass=user))")
            $userSearcher.SearchRoot = "LDAP://$ldapServer/$ouDN"
            $userSearcher.PropertiesToLoad.Add("sAMAccountName")
            $userSearcher.PropertiesToLoad.Add("displayName")
            $userSearcher.PropertiesToLoad.Add("userAccountControl")
            $userResults = $userSearcher.FindAll()

            if ($userResults.Count -gt 0) {
                Write-Host "  Találat: $($userResults.Count) felhasználó" -ForegroundColor Cyan
                foreach ($userResult in $userResults) {
                    $samAccountName = $userResult.Properties["sAMAccountName"][0]
                    $displayName = $userResult.Properties["displayName"][0]
                    $userAccountControl = [int]$userResult.Properties["userAccountControl"][0]
                    $enabled = ($userAccountControl -band 2) -ne 2
                    $enabledText = if ($enabled) { "IGEN" } else { "NEM" }

                    $line = "$ouName;$ouDN;$samAccountName;$displayName;$enabledText"
                    $line | Out-File -FilePath $OutputPath -Append -Encoding UTF8
                }
            } else {
                Write-Host "  Nincsenek felhasználók" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "`nHiba történt a művelet közben: $_" -ForegroundColor Red
        return $false
    } finally {
        if ($dirEntry) {
            $dirEntry.Dispose()
        }
    }
    return $true
}

function Open-ExportedFile {
    param([string]$Path)
    if (Test-Path $Path) {
        Write-Host "A fájl megnyitása..." -ForegroundColor Green
        Invoke-Item $Path
    } else {
        Write-Host "Hiba: A fájl nem létezik. Előbb exportálni kell a felhasználókat." -ForegroundColor Red
    }
}

#-----------------------------------------------------------------------------------------------------------------------
# Fő menü
#-----------------------------------------------------------------------------------------------------------------------

do {
    Clear-Host
    Write-Host "Active Directory / Samba4 AD DC kezelő menü" -ForegroundColor Green
    Write-Host "----------------------------------------------" -ForegroundColor Green
    Write-Host "1. Felhasználók exportálása CSV fájlba (OU-ként)"
    Write-Host "2. Az elkészült CSV fájl megnyitása"
    Write-Host "3. Kilépés"
    Write-Host "----------------------------------------------" -ForegroundColor Green

    $choice = Read-Host "Válasszon egy opciót (1-3)"

    switch ($choice) {
        "1" {
            Write-Host "`nFelhasználók exportálása..." -ForegroundColor Yellow
            if (Export-UsersToCsv -OutputPath $exportPath) {
                Write-Host "`nKész! Az adatok sikeresen mentve lettek ide: $exportPath" -ForegroundColor Green
            }
            Write-Host "`nNyomj Entert a folytatáshoz..." -ForegroundColor Yellow
            Read-Host | Out-Null
        }
        "2" {
            Open-ExportedFile -Path $exportPath
            Write-Host "`nNyomj Entert a folytatáshoz..." -ForegroundColor Yellow
            Read-Host | Out-Null
        }
        "3" {
            Write-Host "Viszlát!" -ForegroundColor Cyan
            Start-Sleep -Seconds 1
            break
        }
        default {
            Write-Host "Érvénytelen választás. Kérlek, 1 és 3 közötti számot adj meg." -ForegroundColor Red
            Write-Host "`nNyomj Entert a folytatáshoz..." -ForegroundColor Yellow
            Read-Host | Out-Null
        }
    }
} while ($true)
