$ErrorActionPreference = 'Stop'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$backend = 'C:\Users\thain\Desktop\AppDocTruyen\NVTDuong_AppReadBook_BE-\ReadBook'
$api = 'http://localhost:5154'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$dbPass = 'T!' + [Guid]::NewGuid().ToString('N')
$bytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes); $rng.Dispose()
$jwt = [Convert]::ToBase64String($bytes)
$category = [Guid]::NewGuid().ToString()
$narrowCategory = [Guid]::NewGuid().ToString()
$novels = 1..21 | ForEach-Object { [Guid]::NewGuid().ToString() }
$chapters = 1..21 | ForEach-Object { [Guid]::NewGuid().ToString() }
$categoryName = "BXH E2E $suffix"
$narrowCategoryName = "BXH hẹp $suffix"
$title = "BXH Flutter $suffix"
$pageTwoTitle = "BXH trang hai $suffix"
$ownerId = $null

$target = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute='SELECT DATABASE()'
if ($target -ne 'novi_test') { throw "Refusing target database: $target" }
& $mysql --login-path=novi_test_setup --database=novi_test --execute="CREATE USER IF NOT EXISTS 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; ALTER USER 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; GRANT SELECT,INSERT,UPDATE,DELETE ON novi_test.* TO 'novi_backend_test'@'localhost';"
$env:ConnectionStrings__Default = "Server=localhost;Database=novi_test;UserID=novi_backend_test;Password=$dbPass;CharSet=utf8mb4"
$env:Jwt__Key = $jwt
$env:Jwt__Issuer = 'Novi.Api'
$env:Jwt__Audience = 'Novi.Mobile'
$env:ASPNETCORE_URLS = $api
$env:ASPNETCORE_ENVIRONMENT = 'Production'
$log = Join-Path $env:TEMP 'novi-ranking-flutter-api.log'
$err = Join-Path $env:TEMP 'novi-ranking-flutter-api.err.log'
$dll = Join-Path $backend 'ReadBookApi\bin\Release\net8.0\ReadBookApi.dll'
$proc = Start-Process dotnet -ArgumentList "`"$dll`"" -WorkingDirectory (Split-Path $dll -Parent) -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
try {
  for ($i=0; $i -lt 40; $i++) { try { Invoke-WebRequest "$api/api/novels?page=1&pageSize=1" -UseBasicParsing | Out-Null; break } catch { Start-Sleep -Milliseconds 500 } }
  $password = "Test!${suffix}aA1"
  $fixture = Invoke-RestMethod -Method Post -Uri "$api/api/auth/register" -ContentType application/json -Body (@{fullName='Ranking Flutter';email="ranking-flutter-$suffix@novi.test";password=$password;confirmPassword=$password}|ConvertTo-Json)
  $ownerId = $fixture.user.userId
  $novelValues = @()
  $chapterValues = @()
  $categoryValues = @()
  $viewValues = @()
  for ($i = 0; $i -lt $novels.Count; $i++) {
    $fixtureTitle = if ($i -eq 0) { "$title - tên truyện rất dài để kiểm tra bố cục trên màn hình hẹp" } elseif ($i -eq 20) { $pageTwoTitle } else { "BXH Flutter $($i + 1) $suffix" }
    $completed = if ($i -lt 2) { 1 } else { 0 }
    $novelValues += "('$($novels[$i])','$ownerId','$fixtureTitle','ranking-flutter-$($i + 1)-$suffix','Tác giả NoVi có tên dài',$completed,1,0,DATE_SUB(UTC_TIMESTAMP(), INTERVAL $i MINUTE))"
    $chapterValues += "('$($chapters[$i])','$($novels[$i])',1,'Chương một','Nội dung fixture BXH',1,0,UTC_TIMESTAMP())"
    $categoryValues += "('$($novels[$i])','$category')"
    $viewCount = if ($i -eq 0) { 100 } else { 40 - $i }
    1..$viewCount | ForEach-Object { $viewValues += "('$($chapters[$i])',UTC_TIMESTAMP())" }
  }
  $categoryValues += "('$($novels[0])','$narrowCategory')"
  $fixtureSql = "INSERT INTO category(category_id,name,slug) VALUES('$category','$categoryName','ranking-flutter-$suffix'),('$narrowCategory','$narrowCategoryName','ranking-narrow-$suffix'); INSERT INTO novel(novel_id,uploader_id,title,slug,original_author,completion_status,review_status,visibility,published_at) VALUES $($novelValues -join ','); INSERT INTO novel_category(novel_id,category_id) VALUES $($categoryValues -join ','); INSERT INTO chapter(chapter_id,novel_id,chapter_number,title,content,review_status,visibility,published_at) VALUES $($chapterValues -join ','); INSERT INTO chapter_view(chapter_id,viewed_at) VALUES $($viewValues -join ',');"
  & $mysql --login-path=novi_test_setup --database=novi_test --default-character-set=utf8mb4 --execute=$fixtureSql
  if ($LASTEXITCODE -ne 0) { throw 'Ranking Flutter fixture failed.' }
  flutter test integration_test\ranking_flow_test.dart -d windows --dart-define=API_BASE_URL=$api --dart-define=E2E_RANKING_TITLE=$title --dart-define=E2E_RANKING_CATEGORY=$categoryName --dart-define=E2E_RANKING_NOVEL_ID=$($novels[0]) --dart-define=E2E_NARROW_CATEGORY=$narrowCategoryName --dart-define=E2E_PAGE_TWO_TITLE=$pageTwoTitle --dart-define=E2E_MYSQL=$mysql
  if ($LASTEXITCODE -ne 0) { throw "Flutter ranking E2E failed: $LASTEXITCODE" }
}
finally {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  if ($ownerId) {
    $ids = ($novels | ForEach-Object { "'$_'" }) -join ','
    $oldPreference = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $mysql --login-path=novi_test_setup --default-character-set=utf8mb4 --database=novi_test --execute="DELETE FROM novel_category WHERE novel_id IN ($ids); DELETE FROM chapter WHERE novel_id IN ($ids); DELETE FROM novel WHERE novel_id IN ($ids); DELETE FROM user WHERE user_id='$ownerId'; DELETE FROM category WHERE category_id IN ('$category','$narrowCategory');" 2>$null } catch { }
    $ErrorActionPreference = $oldPreference
  }
}
