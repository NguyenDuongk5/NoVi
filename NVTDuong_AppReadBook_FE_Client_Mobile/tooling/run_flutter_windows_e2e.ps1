$ErrorActionPreference = 'Stop'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$backend = 'C:\Users\thain\Desktop\AppDocTruyen\NVTDuong_AppReadBook_BE-\ReadBook'
$api = 'http://localhost:5148'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$dbPass = 'T!' + [Guid]::NewGuid().ToString('N')
$bytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes); $rng.Dispose()
$jwt = [Convert]::ToBase64String($bytes)
$password = 'Test!' + $suffix + 'aA1'
$email1 = "flutter-one-$suffix@novi.test"
$email2 = "flutter-two-$suffix@novi.test"
$title = "Flutter E2E $suffix"
$categoryName = "E2E Flutter $suffix"
$novel = [Guid]::NewGuid().ToString()
$chapter1 = [Guid]::NewGuid().ToString()
$chapter2 = [Guid]::NewGuid().ToString()
$category = [Guid]::NewGuid().ToString()

$target = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute='SELECT DATABASE()'
if ($target -ne 'novi_test') { throw "Refusing target database: $target" }
& $mysql --login-path=novi_test_setup --database=novi_test --execute="CREATE USER IF NOT EXISTS 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; ALTER USER 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; GRANT SELECT,INSERT,UPDATE,DELETE ON novi_test.* TO 'novi_backend_test'@'localhost';"
$env:ConnectionStrings__Default = "Server=localhost;Database=novi_test;UserID=novi_backend_test;Password=$dbPass;CharSet=utf8mb4"
$env:Jwt__Key = $jwt
$env:Jwt__Issuer = 'Novi.Api'
$env:Jwt__Audience = 'Novi.Mobile'
$env:ASPNETCORE_URLS = $api
$log = Join-Path $env:TEMP 'novi-flutter-e2e-api.log'
$err = Join-Path $env:TEMP 'novi-flutter-e2e-api.err.log'
$proc = Start-Process dotnet -ArgumentList 'run --project ReadBookApi --no-build --no-launch-profile' -WorkingDirectory $backend -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
try {
  $ready = $false
  for ($i=0; $i -lt 40; $i++) { try { Invoke-WebRequest "$api/api/novels?page=1&pageSize=1" -UseBasicParsing | Out-Null; $ready=$true; break } catch { Start-Sleep -Milliseconds 500 } }
  if (!$ready) { throw 'Backend did not become ready; inspect temp logs.' }
  $body = @{fullName='Flutter Fixture';email="fixture-$suffix@novi.test";password=$password;confirmPassword=$password}|ConvertTo-Json
  $fixture = Invoke-RestMethod -Method Post -Uri "$api/api/auth/register" -ContentType application/json -Body $body
  $paragraph = ('Flutter scroll and progress fixture content. ' * 80).Replace("'", "''")
  & $mysql --login-path=novi_test_setup --database=novi_test --default-character-set=utf8mb4 --execute="INSERT INTO category(category_id,name,slug) VALUES('$category','$categoryName','e2e-flutter-$suffix'); INSERT INTO novel(novel_id,uploader_id,title,slug,original_author,description,review_status,visibility,published_at) VALUES('$novel','$($fixture.user.userId)','$title','flutter-e2e-$suffix','NoVi E2E','Flutter E2E fixture',1,0,UTC_TIMESTAMP()); INSERT INTO novel_category(novel_id,category_id) VALUES('$novel','$category'); INSERT INTO chapter(chapter_id,novel_id,chapter_number,title,content,review_status,visibility,published_at) VALUES('$chapter1','$novel',1,'Chapter one','$paragraph',1,0,UTC_TIMESTAMP()),('$chapter2','$novel',2,'Chapter two','$paragraph',1,0,UTC_TIMESTAMP());"
  if ($LASTEXITCODE -ne 0) { throw "Fixture SQL failed with exit code $LASTEXITCODE" }
  flutter test integration_test\reader_flow_test.dart -d windows --dart-define=API_BASE_URL=$api --dart-define=E2E_NOVEL_TITLE=$title --dart-define=E2E_CATEGORY_NAME=$categoryName --dart-define=E2E_NOVEL_ID=$novel --dart-define=E2E_CHAPTER_ID=$chapter1 --dart-define=E2E_EMAIL_1=$email1 --dart-define=E2E_EMAIL_2=$email2 --dart-define=E2E_PASSWORD=$password --dart-define=E2E_MYSQL=$mysql
  if ($LASTEXITCODE -ne 0) { throw "Flutter E2E failed with exit code $LASTEXITCODE" }
} finally {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}
