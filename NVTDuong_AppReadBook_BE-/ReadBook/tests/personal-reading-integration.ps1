$ErrorActionPreference='Stop'
$mysql='C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$root='C:\Users\thain\Desktop\AppDocTruyen\NVTDuong_AppReadBook_BE-\ReadBook'
$api='http://localhost:5148'
$suffix=[Guid]::NewGuid().ToString('N').Substring(0,10)
$dbPass='T!'+[Guid]::NewGuid().ToString('N')
$bytes=New-Object byte[] 48;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();$rng.GetBytes($bytes);$rng.Dispose();$jwt=[Convert]::ToBase64String($bytes)
& $mysql --login-path=novi_test_setup --database=novi_test --execute="CREATE USER IF NOT EXISTS 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; ALTER USER 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; GRANT SELECT,INSERT,UPDATE,DELETE ON novi_test.* TO 'novi_backend_test'@'localhost';"
$env:ConnectionStrings__Default="Server=localhost;Database=novi_test;UserID=novi_backend_test;Password=$dbPass;CharSet=utf8mb4"
$env:Jwt__Key=$jwt;$env:Jwt__Issuer='Novi.Api';$env:Jwt__Audience='Novi.Mobile';$env:ASPNETCORE_URLS=$api
$log=Join-Path $env:TEMP 'novi-personal-api.log';$err=Join-Path $env:TEMP 'novi-personal-api.err.log'
$proc=Start-Process dotnet -ArgumentList 'run --project ReadBookApi --no-build --no-launch-profile' -WorkingDirectory $root -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
try{
  for($i=0;$i-lt 30;$i++){try{Invoke-WebRequest "$api/swagger/index.html" -UseBasicParsing|Out-Null;break}catch{Start-Sleep -Milliseconds 500}}
  function Reg($name){$email="$name-$suffix@novi.test";$pass='Test!'+$suffix+'aA1';$body=@{fullName=$name;email=$email;password=$pass;confirmPassword=$pass}|ConvertTo-Json;$r=Invoke-RestMethod -Method Post -Uri "$api/api/auth/register" -ContentType application/json -Body $body;return $r}
  function AuthHeaders($t){@{Authorization="Bearer $t"}}
  function Status($action){try{&$action|Out-Null;return 200}catch{return [int]$_.Exception.Response.StatusCode}}
  $u1=Reg 'reader-one';$u2=Reg 'reader-two';$locked=Reg 'locked-reader';$admin=Reg 'admin';$smoke=Reg 'smoke-reader'
  $novel=[Guid]::NewGuid();$chapter=[Guid]::NewGuid();$chapter2=[Guid]::NewGuid();$otherNovel=[Guid]::NewGuid();$otherChapter=[Guid]::NewGuid()
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="INSERT INTO novel(novel_id,uploader_id,title,slug,review_status,visibility) VALUES('$novel','$($u1.user.userId)','Personal $suffix','personal-$suffix',1,0),('$otherNovel','$($u1.user.userId)','Other $suffix','other-$suffix',1,0); INSERT INTO chapter(chapter_id,novel_id,chapter_number,title,content,review_status,visibility) VALUES('$chapter','$novel',1,'Chapter','content',1,0),('$chapter2','$novel',2,'Chapter 2','content',1,0),('$otherChapter','$otherNovel',1,'Other chapter','content',1,0);"
  $saveJobs=1..2|ForEach-Object{Start-Job -ScriptBlock{param($url,$h)Invoke-WebRequest -Method Put -Uri $url -Headers $h -UseBasicParsing|Out-Null} -ArgumentList "$api/api/me/library/$novel",(AuthHeaders $u1.accessToken)};$saveJobs|Wait-Job|Receive-Job;$saveJobs|Remove-Job
  $count=&$mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT COUNT(*) FROM library_item WHERE user_id='$($u1.user.userId)' AND novel_id='$novel'"
  if($count-ne '1'){throw 'library duplicate'}
  $removeJobs=1..2|ForEach-Object{Start-Job -ScriptBlock{param($url,$h)Invoke-WebRequest -Method Delete -Uri $url -Headers $h -UseBasicParsing|Out-Null} -ArgumentList "$api/api/me/library/$novel",(AuthHeaders $u1.accessToken)};$removeJobs|Wait-Job|Receive-Job;$removeJobs|Remove-Job
  $removed=&$mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT COUNT(*) FROM library_item WHERE user_id='$($u1.user.userId)' AND novel_id='$novel'";if($removed-ne '0'){throw 'concurrent remove failed'}
  $wrong=Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$otherChapter/sessions" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing}
  if($wrong-ne 404){throw "wrong chapter $wrong"}
  $session=Invoke-RestMethod -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/sessions" -Headers (AuthHeaders $u1.accessToken)
  $historyBefore=Invoke-RestMethod -Uri "$api/api/me/history?page=1&pageSize=10" -Headers (AuthHeaders $u1.accessToken)
  $p1=@{sessionId=$session.sessionId;sequence=2;positionPercent=70}|ConvertTo-Json
  $pOld=@{sessionId=$session.sessionId;sequence=1;positionPercent=10}|ConvertTo-Json
  Invoke-RestMethod -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $p1|Out-Null
  Invoke-RestMethod -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $pOld|Out-Null
  $historyAfter=Invoke-RestMethod -Uri "$api/api/me/history?page=1&pageSize=10" -Headers (AuthHeaders $u1.accessToken)
  if($historyAfter.totalItems-ne $historyBefore.totalItems){throw 'progress created extra history rows'}
  if((Status {Invoke-WebRequest -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u2.accessToken) -ContentType application/json -Body $p1 -UseBasicParsing})-ne 409){throw 'foreign read session accepted'}
  $continue=Invoke-RestMethod -Uri "$api/api/me/novels/$novel/continue" -Headers (AuthHeaders $u1.accessToken)
  if([decimal]$continue.positionPercent-ne 70){throw 'old progress overwrote new'}
  $session2=Invoke-RestMethod -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter2/sessions" -Headers (AuthHeaders $u1.accessToken)
  $newer=@{sessionId=$session2.sessionId;sequence=0;positionPercent=20}|ConvertTo-Json
  Invoke-RestMethod -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter2/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $newer|Out-Null
  $late=@{sessionId=$session.sessionId;sequence=99;positionPercent=99}|ConvertTo-Json
  Invoke-RestMethod -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $late|Out-Null
  $afterLate=Invoke-RestMethod -Uri "$api/api/me/novels/$novel/continue" -Headers (AuthHeaders $u1.accessToken)
  if($afterLate.chapterId-ne $chapter2.ToString()){throw 'older session overwrote newer session'}
  $reread=Invoke-RestMethod -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/sessions" -Headers (AuthHeaders $u1.accessToken)
  $rereadBody=@{sessionId=$reread.sessionId;sequence=0;positionPercent=5}|ConvertTo-Json
  Invoke-RestMethod -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $rereadBody|Out-Null
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE chapter SET visibility=1 WHERE chapter_id='$chapter'"
  $hiddenContinue=Invoke-RestMethod -Uri "$api/api/me/novels/$novel/continue" -Headers (AuthHeaders $u1.accessToken)
  if($hiddenContinue.available-ne $false){throw 'hidden chapter reported available'}
  $hiddenHistory=Invoke-RestMethod -Uri "$api/api/me/history?page=1&pageSize=10" -Headers (AuthHeaders $u1.accessToken)
  if($hiddenHistory.items[0].available-ne $false){throw 'hidden history reported available'}
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE chapter SET visibility=0 WHERE chapter_id='$chapter'"
  $bad=@{sessionId=$session.sessionId;sequence=3;positionPercent=101}|ConvertTo-Json
  if((Status {Invoke-WebRequest -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $bad -UseBasicParsing})-ne 400){throw 'progress bounds'}
  $jobs=1..2|ForEach-Object{Start-Job -ScriptBlock{param($url,$h)try{(Invoke-WebRequest -Method Post -Uri $url -Headers $h -UseBasicParsing).Content}catch{$_.Exception.Message}} -ArgumentList "$api/api/me/novels/$novel/chapters/$chapter/views",(AuthHeaders $u1.accessToken)}
  $null=$jobs|Wait-Job|Receive-Job;$jobs|Remove-Job
  $views=&$mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT COUNT(*) FROM chapter_view WHERE user_id='$($u1.user.userId)' AND chapter_id='$chapter'"
  if($views-ne '1'){throw "view duplicate $views"}
  $bucket=[math]::Floor([DateTime]::UtcNow.Ticks/([TimeSpan]::TicksPerMinute*30))
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE chapter_view SET view_window=$($bucket-1),viewed_at=UTC_TIMESTAMP() WHERE user_id='$($u1.user.userId)' AND chapter_id='$chapter'"
  $boundary=Invoke-RestMethod -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/views" -Headers (AuthHeaders $u1.accessToken)
  if($boundary.counted-ne $true){throw 'fixed-window boundary did not count'}
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE novel SET review_status=0 WHERE novel_id='$novel'"
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/sessions" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'pending novel session'}
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/views" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'pending novel view'}
  if((Status {Invoke-WebRequest -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $rereadBody -UseBasicParsing})-ne 404){throw 'pending novel progress'}
  $pendingContinue=Invoke-RestMethod -Uri "$api/api/me/novels/$novel/continue" -Headers (AuthHeaders $u1.accessToken);if($pendingContinue.available-ne $false){throw 'pending novel continue'}
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE novel SET review_status=1 WHERE novel_id='$novel'; UPDATE chapter SET review_status=0 WHERE chapter_id='$chapter'"
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/sessions" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'pending chapter session'}
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/views" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'pending chapter view'}
  if((Status {Invoke-WebRequest -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $rereadBody -UseBasicParsing})-ne 404){throw 'pending chapter progress'}
  $pendingChapterContinue=Invoke-RestMethod -Uri "$api/api/me/novels/$novel/continue" -Headers (AuthHeaders $u1.accessToken);if($pendingChapterContinue.available-ne $false){throw 'pending chapter continue'}
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE chapter SET review_status=1,deleted_at=UTC_TIMESTAMP() WHERE chapter_id='$chapter'"
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/sessions" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'deleted chapter session'}
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/views" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'deleted chapter view'}
  if((Status {Invoke-WebRequest -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $rereadBody -UseBasicParsing})-ne 404){throw 'deleted chapter progress'}
  $deletedContinue=Invoke-RestMethod -Uri "$api/api/me/novels/$novel/continue" -Headers (AuthHeaders $u1.accessToken);if($deletedContinue.available-ne $false){throw 'deleted chapter continue'}
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE chapter SET deleted_at=NULL WHERE chapter_id='$chapter'; UPDATE novel SET deleted_at=UTC_TIMESTAMP() WHERE novel_id='$novel'"
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/sessions" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'deleted novel session'}
  if((Status {Invoke-WebRequest -Method Post -Uri "$api/api/me/novels/$novel/chapters/$chapter/views" -Headers (AuthHeaders $u1.accessToken) -UseBasicParsing})-ne 404){throw 'deleted novel view'}
  if((Status {Invoke-WebRequest -Method Put -Uri "$api/api/me/novels/$novel/chapters/$chapter/progress" -Headers (AuthHeaders $u1.accessToken) -ContentType application/json -Body $rereadBody -UseBasicParsing})-ne 404){throw 'deleted novel progress'}
  $deletedNovelContinue=Invoke-RestMethod -Uri "$api/api/me/novels/$novel/continue" -Headers (AuthHeaders $u1.accessToken);if($deletedNovelContinue.available-ne $false){throw 'deleted novel continue'}
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE novel SET deleted_at=NULL WHERE novel_id='$novel'"
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE user SET status=0 WHERE user_id='$($locked.user.userId)'"
  if((Status {Invoke-WebRequest -Uri "$api/api/me/library" -Headers (AuthHeaders $locked.accessToken) -UseBasicParsing})-ne 403){throw 'locked account'}
  $private=Invoke-RestMethod -Uri "$api/api/me/library" -Headers (AuthHeaders $u2.accessToken)
  if($private.totalItems-ne 0){throw 'cross-user library leak'}
  $fake=Join-Path $env:TEMP 'novi-fake.jpg';[IO.File]::WriteAllText($fake,'not an image')
  $large=Join-Path $env:TEMP 'novi-large.jpg';[IO.File]::WriteAllBytes($large,(New-Object byte[] (2*1024*1024+1)))
  $png=Join-Path $env:TEMP 'novi-valid.png';[IO.File]::WriteAllBytes($png,[Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
  $noJwt=& curl.exe -s -o NUL -w '%{http_code}' -F "file=@$png;type=image/png" "$api/api/media/avatar"
  $fakeCode=& curl.exe -s -o NUL -w '%{http_code}' -H "Authorization: Bearer $($u1.accessToken)" -F "file=@$fake;type=image/jpeg" "$api/api/media/avatar"
  $largeCode=& curl.exe -s -o NUL -w '%{http_code}' -H "Authorization: Bearer $($u1.accessToken)" -F "file=@$large;type=image/jpeg" "$api/api/media/avatar"
  $validCode=& curl.exe -s -o NUL -w '%{http_code}' -H "Authorization: Bearer $($u1.accessToken)" -F "file=@$png;type=image/png" "$api/api/media/avatar"
  if($noJwt-ne '401' -or $fakeCode-ne '400' -or ($largeCode-ne '400' -and $largeCode-ne '413') -or $validCode-ne '503'){throw "image validation $noJwt/$fakeCode/$largeCode/$validCode"}
  & $mysql --login-path=novi_test_setup --database=novi_test --execute="UPDATE user SET role=2 WHERE user_id='$($admin.user.userId)'"
  $env:NOVI_API_BASE=$api;$env:NOVI_ADMIN_EMAIL=$admin.user.email;$env:NOVI_ADMIN_PASSWORD='Test!'+$suffix+'aA1'
  $env:NOVI_READER_EMAIL=$u2.user.email;$env:NOVI_READER_PASSWORD='Test!'+$suffix+'aA1'; & "$root\tests\publishing-integration.ps1"
  $env:NOVI_READER_EMAIL=$smoke.user.email; & "$root\tests\publishing-smoke.ps1"
  'PASS SkiaSharp validation 401/400/413-or-400/503'
  'PASS personal reading core'
}finally{Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue}
