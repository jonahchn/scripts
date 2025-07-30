# Based on https://learn.microsoft.com/en-us/intune/intune-service/protect/endpoint-security-app-control-policy#remove-all-applocker-policies-from-a-device-optional


#This is used to ensure TLS 1.2 is used to communicate
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

#Create TimeStamp Variable to append to the old registry.pol file if it is replaced
$TimeStamp = (Get-Date).ToString('yyyy-MM-dd-HH-mm-ss') # A timestamp to use in the folder name

#Search for Event 1096 in the System Event Log. If any instances exist, the local GPO is corrupted and needs to be fixed.
$events = Get-WinEvent -FilterHashtable @{
    LogName='System'
    ProviderName='*GroupPolicy'
    Id='1096'
 }|where-object{$_.message -match "LocalGPO"} -ErrorAction SilentlyContinue

 #If there are any instances of the 1096 Event, rename the current registry.pol file.
 #Also output a list of the files in the Machine folder to see the date of the corrupted file.
 IF($Null -ne $Events -and $Events -ne 0){
    rename-item "c:\windows\system32\GroupPolicy\Machine\registry.pol" -NewName "registry$TimeStamp.old"
    get-childitem -path "c:\windows\system32\GroupPolicy\Machine" -File|select-object Name,Length,LastWriteTime
 }

#Remove Intune Managed Installer
Remove-ItemProperty -Path Registry::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies" -Name "ManagedInstallerEnabled" -ErrorAction SilentlyContinue

#Clear Local AppLocker Policy
[string]$CleanupScript = 
@"
<?xml version="1.0"?>
<AppLockerPolicy Version="1" />
"@


function SetAppLockerPolicy([string]$policyXml)
{
    # save the applocker policy xml to temp folder
    $policyFile = "$($env:tmp)\CatCleamAllAppLockerPolicy_$(get-date -f yyyyMMddhhmmss).xml"
    $policyXml | Out-File $policyFile


    Set-AppLockerPolicy -XmlPolicy $policyFile -ErrorAction SilentlyContinue    
}

SetAppLockerPolicy($CleanupScript)

#Remove Cache
$RemoveFiles = @(
    "C:\Windows\System32\AppLocker\Msi.AppLocker"
    "C:\Windows\System32\AppLocker\Script.AppLocker"
    "C:\Windows\System32\AppLocker\Appx.AppLocker"
    "C:\Windows\System32\AppLocker\Dll.AppLocker"
    "C:\Windows\System32\AppLocker\Exe.AppLocker"
    "C:\Windows\System32\AppLocker\ManagedInstaller.AppLocker"    
)

$RemoveFiles|ForEach-Object{
    $FilePath = $_
    If(test-path $FilePath){
        Remove-Item $FilePath -ErrorAction SilentlyContinue
    }
    Else{
        write-host "File $FilePath does not exist"
    }
}

#Clear Effective AppLocker Policy
$RemoveAllFiles = @(
    "HKLM:\Software\Policies\Microsoft\Windows\SrpV2"
    "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\SrpV2"
)
$RemoveAllFiles|ForEAch-Object{
    $RegPath = $_
    If(Test-Path $RegPath){
        Remove-Item -Path "$RegPath\*" -Recurse -ErrorAction SilentlyContinue
    }
    Else{
        write-host "$RegPath does not exist - no subkeys deleted"
    }
}

#Set applockerfltr service to Manual start
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\applockerfltr" -Name "Start" -Value 3

#Stop applockerfltr Service
#Restart Other Services

$StopServices = @(
    "IntuneManagementExtension"
    "applockerfltr"
    "appidsvc"
    "appid"
)

$StopServices|ForEach-Object{
    $StopService = $_
    IF((get-service $StopService|select-object -expandproperty Status -ErrorAction SilentlyContinue) -eq "Running"){
        try{
            get-service -Name $StopService|out-Null
            Stop-Service -Name $StopService -ErrorAction SilentlyContinue
        }
        Catch{
            write-host "The $StopService service does not exist"
        }
    }
    Else{
        write-host "The $StopService service is not currently running"
    }
}

Start-Sleep -Seconds 5

$StartServices = @(
    "IntuneManagementExtension"
    "appidsvc"
    "appid"
)

$StartServices|ForEach-Object{
    $StartService = $_
    IF((get-service $StartService|select-object -expandproperty Status -ErrorAction SilentlyContinue) -eq "Stopped"){
        try{
            get-service -Name $StartService|out-Null
            Start-Service -Name $StartService -ErrorAction SilentlyContinue
        }
        Catch{
            write-host "The $StartService service does not exist"
        }        
    }
    Else{
        write-host "The $StartService service is not currently stopped"
    }
}
