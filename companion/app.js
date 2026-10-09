import {
  KIND,
  bodyExcerpt,
  buildNewIssueUrl,
  classifyHttpFailure,
  commentLabel,
  displaySubject,
  filterInboxIssues,
  fixtureIssues,
  formatUpdated,
  issuesApiUrl,
  matchesFilter,
  mergeIssues,
  NEW_ISSUE_URL,
  nextAutoRefreshDelay,
  nextPageUrl,
  parseProject,
  PER_PAGE,
  beginNetworkLoad,
  describeRetryWait,
  rateLimitMessage,
  REVIEW_ON_GITHUB_NOTE,
  safeGithubUrl,
  statusForIssue,
  statusSlug,
} from "./protocol.mjs";

const PREVIEW_NAMES = new Set(["loading", "empty", "error", "rate-limit", "sample"]);

const inbox = document.querySelector("#inbox");
const previewBanner = document.querySelector("#preview-banner");
const banner = document.querySelector("#inbox-banner");
const alertBox = document.querySelector("#inbox-alert");
const list = document.querySelector("#issue-list");
const empty = document.querySelector("#inbox-empty");
const refreshButton = document.querySelector("#refresh");
const loadMoreButton = document.querySelector("#load-more");
const filterInputs = document.querySelectorAll('input[name="status-filter"]');
const form = document.querySelector("#composer");
const ideaNote = document.querySelector("#idea-note");
const projectHint = document.querySelector("#project-hint");
const authorizationField = document.querySelector("#authorization-field");
const errors = document.querySelector("#form-errors");
const resultNote = document.querySelector("#composer-result");
const copyPanel = document.querySelector("#copy-panel");
const copyTitle = document.querySelector("#copy-title");
const copyBody = document.querySelector("#copy-body");
const fallback = document.querySelector("#composer-fallback");
const acceptanceHint = document.querySelector("#acceptance-hint");
const boundariesHint = document.querySelector("#boundaries-hint");

const previewName = new URLSearchParams(window.location.search).get("preview");
const state = {
  preview: PREVIEW_NAMES.has(previewName) ? previewName : null,
  issues: [],
  nextUrl: null,
  phase: "loading",
  banner: "Loading public requests…",
  alertTitle: "",
  alertMessage: "",
  filter: "all",
  lastFetchAt: 0,
  retryUntil: 0,
  requestId: 0,
};

if (state.preview) document.documentElement.dataset.preview = state.preview;

let refreshTimer = 0;
let activeRequest = null;

function node(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text != null) element.textContent = text;
  return element;
}

function selectedKind() {
  const checked = form.querySelector('input[name="kind"]:checked');
  return checked ? checked.value : KIND.IDEA;
}

function syncKind() {
  const ready = selectedKind() === KIND.READY;
  authorizationField.hidden = !ready;
  ideaNote.hidden = ready;
  projectHint.textContent = ready ? "Required for a Ready request." : "Optional for an idea.";
  acceptanceHint.textContent = ready ? "Required for a Ready request." : "Optional for an idea.";
  boundariesHint.textContent = ready ? "Required for a Ready request." : "Optional for an idea.";
}

function readFields() {
  return {
    kind: selectedKind(),
    subject: document.querySelector("#subject").value,
    project: document.querySelector("#project").value,
    outcome: document.querySelector("#outcome").value,
    context: document.querySelector("#context").value,
    acceptance: document.querySelector("#acceptance").value,
    boundaries: document.querySelector("#boundaries").value,
    visibilityConfirmed: document.querySelector("#visibility").checked,
    authorized: document.querySelector("#authorization").checked,
  };
}

function showErrors(messages) {
  errors.replaceChildren();
  if (!messages.length) {
    errors.hidden = true;
    return;
  }
  for (const message of messages) errors.append(node("li", null, message));
  errors.hidden = false;
  errors.focus();
}

