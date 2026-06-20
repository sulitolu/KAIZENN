import { createClient } from "jsr:@supabase/supabase-js@2";
import { clientDataHash, verifyAssertion, verifyAttestation } from "./appattest.ts";
import { checkAndIncrement, type Db } from "./ratelimit.ts";
import { buildChatBody, buildVisionBody, callAnthropic } from "./anthropic.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const APPLE_TEAM_ID = Deno.env.get("APPLE_TEAM_ID")!;
const APP_BUNDLE_ID = Deno.env.get("APP_BUNDLE_ID")!;
const APP_ID = `${APPLE_TEAM_ID}.${APP_BUNDLE_ID}`;
const DEV_BYPASS_ENABLED = Deno.env.get("DEV_BYPASS_ENABLED") === "true";
const DEV_BYPASS_TOKEN = Deno.env.get("DEV_BYPASS_TOKEN") ?? "";

if (DEV_BYPASS_ENABLED) {
  console.warn(
    "⚠️  DEV_BYPASS_ENABLED is true — App Attest is bypassable. NEVER enable in production.",
  );
}

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const db: Db = {
  async getCounts(keyId, day) {
    const { data } = await sb
      .from("usage_counters")
      .select("chat_count,vision_count")
      .eq("key_id", keyId)
      .eq("day", day)
      .maybeSingle();
    return { chat: data?.chat_count ?? 0, vision: data?.vision_count ?? 0 };
  },
  async increment(keyId, day, kind) {
    const cur = await this.getCounts(keyId, day);
    await sb.from("usage_counters").upsert({
      key_id: keyId,
      day,
      chat_count: cur.chat + (kind === "chat" ? 1 : 0),
      vision_count: cur.vision + (kind === "vision" ? 1 : 0),
    }, { onConflict: "key_id,day" });
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function randomChallenge(): string {
  const b = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...b));
}

/** Returns the device key_id if the request is authentic, else null. */
async function authenticate(req: Request, rawBody: Uint8Array): Promise<string | null> {
  const keyId = req.headers.get("x-key-id");
  if (!keyId) return null;

  // Simulator/dev path — gated by BOTH the server flag and a matching token.
  if (DEV_BYPASS_ENABLED && DEV_BYPASS_TOKEN && req.headers.get("x-dev-bypass") === DEV_BYPASS_TOKEN) {
    return keyId;
  }

  const challenge = req.headers.get("x-challenge");
  const assertionB64 = req.headers.get("x-assertion");
  if (!challenge || !assertionB64) return null;

  // Consume the challenge (single use).
  const { data: ch } = await sb
    .from("attest_challenges").select("challenge").eq("challenge", challenge).maybeSingle();
  if (!ch) return null;
  await sb.from("attest_challenges").delete().eq("challenge", challenge);

  const { data: dev } = await sb
    .from("attest_devices").select("public_key,sign_count").eq("key_id", keyId).maybeSingle();
  if (!dev) return null;

  const cdh = await clientDataHash(challenge, rawBody);
  const res = await verifyAssertion({
    publicKeyDer: Uint8Array.from(atob(dev.public_key), (c) => c.charCodeAt(0)),
    storedSignCount: Number(dev.sign_count),
    assertionB64,
    clientDataHash: cdh,
  });
  if (!res.ok) return null;

  await sb.from("attest_devices").update({ sign_count: res.newSignCount }).eq("key_id", keyId);
  return keyId;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  // Robust to both "/kai-proxy/<route>" and "/functions/v1/kai-proxy/<route>".
  const path = url.pathname.split("/kai-proxy").pop() ?? "";

  if (req.method === "GET" && path === "/challenge") {
    const challenge = randomChallenge();
    await sb.from("attest_challenges").insert({ challenge });
    return json({ challenge });
  }

  if (req.method === "POST" && path === "/attest") {
    const { keyId, attestation, challenge } = await req.json();
    const { data: ch } = await sb
      .from("attest_challenges").select("challenge").eq("challenge", challenge).maybeSingle();
    if (!ch) return json({ error: "bad challenge" }, 400);
    await sb.from("attest_challenges").delete().eq("challenge", challenge);
    try {
      const { publicKeyDer, signCount } = await verifyAttestation({
        attestationB64: attestation,
        keyId,
        challenge,
        appId: APP_ID,
      });
      await sb.from("attest_devices").upsert({
        key_id: keyId,
        public_key: btoa(String.fromCharCode(...publicKeyDer)),
        sign_count: signCount,
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
