<# 

 SmtpDiag.ps1
 
 Author: Abdelhamid Aiche
         aicheh@gmail.com

 Version 1.1 - Last modified : 06/27/2020 22:25

 .SYNOPSIS

     Analyze MX records.

.DESCRIPTION

     Script is intended to analyze MX records for the specified domain.
     It will gather MX hostnames, corresponding ip address, ping each ip and
     check if smtp port is open. It also retrieve geo ip information and 
     the server response when possible.
 
 .PARAMETER Domain
    
    Specify the domain to analyze

 .EXAMPLE
      
      .\smtpdiag.ps1 -domain ibm.com      

#>

Param(
    [Parameter(Mandatory=$true)][string]$domain	
	)


function FormatTTL($value)
{
    if ($value -gt 86400)    { "{0} days" -f ([math]::Round($value/86400)) } 
    elseif ($value -gt 3600) { "{0} hours" -f ([math]::Round($value/3600)) }
    elseif ($value -gt 60)   { "{0} min" -f ([math]::Round($value/60)) }
    else                     { "{0} sec" -f $value }
}

function GeoIp($ipaddress)
{
    $restUrl = "http://ip-api.com/json/$ipaddress"
    return (Invoke-RestMethod -Method get -Uri $restUrl)
}

function TestPort($hostname, $port)
{
    $tcpClient  = New-Object System.Net.Sockets.TcpClient
    return $tcpClient.ConnectAsync($hostname, $port).Wait(1000)
}

function ReadServerResponse {

    $result = ""
    
    while($stream.DataAvailable)
    {
        $read = $stream.Read($buffer, 0, 1024)
        $result+= ($encoding.GetString($buffer, 0, $read))       
    }

    return $result
}

function ReadServerGreetings($hostname) {

    $socket = new-object System.Net.Sockets.TcpClient($hostname, 25)
    if($socket -eq $null) { return; }

    $stream = $socket.GetStream()
    $writer = new-object System.IO.StreamWriter($stream)
    $buffer = new-object System.Byte[] 1024
    $encoding = new-object System.Text.AsciiEncoding
    $command = "HELO no-reply.com" #+ $domain
    $writer.WriteLine($command)
    $writer.Flush()
    start-sleep -m 500
    ReadServerResponse($stream)
}


$ErrorActionPreference   = "SilentlyContinue"
$WarningActionPreference = "SilentlyContinue"

$output = @()

$mx = Resolve-DnsName -Name $domain -Type MX -DnsOnly

if (!$mx) { write-host "Sorry, unable to resolve domain $domain or no MX found." -f Red; exit}

write-host "Analyzing domain $domain ..." -f Yellow
write-host "$($mx.count) MX records found." -f Green

$mx | %{
  
    $ho   = $_.NameExchange
    $ip   = ([System.Net.Dns]::GetHostByName($ho).AddressList[0].IPAddressToString)
    $tcp  = (TestPort $ip 25) 
    $ping = (Test-Connection $ip -Quiet -Count 1)
    $geo  = (GeoIp $ip)
    
    $item = New-Object PSObject -Property @{
                    Domain     = $_.Name
                    Type       = "MX"
                    Hostname   = $ho
                    Preference = $_.Preference
                    IpAddress  = $ip
                    TTL        = FormatTTL $_.TTL 
                    Ping       = "Success"
                    Status     = "SMTP port is open."
                    Network    = ""
                    Response   = ""
                    }
    
    if (!$ping) { $item.Ping = "Request timed out"}
    if (!$tcp)  { $item.Status = "SMTP port is closed/filtered." } 
    if ($geo)   { $item.Network = "{0}/{1}" -f $geo.as, $geo.country} 
    if ($tcp)   { $item.Response = (ReadServerGreetings $ip) }
 
    $output+=$item    
   
}



$output | Sort Preference | Select Domain, Type, Hostname, IPAddress, Network, Preference, TTL, Ping, Status, Response

