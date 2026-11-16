# Flutter ranking test matrix — 30/10/2026

| Test | Result | Evidence |
|---|---|---|
| Ranking DTO preserves exact count/rank/categories | PASS | Flutter unit test. |
| K/M display formatter | PASS | Flutter unit test validates `1,234,567 → 1.2M`; model retains `1,234,567`. |
| Stale response cannot overwrite newer filter | PASS | `RankingRequestGate` regression test rejects the earlier generation. |
| Home ranking icon and monthly top block | PASS | Windows integration test found tooltip and live monthly fixture. |
| Home → full ranking → period/category filter | PASS | Windows integration test against backend Release and `novi_test`. |
| Ranking → detail → back retains filter state | PASS | Windows integration test returned to the same state and fixture remained visible. |
| Opening ranking/detail creates no view | PASS | Database `chapter_view` count compared before/after UI flow and remained unchanged. |
| Loading/empty/error/retry/load-more | PASS (widget/code path) | Implemented for preview/full screen; compilation and widget tests pass. Empty/error paths were not forced in Windows UI test. |
| Narrow screen bottom-sheet filter | NOT RUN | Implemented at `<520` logical pixels; Windows E2E used wide layout. |
| Flutter analyzer | PASS | `dart analyze lib/main.dart lib/core lib/ui test/widget_test.dart`: no issues. |
| Flutter tests | PASS | 7/7. |
| Windows debug build | PASS | `build/windows/x64/runner/Debug/flutter_application_1.exe`. |
