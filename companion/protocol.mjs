/**
 * Pure helpers for the Daymark Agent Inbox companion.
 * No DOM, network, tokens, or webhook values.
 */

export const REPO_OWNER = "Silverlin19";
export const REPO_NAME = "Daymark";
export const REPO_SLUG = `${REPO_OWNER}/${REPO_NAME}`;

export const IDEA_PREFIX = "[Daymark Idea] ";
export const READY_PREFIX = "[Daymark Ready] ";

export const KIND = {
  IDEA: "idea",
  READY: "ready",
};

export const STATUS = {
  COMPLETE: "Complete",
  NEEDS_INPUT: "Needs your input",
  REVIEW: "Review",
  WORKING: "Working",
  READY: "Ready",
  IDEA: "Idea",
};

/** Open issues: the first matching label wins. Closed always becomes Complete. */
export const STATUS_LABEL_PRECEDENCE = [
  { label: "agent:needs-input", status: STATUS.NEEDS_INPUT },
  { label: "agent:review", status: STATUS.REVIEW },
  { label: "agent:working", status: STATUS.WORKING },
];

export const VISIBILITY_CONFIRMATION =
  "I understand this request will be public on GitHub and that personal planner data stays local.";

export const READY_AUTHORIZATION =
  "I authorize this as an explicit work request. Codex may scope it and hand off to Grok. The browser does not dispatch work.";

export const IDEA_NO_ACTION =
  "No work is authorized. This idea must not dispatch an agent or start implementation.";

export const PER_PAGE = 30;
export const REFRESH_INTERVAL_MS = 5 * 60 * 1000;
export const MAX_ISSUE_URL_LENGTH = 7500;
export const MAX_SUBJECT_LENGTH = 200;

export function recognizeKind(title) {
  if (typeof title !== "string") return null;
  if (title.startsWith(READY_PREFIX)) return KIND.READY;
  if (title.startsWith(IDEA_PREFIX)) return KIND.IDEA;
  return null;
}

export function isPullRequest(item) {
  return Boolean(item && typeof item === "object" && item.pull_request);
}

export function labelNames(issue) {
  const labels = issue && Array.isArray(issue.labels) ? issue.labels : [];
  const names = [];
  for (const label of labels) {
    if (typeof label === "string" && label) names.push(label);
    else if (label && typeof label.name === "string" && label.name) names.push(label.name);
  }
  return names;
}

export function statusForIssue(issue) {
  if (!issue || typeof issue !== "object" || isPullRequest(issue)) return null;
  const kind = recognizeKind(issue.title);
  if (!kind) return null;
  if (String(issue.state || "").toLowerCase() === "closed") return STATUS.COMPLETE;
  const names = new Set(labelNames(issue));
  for (const entry of STATUS_LABEL_PRECEDENCE) {
    if (names.has(entry.label)) return entry.status;
  }
  return kind === KIND.READY ? STATUS.READY : STATUS.IDEA;
}

export function statusSlug(status) {
  switch (status) {
    case STATUS.NEEDS_INPUT:
      return "needs-input";
    case STATUS.COMPLETE:
      return "complete";
    case STATUS.REVIEW:
      return "review";
    case STATUS.WORKING:
      return "working";
    case STATUS.READY:
      return "ready";
    case STATUS.IDEA:
      return "idea";
    default:
      return "unknown";
  }
}

export function isInboxIssue(item) {
  return Boolean(item && typeof item === "object" && !isPullRequest(item) && recognizeKind(item.title));
}

export function filterInboxIssues(items) {
  if (!Array.isArray(items)) return [];
  return items.filter(isInboxIssue);
}

export function matchesFilter(issue, filter) {
  const status = statusForIssue(issue);
  if (!status) return false;
  if (!filter || filter === "all") return true;
  if (filter === "idea") return status === STATUS.IDEA;
  if (filter === "ready") return status === STATUS.READY;
  if (filter === "needs-input") return status === STATUS.NEEDS_INPUT;
  if (filter === "review") return status === STATUS.REVIEW;
  if (filter === "working") return status === STATUS.WORKING;
  if (filter === "complete") return status === STATUS.COMPLETE;
  return false;
}

export function mergeIssues(existing, incoming) {
  const base = Array.isArray(existing) ? existing : [];
  const extra = Array.isArray(incoming) ? incoming : [];
  const merged = base.slice();
  const seen = new Set(base.map(issueKey));
  for (const item of extra) {
    const key = issueKey(item);
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(item);
  }
  return merged;
}

function issueKey(item) {
  if (!item || typeof item !== "object") return "";
  if (item.id != null) return `id:${item.id}`;
  if (typeof item.html_url === "string" && item.html_url) return `url:${item.html_url}`;
  return `title:${item.title || ""}`;
}

