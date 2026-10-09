import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  IDEA_NO_ACTION,
  IDEA_PREFIX,
  KIND,
  MAX_ISSUE_URL_LENGTH,
  NEW_ISSUE_URL,
  PER_PAGE,
  READY_AUTHORIZATION,
  READY_PREFIX,
  REFRESH_INTERVAL_MS,
  REVIEW_ON_GITHUB_NOTE,
  STATUS,
  VISIBILITY_CONFIRMATION,
  bodyExcerpt,
  buildNewIssueUrl,
  buildRequestBody,
  classifyHttpFailure,
  commentLabel,
  displaySubject,
  filterInboxIssues,
  fixtureIssues,
  formatUpdated,
  issuesApiUrl,
  matchesFilter,
  mergeIssues,
  nextAutoRefreshDelay,
  nextPageUrl,
  parseNextLink,
  parseProject,
  recognizeKind,
  requestGate,
  safeGithubUrl,
  statusForIssue,
} from "./protocol.mjs";

const ideaFields = {
  kind: KIND.IDEA,
  subject: "Quieter mornings",
  project: "",
  outcome: "The day starts with one local intention.",
  context: "Planner data stays on the device.",
  acceptance: "No request is filed until the person submits it on GitHub.",
  boundaries: "Do not upload private tasks.",
  visibilityConfirmed: true,
  authorized: false,
};

const readyFields = {
  kind: KIND.READY,
  subject: "Ship A & B #1",
  project: "Silverlin19/Daymark",
  outcome: 'Quotes " and slash \\ and newline\nnext',
  context: "Public notes only.",
  acceptance: "The issue title keeps the Ready prefix.",
  boundaries: "No browser dispatch.",
  visibilityConfirmed: true,
  authorized: true,
};

function readRepo(relativePath) {
  return readFileSync(new URL(relativePath, import.meta.url), "utf8");
}

test("recognizes only the exact Idea and Ready prefixes", () => {
  const cases = [
    ["[Daymark Idea] Ship a quieter morning", KIND.IDEA],
    ["[Daymark Ready] Package the app", KIND.READY],
    ["[Daymark Idea] ", KIND.IDEA],
    ["[Daymark Ready] ", KIND.READY],
    ["[Daymark Idea]", null],
    ["[Daymark Ready]", null],
    ["[Daymark idea] lower", null],
    ["[Daymark Ready]extra", null],
    [" [Daymark Idea] padded", null],
    ["Note [Daymark Idea] later", null],
    ["[Daymark Ready][Daymark Idea] mixed", null],
    ["", null],
    [null, null],
    [undefined, null],
    [12, null],
  ];
  for (const [title, expected] of cases) {
    assert.equal(recognizeKind(title), expected, `title ${JSON.stringify(title)}`);
  }
  assert.equal(IDEA_PREFIX, "[Daymark Idea] ");
  assert.equal(READY_PREFIX, "[Daymark Ready] ");
});

test("excludes pull requests and titles that are not Daymark requests", () => {
  const items = [
    { title: "[Daymark Idea] hidden pr", pull_request: { url: "https://api.github.com/pulls/1" }, state: "open" },
    { title: "[Daymark Ready] keep", state: "open", labels: [] },
    { title: "weekly notes", state: "open" },
    { title: "[Daymark Idea] also keep", state: "closed" },
    { title: "[Daymark Idea]", state: "open" },
    null,
    { title: "[Daymark Ready] blank pr object", pull_request: {}, state: "open" },
  ];
  assert.deepEqual(
    filterInboxIssues(items).map((item) => item.title),
    ["[Daymark Ready] keep", "[Daymark Idea] also keep"],
  );
  assert.deepEqual(filterInboxIssues(null), []);
  assert.deepEqual(filterInboxIssues({ title: "[Daymark Idea] no" }), []);
  const original = items.slice();
  filterInboxIssues(items);
  assert.deepEqual(items, original);
  assert.equal(statusForIssue(items[0]), null);
});

