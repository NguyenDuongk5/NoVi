$ErrorActionPreference = 'Stop'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$root = Split-Path $PSScriptRoot -Parent
$api = 'http://localhost:5153'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$dbPass = 'T!' + [Guid]::NewGuid().ToString('N')
$bytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$jwt = [Convert]::ToBase64String($bytes)

$target = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute='SELECT DATABASE()'
if ($target -ne 'novi_test') { throw "Refusing database target: $target" }

& $mysql --login-path=novi_test_setup --database=novi_test --execute="CREATE USER IF NOT EXISTS 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; ALTER USER 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; GRANT SELECT,INSERT,UPDATE,DELETE ON novi_test.* TO 'novi_backend_test'@'localhost';"
$env:ConnectionStrings__Default = "Server=localhost;Database=novi_test;UserID=novi_backend_test;Password=$dbPass;CharSet=utf8mb4"
$env:Jwt__Key = $jwt
$env:Jwt__Issuer = 'Novi.Api'
$env:Jwt__Audience = 'Novi.Mobile'
$env:ASPNETCORE_URLS = $api
$env:ASPNETCORE_ENVIRONMENT = 'Production'

$log = Join-Path $env:TEMP 'novi-rankings-api.log'
$err = Join-Path $env:TEMP 'novi-rankings-api.err.log'
$dll = Join-Path $root 'ReadBookApi\bin\Release\net8.0\ReadBookApi.dll'
$proc = Start-Process dotnet -ArgumentList "`"$dll`"" -WorkingDirectory (Split-Path $dll -Parent) -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err

$novels = 1..8 | ForEach-Object { [Guid]::NewGuid().ToString() }
$chapters = 1..8 | ForEach-Object { [Guid]::NewGuid().ToString() }
$categoryA = [Guid]::NewGuid().ToString()
$categoryB = [Guid]::NewGuid().ToString()
$ownerId = $null

try {
  for ($i = 0; $i -lt 40; $i++) {
    try { Invoke-WebRequest "$api/swagger/index.html" -UseBasicParsing | Out-Null; break }
    catch { Start-Sleep -Milliseconds 500 }
  }
  if ($proc.HasExited) { throw "API failed to start. See $err" }

  $email = "ranking-$suffix@novi.test"
  $password = "Test!${suffix}aA1"
  $registration = Invoke-RestMethod -Method Post -Uri "$api/api/auth/register" -ContentType application/json -Body (@{
      fullName = 'Ranking fixture'; email = $email; password = $password; confirmPassword = $password
    } | ConvertTo-Json)
  $ownerId = $registration.user.userId

  $tz = [TimeZoneInfo]::FindSystemTimeZoneById('SE Asia Standard Time')
  $utcNow = [DateTime]::UtcNow
  $localNow = [TimeZoneInfo]::ConvertTimeFromUtc($utcNow, $tz)
  $weekStartLocal = $localNow.Date.AddDays(-(([int]$localNow.DayOfWeek + 6) % 7))
  $monthStartLocal = [DateTime]::new($localNow.Year, $localNow.Month, 1)
  $weekStartUtc = [TimeZoneInfo]::ConvertTimeToUtc($weekStartLocal, $tz)
  $monthStartUtc = [TimeZoneInfo]::ConvertTimeToUtc($monthStartLocal, $tz)
  function SqlDate([DateTime]$value) { $value.ToString('yyyy-MM-dd HH:mm:ss') }

  $sql = @"
INSERT INTO category(category_id,name,slug) VALUES
('$categoryA','Ranking A $suffix','ranking-a-$suffix'),('$categoryB','Ranking B $suffix','ranking-b-$suffix');
INSERT INTO novel(novel_id,uploader_id,title,slug,original_author,completion_status,review_status,visibility,published_at) VALUES
('$($novels[0])','$ownerId','Rank One $suffix','rank-one-$suffix','Author',0,1,0,'2026-01-02 00:00:00'),
('$($novels[1])','$ownerId','Rank Tie Earlier $suffix','rank-tie-$suffix','Author',0,1,0,'2026-01-01 00:00:00'),
('$($novels[2])','$ownerId','Rank Month $suffix','rank-month-$suffix','Author',0,1,0,'2026-01-03 00:00:00'),
('$($novels[3])','$ownerId','Hidden Novel $suffix','hidden-rank-$suffix','Author',0,1,1,'2026-01-04 00:00:00'),
('$($novels[4])','$ownerId','Hidden Chapter $suffix','hidden-chapter-$suffix','Author',0,1,0,'2026-01-05 00:00:00'),
('$($novels[5])','$ownerId','Pending Novel $suffix','pending-rank-$suffix','Author',0,0,0,'2026-01-06 00:00:00'),
('$($novels[6])','$ownerId','Deleted Novel $suffix','deleted-rank-$suffix','Author',0,1,0,'2026-01-07 00:00:00'),
('$($novels[7])','$ownerId','Completed Multi Category $suffix','completed-rank-$suffix','Author',1,1,0,'2026-01-08 00:00:00');
UPDATE novel SET deleted_at=UTC_TIMESTAMP() WHERE novel_id='$($novels[6])';
INSERT INTO chapter(chapter_id,novel_id,chapter_number,title,content,review_status,visibility,published_at) VALUES
('$($chapters[0])','$($novels[0])',1,'Chapter','content',1,0,'2026-01-02 00:00:00'),
('$($chapters[1])','$($novels[1])',1,'Chapter','content',1,0,'2026-01-01 00:00:00'),
('$($chapters[2])','$($novels[2])',1,'Chapter','content',1,0,'2026-01-03 00:00:00'),
('$($chapters[3])','$($novels[3])',1,'Chapter','content',1,0,'2026-01-04 00:00:00'),
('$($chapters[4])','$($novels[4])',1,'Chapter','content',1,1,'2026-01-05 00:00:00'),
('$($chapters[5])','$($novels[5])',1,'Chapter','content',1,0,'2026-01-06 00:00:00'),
('$($chapters[6])','$($novels[6])',1,'Chapter','content',1,0,'2026-01-07 00:00:00'),
('$($chapters[7])','$($novels[7])',1,'Chapter','content',1,0,'2026-01-08 00:00:00');
INSERT INTO novel_category(novel_id,category_id) VALUES
('$($novels[0])','$categoryA'),('$($novels[1])','$categoryA'),('$($novels[2])','$categoryB'),
('$($novels[3])','$categoryA'),('$($novels[4])','$categoryA'),('$($novels[5])','$categoryA'),('$($novels[6])','$categoryA'),
('$($novels[7])','$categoryA'),('$($novels[7])','$categoryB');
INSERT INTO chapter_view(chapter_id,viewed_at) VALUES
('$($chapters[0])','$(SqlDate $weekStartUtc.AddSeconds(1))'),('$($chapters[0])','$(SqlDate $utcNow.AddMinutes(-2))'),('$($chapters[0])','$(SqlDate $utcNow.AddMinutes(-1))'),
('$($chapters[0])','$(SqlDate $weekStartUtc.AddSeconds(-1))'),
('$($chapters[1])','$(SqlDate $weekStartUtc.AddSeconds(2))'),('$($chapters[1])','$(SqlDate $utcNow.AddMinutes(-4))'),('$($chapters[1])','$(SqlDate $utcNow.AddMinutes(-3))'),
('$($chapters[2])','$(SqlDate $monthStartUtc.AddSeconds(1))'),('$($chapters[2])','$(SqlDate $weekStartUtc.AddSeconds(-2))'),
('$($chapters[3])','$(SqlDate $utcNow.AddMinutes(-1))'),('$($chapters[4])','$(SqlDate $utcNow.AddMinutes(-1))'),
('$($chapters[5])','$(SqlDate $utcNow.AddMinutes(-1))'),('$($chapters[6])','$(SqlDate $utcNow.AddMinutes(-1))'),
('$($chapters[7])','$(SqlDate $utcNow.AddMinutes(-6))'),('$($chapters[7])','$(SqlDate $utcNow.AddMinutes(-5))');
"@
  $sql | & $mysql --login-path=novi_test_setup --database=novi_test --default-character-set=utf8mb4
  if ($LASTEXITCODE -ne 0) { throw 'Fixture insert failed.' }

  $week = Invoke-RestMethod "$api/api/novels/rankings?period=week&categoryId=$categoryA&page=1&pageSize=20"
  if ($week.totalItems -ne 3) { throw "Week expected 3, got $($week.totalItems)" }
  if ($week.items[0].novelId -ne $novels[1] -or $week.items[1].novelId -ne $novels[0]) { throw 'Stable tie ordering failed.' }
  if ($week.items[0].rank -ne 1 -or $week.items[1].rank -ne 2) { throw 'Rank numbering failed.' }
  if ($week.items[2].periodViewCount -ne 2) { throw 'Multi-category view count was multiplied.' }

  $month = Invoke-RestMethod "$api/api/novels/rankings?period=month&categoryId=$categoryA&page=1&pageSize=20"
  $n1 = $month.items | Where-Object novelId -eq $novels[0]
  if ($n1.periodViewCount -ne 4) { throw "Month boundary expected 4, got $($n1.periodViewCount)" }

  $page2 = Invoke-RestMethod "$api/api/novels/rankings?period=month&categoryId=$categoryA&page=2&pageSize=2"
  if ($page2.items[0].rank -ne 3) { throw 'Rank did not continue across pages.' }
  $completed = Invoke-RestMethod "$api/api/novels/rankings?period=week&categoryId=$categoryA&completed=true&page=1&pageSize=20"
  if ($completed.totalItems -ne 1 -or $completed.items[0].novelId -ne $novels[7]) { throw 'Completed filter failed.' }
  $category = Invoke-RestMethod "$api/api/novels/rankings?period=month&categoryId=$categoryB&page=1&pageSize=20"
  if ($category.totalItems -ne 2) { throw 'Category filter failed.' }
  try { Invoke-WebRequest "$api/api/novels/rankings?period=year" -UseBasicParsing | Out-Null; throw 'Invalid period accepted.' }
  catch { if ([int]$_.Exception.Response.StatusCode -ne 400) { throw } }

  Write-Output 'PASS rankings integration'
  Write-Output 'PASS Vietnam week/month boundaries and stable tie ordering'
  Write-Output 'PASS visibility, multi-category, combined filters and pagination'
}
finally {
  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
  if ($ownerId) {
    $ids = ($novels | ForEach-Object { "'$_'" }) -join ','
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      & $mysql --login-path=novi_test_setup --default-character-set=utf8mb4 --database=novi_test --execute="DELETE FROM novel_category WHERE novel_id IN ($ids); DELETE FROM chapter WHERE novel_id IN ($ids); DELETE FROM novel WHERE novel_id IN ($ids); DELETE FROM user WHERE user_id='$ownerId'; DELETE FROM category WHERE category_id IN ('$categoryA','$categoryB');" 2>$null
    } catch { }
    $ErrorActionPreference = $oldPreference
  }
  Remove-Item Env:ConnectionStrings__Default, Env:Jwt__Key, Env:Jwt__Issuer, Env:Jwt__Audience, Env:ASPNETCORE_URLS, Env:ASPNETCORE_ENVIRONMENT -ErrorAction SilentlyContinue
}