export function normalizeBody(body) {
  return typeof body === "string" ? body.replace(/\r\n/g, "\n") : "";
}

export function parseProject(body) {
  const text = normalizeBody(body);
  const labeled = text.match(/^Project \/ repo:\s*(.*)$/m);
  const fromLabel = cleanProject(labeled && labeled[1]);
  if (fromLabel) return fromLabel;
  const heading = text.match(/###\s*Project\s*\/\s*repo\s*\n+([^\n]+)/i);
  return cleanProject(heading && heading[1]);
}

function cleanProject(value) {
  const project = String(value || "").trim();
  if (!project || project === "(not specified)" || project === "_No response_") return "";
  return project;
}

export function excerpt(text, max = 200) {
  const collapsed = String(text || "").replace(/\s+/g, " ").trim();
  if (collapsed.length <= max) return collapsed;
  return `${collapsed.slice(0, max - 1).trimEnd()}…`;
}

export function bodyExcerpt(body, max = 200) {
  const text = normalizeBody(body);
  const custom = text.match(/Requested outcome:\s*\n+([\s\S]*?)(?:\n\s*\n|$)/);
  const form = text.match(/###\s*Requested outcome\s*\n+([\s\S]*?)(?:\n###|$)/i);
  const source = (custom && custom[1].trim()) || (form && form[1].trim()) || text;
  return excerpt(source, max);
}

export function commentLabel(count) {
  const n = Number(count);
  const safe = Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
  return safe === 1 ? "1 comment" : `${safe} comments`;
}

export function formatUpdated(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "Unknown update time";
  const formatted = new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(date);
  return `${formatted} UTC`;
}

export function safeGithubUrl(value) {
  if (typeof value !== "string" || value.trim() !== value || !value) return null;
  let url;
  try {
    url = new URL(value);
  } catch {
    return null;
  }
  if (url.protocol !== "https:") return null;
  if (url.username || url.password) return null;
  if (url.hostname !== "github.com") return null;
  if (!url.pathname.startsWith(`/${REPO_SLUG}/`)) return null;
  return url.toString();
}

export function composeTitle(kind, subject) {
  const prefix = kind === KIND.READY ? READY_PREFIX : IDEA_PREFIX;
  return prefix + String(subject || "").trim();
}

export function buildRequestBody(fields) {
  const kind = fields && fields.kind === KIND.READY ? KIND.READY : KIND.IDEA;
  const project = String(fields?.project || "").trim();
  const outcome = String(fields?.outcome || "").trim();
  const context = String(fields?.context || "").trim();
  const acceptance = String(fields?.acceptance || "").trim();
  const boundaries = String(fields?.boundaries || "").trim();
  const lines = [
    `Project / repo: ${project || "(not specified)"}`,
    "",
    "Requested outcome:",
    outcome,
    "",
    "Context:",
    context,
    "",
    "Acceptance checks:",
    acceptance,
    "",
    "Boundaries:",
    boundaries,
    "",
    "Visibility:",
    `- [x] ${VISIBILITY_CONFIRMATION}`,
    "",
    "Work authorization:",
  ];
  if (kind === KIND.READY) lines.push(`- [x] ${READY_AUTHORIZATION}`);
  else lines.push(IDEA_NO_ACTION);
  return lines.join("\n");
}

export function validateRequest(fields) {
  const errors = [];
  const kind = fields && fields.kind;
  if (kind !== KIND.IDEA && kind !== KIND.READY) errors.push("Choose Idea or Ready.");
  const subject = String(fields?.subject || "").trim();
  if (!subject) errors.push("Title is required.");
  else if (/[\r\n]/.test(String(fields?.subject || ""))) errors.push("Title must be a single line.");
  else if (
    subject.startsWith(IDEA_PREFIX) ||
    subject.startsWith(READY_PREFIX) ||
    subject === "[Daymark Idea]" ||
    subject === "[Daymark Ready]"
  ) {
    errors.push("Enter the subject only. The Idea or Ready prefix is added for you.");
  } else if (subject.length > MAX_SUBJECT_LENGTH) errors.push("Title is too long.");
  if (kind === KIND.READY && !String(fields?.project || "").trim()) {
    errors.push("Project / repo is required for a Ready request.");
  }
  if (!String(fields?.outcome || "").trim()) errors.push("Requested outcome is required.");
  if (!String(fields?.context || "").trim()) errors.push("Context is required.");
  if (!String(fields?.acceptance || "").trim()) errors.push("Acceptance checks are required.");
  if (!String(fields?.boundaries || "").trim()) errors.push("Boundaries are required.");
  if (!fields?.visibilityConfirmed) errors.push("Confirm that you understand this request is public.");
  if (kind === KIND.READY && !fields?.authorized) {
    errors.push("Ready requests require an explicit authorization checkbox.");
  }
  return errors;
}

export function newIssueUrl(title, body) {
  const params = new URLSearchParams();
  params.set("title", title);
  params.set("body", body);
  return `https://github.com/${REPO_SLUG}/issues/new?${params.toString()}`;
}

export function buildNewIssueUrl(fields) {
  const errors = validateRequest(fields);
  if (errors.length) return { ok: false, errors, url: null, title: null, body: null };
  const title = composeTitle(fields.kind, fields.subject);
  const body = buildRequestBody(fields);
  const url = newIssueUrl(title, body);
  if (url.length > MAX_ISSUE_URL_LENGTH) {
    return {
      ok: false,
      errors: [
        "This request is too long to prefill a GitHub link. Shorten the fields or use the Idea or Ready form on GitHub.",
      ],
      url: null,
      title: null,
      body: null,
    };
  }
  return { ok: true, errors: [], url, title, body };
}

export function templateUrl(kind) {
  if (kind === KIND.READY) return `https://github.com/${REPO_SLUG}/issues/new?template=daymark-ready.yml`;
  if (kind === KIND.IDEA) return `https://github.com/${REPO_SLUG}/issues/new?template=daymark-idea.yml`;
  return null;
}

export function issuesApiUrl(page = 1) {
  const url = new URL(`https://api.github.com/repos/${REPO_SLUG}/issues`);
  url.searchParams.set("state", "all");
  url.searchParams.set("per_page", String(PER_PAGE));
  url.searchParams.set("sort", "updated");
  url.searchParams.set("direction", "desc");
  url.searchParams.set("page", String(page));
  return url.toString();
}

export function parseNextLink(linkHeader) {
  if (typeof linkHeader !== "string" || !linkHeader) return null;
  const pattern = /<([^>]+)>\s*;\s*rel="?([^",]+)"?/gi;
  let match = pattern.exec(linkHeader);
  while (match) {
    const rels = match[2].toLowerCase().split(/\s+/);
    if (rels.includes("next")) return match[1];
    match = pattern.exec(linkHeader);
  }
  return null;
}