test("status labels have precedence and closed requests are Complete", () => {
  const base = { title: "[Daymark Ready] ship", state: "open" };
  assert.equal(
    statusForIssue({
      ...base,
      labels: [{ name: "agent:working" }, { name: "agent:review" }, "agent:needs-input"],
    }),
    STATUS.NEEDS_INPUT,
  );
  assert.equal(
    statusForIssue({ ...base, labels: [{ name: "agent:working" }, { name: "agent:review" }] }),
    STATUS.REVIEW,
  );
  assert.equal(statusForIssue({ ...base, labels: ["agent:working"] }), STATUS.WORKING);
  assert.equal(statusForIssue({ ...base, labels: [{ name: "bug" }] }), STATUS.READY);
  assert.equal(statusForIssue({ ...base, title: "[Daymark Idea] note", labels: [] }), STATUS.IDEA);
  assert.equal(statusForIssue({ ...base, labels: [{ name: "Agent:Working" }] }), STATUS.READY);
  assert.equal(
    statusForIssue({
      title: "[Daymark Idea] done",
      state: "closed",
      labels: [{ name: "agent:needs-input" }, { name: "agent:working" }],
    }),
    STATUS.COMPLETE,
  );
  assert.equal(
    statusForIssue({ title: "[Daymark Ready] done", state: "CLOSED", labels: ["agent:review"] }),
    STATUS.COMPLETE,
  );
  assert.equal(statusForIssue({ title: "nope", state: "closed", labels: ["agent:working"] }), null);
  assert.equal(statusForIssue({ title: "[Daymark Ready] open", labels: null }), STATUS.READY);
});

test("fixture inbox drops pull requests and unrelated issues", () => {
  const visible = filterInboxIssues(fixtureIssues());
  assert.equal(visible.some((issue) => issue.pull_request), false);
  assert.equal(visible.some((issue) => issue.title === "Unrelated repository chore"), false);
  assert.equal(visible.some((issue) => issue.title.startsWith("[Daymark Idea] This pull request")), false);
  assert.equal(visible.length, fixtureIssues().length - 2);
  const byId = Object.fromEntries(visible.map((issue) => [issue.id, statusForIssue(issue)]));
  assert.equal(byId[1], STATUS.IDEA);
  assert.equal(byId[2], STATUS.READY);
  assert.equal(byId[3], STATUS.REVIEW);
  assert.equal(byId[4], STATUS.WORKING);
  assert.equal(byId[5], STATUS.NEEDS_INPUT);
  assert.equal(byId[6], STATUS.COMPLETE);
  assert.equal(matchesFilter(visible.find((issue) => issue.id === 3), "ready"), false);
  assert.equal(matchesFilter(visible.find((issue) => issue.id === 3), "review"), true);
  assert.equal(matchesFilter(visible.find((issue) => issue.id === 6), "complete"), true);
  assert.equal(matchesFilter(visible.find((issue) => issue.id === 6), "ready"), false);
});

test("paginates from the Link header and does not stop early when the header is missing", () => {
  const header = [
    '<https://api.github.com/repositories/1/issues?page=2&state=all>; rel="next"',
    '<https://api.github.com/repositories/1/issues?page=4>; rel="last"',
  ].join(", ");
  assert.equal(
    parseNextLink(header),
    "https://api.github.com/repositories/1/issues?page=2&state=all",
  );
  assert.equal(parseNextLink('<https://api.github.com/issues?page=1>; rel="prev"'), null);
  assert.equal(parseNextLink(""), null);
  assert.equal(parseNextLink(null), null);
  const current = issuesApiUrl(1);
  assert.equal(
    nextPageUrl({ currentUrl: current, rawPageCount: PER_PAGE, perPage: PER_PAGE, linkHeader: header }),
    "https://api.github.com/repositories/1/issues?page=2&state=all",
  );
  assert.equal(
    nextPageUrl({ currentUrl: current, rawPageCount: PER_PAGE, perPage: PER_PAGE, linkHeader: '<https://api.github.com/issues?page=1>; rel="prev"' }),
    null,
  );
  assert.equal(nextPageUrl({ currentUrl: current, rawPageCount: 3, perPage: PER_PAGE, linkHeader: null }), null);
  const fallback = nextPageUrl({ currentUrl: current, rawPageCount: PER_PAGE, perPage: PER_PAGE, linkHeader: null });
  assert.equal(new URL(fallback).searchParams.get("page"), "2");
  const merged = mergeIssues([{ id: 1, title: "a" }], [{ id: 1, title: "newer" }, { id: 2, title: "b" }]);
  assert.deepEqual(merged.map((issue) => issue.id), [1, 2]);
  assert.equal(merged[0].title, "a");
});

