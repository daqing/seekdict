# SeekDict

SeekDict is a dictionary app for macOS and iOS that aims to beat Apple's built-in Dictionary at its own game: instant English ⇄ Simplified Chinese lookup, enriched with word-related news, Weibo posts, and trending topics pulled from the web.

## Product overview

- **Dictionary first.** English ⇄ Simplified Chinese word and phrase definitions, available fully offline.
- **Beyond the definition.** For the word being looked up, SeekDict also surfaces related news and Weibo content, plus a trending/hot-search board — all powered by web search behind our own backend.
- **macOS.** Global selection lookup (Accessibility-based, like Bob/Easydict) plus a regular lookup window for typed input.
- **iOS.** Manual input only.
- **In-app reading.** News articles open in a built-in Markdown reading view instead of jumping to the browser.

## Scope

### In scope (v1)

- English ⇄ Simplified Chinese dictionary lookup, offline.
- macOS: global selection lookup + input lookup window.
- iOS: manual input lookup.
- Related news list, related Weibo list, trending board.
- In-app article reading (server-fetched Markdown rendered in the app).
- User accounts: Sign in with Apple, GitHub, phone number (SMS code).

### Out of scope

- Any language pair other than English ⇄ Simplified Chinese.
- Wordbook / flashcard features — SeekDict is a dictionary, not a language-learning app.
- Query history (v1).
- Calling DeepSeek APIs directly from the app — all search goes through our backend.

## Architecture

```
SeekDict App (macOS / iOS)  ↔  SeekDict Backend  ↔  DeepSeek Search / Fetch
```

### App (this repository)

- **SwiftUI is used for window/page management only.** Windows, views, controls, and event handling are implemented in AppKit (macOS) and UIKit (iOS); SwiftUI wraps them via `NSViewRepresentable` / `UIViewRepresentable`.
- **Shared core** (Swift, cross-platform): dictionary engine backed by SQLite, backend REST client and models, auth/token handling.
- **macOS host**: selection grabbing via the Accessibility API (requires a user-granted permission in System Settings), lookup panel/window.
- **iOS host**: lookup screen with manual input.

### Backend (separate service, not in this repository)

- Holds the DeepSeek API key; wraps the DeepSeek Search/Fetch APIs.
- Authenticates users and enforces per-user rate limits via bearer token.
- Caches search results to cut DeepSeek call volume.
- Owns user accounts (Apple / GitHub / phone) and login flows.

### Backend API contract (v1)

Base URL TBD. Every endpoint except auth requires `Authorization: Bearer <token>`.

Auth:

| Endpoint | Request | Response |
|---|---|---|
| `POST /auth/apple` | `{id_token}` | `{token, user}` |
| `POST /auth/github` | `{code}` | `{token, user}` |
| `POST /auth/phone` | `{number, sms_code}` | `{token, user}` |

Content:

| Endpoint | Response |
|---|---|
| `GET /v1/search/news?word=&limit=` | `{results: [Item]}` — news related to the word |
| `GET /v1/search/weibo?word=&limit=` | `{results: [Item]}` — Weibo content related to the word |
| `GET /v1/hot` | `{items: [HotItem]}` — trending board (rank, title, url, heat) |
| `GET /v1/article?url=` | `{title, content_markdown}` — server-side Fetch for in-app reading |

`Item` shape (aligned with DeepSeek Search results so the backend can stay a thin, caching layer):

```
{title, url, snippet, date, source_name, source_icon, score}
```

Error handling: `401` → route to login; `402` (backend's DeepSeek balance insufficient) → prompt the user to retry later; `429`/5xx → exponential backoff; other 4xx → no retry.

## Dictionary data

Dictionary content ships as data files in this repository, converted into SQLite on first launch.

- **Source**: the glossary tables of the [qingjian](https://github.com/qingjian-team/qingjian) project (`assets/glossary/`):
  - `glossary-zh.tsv` — English → Simplified Chinese, ~45k words, keys lowercased.
  - `glossary-en.tsv` — Chinese → English, ~239k words.
- **Format**: TSV, one word per line — `word \t [pos.] sense \t [pos.] sense`; UTF-8 without BOM, LF newlines, sorted by code point; at most 2 senses per word. POS tags use a fixed enum (`n. v. adj. adv. pron. prep. conj. num. m. part. int. phr.`).
- **Why reuse instead of regenerating**: qingjian already paid the LLM generation cost and published the results; regenerating the same tables would burn API budget for no gain. SeekDict therefore ships under the same license (see below).

## Local storage (SQLite)

- `entries`: dictionary content — `direction` (en→zh / zh→en), `word`, `pos`, `sense`, `sense_order`; indexed for exact-match lookup.
- `news_cache` (optional): `word`, `payload_json`, `fetched_at`, with per-section TTL — pure optimization, the backend caches too.

The app works fully offline for dictionary lookup; news sections require a network connection and degrade to cached/empty states with retry.

## Auth & tokens

- Sign in with Apple, GitHub OAuth, and phone number + SMS code; the backend issues a bearer token per user, used for authentication and rate limiting.
- Sign in with Apple is mandatory (App Store policy requires it when third-party login exists).
- Tokens are stored in the Keychain; a `401` response routes the user back to login.

## Licensing

GPL-3.0-or-later, matching the dictionary data's license. Dictionary tables © qingjian-team, used under GPL-3.0-or-later with attribution in the repository and the app's About page.

## Prototype milestones / validation items

These are backend-side questions to settle with early prototypes; the app builds against the fixed contract above regardless of the answers.

- Validate Weibo content quality via DeepSeek Search with `site:weibo.com` filtering.
- Validate the trending-board source (fetching Weibo's hot page directly may be blocked; fallback is a search-digest of trending queries).
- Confirm App Store review accepts Accessibility-based selection lookup (entitlement + justification).
