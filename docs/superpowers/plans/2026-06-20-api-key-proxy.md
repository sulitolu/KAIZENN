# Anthropic API Key Proxy (SEC-01) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Anthropic API key off-device into a Supabase Edge Function that verifies every request with Apple App Attest and enforces per-device daily limits.

**Architecture:** A Deno/TypeScript Supabase Edge Function (`kai-proxy`) holds the key as a secret and exposes `/challenge`, `/attest`, `/chat`, `/vision`. iOS gains an `AppAttestManager` that attests once per install and signs each request; `ClaudeService` is rewritten to call the proxy instead of Anthropic directly, keeping its existing method signatures so the three call sites are untouched.

**Tech Stack:** Supabase Edge Functions (Deno, TypeScript), Supabase Postgres, Swift / SwiftUI, `DeviceCheck` (`DCAppAttestService`), Keychain.

## Global Constraints

- Anthropic model pinned server-side: `claude-sonnet-4-6` (copied from current `ClaudeService`).
- `max_tokens` pinned server-side: `1024`.
- `anthropic-version` header: `2023-06-01`.
- App identity for attestation: `appID = "<APPLE_TEAM_ID>.<APP_BUNDLE_ID>"`.
- Rate limits: 50 `/chat` + 20 `/vision` requests per device per day (HTTP 429 on exceed).
- Dev bypass requires BOTH `#if DEBUG` (compile-time) AND server `DEV_BYPASS_ENABLED=true` (runtime).
- Proxy base URL is non-secret; ship as a Swift constant.
- `ClaudeService.chat(messages:systemPrompt:)` and `chatWithImage(image:systemPrompt:)` MUST keep their exact existing signatures.
- The current key (`sk-ant-...` in `KAIZENN/Config.xcconfig`) is compromised and MUST be rotated at cutover (Task 11).

## File Structure

**Proxy (new `supabase/` tree at repo root):**
- `supabase/config.toml` — Supabase project config.
- `supabase/migrations/0001_attest_and_usage.sql` — tables.
- `supabase/functions/kai-proxy/index.ts` — HTTP router.
- `supabase/functions/kai-proxy/appattest.ts` — challenge + attestation + assertion verification.
- `supabase/functions/kai-proxy/ratelimit.ts` — per-device daily counters.
- `supabase/functions/kai-proxy/anthropic.ts` — build + send pinned Anthropic requests.
- `supabase/functions/kai-proxy/appattest_test.ts`, `ratelimit_test.ts` — Deno tests.

**iOS:**
- `KAIZENN/Core/Networking/ProxyConfig.swift` — base URL constant (new).
- `KAIZENN/Core/Networking/AppAttestManager.swift` — attest + assert (new).
- `KAIZENN/Data/Network/ClaudeService.swift` — rewritten to call the proxy.
- `KAIZENN/KAIZENN.entitlements` — add App Attest entitlement.
- `KAIZENN/Info.plist` — remove `ClaudeAPIKey`.
- `KAIZENN/Config.xcconfig` — remove `CLAUDE_API_KEY` (local file, gitignored).
- `KAIZENNTests/ClaudeServiceTests.swift` — URLProtocol-mocked request/error tests (new).

---

### Task 1: Scaffold Supabase project + DB migration

**Files:**
- Create: `supabase/config.toml`
- Create: `supabase/migrations/0001_attest_and_usage.sql`

**Interfaces:**
- Produces: tables `attest_devices(key_id text pk, public_key bytea, sign_count bigint, created_at timestamptz)`, `attest_challenges(challenge text pk, created_at timestamptz)`, `usage_counters(key_id text, day date, chat_count int, vision_count int, pk(key_id,day))`.

- [ ] **Step 1: Install Supabase CLI and init**

The CLI is not on PATH. Install via Homebrew, then init at repo root:

```bash
brew install supabase/tap/supabase
cd "/Users/suli/Desktop/Dev Projects/KAIZENN"
supabase init   # creates supabase/config.toml; answer "n" to VS Code settings
```

Expected: `supabase/config.toml` created.

- [ ] **Step 2: Write the migration**

Create `supabase/migrations/0001_attest_and_usage.sql`:

```sql
create table if not exists attest_devices (
  key_id      text        primary key,
  public_key  bytea       not null,
  sign_count  bigint      not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists attest_challenges (
  challenge   text        primary key,
  created_at  timestamptz not null default now()
);

create table if not exists usage_counters (
  key_id       text  not null,
  day          date  not null,
  chat_count   int   not null default 0,
  vision_count int   not null default 0,
  primary key (key_id, day)
);

-- Tables are accessed only by the Edge Function via the service-role key,
-- which bypasses RLS. Enable RLS with no policies so nothing else can read them.
alter table attest_devices    enable row level security;
alter table attest_challenges enable row level security;
alter table usage_counters    enable row level security;
```

- [ ] **Step 3: Start local stack and apply migration**

```bash
supabase start              # boots local Postgres + Edge runtime (Docker)
supabase migration up       # applies 0001
```

Expected: `Applying migration 0001_attest_and_usage.sql...` then success. `supabase start` prints local API URL + anon/service_role keys — note them for later steps.

- [ ] **Step 4: Verify tables exist**

```bash
supabase db diff --schema public
```

Expected: no pending diff (schema matches migration).

- [ ] **Step 5: Commit**

```bash
git add supabase/config.toml supabase/migrations/0001_attest_and_usage.sql
git commit -m "feat(proxy): scaffold supabase project + attest/usage tables"
```

---

### Task 2: App Attest verification module

**Files:**
- Create: `supabase/functions/kai-proxy/appattest.ts`
- Test: `supabase/functions/kai-proxy/appattest_test.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure crypto + a small DB port passed in).
- Produces:
  - `verifyAssertion(opts: { publicKeyDer: Uint8Array; storedSignCount: number; assertionB64: string; clientDataHash: Uint8Array }): Promise<{ ok: boolean; newSignCount: number }>`
  - `clientDataHash(challenge: string, body: Uint8Array): Promise<Uint8Array>` — returns `SHA256(utf8(challenge) ‖ body)`.
  - `verifyAttestation(opts: { attestationB64: string; keyId: string; challenge: string; appId: string }): Promise<{ publicKeyDer: Uint8Array; signCount: number }>` (throws on failure).

App Attest verification is the security-critical core. Implement assertion verification first with a self-generated EC keypair test vector (fully testable offline), then attestation verification (needs Apple's cert chain — gated by a real-device manual test in Task 10).

- [ ] **Step 1: Add CBOR dependency and write the assertion test**

Create `supabase/functions/kai-proxy/appattest_test.ts`. This test generates a P-256 keypair, signs a known `clientDataHash` the way the Secure Enclave would (authenticatorData ‖ hash), and asserts `verifyAssertion` accepts it and rejects a non-incrementing counter:

```ts
import { assertEquals } from "jsr:@std/assert";
import { verifyAssertion, clientDataHash } from "./appattest.ts";