export function nextPageUrl({ currentUrl, rawPageCount, perPage = PER_PAGE, linkHeader }) {
  if (linkHeader != null) return parseNextLink(linkHeader);
  if (!Number.isFinite(rawPageCount) || rawPageCount < perPage) return null;
  const url = new URL(currentUrl);
  const page = Number(url.searchParams.get("page") || "1");
  url.searchParams.set("page", String(Number.isFinite(page) && page > 0 ? page + 1 : 2));
  return url.toString();
}

export function rateLimitMessage({ retryAfter, resetSeconds } = {}) {
  if (typeof retryAfter === "string" && /^\d+$/.test(retryAfter)) {
    return `GitHub rate limit reached. Try again in ${retryAfter} seconds.`;
  }
  if (Number.isFinite(resetSeconds) && resetSeconds > 0) {
    const minutes = Math.max(1, Math.ceil(resetSeconds / 60));
    return `GitHub rate limit reached. Try again in about ${minutes} minutes.`;
  }
  return "GitHub rate limit reached. Wait before refreshing.";
}

function headerGet(headers, name) {
  if (!headers) return null;
  if (typeof headers.get === "function") {
    const value = headers.get(name);
    return value == null ? null : String(value);
  }
  const key = Object.keys(headers).find((candidate) => candidate.toLowerCase() === name.toLowerCase());
  if (!key || headers[key] == null) return null;
  return String(headers[key]);
}

export function classifyHttpFailure(status, headers, bodyText, now = Date.now()) {
  const remaining = headerGet(headers, "x-ratelimit-remaining");
  const retryAfter = headerGet(headers, "retry-after");
  const reset = headerGet(headers, "x-ratelimit-reset");
  const text = typeof bodyText === "string" ? bodyText : "";
  const rateLimited = status === 429 || (status === 403 && remaining === "0") || /rate limit/i.test(text);
  if (rateLimited) {
    let resetSeconds = null;
    if (reset && /^\d+$/.test(reset)) resetSeconds = Math.round(Number(reset) * 1000 - now) / 1000;
    return { type: "rate-limit", message: rateLimitMessage({ retryAfter, resetSeconds }) };
  }
  const code = Number.isFinite(status) ? status : 0;
  return { type: "error", message: `GitHub request failed (${code}).` };
}

export function nextAutoRefreshDelay(lastFetchAt, now, hidden) {
  if (hidden) return null;
  if (typeof lastFetchAt !== "number" || lastFetchAt <= 0) return REFRESH_INTERVAL_MS;
  const remaining = REFRESH_INTERVAL_MS - (now - lastFetchAt);
  return remaining <= 0 ? 0 : remaining;
}

