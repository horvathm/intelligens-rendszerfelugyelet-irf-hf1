<#
.SYNOPSIS
	349-es kódú házi. 
.DESCRIPTION
    Egyetemi tanszéket megadjuk a Department paraméternek és kiírjuk a tanszéken belül kutatócsoportokat, a maximumot ahány porjektben valamelyik oktató(k) rész vesz (a kutató csoporton belül persze), végül az oktatók számát, akik ezt a maximumot elérik. A kimeneti fájl neve az OutFile paraméterben van megadva és kutató csoport szerint van rendezve növekvő sorrendben, -Descending paraméter esetén meg csökkenő sorrendben. Kimenet formátuma adott.
.PARAMETER Department
	Kötelező paraméter. String típusú. Ha nem létezik hibát dob. Megadaja a tanszéket, amelyen belül a kutatocsoportokra vagyunk kíváncsiak. Megadott paraméter ellenőrizve van, hogy létezik-e.
.PARAMETER OutFile
	Kötöelező paramáter. String típusú. Ha nem létezik hibat dob. Megadja a CV file útvonalat, ahova elkeszül a lekérdezés. Ha már létezik a file, akkor felülíródik. Ellenőrizve van, hogy üres-e a bemenet, illetve az érvénytelen karaktereket egy try-catch blokkal szándékoztam ellenőrizni. 
.PARAMETER Descending
	Opcionális flag típusú paraméter. Ha nincs beállítva, akkor tanszék szerint növekvő sorrendben történik a kiíratás. Ha be van állítva, akkor tanszék szerint csökkenő sorrendben történik a kiíratás.
.NOTES
    Author: Hovath Mate
    Date: 2016.04.03. 
    File-name: Get-ProjectsForGroups.ps1
.EXAMPLE
    c:\PS> Get-ProjectsForGroups.ps1 -Department "Department of Networks" -OutFile "OutFile.csv"
    Departments of Networks tanszéken belüli kutatócsoportokat vizsgáljuk. Az OutFile.csv-ban a végeredmény kutató csoport szerint lesz rendezve növekvő sorrendben.
.EXAMPLE
    c:\PS> Get-ProjectsForGroups.ps1 -Descending -Department "Department of Mechanics" -OutFile "OutFile2.csv" -Descending
    Departments of Mechanics tanszéken belüli kutatócsoportokat vizsgáljuk. Az OutFile2.csv-ban a végeredmény kutató csoport szerint lesz rendezve csökkenő sorrendben.
.LINK
    Link a Get-help barát paraméterezésről: https://technet.microsoft.com/en-us/library/hh847834.aspx
#>

param
(
    [Parameter(Mandatory=$true)][string]$Department,
    [Parameter(Mandatory=$true)][String]$OutFile,
    [switch]$Descending
)

#Megkeressük, hogy a karok valamelyikén van-e a Departmentben megadott nevű tanszék. Igy oldottam meg, hogy csak az adott hierarchiaszinten keressen, mivel nem tudjuk, hogy melyik kar-on van és alatta lévő szinten kell keresni, így nem találtam jobb megoldást, hogy ne nézzen szét alatta is.
$srcDepartment = Get-ADOrganizationalUnit -Filter 'OU -like "*"' -SearchBase 'OU=Faculties,OU=University,DC=irfhf,DC=local' -SearchScope OneLevel | ForEach-Object{Get-ADOrganizationalUnit -SearchBase "$($_.DistinguishedName)" -SearchScope OneLevel -Filter 'OU -like $Department'} | measure
if($srcDepartment.Count -eq 1) #Department exists
{
        #Megkeressük, hogy hol is van ez a Tanszék
        $pathOfDep = (Get-ADOrganizationalUnit -Filter 'OU -like $Department' -SearchScope Subtree).DistinguishedName
        
        #rendezés módjának a beállítása
        if($Descending -eq $true)
        {
            $objOfKcs = Get-ADOrganizationalUnit -Filter 'OU -like "*"' -SearchBase $pathOfDep -SearchScope OneLevel | Sort-Object -Descending
        }
        else
        {
            $objOfKcs = Get-ADOrganizationalUnit -Filter 'OU -like "*"' -SearchBase $pathOfDep -SearchScope OneLevel
        }
    
        #File létrehozása, header hozzádása
        try
        {
            if($OutFile.EndsWith('.csv')  -ne $true)
            {
                Write-Output 'Hibás a fájl kiterjesztése'
                return
            }

            New-Item -path .\$OutFile -ItemType file -force > $null
        }
        catch
        {
            Write-Output 'Hiba! Ilyen nevű fájlt nem lehet létrehozni.'
            return
        }
        $output = 'Group;Max;Members'
        Write-Output $output | Add-Content .\$OutFile

        #Kutatócsopotonként megkeresi az oktatókat, az oktatók hány projektben vannak benne és ez alapján kiszámol kutatócsoportokra
        foreach($i in $objOfKcs)
        {
            #lokális változók a számított értékekhez
            $max = 0
            $db = 0
            $temp = 0
            
            #Oktatók objektumai az i kcs-ban
            $srcUsers =Get-ADUser -Filter 'Name -like "*"' -SearchBase $i.DistinguishedName -SearchScope OneLevel
            foreach($j in $srcUsers)
            {
                #Oktatók hány projektben vannak benne. Például: Department of Networks: (0)dely | (1)crawdon | (2)etillinghast1, tehát jó eredményt ad vissza
                $temp = ((Get-ADUser -Identity $j –Properties MemberOf | Select-Object MemberOf).MemberOf | measure).count
                if($temp -lt $max)
                {
                    #skip
                }
                elseif($temp -eq $max)
                {
                    $db = $db + 1 #van még egy olyan ahol max
                }
                else
                {
                    $max = $temp #hopp, van egy ami nagyobb
                    $db = 1
                }
           }

        #Kimenet összeállítása és kiírása file-ba
        $output = $i.Name
        $output += ';'
        $output += $max
        $output += ';'
        $output += $db
        Write-Output $output | Add-Content .\$OutFile
        }

    
}
else #Tanszék nem létezik
{
    Write-Output 'Hiba! Nem letezik ilyen tanszek!'
}