// Build a minimal authenticatorData: 32-byte rpIdHash + 1 flag byte + 4-byte signCount.
function authData(signCount: number): Uint8Array {
  const buf = new Uint8Array(37);
  new DataView(buf.buffer).setUint32(33, signCount, false); // big-endian at offset 33
  return buf;
}

Deno.test("verifyAssertion accepts a valid, advancing signature", async () => {
  const kp = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"],
  );
  const publicKeyDer = new Uint8Array(await crypto.subtle.exportKey("spki", kp.publicKey));
  const hash = await clientDataHash("challenge-123", new TextEncoder().encode("{}"));

  const ad = authData(5);
  const signed = new Uint8Array([...ad, ...new Uint8Array(await crypto.subtle.digest("SHA-256", hash))]);
  const sigRaw = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, kp.privateKey, signed,
  ));

  // App Attest assertions are CBOR { signature, authenticatorData } with DER (ASN.1) signatures.
  const { encodeAssertion } = await import("./appattest_test_helpers.ts");
  const assertionB64 = await encodeAssertion(sigRaw, ad);

  const res = await verifyAssertion({ publicKeyDer, storedSignCount: 4, assertionB64, clientDataHash: hash });
  assertEquals(res.ok, true);
  assertEquals(res.newSignCount, 5);
});

Deno.test("verifyAssertion rejects a replayed (non-advancing) counter", async () => {
  const kp = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"],
  );
  const publicKeyDer = new Uint8Array(await crypto.subtle.exportKey("spki", kp.publicKey));
  const hash = await clientDataHash("c", new TextEncoder().encode("{}"));
  const ad = authData(5);
  const signed = new Uint8Array([...ad, ...new Uint8Array(await crypto.subtle.digest("SHA-256", hash))]);
  const sigRaw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, kp.privateKey, signed));
  const { encodeAssertion } = await import("./appattest_test_helpers.ts");
  const assertionB64 = await encodeAssertion(sigRaw, ad);

  const res = await verifyAssertion({ publicKeyDer, storedSignCount: 5, assertionB64, clientDataHash: hash });
  assertEquals(res.ok, false);
});
```

Create the test helper `supabase/functions/kai-proxy/appattest_test_helpers.ts` (CBOR-encodes an assertion with a DER signature, mirroring what the device sends):

```ts
import { encodeCbor } from "jsr:@levischuck/tiny-cbor";

// Convert a raw (r‖s) P-256 signature to ASN.1 DER, as Apple sends.
export function rawToDer(raw: Uint8Array): Uint8Array {
  const r = raw.slice(0, 32), s = raw.slice(32, 64);
  const trim = (b: Uint8Array) => { let i = 0; while (i < b.length - 1 && b[i] === 0) i++; let v = b.slice(i); if (v[0] & 0x80) v = new Uint8Array([0, ...v]); return v; };
  const rd = trim(r), sd = trim(s);
  const seqLen = 2 + rd.length + 2 + sd.length;
  return new Uint8Array([0x30, seqLen, 0x02, rd.length, ...rd, 0x02, sd.length, ...sd]);
}

