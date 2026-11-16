# NoVi read rankings

`GET /api/novels/rankings` is a public read-count ranking. It is not a personal recommendation algorithm and never records a view.

## Query

```http
GET /api/novels/rankings?period=month&categoryId=<uuid>&completed=false&page=1&pageSize=20
```

- `period`: `week`, `month`, or `all`; default `month`.
- `categoryId`: optional active category filter.
- `completed`: when `true`, only novels with `completion_status = 1`.
- `page`: at least 1.
- `pageSize`: 1–50.

Example response:

```json
{
  "items": [
    {
      "rank": 1,
      "novelId": "00000000-0000-0000-0000-000000000000",
      "title": "Example",
      "originalAuthor": "Author",
      "coverUrl": null,
      "description": null,
      "completionStatus": 0,
      "periodViewCount": 42,
      "publishedAt": "2026-01-01T00:00:00",
      "categories": [
        { "categoryId": "00000000-0000-0000-0000-000000000001", "name": "Kỳ ảo", "slug": "ky-ao" }
      ]
    }
  ],
  "period": "month",
  "page": 1,
  "pageSize": 20,
  "totalItems": 1,
  "periodStartUtc": "2026-09-30T17:00:00Z",
  "periodEndUtc": "2026-10-30T00:00:00Z"
}
```

## Rules

- Week starts Monday 00:00 in `Asia/Ho_Chi_Minh`; month starts at local day 1, 00:00. Boundaries are converted to UTC before querying `chapter_view.viewed_at`.
- Only approved, visible, non-deleted novels and currently public chapters qualify.
- Novels with zero qualifying views are omitted.
- Sort: period views descending, `published_at` ascending, then `novel_id` ascending.
- Rank uses `ROW_NUMBER()` over the full filtered result, so it remains continuous across pages.
- View aggregation happens before category retrieval. Categories are loaded in one additional query for the page, preventing both N+1 and multi-category count multiplication.
- Existing view deduplication remains owned by the view-write endpoint; ranking is read-only.

## Migration and test

Verify `SELECT DATABASE()` returns `novi_test`, then apply:

```powershell
mysql --login-path=novi_test_setup --database=novi_test < ..\NVTDuong_AppReadBook_DB\migrations\004_read_rankings.sql
powershell -ExecutionPolicy Bypass -File tests\rankings-integration.ps1
```

The migration only adds `idx_chapter_view_period(viewed_at, chapter_id)` and is idempotent.
