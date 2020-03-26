<# 

.SYNOPSIS
    
    NA-UpdateUPN

    Abdelhamid Aiche / aicheh@gmail.com
    Version 1.0, March 26th, 2020

    Script is intended to bulk update Active Diretory users UPN and change it to the user email address. 

    Prereq :

    You have to add the UPN suffix before you can launch the script. This can be done with powershell : 

       Set-ADForest -UPNSuffixes @{Add="youremaildomain.com"}

    
    Some interesting links :
    
    https://docs.microsoft.com/en-us/office365/enterprise/prepare-a-non-routable-domain-for-directory-synchronization
    https://www.concurrency.com/blog/w/change-user-principal-names-to-match-email-address
    https://www.mustbegeek.com/change-upn-of-domain-users-in-active-directory/
    https://www.petenetlive.com/KB/Article/0001238

     
#>


# Get the users
$users = ( Get-ADUser -SearchBase "DC=domain,DC=com" -LdapFilter "(&(proxyAddresses=*)(!(cn=HealthMailbox*))(!(cn=SystemMailbox*)))" -ResultSetSize $null -Properties EmailAddress) | Select Name,SamAccountName,UserPrincipalName,EmailAddress

# Just for backup purpose (in case). You can skip this line.
$users | export-csv ".\users_before_update.csv" -NoTypeInformation -Delimiter ";"

# Update the UPN for all users
$users | %{ Set-ADUser -Identity $_.SamAccountName -UserPrincipalName $_.EmailAddress.ToLower() }