test("encodes title and body into the GitHub new-issue URL", () => {
  const result = buildNewIssueUrl(readyFields);
  assert.equal(result.ok, true);
  const url = new URL(result.url);
  assert.equal(url.origin, "https://github.com");
  assert.equal(url.pathname, "/Silverlin19/Daymark/issues/new");
  assert.deepEqual([...url.searchParams.keys()].sort(), ["body", "title"]);
  assert.equal(url.searchParams.get("title"), "[Daymark Ready] Ship A & B #1");
  assert.equal(url.searchParams.get("body"), result.body);
  assert.equal(result.url.includes(" "), false);
  assert.equal(result.url.includes("\n"), false);
  assert.equal(result.url.includes("#"), false);
  assert.match(result.url, /%26|Ship\+A\+%26|Ship%20A%20%26/);
  assert.equal(url.searchParams.get("access_token"), null);
  assert.ok(result.url.length <= MAX_ISSUE_URL_LENGTH);
});

test("Ready payload records the authorization checkbox and Idea performs no action", () => {
  const ready = buildNewIssueUrl(readyFields);
  assert.equal(ready.ok, true);
  assert.ok(ready.body.includes(`- [x] ${READY_AUTHORIZATION}`));
  assert.ok(ready.body.includes(`- [x] ${VISIBILITY_CONFIRMATION}`));
  assert.equal(ready.body.includes(IDEA_NO_ACTION), false);
  assert.equal(ready.url.includes("/dispatches"), false);
  assert.equal(ready.url.includes("api.github.com"), false);

  const missing = buildNewIssueUrl({ ...readyFields, authorized: false });
  assert.equal(missing.ok, false);
  assert.equal(missing.url, null);
  assert.match(missing.errors.join("\n"), /authorization/i);

  const idea = buildNewIssueUrl({ ...ideaFields, authorized: true });
  assert.equal(idea.ok, true);
  assert.ok(idea.body.includes(IDEA_NO_ACTION));
  assert.equal(idea.body.includes(READY_AUTHORIZATION), false);
  assert.equal(idea.body.includes("[x] I authorize"), false);
  assert.ok(idea.body.includes(`- [x] ${VISIBILITY_CONFIRMATION}`));
  const ideaUrl = new URL(idea.url);
  assert.equal(ideaUrl.pathname, "/Silverlin19/Daymark/issues/new");
  assert.deepEqual([...ideaUrl.searchParams.keys()].sort(), ["body", "title"]);
  assert.equal(idea.title.startsWith(IDEA_PREFIX), true);
  assert.equal(parseProject(idea.body), "");

  const quickIdea = buildNewIssueUrl({
    kind: KIND.IDEA,
    subject: "A note",
    project: "",
    outcome: "Remember this",
    context: "",
    acceptance: "",
    boundaries: "",
    visibilityConfirmed: true,
    authorized: true,
  });
  assert.equal(quickIdea.ok, true);
  assert.ok(quickIdea.body.includes(IDEA_NO_ACTION));
  assert.equal(quickIdea.body.includes(READY_AUTHORIZATION), false);
  assert.equal(quickIdea.errors.length, 0);

  const readyWithoutContext = buildNewIssueUrl({ ...readyFields, context: "  " });
  assert.equal(readyWithoutContext.ok, true);
  const readyWithoutChecks = buildNewIssueUrl({ ...readyFields, acceptance: "" });
  assert.equal(readyWithoutChecks.ok, false);
  assert.match(readyWithoutChecks.errors.join("\n"), /Acceptance checks/);
  const readyWithoutBoundaries = buildNewIssueUrl({ ...readyFields, boundaries: "" });
  assert.equal(readyWithoutBoundaries.ok, false);
  assert.match(readyWithoutBoundaries.errors.join("\n"), /Boundaries/);

  const privateIdea = buildNewIssueUrl({ ...ideaFields, visibilityConfirmed: false });
  assert.equal(privateIdea.ok, false);
  assert.match(privateIdea.errors.join("\n"), /public/);

  const noProject = buildNewIssueUrl({ ...readyFields, project: "  " });
  assert.equal(noProject.ok, false);
  assert.match(noProject.errors.join("\n"), /Project/);
});

