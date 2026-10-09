# Daymark Agent Inbox companion

A buildless page for browsing public Daymark requests and opening a GitHub issue draft. It runs in the browser as HTML, CSS, and JavaScript.

The inbox reads public issues in [Silverlin19/Daymark](https://github.com/Silverlin19/Daymark). Only titles that start with `[Daymark Idea] ` or `[Daymark Ready] ` are shown. Cards show the subject without that prefix. Pull requests are left out. An idea is a note and does not start work. A Ready request asks for work, and you still review and submit it on GitHub.

## Run locally

From the repository root:

```sh
python3 -m http.server 8080 --directory companion
```

Open <http://127.0.0.1:8080/>.

Use the HTTP server. Opening `index.html` as a file can block the module script and GitHub requests.

## Tests

From the repository root, with Node 22 or newer:

```sh
node --test companion/*.test.mjs
```

The tests cover prefix recognition, pull-request exclusion, status-label precedence, closed requests, URL encoding, the shared Ready authorization line, the Idea no-action payload, native project headings, and rate-limit suppression.

## Example browser flow

1. Open the page. It loads public issues from GitHub and shows a loading state, then the list or the empty state.
2. Filter by recorded status. Tab to a request and follow **Open issue** to GitHub.
3. Choose **Idea** or **Ready**. An idea needs a title, a requested outcome, and the visibility confirmation. Ready also needs a project, acceptance checks, boundaries, and the authorization checkbox. Context is optional for both.
4. Choose **Review on GitHub**. The page tries to open GitHub's new-issue screen with the title and body filled in. The result text is always "Review and submit on GitHub; if no tab appeared, use the link below." Paste the shown title and body into [a new GitHub issue](https://github.com/Silverlin19/Daymark/issues/new) if the tab did not fill them in. Issue-form links are not offered here, because those forms work only after they are on the default branch.

Recorded status on a card is the GitHub state and labels only:

- Closed issues are **Complete**.
- Open label `agent:needs-input` is **Needs your input**.
- Open label `agent:review` is **Review**.
- Open label `agent:working` is **Working**.
- If several of those labels are present, that order wins.
- Otherwise an open request is **Idea** or **Ready** from its title prefix.

These local previews skip the network and show a sample-data label:

- <http://127.0.0.1:8080/?preview=sample>
- <http://127.0.0.1:8080/?preview=empty>
- <http://127.0.0.1:8080/?preview=error>
- <http://127.0.0.1:8080/?preview=rate-limit>
- <http://127.0.0.1:8080/?preview=loading>

## Limitations

- There is no hosting integration. Serve the `companion` directory yourself.
- Unauthenticated GitHub REST allows about 60 requests an hour for each IP. The page refreshes automatically at most once every 5 minutes, and only while the tab is visible. It does not poll a hidden tab. A rate-limit response sets a deadline from `Retry-After` or `X-RateLimit-Reset` (60 seconds when neither is usable). Refresh and automatic reload both wait until that deadline.
- Later pages load only through **Load more**, so a long list is not cut off without a control. A refresh starts again at the first page.
- Status text is recorded GitHub state, not proof that an agent is running.
- Drafts that would make a GitHub URL longer than 7500 characters are refused. Shorten the note and paste it into a new GitHub issue.
- The prefilled composer depends on GitHub still accepting `issues/new?title&body`. The visible fallback is the plain new-issue page plus the title and body to paste.

## Assumptions

- Open-issue label precedence is `agent:needs-input`, then `agent:review`, then `agent:working`. Closed wins over every label.
- Blank issues stay enabled so a prefilled title and body can open GitHub's classic new-issue screen. The YAML forms are for after they reach the default branch.
- Project text is read from `Project / repo:`, `Project / repository:`, `### Project / repo`, or `### Project / repository`, including the body the Mac app writes.
- Outside a rate-limit deadline, manual refresh is not held for five minutes. The five-minute cap applies to the automatic refresh, and a rate-limit deadline can extend that wait.
- An idea requires a title, requested outcome, and visibility confirmation. Ready also requires a project, acceptance checks, boundaries, and the shared authorization sentence. Context is optional.
