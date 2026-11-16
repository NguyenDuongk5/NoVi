# Personal reading verification

| Group | Result | Notes |
|---|---|---|
| Migration 003 | PASS | `SELECT DATABASE()` returned `novi_test`; `reading_session` and additive columns/index created. |
| Compile Debug | PASS | 0 errors; existing nullable/async warnings remain. |
| Compile Release | PASS | 0 errors. |
| SkiaSharp image validation | PASS | No JWT 401; fake image 400; oversized request 400/413; valid PNG reached missing-Firebase 503. |
| JWT / locked account / ownership isolation | PASS | Locked account 403; second user's library remained empty. |
| Library concurrent save/remove | PASS | Two simultaneous saves produced one row; two simultaneous removes succeeded and left zero rows. |
| Wrong novel/chapter and hidden chapter | PASS | Mismatched chapter returned 404; hidden saved chapter returned `available:false`. |
| Progress bounds, continue, out-of-order | PASS | 101 rejected; lower sequence ignored; older session ignored; a new session allowed rereading chapter 1. |
| History endpoint/privacy | PASS | Caller-only pagination, newest-first order, no content; hidden target returned `available:false`. |
| History creation rule | PASS | Session creation added history; multiple percentage updates did not change the history count. |
| Read-session ownership | PASS | A second account using the creator's session received 409. |
| Pending novel/chapter | PASS | Session, progress and view returned 404; continue returned `available:false`. |
| Soft-deleted novel/chapter | PASS | Session, progress and view returned 404; continue returned `available:false`. |
| View duplicate + concurrent | PASS | Two simultaneous requests produced one `chapter_view` row in the same configured bucket. |
| View fixed-window boundary | PASS | A previous-bucket row did not block the current bucket; documentation explicitly does not claim a rolling 30-minute minimum. |
| Progress does not count view | PASS | Progress endpoint did not create a view row; only the explicit view endpoint did. |
| Publishing regression | PASS | Integration flow passed; concurrent moderation returned exactly 204 and 409. |
| Firebase real upload | BLOCKED | Firebase variables/credentials absent. |
| Firebase orphan dry-run | BLOCKED | Firebase variables/credentials absent. |
