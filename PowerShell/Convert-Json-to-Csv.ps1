$procs = Get-Content -Path C:\Temp\artifacts.json  ConvertFrom-Json

$procs  ConvertTo-Csv -Delimiter `t -NoTypeInformation  Out-File C:\Temp\artifacts.csv
& C:\Temp\artifacts.csv
