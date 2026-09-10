# Project: FISHER (Wish Fisher)
## Current Status

A well-architected, genuinely original SwiftUI/macOS classifieds watcher (~3,600 LOC, no dependencies, builds clean as of 2026-09-10) whose data-driven adapter layer is its best idea — but two scheduling settings are decorative, adapter fixes never reach existing users, and there is zero test coverage.

---

## 10 Things to Work On

### 1. UI/UX Gap (misleading setting): The "At about [hour]" picker does nothing
**Severity:** 🔴 Critical
**File(s):** `FISHER/Engine/Scheduler.swift`, `FISHER/Engine/Prefs.swift` (lines 95, 117), `FISHER/UI/SettingsView.swift` (line 27), `FISHER/UI/EditionView.swift` (line 393)
**Details:** The General tab lets you pick "Check: Once a day / At about 4 [a.m.]", and the colophon prints "Next edition tomorrow, about 4 a.m." But `Scheduler.schedule()` only sets `NSBackgroundActivityScheduler.interval` — the system fires it whenever it suits within that interval. `Defaults.hour`, `PrefKey.hour`, and `Scheduler.jitteredMinute` are never read by any scheduling logic. The user is promised 4 a.m. and gets "some time, maybe."
**Suggested fix:** Two honest options: (a) remove the hour picker and say "once a day, at a quiet moment"; or (b) implement it — schedule a repeating activity and gate the actual sweep on `Calendar.component(.hour)` matching the chosen hour (NSBackgroundActivityScheduler cannot pin an exact time; gating is the standard workaround). Delete `jitteredMinute` if unused.

### 2. UI/UX Gap (decorative feature): Per-wish cadence is never enforced
**Severity:** 🔴 Critical
**File(s):** `FISHER/Models/WantedAd.swift` (lines 16, 21–42), `FISHER/UI/MainWindow.swift` (line 179)
**Details:** `WantedAd.Cadence` supports "Every hour / Only when I ask" per wish, and the sidebar subtitle displays it. But `Scheduler` and `Store.sweep()` never look at it — every active wish is swept at the global frequency, always. A wish set to "manual" still gets searched every night.
**Suggested fix:** Either wire it (filter `activeWishes` by `wish.cadence.interval` vs. time since `wish.lastSweep` inside `sweep()`) or remove the field until it works. `wish.lastSweep` is already tracked and updated — the plumbing is half there.

### 3. Missing Core Feature: Adapter fixes never reach existing users
**Severity:** 🔴 Critical
**File(s):** `FISHER/Engine/Store.swift` (lines 44–65)
**Details:** The README's core promise is "a broken site is a file to republish — not a build." But `load()` prefers the user's saved `adapters.json` in Application Support over the bundle, replacing the bundle only when all saved adapters have `language == nil`. So if you ship a corrected selector in an app update, every existing user keeps the broken one forever. The promise only works for first launch.
**Suggested fix:** Add an `adapterVersion: Int` to the bundle file. On launch, for each bundled adapter whose version is newer than the saved one with the same `id`, replace the saved entry *unless the user modified it* (keep a `userEdited: Bool` flag set by the Sources editor). Ship the "Restore bundled sources" button you already have as the escape hatch.

### 4. Critical Bug (silent failure): A sweep that fails everywhere looks identical to a quiet morning
**Severity:** 🟡 Medium
**File(s):** `FISHER/Engine/Sweep.swift` (lines 78–80, 85), `FISHER/Engine/Notifier.swift` (line 14)
**Details:** Every fetch/parse error is `catch { continue }`. If all 9 sources 403 or time out, the edition prints "9 sources read overnight" is *not* shown — actually `sourcesRead` only increments on success, so the dateline reads "0 sources read overnight. Nothing new" — indistinguishable from a world with no listings. The user can't tell "no boats for sale" from "FISHER is broken." You already have `AdapterProbe` and `canaryMinResults`; the machinery exists.
**Suggested fix:** Track per-adapter failures during the sweep, and print one honest line in the edition: "Could not read Blocket, DBA (HTTP 403)." That's it — no dashboard needed, consistent with the paper philosophy.

### 5. File I/O Limitation: `listings.json` grows forever
**Severity:** 🟢 Low
**File(s):** `FISHER/Engine/Store.swift`, `FISHER/Engine/Sweep.swift` (lines 88–100)
**Details:** Listings marked `isGone` are kept indefinitely, and every listing carries a `priceHistory` that only appends. A year of daily sweeps on 9 sources = tens of thousands of dead records in one pretty-printed JSON file, parsed at launch forever.
**Suggested fix:** On save, prune listings gone for > 60 days; cap `priceHistory` at ~12 points (one per re-price is overkill; monthly suffices). Optionally move listings to a lightweight SQLite/GRDB store — but pruning alone solves the real problem.

