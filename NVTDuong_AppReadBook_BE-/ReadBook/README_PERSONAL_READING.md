# NoVi personal library and reading

All endpoints require JWT and derive the user id from the token. Locked users receive 403. Anonymous view counting is not supported yet.

## API

- `PUT /api/me/library/{novelId}` and `DELETE /api/me/library/{novelId}` are idempotent.
- `GET /api/me/library?page=1&pageSize=20&sort=saved|updated|title` returns only the caller's saved rows. A saved novel that is later hidden/deleted remains visible in this private list so the client can explain its state; public reading endpoints still reject it.
- `GET /api/me/history?page=1&pageSize=20` returns the caller's newest history first. It contains identifiers, titles, chapter number, `readAt` and `available`; it never contains chapter content.
- `POST /api/me/novels/{novelId}/chapters/{chapterId}/sessions` creates a server-timestamped read session.
- `PUT /api/me/novels/{novelId}/chapters/{chapterId}/progress` body: `{ "sessionId":"uuid", "sequence":1, "positionPercent":42.5 }`.
- `GET /api/me/novels/{novelId}/continue` returns the saved chapter and `available`. If the parent/chapter later becomes hidden/deleted, metadata is returned with `available:false`; content is never returned.
- `POST /api/me/novels/{novelId}/chapters/{chapterId}/views` counts a view only once per authenticated user/chapter/window.

Progress requires 0..100. Within one session only a greater sequence wins. A newer server-issued session wins over an older session, so delayed requests cannot overwrite it. Starting a new session explicitly allows rereading an earlier chapter. Saving progress never increments views.

A history row is created only after a public-readable chapter successfully opens a new read session. Percentage updates do not create history rows, including repeated and stale progress requests. When a saved history target later becomes pending, hidden or soft-deleted, the private history row remains but is returned with `available:false` and metadata only.

`Reading__ViewDeduplicationMinutes` defaults to 30 and is clamped to 1..1440. This is a fixed server-time bucket, not a rolling minimum interval from the last counted view. Therefore two views a few seconds apart can both count when they fall on opposite sides of a bucket boundary. The server chooses identity, clock and bucket. `INSERT IGNORE` plus the unique database key prevents duplicates inside the same bucket, including concurrent requests.

Apply `migrations/003_personal_reading.sql` to `novi_test` after `002_publishing.sql`.
