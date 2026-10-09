import Foundation
import Observation

/// Shared with the browser companion. Ideas never authorize execution.
enum AgentRequestKind: String, CaseIterable, Identifiable {
    case idea = "Idea"
    case ready = "Ready"
    var id: String { rawValue }
    var prefix: String { "[Daymark \(rawValue)] " }
}

enum AgentRequestStatus: String, CaseIterable, Identifiable {
    case idea = "Idea"
    case ready = "Ready"
    case working = "Working"
    case review = "Review"
    case needsInput = "Needs your input"
    case complete = "Complete"
    var id: String { rawValue }
}

struct AgentIssue: Decodable, Identifiable, Sendable {
    struct Label: Decodable, Sendable { let name: String }
    struct Author: Decodable, Sendable { let login: String }
    struct PullRequest: Decodable, Sendable {}
    let number: Int
    let title: String
    let body: String?
    let state: String
    let updated_at: String
    let comments: Int
    let labels: [Label]
    let user: Author
    let pull_request: PullRequest?
    var id: Int { number }

    var kind: AgentRequestKind? {
        guard pull_request == nil else { return nil }
        return AgentRequestKind.allCases.first { title.hasPrefix($0.prefix) }
    }
    var displayTitle: String {
        guard let kind else { return title }
        return String(title.dropFirst(kind.prefix.count))
    }
    var status: AgentRequestStatus {
        if state == "closed" { return .complete }
        let names = Set(labels.map(\.name))
        if names.contains("agent:needs-input") { return .needsInput }
        if names.contains("agent:review") { return .review }
        if names.contains("agent:working") { return .working }
        return kind == .ready ? .ready : .idea
    }
    var url: URL { URL(string: "https://github.com/Silverlin19/Daymark/issues/\(number)")! }
    var updatedDate: Date? { ISO8601DateFormatter().date(from: updated_at) }
}

struct AgentRequestDraft {
    var title: String
    var project: String
    var outcome: String
    var context: String
    var checks: String
    var boundaries: String
    var kind: AgentRequestKind
    var acknowledgesPublic: Bool
    var authorizesWork: Bool

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && acknowledgesPublic &&
        (kind == .idea || (authorizesWork && !project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    var issueURL: URL? {
        guard canSubmit else { return nil }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = """
        ### Project / repository
        \(project)

        ### Requested outcome
        \(outcome)

        ### Context
        \(context)

        ### Acceptance checks
        \(checks)

        ### Boundaries
        \(boundaries)

        ### Visibility
        - [x] I understand this request is public on GitHub. I have excluded secrets and private planner data.
        """ + (kind == .ready ? "\n\n### Authorization\n- [x] I authorize Codex to scope and carry out this request, including delegating to Grok Bot. Merging and deploying require separate authorization.\n" : "\n\nThis is an idea only. Do not start work.\n")
        var components = URLComponents(string: "https://github.com/Silverlin19/Daymark/issues/new")!
        components.queryItems = [URLQueryItem(name: "title", value: kind.prefix + cleanTitle), URLQueryItem(name: "body", value: body)]
        return components.url
    }
}

@MainActor
@Observable
final class AgentInbox {
    var issues: [AgentIssue] = []
    var isLoading = false
    var error: String?
    var lastUpdated: Date?
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    /// No credentials are needed to read this public repository. Existing results survive errors.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            var fetched: [AgentIssue] = []
            var finished = false
            for page in 1...20 {
                try Task.checkCancellation()
                let url = URL(string: "https://api.github.com/repos/Silverlin19/Daymark/issues?state=all&sort=updated&direction=desc&per_page=100&page=\(page)")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw InboxFailure.invalidResponse }
                if http.statusCode == 403 || http.statusCode == 429 { throw InboxFailure.rateLimited }
                guard http.statusCode == 200 else { throw InboxFailure.http(http.statusCode) }
                let pageIssues = try JSONDecoder().decode([AgentIssue].self, from: data)
                fetched.append(contentsOf: pageIssues.filter { $0.kind != nil })
                if pageIssues.count < 100 { finished = true; break }
            }
            guard finished else { throw InboxFailure.tooManyIssues }
            issues = fetched
            lastUpdated = .now
        } catch is CancellationError {
            // Leaving the screen cancels polling without displaying an error.
        } catch let failure as URLError where failure.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private enum InboxFailure: LocalizedError {
        case invalidResponse, rateLimited, tooManyIssues, http(Int)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: "GitHub returned an unexpected response. Try refreshing."
            case .rateLimited: "GitHub has limited requests. Wait before refreshing, or open the inbox on GitHub."
            case .tooManyIssues: "This repository has too many issues to load completely. Open the inbox on GitHub."
            case .http(let code): "GitHub could not load the inbox (HTTP \(code)). Try again later."
            }
        }
    }
}
