$ping = Test-Path -Path "Z:\"
 if($ping -eq $false) {
$acctKey = ConvertTo-SecureString -String "{ACCOUNT_KEY}" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\{STORAGE_ACCOUNT}", $acctKey
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\{STORAGE_ACCOUNT}.file.core.windows.net\gpo-backups" -Credential $credential -Persist
 }

Try
{
Import-Module grouppolicy
$date = get-date -format M.d.yyyy 
$NamesPath = 'Z:\GPO_Names'
$BackupsPath = 'Z:\Backups'
$limit = (Get-Date).AddDays(-365)
$VmNamesPath = 'C:\GPOBackups\GPONames'
$VmBackupsPath = 'C:\GPOBackups\Backups'
$Vmlimit = (Get-Date).AddDays(-30)
$ErrorActionPreference = 'SilentlyContinue'
$exclude = @('test*', '[AGPM]*')

#Creates a file that is ingested into Azure that's used to resolve GPO Names from the GUID (for dashboard)
get-gpo -all | select Id, displayname | export-csv -path $NamesPath\$date.GPONames.csv
get-gpo -all | select Id, displayname | export-csv -path $VMNamesPath\$date.GPONames.csv
#Creates a new file named with the date and puts the GPO backup in it
New-Item -Path $BackupsPath\$date -ItemType directory
Get-GPO -All | where{$exclude -notcontains $_.DisplayName} | ForEach-Object {
  Backup-GPO -Guid $_.Id -Path $BackupsPath\$date
  }
}

Catch
{
#Sends an Email if there are any errors while running this script
$ErrorMessage = $_.Exception.Message
Send-MailMessage -to "{EMAIL@EMAIL.COM}" -subject "GPO Backup Script Has Errors" -from "GPO Backup <gpobackupscript@sba.gov>" -smtpserver '{SERVER.DOMAIN}' -body "The GPO Backup script has not completed or may have errors and not backed up all objects. 

The error message was: 
$ErrorMessage

The server running the script is: 
{SERVER_NAME}

"

#Creates a new file named with the date on the server and puts the GPO backup in it
New-Item -Path $VmBackupsPath\$date -ItemType directory
Backup-Gpo -All -Path $VmBackupsPath\$date

}

# Deletes files that were created over the number of days defnined in '$limit'
Get-ChildItem –Path $NamesPath -Recurse -Force | Where-Object {($_.CreationTime -lt $limit)} | Remove-Item -Force
Get-ChildItem –Path $BackupsPath -Recurse -Force | Where-Object {($_.CreationTime -lt $limit)} | Remove-Item -Force
# Deletes files that were created over the number of days defnined in '$Vmlimit'
Get-ChildItem –Path $VmNamesPath -Recurse -Force | Where-Object {($_.CreationTime -lt $Vmlimit)} | Remove-Item -Force
Get-ChildItem –Path $VmBackupsPath -Recurse -Force | Where-Object {($_.CreationTime -lt $Vmlimit)} | Remove-Item -Force