### 6. Performance: Sweeps are fully serial across hosts
**Severity:** 🟢 Low
**File(s):** `FISHER/Engine/Sweep.swift` (lines 28–86), `FISHER/Engine/Fetcher.swift`
**Details:** Adapters are fetched one at a time in nested loops. With 9 adapters × ~2 queries × 3 pages × 3–6 s throttle, a full sweep is 10–30 minutes even when everything is healthy. The throttle is per-host (`Fetcher.lastHit` is keyed by host), so fetching different hosts concurrently is still perfectly polite.
**Suggested fix:** `async let` / `withTaskGroup` over adapters (keep per-host serialization inside `Fetcher`; it already is). Also cache `Money.format`'s `NumberFormatter` (it's rebuilt per call, including inside table rows).

### 7. Test Coverage: Zero tests for the most testable code in the app
**Severity:** 🟡 Medium
**File(s):** whole project — no test target
**Details:** `PriceParser`, `WishParser`, `Matcher`, `Lexicon`, `JSONWalker`, and `Editor.compose` are pure functions with exact, documentable behavior ("19.500 kr." → 19500 DKK). These are exactly the functions that silently rot when a site changes its format or you tweak a regex. Nothing guards them.
**Suggested fix:** Add a unit-test target (no dependencies needed) with table-driven tests: one fixture file per engine component, each row an input → expected output. Start with PriceParser and WishParser; 40 cases would cover 90% of realistic regressions. Run `xcodebuild test` in CI.

### 8. Architecture Debt: Duplicate project copies and dead code
**Severity:** 🟢 Low
**File(s):** `Claude outputs/` (whole folder), `FISHER/Engine/Prefs.swift`, `FISHER/Engine/Scheduler.swift`, `FISHER/Models/WantedAd.swift`
**Details:** `Claude outputs/` holds an older full copy of the project plus a zip — any future edit risks landing in the wrong tree (the two have already diverged: only the active copy has `BrowserFetcher`, `Lexicon`, `Rates`). And the dead `hour`/`jitteredMinute`/`Cadence` wiring from items 1–2 is dead code that actively misleads.
**Suggested fix:** Delete or move `Claude outputs/` out of the working folder (it's in git history if the repo is committed). Remove dead symbols when fixing items 1–2.

### 9. Developer Experience: Manual signing, no CI, README drift
**Severity:** 🟢 Low
**File(s):** `FISHER.xcodeproj/project.pbxproj`, `README.md`
**Details:** Build verified working (Debug, unsigned, `BUILD SUCCEEDED`). Signing is manual per-machine, fine for personal use. But there's no CI running the build, and the README already drifts from the code (⌘P print is implemented in `FISHERApp.swift` but still listed under "Next"; the README's adapter count says 9 while `adapters.json` now carries 11 entries + a template).
**Suggested fix:** A 10-line GitHub Actions workflow running `xcodebuild build CODE_SIGNING_ALLOWED=NO` on push. Refresh README "Next" to match reality.

### 10. Future Roadmap: What actually comes next
**Severity:** 🟡 Medium (direction-setting)
**Details:** The README lists LLM headlines, iOS reader, print. Print is done. Realistic priority order:
1. **Adapter registry over HTTPS** (item 3's big sibling): host `adapters.json` on a static URL; the app checks it weekly. Then a site break is a file you edit *on the server* — no App Store, no update, works for everyone. This is the feature that turns FISHER from a project into a product.
2. **LLM headlines via the existing `HeadlineWriter` protocol** — the seam is already there and well-designed; numbers stay in `Editor`.
3. **iOS reader via CloudKit** — Mac stays the worker, phone is a viewer. Cheap because editions are already plain Codable structs.
4. Robots.txt / `Retry-After` respect in `Fetcher`, so the "honest citizen" posture is verifiable, not just claimed.

---

## Quick Wins (< 1 hour each)

- Add the "Could not read X, Y" line to the edition (half the code exists in `AdapterProbe`).
- Prune `isGone` listings on save (10 lines in `Store.save()`).
- Update README "Next" section (print shipped; adapter count is stale).
- Delete or relocate the `Claude outputs/` duplicate.
- Cache the `NumberFormatter` in `Money.format`.

## Next Milestone Recommendation

**Fix the adapter-update path (item 3) plus failure visibility (item 4).** Together they make the app's central promise — "a broken site is a file to republish" — actually true in both directions: fixes reach users, and users can see when a source is down instead of reading "no news today." That pair is the difference between a clever demo and a tool you trust every morning. Everything else (LLM headlines, iOS) is additive on top of a trustworthy engine.
