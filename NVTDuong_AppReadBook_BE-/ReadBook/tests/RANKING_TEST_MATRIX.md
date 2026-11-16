# Ranking test matrix — 30/10/2026

| Test group | Result | Evidence |
|---|---|---|
| Migration targets `novi_test` and period index exists | PASS | Verified `SELECT DATABASE()` before applying `004_read_rankings.sql`; index present. |
| Release backend build | PASS | `dotnet build ReadBookApi.sln -c Release --no-restore`; 0 errors. Existing legacy nullable warnings remain. |
| Week/month Vietnam boundaries | PASS | Fixture placed views immediately before/after computed local boundaries; API counts matched. |
| Stable ties | PASS | Equal view counts ordered by earlier `published_at`, then stable id rule. |
| Continuous pagination ranks | PASS | Page 2 starts at rank 3 for page size 2. |
| Combined category/completed filters | PASS | Fixture category and completed filters returned only expected novels. |
| Hidden/pending/deleted novel and hidden chapter | PASS | High-view excluded fixtures did not enter the isolated category ranking. |
| Multiple categories do not multiply views | PASS | Two-category novel retained its exact two-view total. |
| Invalid period | PASS | `period=year` returned HTTP 400. |
| API does not create views | PASS | Endpoint implementation is read-only and integration calls did not invoke the view-write endpoint. |
| Query plan / index | PASS | `EXPLAIN FORMAT=JSON` on `novi_test` includes `idx_chapter_view_period`; existing chapter statistics index also remains available. |
| Debug build while local API was running | BLOCKED | Existing process locked Debug output DLLs; Release build passed. |
