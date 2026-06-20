import { encodeCBOR } from "jsr:@levischuck/tiny-cbor@0.2";

// Convert a raw (r‖s) P-256 signature to ASN.1 DER, as Apple sends in assertions.
export function rawToDer(raw: Uint8Array): Uint8Array {
  const r = raw.slice(0, 32), s = raw.slice(32, 64);
  const trim = (b: Uint8Array) => {
    let i = 0;
    while (i < b.length - 1 && b[i] === 0) i++;
    let v = b.slice(i);
    if (v[0] & 0x80) v = new Uint8Array([0, ...v]);
    return v;
  };
  const rd = trim(r), sd = trim(s);
  const seqLen = 2 + rd.length + 2 + sd.length;
  return new Uint8Array([0x30, seqLen, 0x02, rd.length, ...rd, 0x02, sd.length, ...sd]);
}

// CBOR-encode an assertion the way the Secure Enclave does: a map with a
// DER-encoded `signature` and the raw `authenticatorData` bytes.
export function encodeAssertion(sigRaw: Uint8Array, authenticatorData: Uint8Array): string {
  const map = new Map<string, Uint8Array>([
    ["signature", rawToDer(sigRaw)],
    ["authenticatorData", authenticatorData],
  ]);
  const cbor = encodeCBOR(map);
  return btoa(String.fromCharCode(...cbor));
}
