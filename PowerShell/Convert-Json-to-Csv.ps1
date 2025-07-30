$procs = Get-Content -Path CTempartifacts.json  ConvertFrom-Json

$procs  ConvertTo-Csv -Delimiter `t -NoTypeInformation  Out-File CTempartifacts.csv
& CTempartifacts.csv
