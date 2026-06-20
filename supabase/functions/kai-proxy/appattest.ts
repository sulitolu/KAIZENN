import { decodeCBOR } from "jsr:@levischuck/tiny-cbor@0.2";
import { Buffer } from "node:buffer";
import { X509Certificate } from "node:crypto";

const te = new TextEncoder();

/** clientDataHash = SHA256(challenge ‖ body) — the value the iOS app passes to generateAssertion. */
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

// Normalize to an ArrayBuffer-backed view. CBOR/cert-decoded arrays are typed
// Uint8Array<ArrayBufferLike>, which WebCrypto's BufferSource param rejects under
// Deno's strict lib types. The copies here are tiny (keys, hashes, signatures).
function ab(u: Uint8Array): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(u.length);
  out.set(u);
  return out;
}

function signCountFromAuthData(ad: Uint8Array): number {
  // authenticatorData: 32-byte rpIdHash + 1 flag byte + 4-byte big-endian signCount @ offset 33.
  return new DataView(ad.buffer, ad.byteOffset).getUint32(33, false);
}

/**
 * Verify an App Attest assertion.
 * Apple signs (authenticatorData ‖ clientDataHash) with ECDSA-SHA256, where
 * clientDataHash is already SHA256(challenge ‖ body). WebCrypto's verify applies
 * SHA-256 internally, so we pass the un-rehashed concatenation as the message.
 * Anti-replay: the signCount in authenticatorData must strictly exceed the stored value.
 */
export async function verifyAssertion(opts: {
  publicKeyDer: Uint8Array;
  storedSignCount: number;
  assertionB64: string;
  clientDataHash: Uint8Array;
}): Promise<{ ok: boolean; newSignCount: number }> {
  const obj = decodeCBOR(b64ToBytes(opts.assertionB64)) as Map<string, Uint8Array>;
  const signatureDer = obj.get("signature")!;
  const authenticatorData = obj.get("authenticatorData")!;

  const newSignCount = signCountFromAuthData(authenticatorData);
  if (newSignCount <= opts.storedSignCount) return { ok: false, newSignCount };

  const signed = new Uint8Array(authenticatorData.length + opts.clientDataHash.length);
  signed.set(authenticatorData, 0);
  signed.set(opts.clientDataHash, authenticatorData.length);

  const key = await crypto.subtle.importKey(
    "spki", ab(opts.publicKeyDer), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"],
  );
  const sigRaw = derToRaw(signatureDer);
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, ab(sigRaw), ab(signed));
  return { ok, newSignCount };
}

/** Convert an ASN.1 DER ECDSA signature to raw r‖s (64 bytes) for WebCrypto verify. */
function derToRaw(der: Uint8Array): Uint8Array {
  let i = 2; // skip SEQUENCE tag (0x30) + length
  if (der[i++] !== 0x02) throw new Error("bad DER: expected INTEGER for r");
  const rLen = der[i++];
  const r = der.slice(i, i + rLen); i += rLen;
  if (der[i++] !== 0x02) throw new Error("bad DER: expected INTEGER for s");
  const sLen = der[i++];
  const s = der.slice(i, i + sLen);
  const pad = (b: Uint8Array) => {
    const v = b[0] === 0 ? b.slice(1) : b;
    const o = new Uint8Array(32);
    o.set(v, 32 - v.length);
    return o;
  };
  return new Uint8Array([...pad(r), ...pad(s)]);
}

// Apple App Attest Root CA — used to anchor the attestation certificate chain.
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

/**
 * Verify an App Attest attestation (one-time per install). Confirms the cert chain
 * anchors to Apple's root, the nonce matches SHA256(authData ‖ SHA256(challenge)),
 * the appID and keyId match, and returns the device public key + initial signCount.
 *
 * NOTE: `parseAppleNonce` is finalized against a real captured device attestation in
 * the deploy/device-test task — Apple publishes no offline attestation test vector.
 */
export async function verifyAttestation(opts: {
  attestationB64: string; keyId: string; challenge: string; appId: string;
}): Promise<{ publicKeyDer: Uint8Array; signCount: number }> {
  const att = decodeCBOR(b64ToBytes(opts.attestationB64)) as Map<string, unknown>;
  if (att.get("fmt") !== "apple-appattest") throw new Error("bad attestation fmt");
  const attStmt = att.get("attStmt") as Map<string, unknown>;
  const x5c = attStmt.get("x5c") as Uint8Array[];
  const authData = att.get("authData") as Uint8Array;

  await verifyCertChain(x5c, APPLE_ROOT_CA_PEM);

  const chHash = new Uint8Array(await crypto.subtle.digest("SHA-256", te.encode(opts.challenge)));
  const nonceInput = new Uint8Array(authData.length + chHash.length);
  nonceInput.set(authData, 0);
  nonceInput.set(chHash, authData.length);
  const expectedNonce = new Uint8Array(await crypto.subtle.digest("SHA-256", nonceInput));
  if (!bytesEqual(expectedNonce, extractNonceExtension(x5c[0]))) throw new Error("nonce mismatch");

  const appIdHash = new Uint8Array(await crypto.subtle.digest("SHA-256", te.encode(opts.appId)));
  if (!bytesEqual(authData.slice(0, 32), appIdHash)) throw new Error("appId mismatch");

  const publicKeyDer = extractSpkiFromCert(x5c[0]);
  const pubKeyHash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", ab(rawPubKeyFromSpki(publicKeyDer))),
  );
  if (btoa(String.fromCharCode(...pubKeyHash)) !== opts.keyId) throw new Error("keyId mismatch");

  return { publicKeyDer, signCount: signCountFromAuthData(authData) };
}

function verifyCertChain(x5c: Uint8Array[], rootPem: string): Promise<void> {
  const leaf = new X509Certificate(Buffer.from(x5c[0]));
  const inter = new X509Certificate(Buffer.from(x5c[1]));
  const root = new X509Certificate(rootPem);
  if (!leaf.verify(inter.publicKey)) throw new Error("leaf not signed by intermediate");
  if (!inter.verify(root.publicKey)) throw new Error("intermediate not signed by root");
  return Promise.resolve();
}

function extractSpkiFromCert(der: Uint8Array): Uint8Array {
  const cert = new X509Certificate(Buffer.from(der));
  return new Uint8Array(cert.publicKey.export({ type: "spki", format: "der" }) as Buffer);
}

// P-256 SPKI ends with the 65-byte uncompressed point (0x04 ‖ X ‖ Y); keyId hashes that point.
function rawPubKeyFromSpki(spki: Uint8Array): Uint8Array {
  return spki.slice(spki.length - 65);
}

function extractNonceExtension(_der: Uint8Array): Uint8Array {
  // OID 1.2.840.113635.100.8.2 — Apple stores the nonce as a DER OCTET STRING in a SEQUENCE.
  // Finalized against a real device attestation in the deploy/device-test task.
  throw new Error(
    "extractNonceExtension: implement ASN.1 nonce extraction against a real device attestation (deploy task)",
  );
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a[i] ^ b[i];
  return d === 0;
}