export async function encodeAssertion(sigRaw: Uint8Array, authenticatorData: Uint8Array): Promise<string> {
  const map = new Map<string, Uint8Array>([
    ["signature", rawToDer(sigRaw)],
    ["authenticatorData", authenticatorData],
  ]);
  const cbor = encodeCbor(map);
  return btoa(String.fromCharCode(...cbor));
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN"
deno test --allow-import supabase/functions/kai-proxy/appattest_test.ts
```

Expected: FAIL — `Module not found "./appattest.ts"`.

- [ ] **Step 3: Implement `appattest.ts`**

Create `supabase/functions/kai-proxy/appattest.ts`:

```ts
import { decodeCbor } from "jsr:@levischuck/tiny-cbor";

const te = new TextEncoder();

export async function clientDataHash(challenge: string, body: Uint8Array): Promise<Uint8Array> {
  const ch = te.encode(challenge);
  const joined = new Uint8Array(ch.length + body.length);
  joined.set(ch, 0);
  joined.set(body, ch.length);
  return new Uint8Array(await crypto.subtle.digest("SHA-256", joined));
}

function b64ToBytes(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function signCountFromAuthData(ad: Uint8Array): number {
  return new DataView(ad.buffer, ad.byteOffset).getUint32(33, false); // big-endian, offset 33
}

export async function verifyAssertion(opts: {
  publicKeyDer: Uint8Array;
  storedSignCount: number;
  assertionB64: string;
  clientDataHash: Uint8Array;
}): Promise<{ ok: boolean; newSignCount: number }> {
  const obj = decodeCbor(b64ToBytes(opts.assertionB64)) as Map<string, Uint8Array>;
  const signatureDer = obj.get("signature")!;
  const authenticatorData = obj.get("authenticatorData")!;

  const newSignCount = signCountFromAuthData(authenticatorData);
  if (newSignCount <= opts.storedSignCount) return { ok: false, newSignCount };

  // nonce = SHA256(authenticatorData ‖ SHA256(clientDataHash))
  const innerHash = new Uint8Array(await crypto.subtle.digest("SHA-256", opts.clientDataHash));
  const signed = new Uint8Array(authenticatorData.length + innerHash.length);
  signed.set(authenticatorData, 0);
  signed.set(innerHash, authenticatorData.length);

  const key = await crypto.subtle.importKey(
    "spki", opts.publicKeyDer, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"],
  );
  const sigRaw = derToRaw(signatureDer);
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, sigRaw, signed);
  return { ok, newSignCount };
}

// Convert ASN.1 DER ECDSA signature to raw r‖s (64 bytes) for WebCrypto verify.
function derToRaw(der: Uint8Array): Uint8Array {
  let i = 2; // skip 0x30, len
  if (der[i++] !== 0x02) throw new Error("bad DER");
  let rLen = der[i++]; let r = der.slice(i, i + rLen); i += rLen;
  if (der[i++] !== 0x02) throw new Error("bad DER");
  let sLen = der[i++]; let s = der.slice(i, i + sLen);
  const pad = (b: Uint8Array) => { b = b[0] === 0 ? b.slice(1) : b; const o = new Uint8Array(32); o.set(b, 32 - b.length); return o; };
  return new Uint8Array([...pad(r), ...pad(s)]);
}

// Attestation verification: parse the CBOR attestation, walk the x5c cert chain to
// Apple's App Attest root, confirm the nonce (challenge) and appID, and extract the
// device public key. Throws on any failure.
const APPLE_ROOT_CA_PEM = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAESoMpQYAfYbId2qTcZ+H0EX8ZA3lF
Aymc4Z6XPYR7ZjJ5N5jHrtP3FXjz0vDtFiOLh0AcOyA4gJ0VqVwLBdr0g8wXNwz
nTd5BAtcLLcZX7l9JV3vCNHA9p5kJqXZ+L4Bo0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

export async function verifyAttestation(opts: {
  attestationB64: string; keyId: string; challenge: string; appId: string;
}): Promise<{ publicKeyDer: Uint8Array; signCount: number }> {
  const att = decodeCbor(b64ToBytes(opts.attestationB64)) as Map<string, unknown>;
  const fmt = att.get("fmt");
  if (fmt !== "apple-appattest") throw new Error("bad attestation fmt");
  const attStmt = att.get("attStmt") as Map<string, unknown>;
  const x5c = attStmt.get("x5c") as Uint8Array[];
  const authData = att.get("authData") as Uint8Array;

  // 1. Verify the cert chain: x5c[0] (credCert) <- x5c[1] (intermediate) <- Apple root.
  await verifyCertChain(x5c, APPLE_ROOT_CA_PEM);

  // 2. nonce = SHA256(authData ‖ SHA256(challenge)). Must match the value in the
  //    credCert's 1.2.840.113635.100.8.2 extension (octet string).
  const chHash = new Uint8Array(await crypto.subtle.digest("SHA-256", te.encode(opts.challenge)));
  const nonceInput = new Uint8Array(authData.length + chHash.length);
  nonceInput.set(authData, 0); nonceInput.set(chHash, authData.length);
  const expectedNonce = new Uint8Array(await crypto.subtle.digest("SHA-256", nonceInput));
  const certNonce = extractNonceExtension(x5c[0]);
  if (!bytesEqual(expectedNonce, certNonce)) throw new Error("nonce mismatch");

  // 3. rpIdHash (authData[0..32]) must equal SHA256(appId).
  const appIdHash = new Uint8Array(await crypto.subtle.digest("SHA-256", te.encode(opts.appId)));
  if (!bytesEqual(authData.slice(0, 32), appIdHash)) throw new Error("appId mismatch");

  // 4. keyId must equal SHA256(credCert public key). credCertPubKey extracted below.
  const publicKeyDer = extractSpkiFromCert(x5c[0]);
  const pubKeyHash = new Uint8Array(await crypto.subtle.digest("SHA-256", rawPubKeyFromSpki(publicKeyDer)));
  if (btoa(String.fromCharCode(...pubKeyHash)) !== opts.keyId) throw new Error("keyId mismatch");

  return { publicKeyDer, signCount: signCountFromAuthData(authData) };
}

// --- helpers (verifyCertChain, extractNonceExtension, extractSpkiFromCert,
//     rawPubKeyFromSpki, bytesEqual) implemented with node:crypto X509Certificate ---
import { X509Certificate } from "node:crypto";

async function verifyCertChain(x5c: Uint8Array[], rootPem: string): Promise<void> {
  const leaf = new X509Certificate(Buffer.from(x5c[0]));
  const inter = new X509Certificate(Buffer.from(x5c[1]));
  const root = new X509Certificate(rootPem);
  if (!leaf.verify(inter.publicKey)) throw new Error("leaf not signed by intermediate");
  if (!inter.verify(root.publicKey)) throw new Error("intermediate not signed by root");
}

function extractSpkiFromCert(der: Uint8Array): Uint8Array {
  const cert = new X509Certificate(Buffer.from(der));
  return new Uint8Array(cert.publicKey.export({ type: "spki", format: "der" }));
}

// P-256 SPKI ends with the 65-byte uncompressed point (0x04 ‖ X ‖ Y). keyId hashes that point.
function rawPubKeyFromSpki(spki: Uint8Array): Uint8Array {
  return spki.slice(spki.length - 65);
}

function extractNonceExtension(der: Uint8Array): Uint8Array {
  const cert = new X509Certificate(Buffer.from(der));
  // OID 1.2.840.113635.100.8.2 — Apple stores the nonce as a DER OCTET STRING inside a SEQUENCE.
  const ext = (cert as unknown as { raw: Buffer }).raw; // parsed via ASN.1 below
  return parseAppleNonce(ext);
}

// Minimal ASN.1 walk to pull the 32-byte nonce out of the Apple extension.
function parseAppleNonce(_raw: Buffer): Uint8Array {
  throw new Error("parseAppleNonce: implement ASN.1 extraction against a real device attestation in Task 10");
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let d = 0; for (let i = 0; i < a.length; i++) d |= a[i] ^ b[i];
  return d === 0;
}
```

> **Note for the implementer:** `parseAppleNonce` is the one piece that needs a real device attestation blob to finalize and test (Apple publishes no offline test vector). Everything else — assertion verify, counter anti-replay, cert-chain verify, appID/keyId checks — is testable now. Capture a real attestation in Task 10 and complete `parseAppleNonce` then; the assertion path (Steps 1–4) is what every live request uses and is fully covered here.

- [ ] **Step 4: Run the assertion tests to verify they pass**

```bash
deno test --allow-import supabase/functions/kai-proxy/appattest_test.ts
```

Expected: both `verifyAssertion` tests PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/kai-proxy/appattest.ts supabase/functions/kai-proxy/appattest_test.ts supabase/functions/kai-proxy/appattest_test_helpers.ts
git commit -m "feat(proxy): App Attest assertion + attestation verification"
```

---

### Task 3: Rate-limiting module

**Files:**
- Create: `supabase/functions/kai-proxy/ratelimit.ts`
- Test: `supabase/functions/kai-proxy/ratelimit_test.ts`

**Interfaces:**
- Consumes: a `Db` port — `{ getCounts(keyId, day): Promise<{chat:number,vision:number}>; increment(keyId, day, kind): Promise<void> }`.
- Produces: `checkAndIncrement(db: Db, keyId: string, kind: "chat" | "vision", today: string): Promise<{ allowed: boolean }>` with caps `CHAT_LIMIT = 50`, `VISION_LIMIT = 20`.

- [ ] **Step 1: Write the failing test**

Create `supabase/functions/kai-proxy/ratelimit_test.ts` with an in-memory `Db`:

```ts
import { assertEquals } from "jsr:@std/assert";
import { checkAndIncrement } from "./ratelimit.ts";

function memDb() {
  const m = new Map<string, { chat: number; vision: number }>();
  const k = (id: string, d: string) => `${id}:${d}`;
  return {
    store: m,
    async getCounts(id: string, d: string) { return m.get(k(id, d)) ?? { chat: 0, vision: 0 }; },
    async increment(id: string, d: string, kind: "chat" | "vision") {
      const c = m.get(k(id, d)) ?? { chat: 0, vision: 0 }; c[kind]++; m.set(k(id, d), c);
    },
  };
}

Deno.test("allows under the chat cap and increments", async () => {
  const db = memDb();
  const r = await checkAndIncrement(db, "dev1", "chat", "2026-06-20");
  assertEquals(r.allowed, true);
  assertEquals((await db.getCounts("dev1", "2026-06-20")).chat, 1);
});

Deno.test("blocks at the chat cap of 50", async () => {
  const db = memDb();
  db.store.set("dev1:2026-06-20", { chat: 50, vision: 0 });
  const r = await checkAndIncrement(db, "dev1", "chat", "2026-06-20");
  assertEquals(r.allowed, false);
});

Deno.test("vision cap is independent at 20", async () => {
  const db = memDb();
  db.store.set("dev1:2026-06-20", { chat: 50, vision: 19 });
  assertEquals((await checkAndIncrement(db, "dev1", "vision", "2026-06-20")).allowed, true);
  assertEquals((await checkAndIncrement(db, "dev1", "vision", "2026-06-20")).allowed, false);
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
deno test supabase/functions/kai-proxy/ratelimit_test.ts
```

Expected: FAIL — `Module not found "./ratelimit.ts"`.

- [ ] **Step 3: Implement `ratelimit.ts`**

```ts
export const CHAT_LIMIT = 50;
export const VISION_LIMIT = 20;

export interface Db {
  getCounts(keyId: string, day: string): Promise<{ chat: number; vision: number }>;
  increment(keyId: string, day: string, kind: "chat" | "vision"): Promise<void>;
}

export async function checkAndIncrement(
  db: Db, keyId: string, kind: "chat" | "vision", today: string,
): Promise<{ allowed: boolean }> {
  const counts = await db.getCounts(keyId, today);
  const cap = kind === "chat" ? CHAT_LIMIT : VISION_LIMIT;
  if (counts[kind] >= cap) return { allowed: false };
  await db.increment(keyId, today, kind);
  return { allowed: true };
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
deno test supabase/functions/kai-proxy/ratelimit_test.ts
```

Expected: all three tests PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/kai-proxy/ratelimit.ts supabase/functions/kai-proxy/ratelimit_test.ts
git commit -m "feat(proxy): per-device daily rate limiting"
```

---

### Task 4: Anthropic forwarder (pinned params)

**Files:**
- Create: `supabase/functions/kai-proxy/anthropic.ts`
- Test: `supabase/functions/kai-proxy/anthropic_test.ts`

**Interfaces:**
- Produces:
  - `buildChatBody(messages: {role:string;content:string}[], systemPrompt: string): object`
  - `buildVisionBody(imageBase64: string, systemPrompt: string): object`
  - `callAnthropic(apiKey: string, body: object, fetchImpl?: typeof fetch): Promise<{ status: number; text: string }>` — returns the assistant text or an error string.

- [ ] **Step 1: Write the failing test**

Create `supabase/functions/kai-proxy/anthropic_test.ts`:

```ts
import { assertEquals } from "jsr:@std/assert";
import { buildChatBody, buildVisionBody, callAnthropic } from "./anthropic.ts";

Deno.test("buildChatBody pins model and max_tokens", () => {
  const b = buildChatBody([{ role: "user", content: "hi" }], "sys") as Record<string, unknown>;
  assertEquals(b.model, "claude-sonnet-4-6");
  assertEquals(b.max_tokens, 1024);
  assertEquals(b.system, "sys");
});

Deno.test("buildVisionBody embeds a base64 image block", () => {
  const b = buildVisionBody("AAAA", "sys") as any;
  assertEquals(b.messages[0].content[0].source.data, "AAAA");
});

Deno.test("callAnthropic returns assistant text on 200", async () => {
  const fake: typeof fetch = async () =>
    new Response(JSON.stringify({ content: [{ text: "hello" }] }), { status: 200 });
  const r = await callAnthropic("k", buildChatBody([{ role: "user", content: "x" }], "s"), fake);
  assertEquals(r.status, 200);
  assertEquals(r.text, "hello");
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
deno test --allow-net supabase/functions/kai-proxy/anthropic_test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement `anthropic.ts`**

```ts
const MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 1024;
const VERSION = "2023-06-01";
const URL = "https://api.anthropic.com/v1/messages";

export function buildChatBody(messages: { role: string; content: string }[], systemPrompt: string) {
  return { model: MODEL, max_tokens: MAX_TOKENS, system: systemPrompt, messages };
}

export function buildVisionBody(imageBase64: string, systemPrompt: string) {
  return {
    model: MODEL, max_tokens: MAX_TOKENS, system: systemPrompt,
    messages: [{
      role: "user",
      content: [
        { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
        { type: "text", text: "Analyse this image and respond with structured JSON only." },
      ],
    }],
  };
}

export async function callAnthropic(apiKey: string, body: object, fetchImpl: typeof fetch = fetch) {
  const res = await fetchImpl(URL, {
    method: "POST",
    headers: { "x-api-key": apiKey, "anthropic-version": VERSION, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (res.status < 200 || res.status >= 300) {
    return { status: res.status, text: await res.text() };
  }
  const json = await res.json();
  return { status: 200, text: json.content?.[0]?.text ?? "" };
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
deno test --allow-net supabase/functions/kai-proxy/anthropic_test.ts
```

Expected: all three PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/kai-proxy/anthropic.ts supabase/functions/kai-proxy/anthropic_test.ts
git commit -m "feat(proxy): Anthropic forwarder with server-pinned model/max_tokens"
```

---

### Task 5: HTTP router wiring the function together

**Files:**
- Create: `supabase/functions/kai-proxy/index.ts`

**Interfaces:**
- Consumes: `verifyAssertion`, `clientDataHash`, `verifyAttestation` (Task 2); `checkAndIncrement` + `Db` (Task 3); `buildChatBody`, `buildVisionBody`, `callAnthropic` (Task 4).
- Produces: deployable function with routes `GET /challenge`, `POST /attest`, `POST /chat`, `POST /vision`.

- [ ] **Step 1: Implement the router**

Create `supabase/functions/kai-proxy/index.ts`:

```ts
import { createClient } from "jsr:@supabase/supabase-js@2";
import { verifyAssertion, verifyAttestation, clientDataHash } from "./appattest.ts";
import { checkAndIncrement, type Db } from "./ratelimit.ts";
import { buildChatBody, buildVisionBody, callAnthropic } from "./anthropic.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const APPLE_TEAM_ID = Deno.env.get("APPLE_TEAM_ID")!;
const APP_BUNDLE_ID = Deno.env.get("APP_BUNDLE_ID")!;
const APP_ID = `${APPLE_TEAM_ID}.${APP_BUNDLE_ID}`;
const DEV_BYPASS_ENABLED = Deno.env.get("DEV_BYPASS_ENABLED") === "true";
const DEV_BYPASS_TOKEN = Deno.env.get("DEV_BYPASS_TOKEN") ?? "";

if (DEV_BYPASS_ENABLED) {
  console.warn("⚠️  DEV_BYPASS_ENABLED is true — App Attest is bypassable. NEVER enable in production.");
}

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const db: Db = {
  async getCounts(keyId, day) {
    const { data } = await sb.from("usage_counters").select("chat_count,vision_count").eq("key_id", keyId).eq("day", day).maybeSingle();
    return { chat: data?.chat_count ?? 0, vision: data?.vision_count ?? 0 };
  },
  async increment(keyId, day, kind) {
    const col = kind === "chat" ? "chat_count" : "vision_count";
    const cur = await this.getCounts(keyId, day);
    await sb.from("usage_counters").upsert({
      key_id: keyId, day, chat_count: cur.chat + (kind === "chat" ? 1 : 0), vision_count: cur.vision + (kind === "vision" ? 1 : 0),
    }, { onConflict: "key_id,day" });
  },
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function today(): string { return new Date().toISOString().slice(0, 10); }

async function randomChallenge(): Promise<string> {
  const b = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...b));
}

// Returns the device key_id if the request is authentic, else null.
async function authenticate(req: Request, rawBody: Uint8Array): Promise<string | null> {
  const keyId = req.headers.get("x-key-id");
  if (!keyId) return null;

  if (DEV_BYPASS_ENABLED && req.headers.get("x-dev-bypass") === DEV_BYPASS_TOKEN && DEV_BYPASS_TOKEN) {
    return keyId; // simulator path; gated by server flag + matching token
  }

  const challenge = req.headers.get("x-challenge");
  const assertionB64 = req.headers.get("x-assertion");
  if (!challenge || !assertionB64) return null;

  // consume the challenge (single use)
  const { data: ch } = await sb.from("attest_challenges").select("challenge").eq("challenge", challenge).maybeSingle();
  if (!ch) return null;
  await sb.from("attest_challenges").delete().eq("challenge", challenge);

  const { data: dev } = await sb.from("attest_devices").select("public_key,sign_count").eq("key_id", keyId).maybeSingle();
  if (!dev) return null;

  const cdh = await clientDataHash(challenge, rawBody);
  const res = await verifyAssertion({
    publicKeyDer: Uint8Array.from(atob(dev.public_key), (c) => c.charCodeAt(0)),
    storedSignCount: dev.sign_count, assertionB64, clientDataHash: cdh,
  });
  if (!res.ok) return null;
  await sb.from("attest_devices").update({ sign_count: res.newSignCount }).eq("key_id", keyId);
  return keyId;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/kai-proxy/, "");

  if (req.method === "GET" && path === "/challenge") {
    const challenge = await randomChallenge();
    await sb.from("attest_challenges").insert({ challenge });
    return json({ challenge });
  }

  if (req.method === "POST" && path === "/attest") {
    const { keyId, attestation, challenge } = await req.json();
    const { data: ch } = await sb.from("attest_challenges").select("challenge").eq("challenge", challenge).maybeSingle();
    if (!ch) return json({ error: "bad challenge" }, 400);
    await sb.from("attest_challenges").delete().eq("challenge", challenge);
    try {
      const { publicKeyDer, signCount } = await verifyAttestation({ attestationB64: attestation, keyId, challenge, appId: APP_ID });
      await sb.from("attest_devices").upsert({
        key_id: keyId, public_key: btoa(String.fromCharCode(...publicKeyDer)), sign_count: signCount,
      });
      return json({ ok: true });
    } catch (e) {
      return json({ error: String(e) }, 401);
    }
  }

  if (req.method === "POST" && (path === "/chat" || path === "/vision")) {
    const rawBody = new Uint8Array(await req.arrayBuffer());
    const keyId = await authenticate(req, rawBody);
    if (!keyId) return json({ error: "unauthorized" }, 401);

    const kind = path === "/chat" ? "chat" : "vision";
    const rl = await checkAndIncrement(db, keyId, kind, today());
    if (!rl.allowed) return json({ error: "rate_limited" }, 429);

    const payload = JSON.parse(new TextDecoder().decode(rawBody));
    const body = kind === "chat"
      ? buildChatBody(payload.messages, payload.systemPrompt)
      : buildVisionBody(payload.imageBase64, payload.systemPrompt);
    const result = await callAnthropic(ANTHROPIC_API_KEY, body);
    if (result.status !== 200) return json({ error: result.text }, result.status);
    return json({ text: result.text });
  }

  return json({ error: "not found" }, 404);
});
```

- [ ] **Step 2: Serve locally and smoke-test `/challenge`**

```bash
supabase functions serve kai-proxy --env-file supabase/functions/kai-proxy/.env.local --no-verify-jwt
# in another shell:
curl -s http://localhost:54321/functions/v1/kai-proxy/challenge
```

Create `supabase/functions/kai-proxy/.env.local` first (gitignored — see Task 1 `.gitignore` step below) with local values:

```
ANTHROPIC_API_KEY=sk-ant-REPLACE_WITH_FRESH_KEY
APPLE_TEAM_ID=REPLACE
APP_BUNDLE_ID=com.yourcompany.KAIZENN
DEV_BYPASS_ENABLED=true
DEV_BYPASS_TOKEN=local-dev-token
```

Expected: `{"challenge":"<base64>"}`.

- [ ] **Step 3: Add `.env.local` to `.gitignore`**

Append to repo `.gitignore`:

```
# Supabase function local secrets
supabase/functions/**/.env.local
.env.local
```

- [ ] **Step 4: Smoke-test `/chat` via the dev bypass**

```bash
curl -s -X POST http://localhost:54321/functions/v1/kai-proxy/chat \
  -H "x-key-id: testdev" -H "x-dev-bypass: local-dev-token" \
  -H "content-type: application/json" \
  -d '{"messages":[{"role":"user","content":"Say hi in 3 words"}],"systemPrompt":"Be terse."}'
