import { assertEquals } from "jsr:@std/assert@1";
import { clientDataHash, verifyAssertion } from "./appattest.ts";
import { encodeAssertion } from "./appattest_test_helpers.ts";

// Minimal authenticatorData: 32-byte rpIdHash + 1 flag byte + 4-byte signCount (big-endian @ offset 33).
function authData(signCount: number): Uint8Array {
  const buf = new Uint8Array(37);
  new DataView(buf.buffer).setUint32(33, signCount, false);
  return buf;
}

// Sign exactly as Apple's Secure Enclave does for an assertion: ECDSA-SHA256 over
// (authenticatorData ‖ clientDataHash). WebCrypto applies the SHA-256 internally,
// so the message passed to sign/verify is the un-rehashed concatenation.
async function makeAssertion(
  privateKey: CryptoKey,
  ad: Uint8Array,
  hash: Uint8Array,
): Promise<string> {
  const signed = new Uint8Array([...ad, ...hash]);
  const sigRaw = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, privateKey, signed),
  );
  return encodeAssertion(sigRaw, ad);
}

Deno.test("clientDataHash is deterministic and SHA-256 sized", async () => {
  const a = await clientDataHash("challenge-1", new TextEncoder().encode("{}"));
  const b = await clientDataHash("challenge-1", new TextEncoder().encode("{}"));
  assertEquals(a.length, 32);
  assertEquals([...a], [...b]);
  const c = await clientDataHash("challenge-2", new TextEncoder().encode("{}"));
  assertEquals(a.length === c.length && [...a].every((v, i) => v === c[i]), false);
});

Deno.test("verifyAssertion accepts a valid, advancing signature", async () => {
  const kp = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"],
  ) as CryptoKeyPair;
  const publicKeyDer = new Uint8Array(await crypto.subtle.exportKey("spki", kp.publicKey));
  const hash = await clientDataHash("challenge-123", new TextEncoder().encode("{}"));
  const ad = authData(5);
  const assertionB64 = await makeAssertion(kp.privateKey, ad, hash);

  const res = await verifyAssertion({
    publicKeyDer, storedSignCount: 4, assertionB64, clientDataHash: hash,
  });
  assertEquals(res.ok, true);
  assertEquals(res.newSignCount, 5);
});

Deno.test("verifyAssertion rejects a replayed (non-advancing) counter", async () => {
  const kp = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"],
  ) as CryptoKeyPair;
  const publicKeyDer = new Uint8Array(await crypto.subtle.exportKey("spki", kp.publicKey));
  const hash = await clientDataHash("c", new TextEncoder().encode("{}"));
  const ad = authData(5);
  const assertionB64 = await makeAssertion(kp.privateKey, ad, hash);

  const res = await verifyAssertion({
    publicKeyDer, storedSignCount: 5, assertionB64, clientDataHash: hash,
  });
  assertEquals(res.ok, false);
});

Deno.test("verifyAssertion rejects a tampered request body (wrong clientDataHash)", async () => {
  const kp = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"],
  ) as CryptoKeyPair;
  const publicKeyDer = new Uint8Array(await crypto.subtle.exportKey("spki", kp.publicKey));
  const realHash = await clientDataHash("c", new TextEncoder().encode("{}"));
  const ad = authData(5);
  const assertionB64 = await makeAssertion(kp.privateKey, ad, realHash);

  // Verify against a DIFFERENT body hash — signature must not validate.
  const tamperedHash = await clientDataHash("c", new TextEncoder().encode('{"evil":1}'));
  const res = await verifyAssertion({
    publicKeyDer, storedSignCount: 4, assertionB64, clientDataHash: tamperedHash,
  });
  assertEquals(res.ok, false);
});
