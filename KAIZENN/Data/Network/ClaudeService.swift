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

    /// Send a chat turn to the proxy and return the assistant's reply.
    static func chat(messages: [ChatMessage], systemPrompt: String) async throws -> String {
        let anthropicMessages = messages.map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.text]
        }
        let payload: [String: Any] = ["messages": anthropicMessages, "systemPrompt": systemPrompt]
        return try await post(path: "chat", payload: payload)
    }

    /// Send an image to the proxy's vision endpoint and return the analysis.
    static func chatWithImage(image: UIImage, systemPrompt: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeError.requestFailed("Failed to encode image")
        }
        let payload: [String: Any] = [
            "imageBase64": imageData.base64EncodedString(),
            "systemPrompt": systemPrompt,
        ]
        return try await post(path: "vision", payload: payload)
    }

    // MARK: - Shared proxy POST

    private static func post(path: String, payload: [String: Any]) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: payload)

        let headers: [String: String]
        do {
            headers = try await AppAttestManager.shared.authHeaders(for: body)
        } catch {
            throw ClaudeError.unverifiedDevice
        }

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