```

Expected: `{"text":"..."}` from Claude (requires a valid `ANTHROPIC_API_KEY` in `.env.local`). On a missing/expired key, expect a 4xx with the Anthropic error — that confirms wiring.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/kai-proxy/index.ts .gitignore
git commit -m "feat(proxy): HTTP router with challenge/attest/chat/vision + dev bypass"
```

---

### Task 6: iOS `ProxyConfig` constant

**Files:**
- Create: `KAIZENN/Core/Networking/ProxyConfig.swift`

**Interfaces:**
- Produces: `enum ProxyConfig { static let baseURL: URL }`.

- [ ] **Step 1: Create the file**

```swift
import Foundation

/// Base URL of the kai-proxy Supabase Edge Function.
/// This is NOT a secret — the security model assumes attackers know the endpoint;
/// App Attest is what gates access. Safe to ship in the binary.
enum ProxyConfig {
    #if DEBUG
    // Local `supabase functions serve` or a staging project.
    static let baseURL = URL(string: "http://localhost:54321/functions/v1/kai-proxy")!
    #else
    // Production Supabase project (set after `supabase functions deploy`, Task 10).
    static let baseURL = URL(string: "https://REPLACE_PROJECT_REF.supabase.co/functions/v1/kai-proxy")!
    #endif
}
```

