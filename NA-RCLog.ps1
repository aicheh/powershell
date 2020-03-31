
<# 

.SYNOPSIS
    
    NA-RCLog

    Abdelhamid Aiche / aicheh@gmail.com
    Version 1.01, March 30th, 2020

    Script is intended to query MS Exchange 2013/2016 receive connectors log files data and present them in a more usable format.

    Log files are stored by default in %ExchangeInstallPath%TransportRoles\Logs\FrontEnd\ProtocolLog\SmtpReceive\*.log folder.

    You can also get the path using : Get-FrontendTransportService -Identity SERVERNAME | Select ReceiveProtocolLogPath

    Very helpfull if you want to track a specific receive connector activity for example, specially when you deal 
    with custom receive connectors.


.REVISIONS

    1.0     Initial release
    1.01    Some minor changes with performance in mind :
            Replaced $output variable of type Array by an ArrayList. 
               
     
    
.PARAMETER Scope

    Specifies which log files to query. 
 
    Predefined values : 
       AllLogFiles       : Query all the log files in the log folder
       TheCurrentLogFile : Query only the active (current) log file - Default Value
       LogFilesOfTheDay  : Query all the log files generated today
       LogFilesOfTheWeek : Query all the log files generated this week

.PARAMETER Filter
    A basic way to grab only lines in the log file containing the substring define by the Filter parameter


.EXAMPLE

   .\NA-RCLog.ps1 -Scope LogFilesOfTheDay -Filter "EXCHANGE\Default Frontend" | Out-GridView   # Display all activity related to the EXCHANGE\Default Frontend Receive Connector

   .\NA-RCLog.ps1 -Scope LogFilesOfTheDay | ?{ $.Connector -match "EXCHANGE\Default Frontend"} | Out-GridView   # Same thing in a different way

   .\NA-RCLog.ps1 -Scope LogFilesOfTheWeek | select Client -Unique   # print a list of unique client ip connecting to your server the last week

#>


param(
    [parameter(Position=0,Mandatory=$false,ValueFromPipeline=$false)][string]$Filter,
    [parameter(Position=1,Mandatory=$false,ValueFromPipeline=$false)][ValidateSet('AllLogFiles','TheCurrentLogFile','LogFilesOfTheDay','LogFilesOfTheWeek')][string]$Scope='TheCurrentLogFile'
	)

$ExchangeInstallPath = $env:ExchangeInstallPath

$path = "$($ExchangeInstallPath)TransportRoles\Logs\FrontEnd\ProtocolLog\SmtpReceive\*.log"

$files = Get-ChildItem $path | Sort-Object CreationTime -Descending

switch ($scope)
    {
      "TheCurrentLogFile"  { $files = $files | Select-Object -First 1 }
      "LogFilesOfTheDay"   { $files = $files | ? { $_.CreationTime -gt (Get-Date).date } }
      "LogFilesOfTheWeek"  { $files = $files | ? { $_.CreationTime -gt (Get-Date).AddDays(-6) } }
    }

$output  = [System.Collections.ArrayList]@()

foreach ($file in $files) {

    $content = ($file | Get-Content | Select-Object -Skip 5)
   
    foreach ($line in $content) {
   
        $parseline = $line.split(",")  
        $skip = $false
      
        if ($filter) { if (!($parseline -match $filter)) { $skip = $true } }
           
        if (!$skip) {

            $item = New-Object PSObject -Property @{
                    Log        = $file.Name
                    Date       = $parseline[0].split("T")[0]
                    Time       = $parseline[0].split("T")[1].split(".")[0]
                    Connector  = $parseline[1]
                    Client     = $parseline[5].split(":")[0]
                    Server     = $parseline[4].split(":")[0]
                    Data       = $parseline[7]
                    }

            $null = $output.Add($item)
   
        }

    }

}

$output | Select Log, Date, Time, Client, Server, Connector, Data