function issueCard(issue) {
  const status = statusForIssue(issue);
  const article = node("article", "issue");
  article.dataset.status = statusSlug(status);
  article.append(node("p", `status status-${statusSlug(status)}`, status));
  const subject = displaySubject(issue.title);
  article.append(node("h3", null, subject || issue.title || ""));
  const project = parseProject(issue.body || "");
  article.append(node("p", "project", project ? `Project / repo: ${project}` : "No project listed"));
  article.append(node("p", "excerpt", bodyExcerpt(issue.body || "") || "No details in the issue body."));
  const meta = node("p", "meta");
  const time = node("time", null, formatUpdated(issue.updated_at));
  if (issue.updated_at) time.dateTime = issue.updated_at;
  meta.append(time, node("span", null, commentLabel(issue.comments)));
  article.append(meta);
  const href = safeGithubUrl(issue.html_url);
  if (href) {
    const link = node("a");
    link.href = href;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.append(document.createTextNode("Open issue"), node("span", "sr-only", " (opens in a new tab)"));
    article.append(link);
  } else {
    article.append(node("p", "missing-link", "Issue link unavailable"));
  }
  return article;
}

function render() {
  previewBanner.hidden = !state.preview;
  inbox.dataset.state = state.phase;
  inbox.setAttribute("aria-busy", state.phase === "loading" ? "true" : "false");
  banner.textContent = state.banner;
  alertBox.replaceChildren();
  if (state.phase === "error" || state.phase === "rate-limit") {
    alertBox.className = state.phase === "rate-limit" ? "alert alert-rate-limit" : "alert alert-error";
    alertBox.append(node("h3", null, state.alertTitle), node("p", null, state.alertMessage));
    alertBox.hidden = false;
  } else {
    alertBox.hidden = true;
  }

  const visible = state.issues.filter((issue) => matchesFilter(issue, state.filter));
  list.replaceChildren(...visible.map(issueCard));
  const showEmpty = state.phase === "ready" && visible.length === 0;
  empty.hidden = !showEmpty;
  if (showEmpty) {
    empty.textContent = state.issues.length
      ? "No requests match this filter."
      : "No public Daymark requests yet. An idea does not start work. A Ready request is filed only after you review it on GitHub.";
  }
  loadMoreButton.hidden = !state.nextUrl;
}

function applyPreview(name) {
  state.phase = "ready";
  state.alertTitle = "";
  state.alertMessage = "";
  state.nextUrl = null;
  state.issues = [];
  if (name === "loading") {
    state.phase = "loading";
    state.banner = "Loading public requests…";
    return;
  }
  if (name === "empty") {
    state.banner = "Showing 0 of 0 loaded requests.";
    return;
  }
  if (name === "error") {
    state.phase = "error";
    state.banner = "";
    state.alertTitle = "Couldn't load requests";
    state.alertMessage = "GitHub request failed (503).";
    return;
  }
  if (name === "rate-limit") {
    state.phase = "rate-limit";
    state.banner = "";
    state.alertTitle = "GitHub rate limit";
    state.alertMessage = rateLimitMessage({ retryAfter: "60" });
    return;
  }
  state.issues = filterInboxIssues(fixtureIssues());
  state.nextUrl = "preview-next";
  state.banner = `Showing ${state.issues.length} of ${state.issues.length} loaded requests. More pages are available.`;
}

function scheduleAutoRefresh() {
  window.clearTimeout(refreshTimer);
  const delay = nextAutoRefreshDelay(state.lastFetchAt, Date.now(), document.hidden, state.retryUntil);
  if (delay == null) return;
  refreshTimer = window.setTimeout(() => {
    refreshTimer = 0;
    if (document.hidden) return;
    void load({ reset: true });
  }, delay);
}

function setFailure(failure) {
  if (failure.type === "rate-limit" && failure.retryUntil) state.retryUntil = failure.retryUntil;
  state.phase = failure.type === "rate-limit" ? "rate-limit" : "error";
  state.banner = state.issues.length ? "Showing the requests already loaded." : "";
  state.alertTitle = state.phase === "rate-limit" ? "GitHub rate limit" : "Couldn't load requests";
  state.alertMessage = failure.message;
}

