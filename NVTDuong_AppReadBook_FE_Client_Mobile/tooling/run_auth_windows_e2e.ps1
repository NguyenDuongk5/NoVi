$ErrorActionPreference = 'Stop'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$backend = 'C:\Users\thain\Desktop\AppDocTruyen\NVTDuong_AppReadBook_BE-\ReadBook'
$api = 'http://localhost:5159'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 12)
$email = "auth-ui-$suffix@novi.test"
$lockedEmail = "auth-locked-$suffix@novi.test"
$password = "NoVi!${suffix}Aa1"
$dbPass = 'T!' + [Guid]::NewGuid().ToString('N')
$bytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$jwt = [Convert]::ToBase64String($bytes)

$target = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute='SELECT DATABASE()'
if ($target -ne 'novi_test') { throw "Unexpected database target: $target" }
& $mysql --login-path=novi_test_setup --database=novi_test --execute="CREATE USER IF NOT EXISTS 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; ALTER USER 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; GRANT SELECT,INSERT,UPDATE,DELETE ON novi_test.* TO 'novi_backend_test'@'localhost';"
$env:ConnectionStrings__Default = "Server=localhost;Database=novi_test;UserID=novi_backend_test;Password=$dbPass;CharSet=utf8mb4"
$env:Jwt__Key = $jwt
$env:Jwt__Issuer = 'Novi.Api'
$env:Jwt__Audience = 'Novi.Mobile'
$env:ASPNETCORE_URLS = $api
$env:ASPNETCORE_ENVIRONMENT = 'Production'
$dll = Join-Path $backend 'ReadBookApi\bin\Release\net8.0\ReadBookApi.dll'
$log = Join-Path $env:TEMP 'novi-auth-api.log'
$err = Join-Path $env:TEMP 'novi-auth-api.err.log'
$proc = Start-Process dotnet -ArgumentList "`"$dll`"" -WorkingDirectory (Join-Path $backend 'ReadBookApi') -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
try {
  $ready = $false
  for ($i = 0; $i -lt 40; $i++) {
    try { Invoke-WebRequest "$api/api/novels?page=1&pageSize=1" -UseBasicParsing | Out-Null; $ready = $true; break } catch { Start-Sleep -Milliseconds 500 }
  }
  if (-not $ready) { throw 'Test backend did not start.' }
  $registerBody = @{ fullName='NoVi Locked'; email=$lockedEmail; password=$password; confirmPassword=$password } | ConvertTo-Json
  Invoke-RestMethod "$api/api/auth/register" -Method Post -ContentType 'application/json' -Body $registerBody | Out-Null
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE user SET status=0 WHERE email='$lockedEmail';"
  flutter test integration_test\auth_flow_test.dart -d windows --timeout=120s --dart-define=API_BASE_URL=$api --dart-define=E2E_AUTH_EMAIL=$email --dart-define=E2E_AUTH_PASSWORD=$password --dart-define=E2E_LOCKED_EMAIL=$lockedEmail
  if ($LASTEXITCODE -ne 0) { throw "Auth E2E failed: $LASTEXITCODE" }
} finally {
  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="DELETE FROM user WHERE email IN ('$email','$lockedEmail');" 2>$null
  Remove-Item Env:ConnectionStrings__Default -ErrorAction SilentlyContinue
  Remove-Item Env:Jwt__Key -ErrorAction SilentlyContinue
}
