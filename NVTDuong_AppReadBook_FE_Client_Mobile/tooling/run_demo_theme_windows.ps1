param([switch]$ReaderOnly)
$ErrorActionPreference = 'Stop'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$backend = 'C:\Users\thain\Desktop\AppDocTruyen\NVTDuong_AppReadBook_BE-\ReadBook'
$api = 'http://localhost:5156'
$dbPass = 'T!' + [Guid]::NewGuid().ToString('N')
$bytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes); $rng.Dispose()
$jwt = [Convert]::ToBase64String($bytes)
$suffix = [Guid]::NewGuid().ToString('N').Substring(0,10)
$demoEmail = "demo-reader-$suffix@novi.test"
$demoPassword = "Demo!${suffix}aA1"

$target = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute='SELECT DATABASE()'
if ($target -ne 'novi_test') { throw "Từ chối database đích: $target" }
& $mysql --login-path=novi_test_setup --database=novi_test --execute="CREATE USER IF NOT EXISTS 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; ALTER USER 'novi_backend_test'@'localhost' IDENTIFIED BY '$dbPass'; GRANT SELECT,INSERT,UPDATE,DELETE ON novi_test.* TO 'novi_backend_test'@'localhost';"
$env:ConnectionStrings__Default = "Server=localhost;Database=novi_test;UserID=novi_backend_test;Password=$dbPass;CharSet=utf8mb4"
$env:Jwt__Key = $jwt
$env:Jwt__Issuer = 'Novi.Api'
$env:Jwt__Audience = 'Novi.Mobile'
$env:ASPNETCORE_URLS = $api
$env:ASPNETCORE_ENVIRONMENT = 'Production'
$env:Media__Provider = 'Local'
$env:Media__PublicBaseUrl = $api
$dll = Join-Path $backend 'ReadBookApi\bin\Release\net8.0\ReadBookApi.dll'
$log = Join-Path $env:TEMP 'novi-demo-theme-api.log'
$err = Join-Path $env:TEMP 'novi-demo-theme-api.err.log'
$proc = Start-Process dotnet -ArgumentList "`"$dll`"" -WorkingDirectory (Join-Path $backend 'ReadBookApi') -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
try {
  $ready = $false
  for ($i=0; $i -lt 40; $i++) {
    try { Invoke-WebRequest "$api/api/novels?page=1&pageSize=1" -UseBasicParsing | Out-Null; $ready=$true; break } catch { Start-Sleep -Milliseconds 500 }
  }
  if (-not $ready) { throw 'Backend test không khởi động.' }
  $response = Invoke-RestMethod "$api/api/novels/91000000-0000-0000-0000-000000000001"
  if ($response.title -ne 'Bên Nhau Trọn Đời' -or $response.coverUrl -notlike '/uploads/test/demo-covers/*') { throw 'API không trả đúng truyện demo.' }
  $image = Invoke-WebRequest "$api/uploads/test/demo-covers/ben-nhau-tron-doi.jpg" -UseBasicParsing
  if ($image.StatusCode -ne 200 -or $image.Headers.'Content-Type' -notlike 'image/jpeg*') { throw 'Ảnh Media Local không đọc được.' }
  if (-not $ReaderOnly) {
    flutter test integration_test\demo_theme_test.dart -d windows --dart-define=API_BASE_URL=$api
    if ($LASTEXITCODE -ne 0) { throw "Windows integration thất bại: $LASTEXITCODE" }
  }
  flutter test integration_test\demo_reader_test.dart -d windows --timeout=120s --dart-define=API_BASE_URL=$api --dart-define=E2E_DEMO_EMAIL=$demoEmail --dart-define=E2E_DEMO_PASSWORD=$demoPassword --dart-define=E2E_MYSQL=$mysql
  if ($LASTEXITCODE -ne 0) { throw "Demo reader integration thất bại: $LASTEXITCODE" }
  if ($ReaderOnly) { return }
  flutter build windows --debug --dart-define=API_BASE_URL=$api
  if ($LASTEXITCODE -ne 0) { throw "Windows build chụp ảnh thất bại: $LASTEXITCODE" }

  Add-Type -AssemblyName System.Drawing
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NoviWin32 {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hgt, bool repaint);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@
  $output = Join-Path (Get-Location) 'artifacts\screenshots'
  New-Item -ItemType Directory -Force -Path $output | Out-Null
  function Save-NoviWindow([IntPtr]$handle, [string]$name) {
    $rect = New-Object NoviWin32+Rect
    [NoviWin32]::GetWindowRect($handle, [ref]$rect) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size)
    $bitmap.Save((Join-Path $output $name),[System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
  }
  function Click-Novi([IntPtr]$handle,[int]$clientX,[int]$clientY) {
    $rect = New-Object NoviWin32+Rect
    [NoviWin32]::GetWindowRect($handle,[ref]$rect) | Out-Null
    [NoviWin32]::SetCursorPos($rect.Left+$clientX,$rect.Top+32+$clientY) | Out-Null
    [NoviWin32]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [NoviWin32]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 2
  }
  $app = Start-Process (Join-Path (Get-Location) 'build\windows\x64\runner\Debug\flutter_application_1.exe') -PassThru
  try {
    for($i=0;$i -lt 30 -and $app.MainWindowHandle -eq 0;$i++){Start-Sleep -Milliseconds 300;$app.Refresh()}
    $handle=$app.MainWindowHandle
    [NoviWin32]::MoveWindow($handle,100,80,410,900,$true) | Out-Null
    [NoviWin32]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Seconds 4
    Save-NoviWindow $handle 'novi_home_light.png'
    Click-Novi $handle 355 42
    Save-NoviWindow $handle 'novi_home_dark.png'
    Click-Novi $handle 355 178
    Save-NoviWindow $handle 'novi_ranking_dark.png'
    Click-Novi $handle 28 28
    Click-Novi $handle 355 42
    Click-Novi $handle 355 178
    Save-NoviWindow $handle 'novi_ranking_light.png'
  } finally { Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue }
}
finally {
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  $testUserId = & $mysql --login-path=novi_test_setup --database=novi_test --batch --skip-column-names --execute="SELECT user_id FROM user WHERE email='$demoEmail' LIMIT 1"
  if ($testUserId) {
    & $mysql --login-path=novi_test_setup --database=novi_test --execute="DELETE FROM chapter_view WHERE user_id='$testUserId'; DELETE FROM user WHERE user_id='$testUserId';"
  }
}
