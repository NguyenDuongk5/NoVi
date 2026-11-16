# Firebase Storage verification

Verified on 2026-10-29 using `novi_test` only.

| Test | Result | Evidence |
|---|---|---|
| Restore and Debug build | PASS | 0 compile errors. |
| Release build after replacing ImageSharp | PASS | `dotnet build ReadBookApi.sln -c Release`: 0 errors; SkiaSharp 3.119.0. |
| Missing JWT | PASS | `POST /api/media/avatar` returned 401. |
| Fake `.jpg` content | PASS | Authenticated request returned 400. |
| Avatar over 2 MiB | PASS | Authenticated request returned 400. |
| Valid PNG without Firebase configuration | PASS | Returned 503 after decode; no upload occurred. |
| Publishing regression | PASS | Both publishing scripts passed; concurrency remained 204/409. |
| Locked account / wrong cover owner | NOT RUN | Database preflight is implemented; repeat with the Firebase integration fixture. |
| Real upload and public read | BLOCKED | Firebase ADC, bucket and read policy are not configured. |
| Database failure cleanup | BLOCKED | Requires a Firebase test prefix and controlled DB failure after upload. |
| Approved cover revision isolation | BLOCKED for real upload | Implemented through pending `novel_revision`; requires real Storage run. |
| Orphan reconciliation code/build | PASS | Admin endpoint: dry-run default, exact `test/`, age gate, all three reference columns. |
| Orphan reconciliation against Firebase | BLOCKED | Credentials/bucket absent; no delete attempted. |
| Firebase environment | BLOCKED | Credential, bucket, prefix and public base URL were missing on 2026-10-29. |

Do not change blocked rows to PASS until object creation, readable URL, database state and cleanup are observed directly.

## Local provider verification — 2026-10-30

| Test | Result | Evidence |
|---|---|---|
| Release build with Local + Firebase providers | PASS | `dotnet build ReadBookApi.sln -c Release --no-restore`: 0 errors. |
| Target database safety | PASS | Integration script stopped unless `SELECT DATABASE()` returned exactly `novi_test`. |
| Real local avatar upload | PASS | PNG decoded, random object written under `wwwroot/uploads/test/avatars`, returned URL was HTTP-readable and matched `user.avatar_url`. |
| Draft cover upload | PASS | Random local cover written/readable and stored directly on the pending novel. |
| Approved cover isolation | PASS | Public `novel.cover_url` stayed unchanged; new URL existed only in pending `novel_revision`. |
| Existing pending revision | PASS | Second upload returned HTTP 409; before/after local file count was unchanged, proving cleanup of the new object. |
| Locked account | PASS | Local avatar upload returned HTTP 403. |
| Wrong cover owner | PASS | Local cover upload returned HTTP 404. |
| Fake JPEG | PASS | Returned HTTP 400 before storage. |
| Firebase provider compatibility | PASS (build/config) | Firebase implementation and its existing `Firebase__*` options remain registered; default provider is Firebase. Real Firebase upload remains BLOCKED because credentials/bucket are intentionally absent. |
| Legacy unauthenticated `/upload/upload-image` | PASS | Disabled with HTTP 410 so it cannot bypass validation/auth/ownership. |
| Local orphan dry-run | NOT RUN | Provider supports listing and shared reference reconciliation; a time-aged orphan fixture was not created in this run. |

Command executed: `tests/local-media-integration.ps1`. It generated secrets at runtime and did not print or commit them.