test("refuses an oversized prefill instead of opening a truncated link", () => {
  const huge = buildNewIssueUrl({ ...ideaFields, outcome: "o".repeat(8000) });
  assert.equal(huge.ok, false);
  assert.equal(huge.url, null);
  assert.match(huge.errors.join(" "), /too long/i);
});

test("the public issues URL carries no credentials", () => {
  assert.equal(NEW_ISSUE_URL, "https://github.com/Silverlin19/Daymark/issues/new");
  const api = new URL(issuesApiUrl(2));
  assert.equal(api.origin, "https://api.github.com");
  assert.equal(api.pathname, "/repos/Silverlin19/Daymark/issues");
  assert.equal(api.searchParams.get("state"), "all");
  assert.equal(api.searchParams.get("per_page"), "30");
  assert.equal(api.searchParams.get("sort"), "updated");
  assert.equal(api.searchParams.get("direction"), "desc");
  assert.equal(api.searchParams.get("page"), "2");
  assert.equal(api.searchParams.get("access_token"), null);
  assert.equal(api.username, "");
});

test("reads project and outcome excerpts from composer text and GitHub forms", () => {
  const composer = buildRequestBody({ ...readyFields, project: "Silverlin19/Daymark" });
  assert.equal(parseProject(composer), "Silverlin19/Daymark");
  assert.equal(parseProject(buildRequestBody(ideaFields)), "");
  assert.match(bodyExcerpt(composer), /Quotes/);
  const form = "### Project / repo\n\n_No response_\n\n### Requested outcome\n\nForm excerpt should show.\n\n### Context\n\nctx";
  assert.equal(parseProject(form), "");
  assert.equal(bodyExcerpt(form), "Form excerpt should show.");
  const named = "### Project / repo\r\n\r\nowner/repo\r\n";
  assert.equal(parseProject(named), "owner/repo");
  const native = [
    "### Project / repository",
    "Silverlin19/Daymark",
    "",
    "### Requested outcome",
    "Ship the inbox",
    "",
    "### Context",
    "From the Mac app",
    "",
    "### Acceptance checks",
    "The card shows the project",
    "",
    "### Boundaries",
    "Leave planner data local",
    "",
    "### Visibility",
    "- [x] I understand this request is public on GitHub. I have excluded secrets and private planner data.",
    "",
    "### Authorization",
    `- [x] ${READY_AUTHORIZATION}`,
    "",
  ].join("\n");
  assert.equal(parseProject(native), "Silverlin19/Daymark");
  assert.equal(bodyExcerpt(native), "Ship the inbox");
  assert.equal(parseProject("Project / repository: native/app"), "native/app");
  assert.equal(displaySubject("[Daymark Idea] <script>alert(1)</script>"), "<script>alert(1)</script>");
  assert.equal(displaySubject("[Daymark Ready] Ship it"), "Ship it");
  assert.equal(displaySubject("[Daymark Idea] "), "");
  assert.equal(displaySubject("weekly notes"), "weekly notes");
  assert.equal(commentLabel(0), "0 comments");
  assert.equal(commentLabel(1), "1 comment");
  assert.equal(commentLabel(4), "4 comments");
  assert.equal(formatUpdated("2026-04-02T15:04:00Z"), "Apr 2, 2026, 3:04 PM UTC");
  assert.equal(formatUpdated("not-a-date"), "Unknown update time");
});

test("accepts only https links in this repository", () => {
  assert.equal(
    safeGithubUrl("https://github.com/Silverlin19/Daymark/issues/12"),
    "https://github.com/Silverlin19/Daymark/issues/12",
  );
  assert.equal(safeGithubUrl("javascript:alert(1)"), null);
  assert.equal(safeGithubUrl("https://evil.example/Silverlin19/Daymark/issues/1"), null);
  assert.equal(safeGithubUrl("https://github.com/other/Daymark/issues/1"), null);
  assert.equal(safeGithubUrl("http://github.com/Silverlin19/Daymark/issues/1"), null);
  assert.equal(safeGithubUrl("https://user:pass@github.com/Silverlin19/Daymark/issues/1"), null);
});

