# Anthropic API Key Proxy (SEC-01) — Design

**Date:** 2026-06-20
**Status:** Approved, ready for implementation planning
**Owner:** Suli

## Goal & threat model

Move the Anthropic API key off the device entirely.

Today the key ships in `KAIZENN/Config.xcconfig` → `Info.plist` and is extractable
from a downloaded IPA. Anyone who extracts it can run unlimited Anthropic spend on
our account.

After this change:

- The key lives **only** as a Supabase secret, never in the app binary.
- The proxy serves **only genuine, unmodified KAIZENN builds**, verified per request
  via Apple App Attest.
- Each device is capped with a per-day request limit, so a compromised device can't
  run up an unbounded bill.

## Decisions (locked)

| Decision | Choice | Why |
|----------|--------|-----|
| Hosting | **Supabase Edge Function** | Already the intended target; Supabase tooling connected; single Deno/TS function. |
| Abuse protection | **App Attest + per-device rate limit** | Only option not defeated by extracting something from the binary. No login exists to lean on. |
| Proxy contract | **Locked-down `/chat` + `/vision`** | App only does two things with Claude. Pinning model + `max_tokens` server-side caps per-request cost even for a forged request. |
| Simulator support | **Two-gate dev bypass** (`#if DEBUG` *and* server flag) | App Attest does not run on the Simulator; need a frictionless test loop with zero risk of shipping open. |
| Proxy base URL | **Plain `ProxyConfig.swift` constant** | A URL is not a secret; the security model assumes the attacker already knows the endpoint. Hiding it is security theater. |

## Architecture (data flow)

```
iOS app                          Supabase Edge Function "kai-proxy"        Anthropic
───────                          ──────────────────────────────────        ─────────
AppAttestManager
  ├─ (once per install)
  │   GET  /challenge ───────────────────────────────────────▶ issue + store nonce
  │   POST /attest {keyId, attestation, challenge} ──────────▶ verify vs Apple CA
  │                                          └─ store pubkey+counter in Postgres
  └─ (per request) sign payload with attested key
ClaudeService
  POST /chat   {messages, systemPrompt, keyId, assertion} ─▶ verify assertion + counter
  POST /vision {imageBase64, systemPrompt, keyId, assertion}   ├─ rate-limit check (device/day)
                                                               ├─ build Anthropic req
                                                               │   (model/max_tokens server-set)
                                                               └─ inject x-api-key ─────────────▶ /v1/messages
```

## Backend components (Supabase)

### Edge Function `kai-proxy` (Deno / TypeScript)

Routes:

- `GET  /challenge` — issue a short-lived random nonce, store it for one-time use.
- `POST /attest` — one-time per install. Verify the App Attest attestation object:
  certificate chain to Apple's App Attest root CA, nonce match, and
  `appID == "<APPLE_TEAM_ID>.<APP_BUNDLE_ID>"`. Store the device public key + initial
  sign counter.
- `POST /chat` — verify assertion, rate-limit, forward a chat request.
- `POST /vision` — verify assertion, rate-limit, forward an image request.

Secrets / config (Supabase project secrets):

- `ANTHROPIC_API_KEY` — the only real secret being protected.
- `APPLE_TEAM_ID`, `APP_BUNDLE_ID` — used to compute `appID` for attestation.
- `DEV_BYPASS_ENABLED` (default unset/false) — gates the simulator bypass.
- `DEV_BYPASS_TOKEN` — accepted in lieu of an assertion **only** when
  `DEV_BYPASS_ENABLED` is true.

Server-pinned request params (the locked-down contract):

- `model = "claude-sonnet-4-6"`
- `max_tokens = 1024`
- `anthropic-version = "2023-06-01"`

The client sends only `messages`/`systemPrompt` (chat) or `imageBase64`/`systemPrompt`
(vision). It cannot choose the model or token budget.

### Postgres tables

```sql
attest_devices (
  key_id      text        primary key,
  public_key  bytea       not null,
  sign_count  bigint      not null default 0,
  created_at  timestamptz not null default now()
)

attest_challenges (
  challenge   text        primary key,
  created_at  timestamptz not null default now()
  -- single-use; deleted on consumption, expired by age
)

usage_counters (
  key_id       text  not null,
  day          date  not null,
  chat_count   int   not null default 0,
  vision_count int   not null default 0,
  primary key (key_id, day)
)
```

