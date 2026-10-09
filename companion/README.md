# Daymark Agent Inbox companion

A buildless page for browsing public Daymark requests and opening a GitHub issue draft. It runs in the browser as HTML, CSS, and JavaScript. It does not take credentials, store tokens, or dispatch work.

The inbox reads public issues in [Silverlin19/Daymark](https://github.com/Silverlin19/Daymark). Only titles that start with `[Daymark Idea] ` or `[Daymark Ready] ` are shown. Pull requests are left out. An Idea does not authorize work. A Ready request is an explicit work request that you still review and submit on GitHub yourself.

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

The tests cover prefix recognition, pull-request exclusion, status-label precedence, closed requests, URL encoding, the Ready authorization line, and the Idea no-action payload.

## Example browser flow

1. Open the page. It loads public issues from GitHub and shows a loading state, then the list or the empty state.
2. Filter by recorded status. Tab to a request and follow **Open issue** to GitHub.
3. Choose **Idea** or **Ready**. Fill the title, project (required for Ready), outcome, context, acceptance checks, and boundaries.
4. Confirm the visibility checkbox. For Ready, also confirm the authorization checkbox.
5. Choose **Review on GitHub**. A new tab opens GitHub's new-issue page with the title and body filled in. Read it there and submit it yourself. This page does not file the issue and does not say the request was sent.
6. Or use **Open the Idea form on GitHub** / **Open the Ready form on GitHub**. Those forms require the same visibility confirmation, and the Ready form also requires authorization.

Recorded status on a card is the GitHub state and labels only:

- Closed issues are **Complete**.
- Open label `agent:needs-input` is **Needs your input**.
- Open label `agent:review` is **Review**.
- Open label `agent:working` is **Working**.
- If several of those labels are present, that order wins.
- Otherwise an open request is **Idea** or **Ready** from its title prefix.

These local previews skip the network:

- <http://127.0.0.1:8080/?preview=sample>
- <http://127.0.0.1:8080/?preview=empty>
- <http://127.0.0.1:8080/?preview=error>
- <http://127.0.0.1:8080/?preview=rate-limit>
- <http://127.0.0.1:8080/?preview=loading>

## Limitations

- There is no hosting integration. Serve the `companion` directory yourself.
- Unauthenticated GitHub REST allows about 60 requests an hour for each IP. The page refreshes automatically at most once every 5 minutes, and only while the tab is visible. It does not poll a hidden tab. **Refresh** still runs when you choose it.
- Later pages load only through **Load more**, so a long list is not cut off without a control. A refresh starts again at the first page.
- Status text is recorded GitHub state, not proof that an agent is running.
- Drafts that would make a GitHub URL longer than 7500 characters are refused. Use the form links for a long request.
- The prefilled composer depends on GitHub still accepting `issues/new?title&body`. The issue forms are the structured path.

## Assumptions

- Open-issue label precedence is `agent:needs-input`, then `agent:review`, then `agent:working`. Closed wins over every label.
- Blank issues stay enabled so the prefilled title and body can open GitHub's classic new-issue screen. The YAML forms enforce their checkboxes when you use those links.
- Project text is read from a `Project / repo:` line or a `### Project / repo` form heading.
- Manual refresh is not held for five minutes. The five-minute cap applies to the automatic refresh.