export function fixtureIssues() {
  const idea = (project, outcome) =>
    buildRequestBody({
      kind: KIND.IDEA,
      project,
      outcome,
      context: "Public context only.",
      acceptance: "The inbox shows the request.",
      boundaries: "No private planner data.",
    });
  const ready = (project, outcome) =>
    buildRequestBody({
      kind: KIND.READY,
      project,
      outcome,
      context: "Public context only.",
      acceptance: "The recorded outcome is visible on GitHub.",
      boundaries: "Do not dispatch from the browser.",
    });
  return [
    {
      id: 1,
      title: "[Daymark Idea] Morning carry-forward that stays on the device",
      state: "open",
      labels: [],
      comments: 2,
      updated_at: "2026-04-02T15:04:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/1",
      body: idea("Silverlin19/Daymark", "A person can review yesterday without uploading the planner."),
    },
    {
      id: 2,
      title: "[Daymark Ready] Package a quieter focus chime",
      state: "open",
      labels: [],
      comments: 1,
      updated_at: "2026-04-03T18:30:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/2",
      body: ready("Silverlin19/Daymark", "The focus chime is configurable and still local."),
    },
    {
      id: 3,
      title: "[Daymark Ready] Review the weekly summary copy",
      state: "open",
      labels: [{ name: "agent:working" }, { name: "agent:review" }],
      comments: 4,
      updated_at: "2026-04-04T12:00:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/3",
      body: ready("Silverlin19/Daymark", "The weekly summary uses the recorded status wording."),
    },
    {
      id: 4,
      title: "[Daymark Ready] Refresh workspace scan labels",
      state: "open",
      labels: ["agent:working"],
      comments: 0,
      updated_at: "2026-04-05T09:15:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/4",
      body: ready("Silverlin19/Daymark", "Scan labels match the folder the person already chose."),
    },
    {
      id: 5,
      title: "[Daymark Idea] Ask before changing a streak",
      state: "open",
      labels: [{ name: "agent:needs-input" }, "agent:working"],
      comments: 3,
      updated_at: "2026-04-06T08:00:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/5",
      body: idea("", "Streak edits wait for an answer instead of guessing."),
    },
    {
      id: 6,
      title: "[Daymark Ready] Ship the icon pass",
      state: "closed",
      labels: [{ name: "agent:working" }, { name: "agent:needs-input" }],
      comments: 6,
      updated_at: "2026-03-20T16:45:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/6",
      body: ready("Silverlin19/Daymark", "The icon pass is recorded as complete."),
    },
    {
      id: 7,
      title: "[Daymark Idea] This pull request must not appear",
      state: "open",
      pull_request: { url: "https://api.github.com/repos/Silverlin19/Daymark/pulls/7" },
      labels: [],
      comments: 0,
      updated_at: "2026-04-07T10:00:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/pull/7",
      body: idea("Silverlin19/Daymark", "Pull requests are not inbox requests."),
    },
    {
      id: 8,
      title: "Unrelated repository chore",
      state: "open",
      labels: [{ name: "agent:working" }],
      comments: 1,
      updated_at: "2026-04-07T11:00:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/8",
      body: "This issue does not use a Daymark request prefix.",
    },
    {
      id: 9,
      title: `[Daymark Ready] ${"OverflowCheck".repeat(12)}-end`,
      state: "open",
      labels: [],
      comments: 0,
      updated_at: "2026-04-08T07:00:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/9",
      body: ready("Silverlin19/DaymarkVeryLongProjectNameWithoutBreaks-".repeat(3), "A long title stays inside the card."),
    },
    {
      id: 10,
      title: "[Daymark Idea] <script>alert(1)</script>",
      state: "open",
      labels: [],
      comments: 0,
      updated_at: "2026-04-08T07:05:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/10",
      body: idea("Silverlin19/Daymark", "Show <img src=x onerror=alert(1)> as text."),
    },
    {
      id: 11,
      title: "[Daymark Idea] Filed from the GitHub form",
      state: "open",
      labels: [],
      comments: 0,
      updated_at: "2026-03-01T12:00:00Z",
      html_url: "https://github.com/Silverlin19/Daymark/issues/11",
      body: [
        "### Project / repo",
        "",
        "Silverlin19/Daymark",
        "",
        "### Requested outcome",
        "",
        "Form excerpt should show.",
        "",
        "### Context",
        "",
        "ctx",
      ].join("\n"),
    },
    {
      id: 12,
      title: "[Daymark Idea] Unsafe link is not clickable",
      state: "open",
      labels: [],
      comments: 0,
      updated_at: "2026-04-08T07:06:00Z",
      html_url: "javascript:alert(1)",
      body: idea("Silverlin19/Daymark", "A non-GitHub link is not rendered as an anchor."),
    },
  ];
}
