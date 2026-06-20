# kai-proxy Deploy & Cutover Runbook (SEC-01)

The backend Edge Function and the iOS building blocks are built, tested, and
committed on `feat/api-key-proxy`. This runbook covers the remaining **deploy/cutover
phase** (plan Tasks 8–11), which needs infrastructure only you can set up.

> ⚠️ **The cutover breaks the dev app's AI until the proxy is live.** Tasks 8–9 make
> `ClaudeService` call the proxy instead of Anthropic directly and remove the embedded
> key. Do them together with the deploy (Task 10) so there's no broken gap. Until then,
> the dev build keeps working with the key in `Config.xcconfig`.

---

## What you need to provide

| # | Item | Where it's used |
|---|------|-----------------|
| 1 | A **Supabase project** (free tier) | hosts the `kai-proxy` function + Postgres |
| 2 | Project **ref**, **URL**, **service-role key** | function env + iOS `ProxyConfig` prod URL |
| 3 | Your **Apple Developer Team ID** | App Attest `appID = TEAMID.com.kaizenn.app` |
| 4 | A **physical iPhone** | App Attest does not run on the Simulator |
| 5 | A **fresh Anthropic key** | stored as a Supabase secret (NOT the transcript-exposed dev key) |

---

## Step 1 — Supabase project + schema

```bash
brew install supabase/tap/supabase            # CLI not yet installed
cd "/Users/suli/Desktop/Dev Projects/KAIZENN"
supabase login
supabase link --project-ref <YOUR_PROJECT_REF>
supabase db push                              # applies migrations/0001_attest_and_usage.sql
```

No Docker needed for this path — `db push` and `functions deploy` go straight to the
hosted project. (Docker is only required for the *local* `supabase start` stack, which
we skipped.)

## Step 2 — Function secrets (with a FRESH key)

Generate a NEW key at console.anthropic.com (do not reuse the dev key in
`Config.xcconfig` — it's exposed in the build session transcript):

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-NEW_KEY
supabase secrets set APPLE_TEAM_ID=<YOUR_TEAM_ID>
supabase secrets set APP_BUNDLE_ID=com.kaizenn.app
# DEV_BYPASS_ENABLED intentionally NOT set in production.
supabase functions deploy kai-proxy --no-verify-jwt
```

Smoke-test the deployed challenge endpoint:

```bash
curl -s https://<PROJECT_REF>.supabase.co/functions/v1/kai-proxy/challenge
# → {"challenge":"<base64>"}
```

## Step 3 — Finalize the attestation nonce parser (Task 10)

`supabase/functions/kai-proxy/appattest.ts` → `extractNonceExtension()` currently
throws. It needs a real device attestation to finish, because Apple publishes no
offline test vector.

1. Temporarily `print()` the base64 attestation in `AppAttestManager.postAttestation`.
2. Run the app on a physical iPhone, trigger a Coach message, copy the blob from the
   device console.
3. Implement `extractNonceExtension` to pull the 32-byte nonce from the credCert's
   `1.2.840.113635.100.8.2` extension (DER OCTET STRING in a SEQUENCE), and add a Deno
   test using the captured blob as a fixture.
4. `supabase functions deploy kai-proxy` again.

## Step 4 — iOS cutover (plan Tasks 8 & 9)

These are written up in the plan with complete code; apply them when ready:

- **Task 8:** rewrite `KAIZENN/Data/Network/ClaudeService.swift` to POST to the proxy
  `/chat` and `/vision` (keeping the existing `chat`/`chatWithImage` signatures), attach
  `AppAttestManager` headers, map 401→unverified, 429→rate-limited. Add
  `KAIZENNTests/ClaudeServiceTests.swift` (URLProtocol-mocked) and run the test target.
- **Task 9:** remove `ClaudeAPIKey` from `KAIZENN/Info.plist` and `CLAUDE_API_KEY` from
  `KAIZENN/Config.xcconfig`; add `com.apple.developer.devicecheck.appattest-environment`
  to `KAIZENN/KAIZENN.entitlements` (`development` in debug, `production` for release).
- Point `ProxyConfig.swift` release `baseURL` at
  `https://<PROJECT_REF>.supabase.co/functions/v1/kai-proxy`.

## Step 5 — On-device end-to-end test

Build to the physical iPhone. Confirm: Coach replies, food-photo and training-whiteboard
scans work. In Supabase, confirm a row appears in `attest_devices` and `usage_counters`
increments.

## Step 6 — Final key rotation (Task 11)

Once the deployed proxy is confirmed working with the FRESH key, the dev key in
`Config.xcconfig` is no longer needed anywhere. (The originally-leaked key was already
revoked on 2026-06-20.) Optionally rotate the dev key too, and set a monthly spend cap
on the production key.

---

## Status note (2026-06-20): deployed + device-verified via dev-bypass

The proxy is LIVE (`kaizenn-proxy`, ref `oeaphuyfcexpidpzzcri`) and the full
pipeline is verified from a real device (Juls) through the dev-bypass path —
Coach replies, no key in the app, requests logged in `usage_counters` (`dev-*`).

Two items are deferred until the Apple Developer account side is ready:
1. **Program License Agreement** must be accepted at developer.apple.com/account
   (it blocks provisioning updates).
2. **App Attest capability** on App ID `com.kaizenn.app` (auto-added by Xcode once
   the PLA is accepted; else enable manually under Identifiers → Capabilities).

Because of #2, the App Attest **entitlement was temporarily removed** from
`KAIZENN.entitlements` so the device DEBUG build (which uses the bypass, not App
Attest) signs cleanly. Restore it (`com.apple.developer.devicecheck.appattest-environment`
= `development`/`production`) when finalizing the real App Attest path.

`AppAttestManager` now uses the dev-bypass on **both** simulator and device in
DEBUG; release builds use the real App Attest flow. `APPLE_TEAM_ID` for production
attestation is `SXGCGRXFNT`, bundle id `com.kaizenn.app`.

Remaining for production: accept PLA → enable App Attest capability → restore
entitlement → capture one attestation blob from a device to finish
`extractNonceExtension` → set APPLE_TEAM_ID/APP_BUNDLE_ID secrets → disable
DEV_BYPASS_ENABLED → ship release build → delete the `envcheck` function.

## Hand-off

When you've done Steps 1–2 (project + secrets), give me: the **project ref/URL**, your
**Apple Team ID**, and confirm a **device** is available. I'll then apply Tasks 8–9,
finalize the nonce parser with your captured attestation, and walk the on-device test.
