# NoVi media storage providers

Backend supports two interchangeable providers. Upload endpoints, image validation, authorization, ownership checks and cover revision rules are shared; choosing Local does not create a separate bypass.

## Local provider (no Firebase billing)

Use environment variables; do not put test passwords or JWT keys in source:

```powershell
$env:Media__Provider='Local'
$env:Media__EnvironmentPrefix='test'
$env:Media__LocalRoot='uploads'
$env:Media__PublicBaseUrl='http://localhost:5148'
$env:Media__AllowOrphanDelete='false'
```

Files are written below `ReadBookApi/wwwroot/uploads/{prefix}/avatars` or `covers`. Names are random GUIDs and never use client paths. ASP.NET static files expose them as, for example, `http://localhost:5148/uploads/test/avatars/<random>.png`. For Android Emulator set the public base URL to `http://10.0.2.2:5148` only if that URL is also appropriate for persisted clients; for LAN devices use the backend LAN URL. Production should use HTTPS or a reverse proxy/CDN.

`LocalRoot` must be a relative path below `wwwroot`; absolute paths and traversal are rejected. An interrupted/failed copy removes the partial file. If database persistence or cover revision creation fails, the controller deletes the newly uploaded file. Existing referenced files are never deleted during replacement.

## Firebase provider (preserved)

```powershell
$env:Media__Provider='Firebase'
$env:Firebase__Bucket='project-id.appspot.com'
$env:Firebase__EnvironmentPrefix='test'
$env:Firebase__PublicBaseUrl='https://storage.googleapis.com/project-id.appspot.com'
$env:Firebase__AllowOrphanDelete='false'
```

Firebase credentials remain server-only through `GOOGLE_APPLICATION_CREDENTIALS`. No Firebase key belongs in Flutter. Leaving `Media__Provider` unset defaults to Firebase for backward compatibility.

## API and rules

- `POST /api/media/avatar`: authenticated active user, multipart field `file`, maximum 2 MiB.
- `POST /api/media/novels/{novelId}/cover`: active author and owner, maximum 5 MiB.
- Only decoded JPEG, PNG and WebP are accepted; maximum 10,000 x 10,000 and 40 million pixels.
- Avatar URL is saved to `user.avatar_url`.
- An approved novel receives a pending `novel_revision`; its public cover remains unchanged until approval.
- A pending revision returns HTTP 409 and the just-uploaded local/Firebase object is removed.

## Test on novi_test

The integration script generates all secrets in memory, verifies `SELECT DATABASE() = novi_test`, creates isolated fixtures, uploads real PNG files, reads their returned URLs and checks database/revision state:

```powershell
dotnet build ReadBookApi.sln -c Release
.\tests\local-media-integration.ps1
```

It never accesses `novi`. Uploaded test objects remain under the `test` prefix for orphan dry-run verification; real deletion remains disabled by default.
