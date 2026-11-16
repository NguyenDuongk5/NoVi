# NoVi Publishing

## Configuration

Never commit secrets. Configure the API process:

```powershell
$env:ConnectionStrings__Default='Server=localhost;Database=novi_test;UserID=novi_test;Password=...'
$env:Jwt__Key='at-least-32-random-bytes-for-local-tests'
```

Roles stored in `user.role`: `0` reader, `1` author, `2` admin. Account status must be `1` for every publishing operation.

## Migration

For a new test database, first run `novi_schema_v1.sql`, then `migrations/002_publishing.sql`. The publishing migration is additive and creates `author_application` and `moderation_decision`. Do not point tests at the production database.

```powershell
mysql --database=novi_test --execute="source C:/path/novi_schema_v1.sql"
mysql --database=novi_test --execute="source C:/path/migrations/002_publishing.sql"
```

The base schema currently contains `USE novi`; when preparing `novi_test`, execute a test-only copy with that statement changed to `USE novi_test`. Never modify or drop the real `novi` database for testing.

## API

All endpoints below require `Authorization: Bearer <token>`.

### Reader requests author role

`POST /api/author-applications`

```json
{ "message": "Tôi muốn đăng tiểu thuyết tự sáng tác." }
```

Admin lists and decides:

- `GET /api/admin/author-applications`
- `POST /api/admin/author-applications/{id}/decision`

```json
{ "approve": false, "reason": "Vui lòng bổ sung thông tin." }
```

### Author novels

- `GET /api/author/novels`
- `GET /api/author/novels/{id}`
- `POST /api/author/novels`
- `PUT /api/author/novels/{id}`
- `PATCH /api/author/novels/{id}/visibility?visible=false`
- `DELETE /api/author/novels/{id}` (soft delete)

Create/update body:

```json
{
  "title": "Tên truyện",
  "originalAuthor": "Tác giả",
  "sourceType": 0,
  "sourceUrl": null,
  "description": "Mô tả",
  "coverUrl": null,
  "completionStatus": 0
}
```

Updating an approved novel returns a `revisionId`; the public row is unchanged until the revision is approved. Pending/rejected novels are updated in place and resubmitted.

### Author chapters

- `GET /api/author/novels/{novelId}/chapters`
- `POST /api/author/novels/{novelId}/chapters`
- `PUT /api/author/chapters/{chapterId}`
- `PATCH /api/author/chapters/{chapterId}/visibility?visible=false`
- `DELETE /api/author/chapters/{chapterId}` (soft delete)

```json
{ "chapterNumber": 1, "title": "Chương 1", "content": "Nội dung..." }
```

Updating an approved chapter creates `chapter_revision` and preserves public content until approval.

### Moderation

- `GET /api/admin/moderation`
- `POST /api/admin/moderation/{type}/{id}/decision`

`type` is `novel`, `chapter`, `novelRevision`, or `chapterRevision`.

```json
{ "approve": true, "reason": null }
```

Rejection requires a reason. Decisions use a transaction, row lock, and conditional update. A repeated/concurrent decision returns HTTP `409`. Admins cannot approve their own submissions. Every successful decision is appended to `moderation_decision`.

## Publishing invariants

- Public queries only return approved, visible and non-deleted novels/chapters.
- Public chapter reads also validate the parent novel.
- New content is pending until approved.
- Approved content is never overwritten by an unapproved edit.
- Owner checks are performed against the database, not request IDs or JWT role alone.
- Legacy `/manga`, `/chapter`, and `/category` routes return HTTP `410`.

## Testing

Set `NOVI_API_BASE` and fresh reader/admin credentials backed by `novi_test`, then run `tests/publishing-integration.ps1`. Run `tests/publishing-smoke.ps1` separately with another fresh reader to verify that two concurrent decisions produce exactly one success and one conflict. See `tests/PUBLISHING_TEST_MATRIX.md` for ownership, inactive-account, self-review, rejection, parent-state, and audit assertions that require dedicated fixtures.

The repository build can run without MySQL. Migration and HTTP integration tests require an explicit test connection and are not considered passed merely because compilation succeeds.
