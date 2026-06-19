import Foundation
import UIKit

// MARK: — Claude AI Service
// Powers the KAI Coach chat using Anthropic's Claude API.
// ⚠️  Before App Store release, move the API key to a secure backend
//     (e.g. a Supabase Edge Function) so it's never shipped inside the app binary.

enum ClaudeError: LocalizedError {
    case invalidResponse
    case requestFailed(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse:        return "Unexpected response from AI service."
        case .requestFailed(let msg): return msg
        case .noContent:              return "No response received from AI."
        }
    }
}

struct ClaudeService {

    // API key is loaded from Config.xcconfig → Info.plist at build time.
    // Set CLAUDE_API_KEY in KAIZENN/Config.xcconfig (gitignored).
    // ⚠️  For production: fetch this from your backend, never hardcode it.
    private static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "ClaudeAPIKey") as? String ?? ""
    }
    private static let model   = "claude-sonnet-4-6"
    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Send a chat turn to Claude and return the assistant's reply.
    /// - Parameters:
    ///   - messages:     The full conversation so far (ChatMessage array from CoachView).
    ///   - systemPrompt: Context about the user's profile and today's data.
    static func chat(messages: [ChatMessage], systemPrompt: String) async throws -> String {

        // Build the Anthropic messages array from our ChatMessage model
        let anthropicMessages = messages.map { msg in
            ["role": msg.isUser ? "user" : "assistant",
             "content": msg.text]
        }

        let body: [String: Any] = [
            "model":      model,
            "max_tokens": 1024,
            "system":     systemPrompt,
            "messages":   anthropicMessages
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey,          forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",    forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.requestFailed("API error \(http.statusCode): \(msg)")
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let text = decoded.content.first?.text else {
            throw ClaudeError.noContent
        }

        return text
    }

    /// Send an image to Claude Vision and return the assistant's analysis.
    /// image is base64-encoded and sent as a content block alongside the system prompt.
    static func chatWithImage(image: UIImage, systemPrompt: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeError.requestFailed("Failed to encode image")
        }
        let base64 = imageData.base64EncodedString()

        let body: [String: Any] = [
            "model":      model,
            "max_tokens": 1024,
            "system":     systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "image",
                         "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
                        ["type": "text",
                         "text": "Analyse this image and respond with structured JSON only."]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.requestFailed("Vision API error \(http.statusCode): \(msg)")
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = decoded.content.first?.text else { throw ClaudeError.noContent }
        return text
    }
}

// MARK: — Anthropic Response Models
private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
}

private struct ContentBlock: Decodable {
    let text: String
}