async function load({ reset, manual = false }) {
  if (!state.preview) {
    const decision = beginNetworkLoad({
      now: Date.now(),
      retryUntil: state.retryUntil,
      hidden: document.hidden,
      manual,
      issues: state.issues,
    });
    state.issues = decision.issues;
    if (!decision.proceed) {
      if (decision.gate.reason === "rate-limit") {
        state.phase = "rate-limit";
        state.alertTitle = "GitHub rate limit";
        state.alertMessage = describeRetryWait(decision.gate.waitMs);
        state.banner = state.issues.length ? "Showing the requests already loaded." : "";
        render();
      }
      scheduleAutoRefresh();
      return;
    }
  }

  if (state.preview) {
    if (!reset && state.preview === "sample") {
      state.nextUrl = null;
      state.phase = "ready";
      state.banner = `Showing ${state.issues.length} of ${state.issues.length} loaded requests. Preview mode has no more pages.`;
      render();
      return;
    }
    applyPreview(state.preview);
    state.lastFetchAt = Date.now();
    render();
    scheduleAutoRefresh();
    return;
  }

  if (activeRequest) activeRequest.abort();
  const request = new AbortController();
  activeRequest = request;
  const requestId = ++state.requestId;
  const url = !reset && state.nextUrl ? state.nextUrl : issuesApiUrl(1);
  state.lastFetchAt = Date.now();
  if (reset && state.issues.length === 0) {
    state.phase = "loading";
    state.banner = "Loading public requests…";
  } else if (reset) {
    state.banner = "Refreshing public requests…";
  } else {
    state.banner = "Loading the next page…";
  }
  render();

  try {
    const response = await fetch(url, {
      method: "GET",
      credentials: "omit",
      cache: "no-store",
      referrerPolicy: "no-referrer",
      signal: request.signal,
      headers: {
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });
    if (requestId !== state.requestId) return;
    if (!response.ok) {
      const text = await response.text();
      if (requestId !== state.requestId) return;
      setFailure(classifyHttpFailure(response.status, response.headers, text));
      return;
    }
    const data = await response.json();
    if (requestId !== state.requestId) return;
    if (!Array.isArray(data)) {
      setFailure({ type: "error", message: "GitHub returned an unexpected response." });
      return;
    }
    const incoming = filterInboxIssues(data);
    state.issues = reset ? incoming : mergeIssues(state.issues, incoming);
    state.nextUrl = nextPageUrl({
      currentUrl: url,
      rawPageCount: data.length,
      perPage: PER_PAGE,
      linkHeader: response.headers.get("Link"),
    });
    state.phase = "ready";
    state.retryUntil = 0;
    state.alertTitle = "";
    state.alertMessage = "";
    const more = state.nextUrl ? " More pages are available." : "";
    state.banner = `Showing ${state.issues.length} loaded requests.${more}`;
  } catch (error) {
    if (error && error.name === "AbortError") return;
    if (requestId !== state.requestId) return;
    setFailure({ type: "error", message: "Could not reach GitHub. Check the connection and try again." });
  } finally {
    if (requestId === state.requestId) {
      render();
      scheduleAutoRefresh();
    }
  }
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const built = buildNewIssueUrl(readFields());
  resultNote.textContent = "";
  copyPanel.hidden = true;
  fallback.hidden = true;
  if (!built.ok) {
    showErrors(built.errors);
    return;
  }
  showErrors([]);
  copyTitle.textContent = built.title;
  copyBody.textContent = built.body;
  copyPanel.hidden = false;
  fallback.href = NEW_ISSUE_URL;
  fallback.hidden = false;
  window.open(built.url, "_blank", "noopener,noreferrer");
  resultNote.textContent = REVIEW_ON_GITHUB_NOTE;
});

form.addEventListener("change", (event) => {
  if (event.target && event.target.name === "kind") syncKind();
});

refreshButton.addEventListener("click", () => {
  void load({ reset: true, manual: true });
});

loadMoreButton.addEventListener("click", () => {
  void load({ reset: false, manual: true });
});

for (const input of filterInputs) {
  input.addEventListener("change", () => {
    if (!input.checked) return;
    state.filter = input.value;
    if (state.phase === "ready") {
      const visible = state.issues.filter((issue) => matchesFilter(issue, state.filter)).length;
      const more = state.nextUrl ? " More pages are available." : "";
      state.banner = `Showing ${visible} of ${state.issues.length} loaded requests.${more}`;
    }
    render();
  });
}

document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    window.clearTimeout(refreshTimer);
    refreshTimer = 0;
    return;
  }
  scheduleAutoRefresh();
});

syncKind();
void load({ reset: true, manual: true });
