# SeekDict Task Breakdown

Working task list for the plan in [README.md](README.md). Each task is sized to fit in one spare-time session (roughly 30 min – 2 h). Check off with `[x]`; suggested order is top-down, dependencies are noted per task.

Milestones:

- **M1 — Offline dictionary on macOS:** T1.x, T2.x, T4.1–T4.3
- **M2 — Backend content live:** T3.x, T7.1–T7.7
- **M3 — Full macOS app:** M1 + M2 + T4.4–T4.9, T5.x
- **M4 — iOS app:** M2 + T6.x

## T1. Project scaffolding

| ID | Task | Done when |
|---|---|---|
| T1.1 | [x] Create a shared core module (Swift package or framework target) linked by both the macOS and iOS app targets | Core builds once, both apps import it |
| T1.2 | [x] Pick and integrate a SQLite access layer (evaluate GRDB / SQLite.swift / system C API first) | Chosen, added to core, opens a DB file |
| T1.3 | [x] Add a unit-test target for the core module | One trivial test runs in both platform schemes |
| T1.4 | [x] Skeleton proof of the UI split: one AppKit view wrapped via `NSViewRepresentable` in a SwiftUI window, one UIKit view via `UIViewRepresentable` | Builds and renders on both platforms |

## T2. Dictionary data & engine (offline core)

| ID | Task | Done when |
|---|---|---|
| T2.1 | Vendor the two qingjian TSVs (`glossary-zh.tsv`, `glossary-en.tsv`) into `data/` with a README noting source and GPL license | Files in repo, license note present |
| T2.2 | SQLite schema for `entries` (direction, word, pos, sense, sense_order) + first-launch import of the TSVs into the app DB | Fresh install imports without error |
| T2.3 | Strict TSV parser: POS enum validation, ≤2 senses, fail-fast on malformed lines + unit tests covering edge cases | Parser + tests green |
| T2.4 | Lookup layer: exact-match query per direction, lowercase normalization for en→zh keys + unit tests | `lookup("Abandon")` finds `abandon` |
| T2.5 | Import validation report (count of skipped lines) and a rough lookup-latency check on device | Report logged; lookup < 10 ms |
| T2.6 | `DictionaryService` facade: single entry point used by all UI, guaranteed to work in airplane mode | macOS window shows a result offline |

## T3. Backend API client (shared core)

| ID | Task | Done when |
|---|---|---|
| T3.1 | Define contract models (`Item`, `HotItem`, `Article`, errors) matching `docs/README.md` | Codables compile, match contract doc |
| T3.2 | REST client: endpoints `/v1/search/news`, `/v1/search/weibo`, `/v1/hot`, `/v1/article` + bearer token injection + tests with a mock transport | All four calls work in tests |
| T3.3 | Error mapping: 401 → re-login signal, 402 → user notice, 429/5xx → exponential backoff, other 4xx → no retry + tests | Behavior verified in tests |
| T3.4 | `news_cache` table (word, payload_json, fetched_at) with per-section TTL + tests | Second identical query hits cache until TTL expires |
| T3.5 | Shared Markdown → attributed string renderer for the reading view | Renders headings/links/lists on both platforms |

## T4. macOS host (AppKit)

| ID | Task | Done when |
|---|---|---|
| T4.1 | Lookup window skeleton in AppKit (input field + results area), hosted by SwiftUI | Window shows, accepts input |
| T4.2 | Wire input → `DictionaryService` → result display (offline path end-to-end) | Typed word shows its definition |
| T4.3 | Dictionary result rendering detail (word, POS, senses layout) in AppKit views | Matches glossary data faithfully |
| T4.4 | Global hotkey (event monitor) to summon/hide the lookup window | Hotkey toggles window from any app |
| T4.5 | Accessibility selection grabbing: read the selected text of the frontmost app + permission-request flow | Selected text lands in the input field |
| T4.6 | Selection → normalize → dictionary lookup → show pipeline | Select + hotkey shows definition end-to-end |
| T4.7 | News / Weibo / hot sections inside the results window, wired to the backend client | All three sections render real data |
| T4.8 | In-app Markdown reading view (article endpoint + shared renderer) | Article opens readable in-app |
| T4.9 | Empty / offline / error states with retry | Airplane-mode behavior sane |

## T5. Auth (app side)

| ID | Task | Done when |
|---|---|---|
| T5.1 | Sign in with Apple flow (button, credential handling, token exchange with backend) | Apple login yields a bearer token |
| T5.2 | GitHub OAuth flow (system auth session → code → token) | GitHub login yields a bearer token |
| T5.3 | Phone login UI (number + SMS code entry) | Phone login yields a bearer token |
| T5.4 | Keychain token storage (macOS & iOS) + 401 → back to login | Token survives relaunch; 401 routes to login |
| T5.5 | Login window/page plus account state in settings | User can log in/out from both apps |

## T6. iOS host (UIKit)

| ID | Task | Done when |
|---|---|---|
| T6.1 | Lookup screen skeleton in UIKit (input + results), wrapped for SwiftUI page management | Screen shows, accepts input |
| T6.2 | Wire input → `DictionaryService` → rendering | Typed word shows definition |
| T6.3 | Dictionary result rendering (word, POS, senses) | Matches glossary data faithfully |
| T6.4 | News / Weibo / hot sections wired to backend client | All three sections render real data |
| T6.5 | In-app Markdown reading view | Article opens readable in-app |
| T6.6 | Empty / offline / error states with retry | Airplane-mode behavior sane |

## T7. Backend service (separate repository)

| ID | Task | Done when |
|---|---|---|
| T7.1 | Auth service: Apple / GitHub / phone verification, token issuance, user store | Contract auth endpoints return tokens |
| T7.2 | Wrap DeepSeek Search for `/v1/search/news` | Endpoint returns structured items |
| T7.3 | Prototype: validate Weibo content quality via `site:weibo.com` filtering; adjust query strategy | Quality verdict recorded in docs |
| T7.4 | Prototype: trending source validation (direct hot-page fetch vs. fallback digest) | Source decision recorded in docs |
| T7.5 | `/v1/hot` endpoint per T7.4 decision | Board returns rank/title/url/heat |
| T7.6 | `/v1/search/weibo` with the T7.3 query strategy | Endpoint live |
| T7.7 | `/v1/article` via DeepSeek Fetch (Markdown) | Endpoint returns title + markdown |
| T7.8 | Per-user rate limiting + response caching | Limits and TTLs enforceable |
| T7.9 | Map DeepSeek errors to contract error codes (401/402/429 semantics) | App receives contract-compliant errors |

## T8. Release & compliance

| ID | Task | Done when |
|---|---|---|
| T8.1 | GPL-3.0-or-later LICENSE file + qingjian attribution in About page | License file present, About shows credit |
| T8.2 | Accessibility usage description for App Store review (selection-lookup justification) | Text drafted in app metadata |
| T8.3 | Privacy manifest + account-deletion path (required with Sign in with Apple) | Manifest + deletion flow in place |
| T8.4 | App icons & basic visual identity | Both platforms have icons |
