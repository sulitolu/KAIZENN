import XCTest
@testable import KAIZENN

/// Intercepts ClaudeService's requests so we can test request shaping and
/// status→error mapping without hitting the network.
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ClaudeServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        ClaudeService.session = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        ClaudeService.session = .shared
        super.tearDown()
    }

    private func respond(status: Int, body: String) {
        MockURLProtocol.handler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (resp, body.data(using: .utf8)!)
        }
    }

    func testChatReturnsProxyText() async throws {
        respond(status: 200, body: #"{"text":"hi there"}"#)
        let reply = try await ClaudeService.chat(
            messages: [ChatMessage(text: "hi", isUser: true)], systemPrompt: "s")
        XCTAssertEqual(reply, "hi there")
    }

    func testChatPostsToChatEndpoint() async throws {
        var capturedPath: String?
        MockURLProtocol.handler = { req in
            capturedPath = req.url?.path
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, #"{"text":"ok"}"#.data(using: .utf8)!)
        }
        _ = try await ClaudeService.chat(
            messages: [ChatMessage(text: "hi", isUser: true)], systemPrompt: "s")
        XCTAssertEqual(capturedPath?.hasSuffix("/chat"), true)
    }

    func testRateLimitMapsToError() async {
        respond(status: 429, body: #"{"error":"rate_limited"}"#)
        do {
            _ = try await ClaudeService.chat(
                messages: [ChatMessage(text: "hi", isUser: true)], systemPrompt: "s")
            XCTFail("expected throw")
        } catch ClaudeError.rateLimited {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testUnauthorizedMapsToUnverifiedDevice() async {
        respond(status: 401, body: #"{"error":"unauthorized"}"#)
        do {
            _ = try await ClaudeService.chat(
                messages: [ChatMessage(text: "hi", isUser: true)], systemPrompt: "s")
            XCTFail("expected throw")
        } catch ClaudeError.unverifiedDevice {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testEmptyTextMapsToNoContent() async {
        respond(status: 200, body: #"{"text":""}"#)
        do {
            _ = try await ClaudeService.chat(
                messages: [ChatMessage(text: "hi", isUser: true)], systemPrompt: "s")
            XCTFail("expected throw")
        } catch ClaudeError.noContent {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
