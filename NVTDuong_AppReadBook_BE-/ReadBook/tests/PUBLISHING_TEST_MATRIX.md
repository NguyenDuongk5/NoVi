# Publishing verification matrix

Verified on 2026-10-29 against MySQL 8.0.41 and database `novi_test` only. Secrets were generated at runtime and were not logged or committed.

| Group | Result | Actual evidence |
|---|---|---|
| MySQL and target safety | PASS | MySQL80 was running. `SELECT DATABASE()` returned exactly `novi_test` before schema, migration, fixtures, or API writes. |
| Base schema | PASS | Applied idempotently to `novi_test`; 19 tables present. MySQL 8.0.41 compatibility issue in `similarity_match` was fixed. |
| `002_publishing.sql` | PASS | Applied to `novi_test`; `author_application` and `moderation_decision` verified present. |
| Backend build/start | PASS | Final build: 0 errors. API started on `http://localhost:5148`; public novels health request returned HTTP 200. |
| Fixture creation | PASS | Accounts were registered through `/api/auth/register`; roles/status were assigned only in `novi_test`. No plaintext password was inserted into the database. |
| Author promotion | PASS | Approval flow passed in `publishing-integration.ps1`; rejection with reason and a new submission after rejection also passed. Missing rejection reason returned HTTP 400. |
| Role and locked account | PASS | Reader access to author endpoint returned 403; locked account login returned 403. |
| Ownership | PASS | Second author received 404 when reading or updating the first author's novel. |
| Pending/public separation | PASS | Pending novels and chapters returned 404 publicly; approved content became public. |
| Rejection/resubmission | PASS | Rejected novel was edited, reset to pending, then approved successfully. |
| Novel revisions | PASS | Pending revision did not change public title; approved revision was applied. |
| Chapter revisions | PASS | Pending revision did not change public content; approved revision was applied. |
| Visibility and soft delete | PASS | Hidden and soft-deleted novel/chapter returned 404 publicly. |
| Parent-state filtering | PASS | Approved chapter returned 200 while parent was visible and 404 after parent novel was hidden. |
| Self-review | PASS | Admin attempting to approve an admin-owned pending novel received 403. |
| Legacy CRUD | PASS | `/manga/all` returned HTTP 410. |
| Concurrent moderation | PASS | `publishing-smoke.ps1` produced exactly HTTP 204 and HTTP 409. Database assertion found exactly one corresponding audit decision. |
| Audit fields | PASS | Rejection decisions had non-empty reason, reviewer, and review timestamp. |

## Scripts executed

- `tests/publishing-integration.ps1`: PASS (`PASS publishing integration flow`).
- `tests/publishing-smoke.ps1`: PASS (`PASS concurrent author decision: 204,409`).

## Defects found and fixed during verification

1. MySQL 8.0.41 rejected a CHECK constraint on a column also used by an `ON DELETE SET NULL` foreign key.
2. `novel` is a MySQL reserved word and repository queries did not quote it.
3. Dynamic public-list SQL omitted whitespace before `FROM`.
4. MySQL `TINYINT` materialized as `sbyte`, while immutable DTO constructor parameters used `byte`.
5. PowerShell scripts required `UseBasicParsing` on Windows PowerShell 5.1.
6. Integration script helper `H` conflicted with the built-in `h`/`Get-History` alias.

Build success alone was not used as API evidence; every PASS above came from an executed HTTP or database assertion.