`usage_counters` is keyed `(key_id, day)` so daily caps reset naturally and so a future
per-team metering layer can aggregate over it without a schema change.

### App Attest verification

1. **Challenge** — client requests a nonce; proxy stores it single-use.
2. **Attest** (once per install) — proxy verifies the attestation certificate chain to
   Apple's App Attest root CA, checks the nonce, checks `appID`, and stores the device
   public key with `sign_count = 0`.
3. **Assert** (per request) — client signs `SHA256(challenge ‖ requestBody)` with the
   attested key. Proxy verifies the signature against the stored public key and enforces
   that `signCount` is **strictly increasing** — this is the anti-replay mechanism (the
   Secure Enclave increments the counter each assertion; a captured request can't be
   replayed because its counter is no longer ahead of the stored value).

### Rate limiting

Per-device daily caps enforced via `usage_counters`: **50 chat / 20 vision requests per
device per day**. These are starting values, tunable via constants in the function
without a schema change. Exceeding either cap returns HTTP 429.

## iOS components

### New `Core/Networking/AppAttestManager.swift`

Wraps `DCAppAttestService`:

- Generates and **persists the key ID in Keychain** (so we don't re-attest every launch).
- Performs the one-time attestation flow (`/challenge` → `generateKey` → `attestKey` →
  `/attest`).
- Produces a per-request assertion: `assertion(for body: Data) async throws -> Assertion`.
- In `#if DEBUG` on the Simulator (`DCAppAttestService.isSupported == false`), falls back
  to attaching `DEV_BYPASS_TOKEN` instead of an assertion.

### Rewrite `Data/Network/ClaudeService.swift`

- Point `chat` / `chatWithImage` at the proxy `/chat` and `/vision` endpoints.
- Attach `keyId` + assertion (or dev token) to each request.
- **Remove** the `apiKey` property and all direct Anthropic calls.

### New `Core/Networking/ProxyConfig.swift`

- A plain constant for the proxy base URL, with a `#if DEBUG` dev/prod switch.

### Build / project changes

- **Remove** `ClaudeAPIKey` from `Config.xcconfig` and the `Info.plist` build wiring.
- **Add** the entitlement `com.apple.developer.devicecheck.appattest-environment`
  (`development` in debug, `production` in release).

## Error handling

Map proxy responses onto the existing `ClaudeError`:

| HTTP | `ClaudeError` | User-facing message |
|------|---------------|---------------------|
| 401  | `requestFailed` | "Couldn't verify this device." |
| 429  | `requestFailed` | "You've hit today's AI limit — resets tomorrow." |
| 5xx  | `requestFailed` | passthrough server message |
| non-2xx other | `requestFailed` | passthrough |

Coach / scan views already surface `ClaudeError.errorDescription`, so UI changes are
minimal.

## The Simulator gotcha (two-gate bypass)

App Attest does **not** work on the iOS Simulator (`DCAppAttestService.isSupported`
returns false), and tests run on the Simulator. The bypass is gated by **two**
independent conditions:

1. **Compile-time:** the bypass code path is inside `#if DEBUG`, so it is not compiled
   into release builds at all.
2. **Runtime:** the proxy accepts `DEV_BYPASS_TOKEN` only when `DEV_BYPASS_ENABLED` is
   true, which production never sets.

A release build physically cannot send the bypass token; even a leaked debug build is
inert once the server flag is off. The function logs a warning at startup if bypass is
ever enabled, so it's obvious in logs if it's live in prod.

## Testing

- **Proxy (Deno):** unit tests for assertion verification and rate-limit
  increment/reset logic, using a known keypair and a mocked Postgres layer.
- **iOS:** inject a `URLProtocol`-based mock into `ClaudeService` to test request shaping
  and error mapping without network. App Attest itself can only be exercised on a real
  device — documented as a manual test step.

## Out of scope (YAGNI)

- No user login / accounts.
- No team access codes (can layer on `usage_counters` later if billing needs it).
- No response streaming.
- No Android.
