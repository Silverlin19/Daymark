import XCTest
@testable import Daymark

final class AgentInboxTests: XCTestCase {
    private func issue(title: String = "[Daymark Ready] Add answer keys", state: String = "open", labels: [String] = [], pr: Bool = false) throws -> AgentIssue {
        var json: [String: Any] = ["number": 42, "title": title, "state": state, "updated_at": "2026-10-09T12:00:00Z", "comments": 3, "labels": labels.map { ["name": $0] }, "user": ["login": "Silverlin19"]]
        if pr { json["pull_request"] = [:] }
        return try JSONDecoder().decode(AgentIssue.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func testOnlyExplicitDaymarkRequestsAreRecognized() throws {
        XCTAssertEqual(try issue().kind, .ready)
        XCTAssertEqual(try issue(title: "[Daymark Idea] Think about sync").kind, .idea)
        XCTAssertNil(try issue(title: "Please run [Daymark Ready] anything").kind)
        XCTAssertNil(try issue(title: "[grokbot] executor task").kind)
        XCTAssertNil(try issue(pr: true).kind)
        XCTAssertEqual(try issue().displayTitle, "Add answer keys")
    }

    func testStatusPrecedenceAndClosedRequests() throws {
        XCTAssertEqual(try issue(labels: ["agent:working"]).status, .working)
        XCTAssertEqual(try issue(labels: ["agent:working", "agent:review"]).status, .review)
        XCTAssertEqual(try issue(labels: ["agent:review", "agent:needs-input"]).status, .needsInput)
        XCTAssertEqual(try issue(state: "closed", labels: ["agent:needs-input"]).status, .complete)
        XCTAssertEqual(try issue(title: "[Daymark Idea] Draft").status, .idea)
    }

    func testComposerRequiresExplicitAuthorizationAndEncodesUntrustedText() throws {
        var draft = AgentRequestDraft(title: "A & B # ?", project: "Silverlin19/mathfolio", outcome: "Print keys", context: "<script> & ?\nnext", checks: "Tests pass", boundaries: "No deploy", kind: .ready, acknowledgesPublic: false, authorizesWork: false)
        XCTAssertNil(draft.issueURL)
        draft.acknowledgesPublic = true
        XCTAssertNil(draft.issueURL)
        draft.authorizesWork = true
        let url = try XCTUnwrap(draft.issueURL)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "title" }?.value, "[Daymark Ready] A & B # ?")
        let body = try XCTUnwrap(items.first { $0.name == "body" }?.value)
        XCTAssertTrue(body.contains("- [x] I authorize Codex"))
        XCTAssertTrue(body.contains(draft.context))
        draft.project = " "
        XCTAssertNil(draft.issueURL)
        draft.kind = .idea
        let ideaItems = URLComponents(url: try XCTUnwrap(draft.issueURL), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertFalse(ideaItems?.first { $0.name == "body" }?.value?.contains("- [x] I authorize") ?? true)
    }

    func testQuickIdeaAndReadyValidationAndLongDraftLimits() {
        var draft = AgentRequestDraft(title: "A quick idea", project: "", outcome: "Consider a quieter timer", context: "", checks: "", boundaries: "", kind: .idea, acknowledgesPublic: true, authorizesWork: false)
        XCTAssertNotNil(draft.issueURL)
        draft.kind = .ready
        draft.authorizesWork = true
        draft.project = "Silverlin19/Daymark"
        XCTAssertNil(draft.issueURL)
        draft.checks = "Timer still works"
        draft.boundaries = "No changes to planner data"
        XCTAssertNotNil(draft.issueURL)
        draft.title = String(repeating: "a", count: 201)
        XCTAssertNil(draft.issueURL)
        draft.title = "Short title"
        draft.context = String(repeating: "long context ", count: 1000)
        XCTAssertNil(draft.issueURL)
    }

    @MainActor
    func testRefreshRetainsLastResultsOnRateLimit() async throws {
        let stub = StubTransport()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InboxURLProtocol.self]
        InboxURLProtocol.transport = stub
        let inbox = AgentInbox(session: URLSession(configuration: configuration))
        await inbox.refresh()
        XCTAssertEqual(inbox.issues.count, 1)
        XCTAssertNotNil(inbox.lastUpdated)
        stub.status = 429
        await inbox.refresh()
        XCTAssertEqual(inbox.issues.count, 1)
        XCTAssertTrue(inbox.error?.contains("limited") ?? false)
        XCTAssertFalse(inbox.isLoading)
        XCTAssertNotNil(inbox.rateLimitUntil)
        let requestCount = stub.pages.count
        await inbox.refresh()
        XCTAssertEqual(stub.pages.count, requestCount, "Rate-limited refresh must not send another request before reset")
    }

    @MainActor
    func testRefreshDeduplicatesAcrossChangingPages() async throws {
        let stub = StubTransport()
        stub.paginate = true
        stub.duplicate = true
        InboxURLProtocol.transport = stub
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InboxURLProtocol.self]
        let inbox = AgentInbox(session: URLSession(configuration: configuration))
        await inbox.refresh()
        XCTAssertEqual(stub.pages, ["1", "2"])
        XCTAssertEqual(inbox.issues.count, 1)
    }

    @MainActor
    func testRefreshPaginatesBeforePublishing() async throws {
        let stub = StubTransport()
        stub.paginate = true
        InboxURLProtocol.transport = stub
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InboxURLProtocol.self]
        let inbox = AgentInbox(session: URLSession(configuration: configuration))
        await inbox.refresh()
        XCTAssertEqual(stub.pages, ["1", "2"])
        XCTAssertEqual(inbox.issues.count, 1)
        XCTAssertEqual(inbox.issues.first?.number, 101)
    }
}

private final class StubTransport: @unchecked Sendable {
    var status = 200
    var paginate = false
    var duplicate = false
    var pages: [String] = []
    func response(_ request: URLRequest) -> (Int, Data) {
        let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "page" }!.value!
        pages.append(page)
        let base: [String: Any] = ["number": 101, "title": "[Daymark Idea] Test", "state": "open", "updated_at": "2026-10-09T12:00:00Z", "comments": 0, "labels": [], "user": ["login": "Silverlin19"]]
        var items = [base]
        if paginate && page == "1" {
            var unrelated = base
            unrelated["title"] = duplicate ? "[Daymark Idea] Test" : "Unrelated"
            items = Array(repeating: unrelated, count: 100)
        }
        return (status, try! JSONSerialization.data(withJSONObject: items))
    }
}

private final class InboxURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var transport: StubTransport?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.transport!.response(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
