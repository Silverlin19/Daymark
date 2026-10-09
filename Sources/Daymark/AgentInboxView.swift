import SwiftUI

struct AgentInboxView: View {
    @State private var inbox = AgentInbox()
    @State private var filter: AgentRequestStatus?
    @State private var selectedIssue: AgentIssue?
    @State private var composing = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private var visibleIssues: [AgentIssue] {
        inbox.issues.filter { filter == nil || $0.status == filter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    SectionHeading(eyebrow: "Work together", title: "Agent Inbox", subtitle: "Leave a thought. Define a request. Follow the work.")
                    Spacer()
                    Button { Task { await inbox.refresh() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }.disabled(inbox.isLoading)
                    Button("New request") { composing = true }
                        .buttonStyle(.borderedProminent).tint(DaymarkTheme.indigo)
                }
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Shared through GitHub", systemImage: "tray.full.fill").font(.headline)
                        Text("Requests here are public. Your tasks, focus notes, and reflections stay on this Mac.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Link("Open on iPad or GitHub", destination: URL(string: "https://github.com/Silverlin19/Daymark/issues")!)
                            Spacer()
                            if let date = inbox.lastUpdated {
                                Text("Updated \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("Idea saves a thought. Ready requests work. Status changes come from the recorded GitHub workflow.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Picker("Show", selection: $filter) {
                        Text("All requests").tag(Optional<AgentRequestStatus>.none)
                        ForEach(AgentRequestStatus.allCases) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }.frame(maxWidth: 260)
                    Spacer()
                    if inbox.isLoading { ProgressView().controlSize(.small) }
                    Text("\(visibleIssues.count) requests").font(.caption).foregroundStyle(.secondary)
                }
                if let error = inbox.error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(DaymarkTheme.coral)
                }
                if visibleIssues.isEmpty && !inbox.isLoading {
                    Card {
                        ContentUnavailableView(
                            inbox.error == nil ? "Room for your next idea" : "Inbox unavailable",
                            systemImage: "tray",
                            description: Text(inbox.error == nil ? "Capture an idea or create a ready request. You review and submit it on GitHub." : "Refresh later or open GitHub to view your requests.")
                        ).frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                ForEach(visibleIssues) { issue in
                    Button { selectedIssue = issue } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(issue.displayTitle).font(.headline)
                                    Spacer()
                                    Text(issue.status.rawValue).font(.caption.bold())
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(statusColor(issue.status).opacity(0.12), in: Capsule())
                                        .foregroundStyle(statusColor(issue.status))
                                }
                                Text(issue.body ?? "No details yet.").font(.callout).foregroundStyle(.secondary).lineLimit(2)
                                HStack {
                                    Text("#\(issue.number) · @\(issue.user.login)")
                                    Spacer()
                                    Label("\(issue.comments)", systemImage: "bubble.left")
                                    if let date = issue.updatedDate { Text(date, style: .relative) }
                                }.font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(30).frame(maxWidth: 1100, alignment: .leading)
        }
        .navigationTitle("Agent Inbox")
        .sheet(isPresented: $composing) { AgentRequestComposer() }
        .sheet(item: $selectedIssue) { issue in
            AgentIssueDetail(issue: issue)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await inbox.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
                await inbox.refresh()
            }
        }
    }

    private func statusColor(_ status: AgentRequestStatus) -> Color {
        switch status {
        case .idea: .secondary
        case .ready, .review: DaymarkTheme.indigo
        case .working: DaymarkTheme.amber
        case .needsInput: DaymarkTheme.coral
        case .complete: DaymarkTheme.mint
        }
    }
}

private struct AgentIssueDetail: View {
    let issue: AgentIssue
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(issue.displayTitle).font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
            }
            Text("\(issue.status.rawValue) · #\(issue.number) · @\(issue.user.login)").foregroundStyle(.secondary)
            ScrollView { Text(issue.body ?? "No details yet.").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            Link("Read updates and reply on GitHub", destination: issue.url)
                .buttonStyle(.borderedProminent).tint(DaymarkTheme.indigo)
        }.padding(26).frame(width: 650, height: 550)
    }
}

private struct AgentRequestComposer: View {
    @AppStorage("agentDraftTitle") private var title = ""
    @AppStorage("agentDraftProject") private var project = ""
    @AppStorage("agentDraftOutcome") private var outcome = ""
    @AppStorage("agentDraftContext") private var context = ""
    @AppStorage("agentDraftChecks") private var checks = ""
    @AppStorage("agentDraftBoundaries") private var boundaries = ""
    @AppStorage("agentDraftKind") private var kindName = AgentRequestKind.idea.rawValue
    @State private var acknowledgesPublic = false
    @State private var authorizesWork = false
    @State private var openedGitHub = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private var draft: AgentRequestDraft {
        AgentRequestDraft(title: title, project: project, outcome: outcome, context: context, checks: checks,
                          boundaries: boundaries, kind: AgentRequestKind(rawValue: kindName) ?? .idea,
                          acknowledgesPublic: acknowledgesPublic, authorizesWork: authorizesWork)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Leave something for us").font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }
            }
            Text("Your draft saves on this Mac. GitHub requests are public; leave out private information.").font(.callout).foregroundStyle(.secondary)
            Form {
                Picker("Request type", selection: $kindName) {
                    ForEach(AgentRequestKind.allCases) { kind in Text(kind.rawValue).tag(kind.rawValue) }
                }.pickerStyle(.segmented)
                TextField("Title", text: $title)
                TextField("Project / repository", text: $project)
                TextField("Requested outcome", text: $outcome, axis: .vertical).lineLimit(2...4)
                TextField("Context", text: $context, axis: .vertical).lineLimit(2...4)
                TextField("Acceptance checks", text: $checks, axis: .vertical).lineLimit(2...3)
                TextField("Boundaries", text: $boundaries, axis: .vertical).lineLimit(2...3)
                Toggle("I understand this request will be public on GitHub.", isOn: $acknowledgesPublic)
                if draft.kind == .ready {
                    Toggle("I authorize Codex to carry out this request and delegate to Grok Bot.", isOn: $authorizesWork)
                    Text("Ready requests need a project. Merging and deploying require separate authorization.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Ideas are for discussion; they do not start work.").font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
            if openedGitHub { Text("Draft opened on GitHub. Review it and press Submit new issue there to send it.").font(.caption).foregroundStyle(DaymarkTheme.indigo) }
            HStack {
                Button("Clear draft") {
                    title = ""; project = ""; outcome = ""; context = ""; checks = ""; boundaries = ""
                    acknowledgesPublic = false; authorizesWork = false; openedGitHub = false
                }
                Spacer()
                Button("Review on GitHub") {
                    if let url = draft.issueURL { openURL(url); openedGitHub = true }
                }.buttonStyle(.borderedProminent).tint(DaymarkTheme.indigo).disabled(!draft.canSubmit)
            }
        }.padding(24).frame(width: 660, height: 670)
    }
}
