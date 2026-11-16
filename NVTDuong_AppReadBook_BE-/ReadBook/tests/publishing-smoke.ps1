param(
  [string]$ApiBase = $env:NOVI_API_BASE,
  [string]$ReaderEmail = $env:NOVI_READER_EMAIL,
  [string]$ReaderPassword = $env:NOVI_READER_PASSWORD,
  [string]$AdminEmail = $env:NOVI_ADMIN_EMAIL,
  [string]$AdminPassword = $env:NOVI_ADMIN_PASSWORD
)
$ErrorActionPreference='Stop'
$PSDefaultParameterValues['Invoke-WebRequest:UseBasicParsing'] = $true
if(-not $ApiBase -or -not $ReaderEmail -or -not $ReaderPassword -or -not $AdminEmail -or -not $AdminPassword){throw 'Missing NOVI_API_BASE or test credentials.'}
function Login($email,$password){(Invoke-RestMethod -Method Post -Uri "$ApiBase/api/auth/login" -ContentType 'application/json' -Body (@{email=$email;password=$password}|ConvertTo-Json)).accessToken}
function Headers($token){@{Authorization="Bearer $token"}}
$reader=Login $ReaderEmail $ReaderPassword
$admin=Login $AdminEmail $AdminPassword
$application=Invoke-RestMethod -Method Post -Uri "$ApiBase/api/author-applications" -Headers (Headers $reader) -ContentType 'application/json' -Body '{"message":"Publishing smoke test"}'
$decisionBody='{ "approve": true, "reason": null }'
$jobs=1..2|ForEach-Object{Start-Job -ScriptBlock{param($url,$headers,$body)try{Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -Headers $headers -ContentType 'application/json' -Body $body|Select-Object -Expand StatusCode}catch{[int]$_.Exception.Response.StatusCode}} -ArgumentList "$ApiBase/api/admin/author-applications/$($application.id)/decision",(Headers $admin),$decisionBody}
$statuses=$jobs|Wait-Job|Receive-Job;$jobs|Remove-Job
if(($statuses|Where-Object{$_ -eq 204}).Count-ne 1 -or ($statuses|Where-Object{$_ -eq 409}).Count-ne 1){throw "Concurrent decision failed: $($statuses -join ',')"}
"PASS concurrent author decision: $($statuses -join ',')"