- [ ] **Step 2: Confirm it compiles in the iOS target**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

> Add the new file to the Xcode target first (drag into `Core/Networking` group in Xcode, or it won't be compiled). Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add KAIZENN/Core/Networking/ProxyConfig.swift KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(ios): add ProxyConfig base URL constant"
```

---

### Task 7: iOS `AppAttestManager`

**Files:**
- Create: `KAIZENN/Core/Networking/AppAttestManager.swift`

**Interfaces:**
- Produces:
  - `actor AppAttestManager` with `static let shared`.
  - `func authHeaders(for body: Data) async throws -> [String: String]` — returns `["x-key-id", "x-challenge", "x-assertion"]` on device, or `["x-key-id", "x-dev-bypass"]` on the Simulator in DEBUG.
- Consumes: `ProxyConfig.baseURL` (Task 6).

- [ ] **Step 1: Implement the manager**

```swift
import Foundation
import DeviceCheck
import CryptoKit

enum AppAttestError: LocalizedError {
    case unsupported, noKeyId, attestFailed(String), challengeFailed
    var errorDescription: String? {
        switch self {
        case .unsupported:        return "This device can't be verified for AI features."
        case .noKeyId:            return "Device attestation key missing."
        case .attestFailed(let m):return "Device attestation failed: \(m)"
        case .challengeFailed:    return "Couldn't reach the verification service."
        }
    }
}

actor AppAttestManager {
    static let shared = AppAttestManager()
    private let service = DCAppAttestService.shared
    private let keychainTag = "com.kaizenn.appattest.keyId"

    #if DEBUG
    // Mirrors DEV_BYPASS_TOKEN in the proxy's env. Compiled out of release builds.
    private let devBypassToken = "local-dev-token"
    #endif

    /// Headers that authenticate a request whose body is `body`.
    func authHeaders(for body: Data) async throws -> [String: String] {
        #if targetEnvironment(simulator)
        // App Attest is unavailable on the Simulator; use the two-gated dev bypass.
        #if DEBUG
        return ["x-key-id": "simulator-\(deviceKeyIdFallback())", "x-dev-bypass": devBypassToken]
        #else
        throw AppAttestError.unsupported
        #endif
        #else
        guard service.isSupported else { throw AppAttestError.unsupported }
        let keyId = try await ensureAttestedKey()
        let challenge = try await fetchChallenge()
        // clientDataHash = SHA256(challenge ‖ body) — must match the proxy.
        var data = Data(challenge.utf8); data.append(body)
        let hash = Data(SHA256.hash(data: data))
        let assertion = try await service.generateAssertion(keyId, clientDataHash: hash)
        return [
            "x-key-id": keyId,
            "x-challenge": challenge,
            "x-assertion": assertion.base64EncodedString(),
        ]
        #endif
    }

    // MARK: - Attestation (once per install)

    private func ensureAttestedKey() async throws -> String {
        if let existing = loadKeyId() { return existing }
        let keyId = try await service.generateKey()
        let challenge = try await fetchChallenge()
        let hash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await service.attestKey(keyId, clientDataHash: hash)
        try await postAttestation(keyId: keyId, attestation: attestation, challenge: challenge)
        saveKeyId(keyId)
        return keyId
    }

    private func fetchChallenge() async throws -> String {
        let url = ProxyConfig.baseURL.appendingPathComponent("challenge")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONDecoder().decode([String: String].self, from: data),
              let c = obj["challenge"] else { throw AppAttestError.challengeFailed }
        return c
    }

    private func postAttestation(keyId: String, attestation: Data, challenge: String) async throws {
        var req = URLRequest(url: ProxyConfig.baseURL.appendingPathComponent("attest"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "keyId": keyId, "attestation": attestation.base64EncodedString(), "challenge": challenge,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppAttestError.attestFailed(String(data: data, encoding: .utf8) ?? "unknown")
        }
    }

    // MARK: - Keychain persistence of the key ID

    private func saveKeyId(_ id: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: keychainTag]
        SecItemDelete(q as CFDictionary)
        var add = q; add[kSecValueData as String] = Data(id.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    private func loadKeyId() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: keychainTag,
                                kSecReturnData as String: true]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    #if DEBUG
    private func deviceKeyIdFallback() -> String {
        if let id = loadKeyId() { return id }
        let id = UUID().uuidString; saveKeyId(id); return id
    }
    #endif
}
```

- [ ] **Step 2: Build for the iOS target**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

> Add the file to the target in Xcode first. Expected: `** BUILD SUCCEEDED **`. (Ignore SourceKit single-file errors per project convention.)

- [ ] **Step 3: Commit**

```bash
git add KAIZENN/Core/Networking/AppAttestManager.swift KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(ios): AppAttestManager for attestation + per-request assertion"
```

---

### Task 8: Rewrite `ClaudeService` to call the proxy

**Files:**
- Modify: `KAIZENN/Data/Network/ClaudeService.swift`
- Test: `KAIZENNTests/ClaudeServiceTests.swift` (create)

**Interfaces:**
- Consumes: `AppAttestManager.shared.authHeaders(for:)` (Task 7), `ProxyConfig.baseURL` (Task 6).
- Produces: unchanged public API — `static func chat(messages:systemPrompt:) async throws -> String`, `static func chatWithImage(image:systemPrompt:) async throws -> String`. New: `static var session: URLSession` (injectable for tests), `ClaudeError.rateLimited`.

- [ ] **Step 1: Write the failing test**

Create `KAIZENNTests/ClaudeServiceTests.swift`:

```swift
import XCTest
@testable import KAIZENN

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        let (resp, data) = Self.handler!(request)
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ClaudeServiceTests: XCTestCase {
    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        ClaudeService.session = URLSession(configuration: config)
    }

    func testChatReturnsProxyText() async throws {
        MockURLProtocol.handler = { req in
            // proxy responds with {"text":"..."}
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, #"{"text":"hi there"}"#.data(using: .utf8)!)
        }
        let reply = try await ClaudeService.chat(messages: [ChatMessage(text: "hi", isUser: true)], systemPrompt: "s")
        XCTAssertEqual(reply, "hi there")
    }

    func testRateLimitMapsToError() async {
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (resp, #"{"error":"rate_limited"}"#.data(using: .utf8)!)
        }
        do {
            _ = try await ClaudeService.chat(messages: [ChatMessage(text: "hi", isUser: true)], systemPrompt: "s")
            XCTFail("expected throw")
        } catch let ClaudeError.rateLimited {
            // expected
        } catch { XCTFail("wrong error: \(error)") }
    }
}
```

> Note: the test's `authHeaders` path runs on the Simulator → DEBUG dev-bypass branch, so no network attestation occurs. The mock intercepts the `/chat` POST.

- [ ] **Step 2: Run the test to verify it fails**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "ClaudeServiceTests|error:" | head
```

Expected: FAIL — `ClaudeService.session` / `ClaudeError.rateLimited` undefined.

- [ ] **Step 3: Rewrite `ClaudeService.swift`**

Replace the whole file with the proxy-calling version:

```swift
import Foundation
import UIKit

// MARK: — Claude AI Service (via kai-proxy)
// The Anthropic key lives ONLY in the Supabase Edge Function. Every call is
// authenticated with App Attest (see AppAttestManager) and rate-limited server-side.

enum ClaudeError: LocalizedError {
    case invalidResponse
    case requestFailed(String)
    case noContent
    case rateLimited
    case unverifiedDevice

    var errorDescription: String? {
        switch self {
        case .invalidResponse:        return "Unexpected response from AI service."
        case .requestFailed(let msg): return msg
        case .noContent:              return "No response received from AI."
        case .rateLimited:            return "You've hit today's AI limit — it resets tomorrow."
        case .unverifiedDevice:       return "Couldn't verify this device for AI features."
        }
    }
}

struct ClaudeService {
    /// Injectable for tests; defaults to the shared session.
    static var session: URLSession = .shared

    static func chat(messages: [ChatMessage], systemPrompt: String) async throws -> String {
        let anthropicMessages = messages.map { ["role": $0.isUser ? "user" : "assistant", "content": $0.text] }
        let payload: [String: Any] = ["messages": anthropicMessages, "systemPrompt": systemPrompt]
        return try await post(path: "chat", payload: payload)
    }

    static func chatWithImage(image: UIImage, systemPrompt: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeError.requestFailed("Failed to encode image")
        }
        let payload: [String: Any] = ["imageBase64": imageData.base64EncodedString(), "systemPrompt": systemPrompt]
        return try await post(path: "vision", payload: payload)
    }

    // MARK: - Shared proxy POST

    private static func post(path: String, payload: [String: Any]) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: payload)
        let headers: [String: String]
        do { headers = try await AppAttestManager.shared.authHeaders(for: body) }
        catch { throw ClaudeError.unverifiedDevice }

        var request = URLRequest(url: ProxyConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }

        switch http.statusCode {
        case 200..<300: break
        case 401:       throw ClaudeError.unverifiedDevice
        case 429:       throw ClaudeError.rateLimited
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.requestFailed("API error \(http.statusCode): \(msg)")
        }

        let decoded = try JSONDecoder().decode(ProxyReply.self, from: data)
        guard let text = decoded.text, !text.isEmpty else { throw ClaudeError.noContent }
        return text
    }
}

private struct ProxyReply: Decodable { let text: String? }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Test Suite|ClaudeServiceTests|passed|failed" | head
```

Expected: `ClaudeServiceTests` — both tests pass; the existing 30 tests still pass.

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Data/Network/ClaudeService.swift KAIZENNTests/ClaudeServiceTests.swift KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(ios): route ClaudeService through kai-proxy; map 401/429 errors"
```

---

### Task 9: Remove the embedded key + add the App Attest entitlement

**Files:**
- Modify: `KAIZENN/Info.plist:59-60` (remove `ClaudeAPIKey`)
- Modify: `KAIZENN/Config.xcconfig` (remove `CLAUDE_API_KEY` — local, gitignored)
- Modify: `KAIZENN/KAIZENN.entitlements` (add App Attest)

**Interfaces:** none consumed/produced (config only).

- [ ] **Step 1: Remove `ClaudeAPIKey` from Info.plist**

Delete these two lines (`KAIZENN/Info.plist:59-60`):

```xml
	<key>ClaudeAPIKey</key>
	<string>$(CLAUDE_API_KEY)</string>
```

- [ ] **Step 2: Remove the key from Config.xcconfig**

Delete the `CLAUDE_API_KEY = ...` line from `KAIZENN/Config.xcconfig`. The file may now be empty except comments — that's fine; leave it so the build setting reference doesn't break. (This is a local, gitignored file; do not commit it.)

- [ ] **Step 3: Add the App Attest entitlement**

Edit `KAIZENN/KAIZENN.entitlements` to add (inside the top-level `<dict>`):

```xml
	<key>com.apple.developer.devicecheck.appattest-environment</key>
	<string>development</string>
```

> For the App Store/TestFlight build this value becomes `production` (managed via build config or a separate release entitlements file). Note this for Task 10.

- [ ] **Step 4: Build to confirm nothing references the removed key**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **` (no references to `ClaudeAPIKey` remain — that was only `ClaudeService.apiKey`, removed in Task 8).

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Info.plist KAIZENN/KAIZENN.entitlements
git commit -m "feat(ios): remove embedded Anthropic key; add App Attest entitlement"
```

---

### Task 10: Deploy proxy + real-device attestation test

**Files:** none (deployment + manual verification). May modify `appattest.ts` to complete `parseAppleNonce`.

- [ ] **Step 1: Create the production Supabase project + push schema**

```bash
supabase login
supabase projects create kaizenn-proxy --org-id <your-org>   # or use an existing project
supabase link --project-ref <project-ref>
supabase db push   # applies migration 0001 to the remote DB
```

- [ ] **Step 2: Set production secrets (with a FRESH key)**

Generate a NEW key at console.anthropic.com (do not reuse the compromised one), then:

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-NEW_KEY
supabase secrets set APPLE_TEAM_ID=<your-team-id>
supabase secrets set APP_BUNDLE_ID=<your-bundle-id>
# DEV_BYPASS_ENABLED intentionally NOT set in production.
supabase functions deploy kai-proxy --no-verify-jwt
```

- [ ] **Step 3: Point the release build at production**

In `ProxyConfig.swift`, set the `#else` (release) `baseURL` to `https://<project-ref>.supabase.co/functions/v1/kai-proxy`. Commit.

- [ ] **Step 4: Run on a real device and capture an attestation**

Build to a physical iPhone (App Attest requires real hardware). Trigger a Coach message. Add a temporary `print()` of the base64 attestation in `postAttestation`, copy it from the device console, and use it to finalize + unit-test `parseAppleNonce` in `appattest.ts`. Re-deploy the function.

- [ ] **Step 5: Verify end-to-end + commit any `appattest.ts` fix**

On the device: Coach chat returns a reply; food-photo and training-whiteboard scans work. In Supabase, confirm a row in `attest_devices` and incrementing `usage_counters`.

```bash
git add supabase/functions/kai-proxy/appattest.ts KAIZENN/Core/Networking/ProxyConfig.swift
git commit -m "feat(proxy): finalize attestation nonce parsing; point release at prod"
```

---

### Task 11: Rotate the compromised key

**Files:** none.

- [ ] **Step 1: Confirm the new key is live**

Verify (Task 10 Step 5) that the deployed function uses the NEW key and the app works end-to-end through it.

- [ ] **Step 2: Revoke the old key**

At console.anthropic.com → API Keys, **delete/disable** the old key
(`sk-ant-api03-YppK...` from the old `Config.xcconfig`). Any old IPA still holding it stops working — intended.

- [ ] **Step 3: Verify the old key is dead**

```bash
curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: <OLD_KEY>" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-6","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}'
```

Expected: `401` authentication error — confirms the old key is revoked. Done.

---

## Self-Review

**Spec coverage:**
- Hosting (Supabase Edge Function) → Tasks 1, 5, 10. ✓
- App Attest (challenge/attest/assert, anti-replay counter, appID/keyId) → Task 2, router Task 5. ✓
- Locked-down `/chat` + `/vision`, pinned model/max_tokens/version → Task 4. ✓
- Postgres tables (attest_devices, attest_challenges, usage_counters) → Task 1. ✓
- Rate limiting 50/20 per device/day → Task 3, enforced Task 5. ✓
- iOS AppAttestManager + Keychain key-id persistence → Task 7. ✓
- ClaudeService rewrite keeping signatures + error mapping (401/429) → Task 8. ✓
- Remove ClaudeAPIKey from Info.plist/Config.xcconfig; add entitlement → Task 9. ✓
- Two-gate dev bypass (#if DEBUG + DEV_BYPASS_ENABLED) → Task 5 (server) + Task 7 (client). ✓
- ProxyConfig URL constant with dev/prod switch → Task 6, 10. ✓
- Key rotation at cutover → Task 11. ✓
- Testing: Deno tests (Tasks 2–4), URLProtocol iOS tests (Task 8), real-device manual (Task 10). ✓

**Placeholder scan:** The only deferred item is `parseAppleNonce` (Task 2), explicitly flagged and scheduled for completion in Task 10 with a real attestation blob — it cannot be written offline without an Apple test vector. All other steps contain complete code.

**Type consistency:** `authHeaders(for:)` produces the exact header names the router's `authenticate()` reads (`x-key-id`, `x-challenge`, `x-assertion`, `x-dev-bypass`). `clientDataHash(challenge ‖ body)` is computed identically on client (Task 7) and server (Task 2). `ClaudeService.chat`/`chatWithImage` signatures unchanged (verified against the three call sites). `checkAndIncrement` / `Db` names match between Task 3 and Task 5.
