#To deploy, create a Task Scheduler task to execute the above customized PS script. Be sure to update the panos array to include all Pano IPs that have same credential and then supply that credential under the "define Pano creds" note. The task can be run at whatever frequency you specify in the Trigger. 

#Under the task General tab, specify user who can run the script and select radio button for "Run where user is logged on or not"

#Under the Task Actions tab specify the following: 

#Action: Start a program
#Program: Powershell.exe
#Add Arguments: -ExecutionPolicy Bypass "C:\pathtofile…\panoreboot-template.ps1"


#set up the env, ignore certs, add pano devices...
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#add pano IPs to array below in '' and separated by commas
$panos = @('10.1.1.1','10.0.0.0')

ForEach ($pano in $panos) {

#Part 1 login to Pano, get Session Id

#define Pano creds - only support for one common user account across all Panos. Different usernames would require multiple instances of this script
$JSON = @{
user='admin'
password='******'
} 

$body = $JSON | ConvertTo-Json
$bytes = [System.Text.Encoding]::UTF8.GetByteCount($body)

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Content-Length',$bytes)
$headers.Add('Content-Type','application/json')

$uri = 'https://'
$uri += $pano
$uri += '/rest/current/session'
#echo $uri 

$response = Invoke-WebRequest -Uri $uri -SessionVariable 'Session' -Method Post -Headers $headers -Body $body -ContentType 'application/json'
$Session

Write-Output $response.Content

$cookie = $response.Headers.'Set-Cookie'
$acookie = $cookie.split(";", 2)
$cookie = $acookie[0]


#part two, issue the reboot using the cookie from step one

$JSON2 = @{
'action'='reboot'
} 

$body2 = $JSON2 | ConvertTo-Json
$bytes = [System.Text.Encoding]::UTF8.GetByteCount($body2)
$headers2 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers2.Add('Content-Type','application/json')
$headers2.Add('Content-Length',$bytes)
$headers2.Add('Cookie',$cookie)
$headers2.Add('Accept','*/*')
$headers2.Add('Cache-Control','no-cache')
$uri = 'https://'
$uri += $pano
$uri += '/rest/current/system/reboot'

#echo $uri 
Write-Output $headers2

$response2 = Invoke-WebRequest -Uri $uri -WebSession $Session -Method Post -Headers $headers2 -Body $body2 -ContentType 'application/json'
Write-Output $reponse2
$response2
}
