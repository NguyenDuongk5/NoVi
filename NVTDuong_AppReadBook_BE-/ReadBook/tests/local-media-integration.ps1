$ErrorActionPreference = 'Stop'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$root = 'C:\Users\thain\Desktop\AppDocTruyen\NVTDuong_AppReadBook_BE-\ReadBook'
$api = 'http://localhost:5148'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$dbPass = 'T!' + [Guid]::NewGuid().ToString('N')
$password = 'Test!' + $suffix + 'aA1'
$bytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes); $rng.Dispose()
$jwt = [Convert]::ToBase64String($bytes)

$target = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute='SELECT DATABASE()'
if ($target -ne 'novi_test') { throw "Refusing target database: $target" }
& $mysql --login-path=novi_test_setup --database=novi_test --execute="CREATE USER IF NOT EXISTS 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; ALTER USER 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; GRANT SELECT,INSERT,UPDATE,DELETE ON novi_test.* TO 'novi_backend_test'@'localhost';"
if ($LASTEXITCODE -ne 0) { throw 'Could not prepare novi_test backend user.' }

$env:ConnectionStrings__Default = "Server=localhost;Database=novi_test;UserID=novi_backend_test;Password=$dbPass;CharSet=utf8mb4"
$env:Jwt__Key = $jwt
$env:Jwt__Issuer = 'Novi.Api'
$env:Jwt__Audience = 'Novi.Mobile'
$env:ASPNETCORE_URLS = $api
$env:Media__Provider = 'Local'
$env:Media__EnvironmentPrefix = 'test'
$env:Media__LocalRoot = 'uploads'
$env:Media__PublicBaseUrl = $api
$env:Media__AllowOrphanDelete = 'false'
$log = Join-Path $env:TEMP 'novi-local-media-api.log'
$err = Join-Path $env:TEMP 'novi-local-media-api.err.log'
$proc = Start-Process dotnet -ArgumentList 'run --project ReadBookApi -c Release --no-build --no-launch-profile' -WorkingDirectory $root -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
try {
  $ready = $false
  for ($i=0; $i -lt 40; $i++) { try { Invoke-WebRequest "$api/api/novels?page=1&pageSize=1" -UseBasicParsing | Out-Null; $ready=$true; break } catch { Start-Sleep -Milliseconds 500 } }
  if (!$ready) { throw 'Backend did not become ready; inspect temp logs.' }
  function Register($name) {
    $body = @{fullName=$name;email="$name-$suffix@novi.test";password=$password;confirmPassword=$password}|ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$api/api/auth/register" -ContentType application/json -Body $body
  }
  $author = Register 'local-author'
  $other = Register 'local-other'
  $locked = Register 'local-locked'
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE user SET role=1 WHERE user_id='$($author.user.userId)'; UPDATE user SET role=1 WHERE user_id='$($other.user.userId)'; UPDATE user SET status=0 WHERE user_id='$($locked.user.userId)';"
  $loginBody = @{email=$author.user.email;password=$password}|ConvertTo-Json
  $author = Invoke-RestMethod -Method Post -Uri "$api/api/auth/login" -ContentType application/json -Body $loginBody
  $draft = [Guid]::NewGuid().ToString(); $published = [Guid]::NewGuid().ToString(); $otherNovel = [Guid]::NewGuid().ToString()
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="INSERT INTO novel(novel_id,uploader_id,title,slug,review_status,visibility) VALUES('$draft','$($author.user.userId)','Local Draft $suffix','local-draft-$suffix',0,0),('$published','$($author.user.userId)','Local Published $suffix','local-published-$suffix',1,0),('$otherNovel','$($other.user.userId)','Other Local $suffix','other-local-$suffix',0,0);"
  if ($LASTEXITCODE -ne 0) { throw 'Could not create local media fixtures.' }

  $png = Join-Path $env:TEMP "novi-local-$suffix.png"
  [IO.File]::WriteAllBytes($png,[Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
  $fake = Join-Path $env:TEMP "novi-local-$suffix.jpg"; [IO.File]::WriteAllText($fake,'not an image')
  $authHeader = "Authorization: Bearer $($author.accessToken)"

  $avatar = (& curl.exe -sS -f -H $authHeader -F "file=@$png;type=image/png" "$api/api/media/avatar") | ConvertFrom-Json
  if (!$avatar.url.StartsWith("$api/uploads/test/avatars/")) { throw 'Unexpected local avatar URL.' }
  Invoke-WebRequest $avatar.url -UseBasicParsing | Out-Null
  $storedAvatar = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT avatar_url FROM user WHERE user_id='$($author.user.userId)'"
  if ($storedAvatar -ne $avatar.url) { throw 'Avatar URL was not persisted.' }

  $draftCover = (& curl.exe -sS -f -H $authHeader -F "file=@$png;type=image/png" "$api/api/media/novels/$draft/cover") | ConvertFrom-Json
  if ($draftCover.pendingApproval -ne $false) { throw 'Draft cover unexpectedly created a revision.' }
  Invoke-WebRequest $draftCover.url -UseBasicParsing | Out-Null

  $publicBefore = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT COALESCE(cover_url,'') FROM novel WHERE novel_id='$published'"
  $publishedCover = (& curl.exe -sS -f -H $authHeader -F "file=@$png;type=image/png" "$api/api/media/novels/$published/cover") | ConvertFrom-Json
  if ($publishedCover.pendingApproval -ne $true -or !$publishedCover.revisionId) { throw 'Published cover did not create a revision.' }
  $publicAfter = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT COALESCE(cover_url,'') FROM novel WHERE novel_id='$published'"
  $revisionUrl = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT cover_url FROM novel_revision WHERE revision_id='$($publishedCover.revisionId)'"
  if ($publicAfter -ne $publicBefore -or $revisionUrl -ne $publishedCover.url) { throw 'Published cover isolation failed.' }
  Invoke-WebRequest $publishedCover.url -UseBasicParsing | Out-Null

  $filesBefore = @(Get-ChildItem "$root\ReadBookApi\wwwroot\uploads\test" -File -Recurse).Count
  $conflictCode = & curl.exe -s -o NUL -w '%{http_code}' -H $authHeader -F "file=@$png;type=image/png" "$api/api/media/novels/$published/cover"
  $filesAfter = @(Get-ChildItem "$root\ReadBookApi\wwwroot\uploads\test" -File -Recurse).Count
  if ($conflictCode -ne '409' -or $filesAfter -ne $filesBefore) { throw 'Pending revision conflict left an object behind.' }

  $wrongOwner = & curl.exe -s -o NUL -w '%{http_code}' -H $authHeader -F "file=@$png;type=image/png" "$api/api/media/novels/$otherNovel/cover"
  $lockedCode = & curl.exe -s -o NUL -w '%{http_code}' -H "Authorization: Bearer $($locked.accessToken)" -F "file=@$png;type=image/png" "$api/api/media/avatar"
  $fakeCode = & curl.exe -s -o NUL -w '%{http_code}' -H $authHeader -F "file=@$fake;type=image/jpeg" "$api/api/media/avatar"
  $legacyCode = & curl.exe -s -o NUL -w '%{http_code}' -F "file=@$png;type=image/png" "$api/upload/upload-image"
  if ($wrongOwner -ne '404' -or $lockedCode -ne '403' -or $fakeCode -ne '400' -or $legacyCode -ne '410') { throw "Validation/authorization failed: $wrongOwner/$lockedCode/$fakeCode/$legacyCode" }

  "PASS local media integration"
  "PASS avatar URL persisted and readable"
  "PASS draft cover and published cover revision isolation"
  "PASS conflict cleanup and authorization validation"
} finally {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}
