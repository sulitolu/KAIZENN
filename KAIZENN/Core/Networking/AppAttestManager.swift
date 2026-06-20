import Foundation
import DeviceCheck
import CryptoKit

enum AppAttestError: LocalizedError {
    case unsupported
    case attestFailed(String)
    case challengeFailed

    var errorDescription: String? {
        switch self {
        case .unsupported:         return "This device can't be verified for AI features."
        case .attestFailed(let m): return "Device attestation failed: \(m)"
        case .challengeFailed:     return "Couldn't reach the verification service."
        }
    }
}

/// Authenticates proxy requests with Apple App Attest: a one-time hardware-backed
/// attestation per install, then a per-request assertion signed over the request body.
/// On the Simulator (App Attest unavailable) a two-gated dev bypass is used in DEBUG only.
actor AppAttestManager {
    static let shared = AppAttestManager()

    private let service = DCAppAttestService.shared
    private let keychainAccount = "com.kaizenn.appattest.keyId"

    #if DEBUG
    /// Must match DEV_BYPASS_TOKEN in the proxy env. Compiled out of release builds.
    private let devBypassToken = "local-dev-token"
    #endif

    /// Headers that authenticate a request whose body is `body`.
    func authHeaders(for body: Data) async throws -> [String: String] {
        #if DEBUG
        // Dev/testing path: bypass App Attest on BOTH simulator and device, so a
        // debug build can talk to the proxy without the full attestation flow.
        // Gated server-side by DEV_BYPASS_ENABLED (disabled before launch); the
        // token is compiled out of release builds entirely.
        return ["x-key-id": "dev-\(deviceKeyIdFallback())", "x-dev-bypass": devBypassToken]
        #else
        // Production: real App Attest — one-time attestation + per-request assertion.
        guard service.isSupported else { throw AppAttestError.unsupported }
        let keyId = try await ensureAttestedKey()
        let challenge = try await fetchChallenge()
        // clientDataHash = SHA256(challenge ‖ body) — must match the proxy's verifyAssertion.
        var data = Data(challenge.utf8)
        data.append(body)
        let hash = Data(SHA256.hash(data: data))
        let assertion = try await service.generateAssertion(keyId, clientDataHash: hash)
        return [
            "x-key-id": keyId,
            "x-challenge": challenge,
            "x-assertion": assertion.base64EncodedString(),
        ]
        #endif
    }

    // MARK: - One-time attestation per install

    private func ensureAttestedKey() async throws -> String {
        if let existing = loadKeyId() { return existing }
        let keyId = try await service.generateKey()
        let challenge = try await fetchChallenge()
        // Attestation clientDataHash = SHA256(challenge) — matches the proxy's verifyAttestation.
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
              let challenge = obj["challenge"] else {
            throw AppAttestError.challengeFailed
        }
        return challenge
    }

    private func postAttestation(keyId: String, attestation: Data, challenge: String) async throws {
        var req = URLRequest(url: ProxyConfig.baseURL.appendingPathComponent("attest"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "keyId": keyId,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppAttestError.attestFailed(String(data: data, encoding: .utf8) ?? "unknown")
        }
    }

    // MARK: - Keychain persistence of the key ID

    private func saveKeyId(_ id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(id.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    private func loadKeyId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    #if DEBUG
    private func deviceKeyIdFallback() -> String {
        if let id = loadKeyId() { return id }
        let id = UUID().uuidString
        saveKeyId(id)
        return id
    }
    #endif
}