test("classifies rate limits separately from other HTTP failures", () => {
  assert.equal(classifyHttpFailure(429, {}, "").type, "rate-limit");
  assert.equal(classifyHttpFailure(403, { "X-RateLimit-Remaining": "0" }, "").type, "rate-limit");
  assert.equal(classifyHttpFailure(403, { "X-RateLimit-Remaining": "10" }, "forbidden").type, "error");
  assert.equal(classifyHttpFailure(403, {}, "You have exceeded a secondary rate limit").type, "rate-limit");
  assert.equal(classifyHttpFailure(503, {}, "").type, "error");
  assert.match(classifyHttpFailure(503, {}, "").message, /503/);
  const headers = new Headers({ "retry-after": "42", "x-ratelimit-remaining": "0" });
  assert.match(classifyHttpFailure(429, headers, "").message, /42 seconds/);
  const now = Date.parse("2026-04-02T00:00:00Z");
  const reset = String((now + 120000) / 1000);
  const limited = classifyHttpFailure(403, { "x-ratelimit-remaining": "0", "x-ratelimit-reset": reset }, "", now);
  assert.match(limited.message, /2 minutes/);
  assert.equal(limited.retryUntil, now + 120000);
  const both = classifyHttpFailure(
    429,
    { "retry-after": "30", "x-ratelimit-reset": String((now + 180000) / 1000) },
    "",
    now,
  );
  assert.equal(both.retryUntil, now + 180000);
  const bare = classifyHttpFailure(429, {}, "API rate limit exceeded", now);
  assert.equal(bare.retryUntil, now + 60_000);
});

test("suppresses network requests until the rate-limit deadline expires", () => {
  const fetches = [];
  let retryUntil = null;
  function attempt(now, manual) {
    const gate = requestGate({ now, retryUntil, hidden: false, automatic: !manual });
    if (!gate.allow) return gate;
    fetches.push(now);
    if (fetches.length === 1) {
      const failure = classifyHttpFailure(429, { "retry-after": "60", "x-ratelimit-remaining": "0" }, "rate limit", now);
      assert.equal(failure.type, "rate-limit");
      assert.equal(failure.retryUntil, now + 60_000);
      retryUntil = failure.retryUntil;
    }
    return { allow: true, reason: "ok", waitMs: 0 };
  }

  const started = 1_700_000_000_000;
  assert.equal(attempt(started, true).allow, true);
  assert.deepEqual(fetches, [started]);
  const manual = attempt(started + 30_000, true);
  const automatic = attempt(started + 30_000, false);
  assert.equal(manual.allow, false);
  assert.equal(manual.reason, "rate-limit");
  assert.equal(automatic.allow, false);
  assert.equal(automatic.reason, "rate-limit");
  assert.deepEqual(fetches, [started]);
  assert.equal(attempt(started + 60_000, true).allow, true);
  assert.equal(attempt(started + 60_000, false).allow, true);
  assert.deepEqual(fetches, [started, started + 60_000, started + 60_000]);
});

test("automatic refresh waits five minutes and does not run while hidden", () => {
  assert.equal(REFRESH_INTERVAL_MS, 300000);
  assert.equal(nextAutoRefreshDelay(1000, 1000, true), null);
  assert.equal(nextAutoRefreshDelay(0, 5000, false), REFRESH_INTERVAL_MS);
  assert.equal(nextAutoRefreshDelay(1000, 1000 + REFRESH_INTERVAL_MS, false), 0);
  assert.equal(nextAutoRefreshDelay(1000, 2000, false), REFRESH_INTERVAL_MS - 1000);
  assert.equal(nextAutoRefreshDelay(1000, 1000, false, 1000 + 60_000), REFRESH_INTERVAL_MS);
  assert.equal(nextAutoRefreshDelay(1000, 1000, false, 1000 + 600_000), 600_000);
});

