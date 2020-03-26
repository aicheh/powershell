# Création d'un DAG ipless :

$DagName       = "DAG-E2016" 
$WitnessServer = "SERVEUR_TEMOIN"
$WitnessDir    = "C:\DAG-FSW"  

New-DatabaseAvailabilityGroup -Name $DagName -DatabaseAvailabilityGroupIPAddresses ([System.Net.IPAddress]::None) -WitnessServer $WitnessServer –WitnessDirectory $WitnessDir
Add-DatabaseAvailabilityGroupServer -identity $DagName –MailboxServer "SERVEUR_EXC01"
Add-DatabaseAvailabilityGroupServer -identity $DagName –MailboxServer "SERVEUR_EXC02"

Note : Contrairement au DAG avec adresse ip, il n'est pas nécessaire ici de créer et préparer un objet ordinateur CNO.


# Création d'une liste de bases de données depuis un fichier CSV (séparateur ;)
# Préparer d'abord un fichier CSV avec 3 colonnes : Name, EdbFilePath, LogFolderPath et lister y la liste des bases de données à créer.

$databases     = Import-Csv ".\databases.csv" -delimiter ";"

$databases | % {
      write-host "Création de la base de données : " $_.Name
      New-Mailboxdatabase -server "SERVEUR_EXC01" -name $_.Name  -Edbfilepath $_.EdbFilePath -logFolderPath $_.LogFolderPath  
      Sleep -s 10 
}

# Montage des bases de données (suite)

$databases | % {
      write-host "Montage de la base de données : " $_.Name
      Mount-Database $_.Name
      Sleep -s 10
}

# Création d'une copie des bases de données sur le second serveur

$databases | % {
      write-host "Création de la copie : $($_.Name)\SERVEUR_EXC02"
      Add-MailboxDatabaseCopy –Identity $_.Name –MailboxServer "SERVEUR_EXC02" -SeedingPostponed
      sleep -s 10
      Suspend-MailboxDatabaseCopy "$($_.Name)\SERVEUR_EXC02" -Confirm:$false 
      sleep -s 10
      Update-MailboxDatabaseCopy "$($_.Name)\SERVEUR_EXC02" -SourceServer "SERVEUR_EXC01" -DeleteExistingFiles -Confirm:$false
      Sleep -s 10
}

# Mettre les bases de données en enregistrement circulaire

$databases | % {
      Set-MailboxDatabase -Identity $_.Name -CircularLoggingEnabled $true
}

Note : dans un DAG, il n'est pas nécessaire de démonter puis remonter les bases pour que l'enregistrement curculaire prenne effet.
