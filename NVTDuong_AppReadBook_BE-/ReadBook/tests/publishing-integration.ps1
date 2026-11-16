param(
  [string]$ApiBase = $env:NOVI_API_BASE,
  [string]$ReaderEmail = $env:NOVI_READER_EMAIL,
  [string]$ReaderPassword = $env:NOVI_READER_PASSWORD,
  [string]$AdminEmail = $env:NOVI_ADMIN_EMAIL,
  [string]$AdminPassword = $env:NOVI_ADMIN_PASSWORD
)

$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['Invoke-WebRequest:UseBasicParsing'] = $true
if (-not $ApiBase -or -not $ReaderEmail -or -not $ReaderPassword -or -not $AdminEmail -or -not $AdminPassword) {
  throw 'Set NOVI_API_BASE, NOVI_READER_EMAIL/PASSWORD and NOVI_ADMIN_EMAIL/PASSWORD for novi_test.'
}
$ApiBase = $ApiBase.TrimEnd('/')

function Login([string]$email, [string]$password) {
  (Invoke-RestMethod -Method Post -Uri "$ApiBase/api/auth/login" -ContentType 'application/json' -Body (@{ email=$email; password=$password } | ConvertTo-Json)).accessToken
}
function Headers([string]$token) { @{ Authorization = "Bearer $token" } }
function Json($value) { $value | ConvertTo-Json -Depth 8 -Compress }
function Expect-Status([scriptblock]$action, [int]$expected, [string]$label) {
  try { $response = & $action; $actual = [int]$response.StatusCode }
  catch { $actual = [int]$_.Exception.Response.StatusCode }
  if ($actual -ne $expected) { throw "$label expected HTTP $expected, received $actual" }
}
function Decide([string]$type, [string]$id, [string]$token, [bool]$approve, [string]$reason='') {
  Invoke-WebRequest -Method Post -Uri "$ApiBase/api/admin/moderation/$type/$id/decision" -Headers (Headers $token) -ContentType 'application/json' -Body (Json @{ approve=$approve; reason=$(if ($reason) {$reason} else {$null}) })
}

$reader = Login $ReaderEmail $ReaderPassword
$admin = Login $AdminEmail $AdminPassword
$application = Invoke-RestMethod -Method Post -Uri "$ApiBase/api/author-applications" -Headers (Headers $reader) -ContentType 'application/json' -Body (Json @{ message='novi_test publishing integration' })
Invoke-WebRequest -Method Post -Uri "$ApiBase/api/admin/author-applications/$($application.id)/decision" -Headers (Headers $admin) -ContentType 'application/json' -Body (Json @{ approve=$true; reason=$null }) | Out-Null
$author = Login $ReaderEmail $ReaderPassword

$suffix = [Guid]::NewGuid().ToString('N').Substring(0,8)
$originalTitle = "Publishing test $suffix"
$novelBody = @{ title=$originalTitle; originalAuthor='Integration Test'; sourceType=0; sourceUrl=$null; description='public-v1'; coverUrl=$null; completionStatus=0 }
$novel = Invoke-RestMethod -Method Post -Uri "$ApiBase/api/author/novels" -Headers (Headers $author) -ContentType 'application/json' -Body (Json $novelBody)
Expect-Status { Invoke-WebRequest -Uri "$ApiBase/api/novels/$($novel.id)" } 404 'pending novel is private'
Decide 'novel' $novel.id $admin $true | Out-Null
$publicNovel = Invoke-RestMethod -Uri "$ApiBase/api/novels/$($novel.id)"
if ($publicNovel.title -ne $originalTitle) { throw 'approved novel was not published' }

$novelBody.title = "$originalTitle revised"
$novelBody.description = 'public-v2'
$revision = Invoke-RestMethod -Method Put -Uri "$ApiBase/api/author/novels/$($novel.id)" -Headers (Headers $author) -ContentType 'application/json' -Body (Json $novelBody)
$stillPublic = Invoke-RestMethod -Uri "$ApiBase/api/novels/$($novel.id)"
if ($stillPublic.title -ne $originalTitle) { throw 'pending novel revision changed public content' }
Decide 'novelRevision' $revision.revisionId $admin $true | Out-Null
$revisedPublic = Invoke-RestMethod -Uri "$ApiBase/api/novels/$($novel.id)"
if ($revisedPublic.title -ne $novelBody.title) { throw 'approved novel revision was not applied' }

$chapterBody = @{ chapterNumber=1; title='Chapter public-v1'; content='chapter-public-v1' }
$chapter = Invoke-RestMethod -Method Post -Uri "$ApiBase/api/author/novels/$($novel.id)/chapters" -Headers (Headers $author) -ContentType 'application/json' -Body (Json $chapterBody)
Expect-Status { Invoke-WebRequest -Uri "$ApiBase/api/novels/chapters/$($chapter.id)" } 404 'pending chapter is private'
Decide 'chapter' $chapter.id $admin $true | Out-Null

$chapterBody.title = 'Chapter public-v2'
$chapterBody.content = 'chapter-public-v2'
$chapterRevision = Invoke-RestMethod -Method Put -Uri "$ApiBase/api/author/chapters/$($chapter.id)" -Headers (Headers $author) -ContentType 'application/json' -Body (Json $chapterBody)
$chapterBeforeApproval = Invoke-RestMethod -Uri "$ApiBase/api/novels/chapters/$($chapter.id)"
if ($chapterBeforeApproval.content -ne 'chapter-public-v1') { throw 'pending chapter revision changed public content' }
Decide 'chapterRevision' $chapterRevision.revisionId $admin $true | Out-Null

Invoke-WebRequest -Method Patch -Uri "$ApiBase/api/author/chapters/$($chapter.id)/visibility?visible=false" -Headers (Headers $author) | Out-Null
Expect-Status { Invoke-WebRequest -Uri "$ApiBase/api/novels/chapters/$($chapter.id)" } 404 'hidden chapter is private'
Invoke-WebRequest -Method Patch -Uri "$ApiBase/api/author/chapters/$($chapter.id)/visibility?visible=true" -Headers (Headers $author) | Out-Null
Invoke-WebRequest -Method Delete -Uri "$ApiBase/api/author/chapters/$($chapter.id)" -Headers (Headers $author) | Out-Null
Expect-Status { Invoke-WebRequest -Uri "$ApiBase/api/novels/chapters/$($chapter.id)" } 404 'deleted chapter is private'

Invoke-WebRequest -Method Patch -Uri "$ApiBase/api/author/novels/$($novel.id)/visibility?visible=false" -Headers (Headers $author) | Out-Null
Expect-Status { Invoke-WebRequest -Uri "$ApiBase/api/novels/$($novel.id)" } 404 'hidden novel is private'
Invoke-WebRequest -Method Patch -Uri "$ApiBase/api/author/novels/$($novel.id)/visibility?visible=true" -Headers (Headers $author) | Out-Null
Invoke-WebRequest -Method Delete -Uri "$ApiBase/api/author/novels/$($novel.id)" -Headers (Headers $author) | Out-Null
Expect-Status { Invoke-WebRequest -Uri "$ApiBase/api/novels/$($novel.id)" } 404 'deleted novel is private'

Expect-Status { Invoke-WebRequest -Uri "$ApiBase/manga/all" } 410 'legacy CRUD is disabled'
'PASS publishing integration flow'