test("issue forms require visibility, and Ready requires authorization", () => {
  const idea = readRepo("../.github/ISSUE_TEMPLATE/daymark-idea.yml");
  const ready = readRepo("../.github/ISSUE_TEMPLATE/daymark-ready.yml");
  const config = readRepo("../.github/ISSUE_TEMPLATE/config.yml");
  assert.match(idea, /title:\s*"\[Daymark Idea\] "/);
  assert.match(ready, /title:\s*"\[Daymark Ready\] "/);
  assert.ok(idea.includes(VISIBILITY_CONFIRMATION));
  assert.ok(ready.includes(VISIBILITY_CONFIRMATION));
  assert.equal(idea.includes(READY_AUTHORIZATION), false);
  assert.ok(ready.includes(READY_AUTHORIZATION));
  assert.match(idea.slice(idea.indexOf(VISIBILITY_CONFIRMATION), idea.indexOf(VISIBILITY_CONFIRMATION) + 220), /required:\s*true/);
  assert.match(ready.slice(ready.indexOf(READY_AUTHORIZATION), ready.indexOf(READY_AUTHORIZATION) + 220), /required:\s*true/);
  const ideaProject = idea.slice(idea.indexOf("id: project"), idea.indexOf("id: outcome"));
  const readyProject = ready.slice(ready.indexOf("id: project"), ready.indexOf("id: outcome"));
  assert.match(ideaProject, /required:\s*false/);
  assert.match(readyProject, /required:\s*true/);
  const between = (yaml, start, end) => yaml.slice(yaml.indexOf(`id: ${start}`), yaml.indexOf(`id: ${end}`));
  assert.match(between(idea, "context", "acceptance"), /required:\s*false/);
  assert.match(between(idea, "acceptance", "boundaries"), /required:\s*false/);
  assert.match(between(idea, "boundaries", "visibility"), /required:\s*false/);
  assert.match(between(ready, "context", "acceptance"), /required:\s*false/);
  assert.match(between(ready, "acceptance", "boundaries"), /required:\s*true/);
  assert.match(between(ready, "boundaries", "visibility"), /required:\s*true/);
  assert.match(config, /blank_issues_enabled:\s*true/);
});

test("the page renders through textContent and does not carry credentials", () => {
  const app = readRepo("./app.js");
  const html = readRepo("./index.html");
  const protocol = readRepo("./protocol.mjs");
  const css = readRepo("./styles.css");
  for (const source of [app, html, protocol, css]) {
    assert.equal(source.includes("innerHTML"), false);
    assert.equal(source.includes("insertAdjacentHTML"), false);
    assert.equal(source.includes("document.write"), false);
    assert.doesNotMatch(source, /ghp_[A-Za-z0-9]/);
    assert.doesNotMatch(source, /github_pat_/);
    assert.doesNotMatch(source, /access_token/);
    assert.doesNotMatch(source, /["']Authorization["']/);
    assert.doesNotMatch(source, /Authorization\s*:\s*Bearer/);
  }
  assert.match(app, /textContent/);
  assert.match(app, /filterInboxIssues/);
  assert.match(app, /buildNewIssueUrl/);
  assert.match(app, /classifyHttpFailure/);
  assert.match(app, /requestGate/);
  assert.match(app, /nextAutoRefreshDelay/);
  assert.match(app, /visibilitychange/);
  assert.match(app, /document\.hidden/);
  assert.match(app, /credentials:\s*"omit"/);
  assert.match(app, /noopener,noreferrer/);
  assert.ok(app.indexOf("requestGate") < app.indexOf("fetch("));
  assert.ok(html.includes(VISIBILITY_CONFIRMATION));
  assert.ok(html.includes(IDEA_NO_ACTION));
  assert.ok(html.includes(READY_AUTHORIZATION));
  assert.ok(html.includes(NEW_ISSUE_URL));
  assert.ok(html.includes(REVIEW_ON_GITHUB_NOTE));
  assert.ok(html.includes("Sample data"));
  assert.equal(html.includes("template="), false);
  assert.equal(app.includes("new tab was blocked"), false);
  assert.doesNotMatch(`${app}\n${html}`, /request sent|successfully sent|issue created|GitHub credential|stores a token/i);
});
