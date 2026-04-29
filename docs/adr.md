# Papion Architecture Decision Record (ADR)

## Status

Draft (v0 design direction agreed)

---

## Milestones

### v1.0.0 — CLI + GitHub Actions

* MoonBit native binary CLI (Docker fallback)
* GitHub Action integration
* CI-generated static badges
* Distributed scanning only

### v2.0.0 — papion.com (Static)

* Static site hosted on Cloudflare (Workers for routing, Pages for assets)
* Browser-based scanning via JS/WASM
* URL pattern: `papion.com/owner/repo` → scans on demand in browser
* No central index, no backend

### v3.0.0 — Central Marketplace

* Centralized scanning using Papion's own token + queue
* Central searchable index
* Version tracking, scan history
* Badges served from central data

### v4.0.0 — GitHub App

* Owners opt in by installing Papion GitHub App
* Papion uses per-owner App tokens instead of its own token
* Better trust model, scales beyond single-token rate limits
* Upgrades the token strategy from v3

---

## Repository Structure

```
core/        # MoonBit core (parsing, rules, findings)   [v1+]
cli/         # MoonBit native CLI + Docker fallback        [v1+]
action/      # GitHub Action                              [v1+]
web/         # Cloudflare static site + Worker            [v2+]
server/      # Backend application                        [v3+]
infra/       # OpenTofu — cloud + Cloudflare infra        [v3+]
docs/
.claude/
```

---

## Context

Papion is envisioned as a "verifiable index of GitHub Actions" focused on safety (pinning, policy, scanning).

Key goals:

* Help users evaluate safety of GitHub Actions
* Avoid becoming a centralized "source of truth" with heavy trust burden
* Enable reproducible scanning
* Work across multiple environments (CLI, browser, CI, edge)
* Keep system lightweight and scalable

---

## Key Design Principles

1. **Papion is a scanner, not an authority**
2. **Execution is distributed, not centralized**
3. **Results are reproducible, not stored as truth**
4. **Core logic should be portable and environment-agnostic**
5. **Minimize trust surface and infrastructure complexity**

---

## Decision 1: Centralized scanning vs Distributed scanning

### Options

* Centralized scanning service
* Distributed scanning (user/owner executes scan)

### Decision

Adopt **Distributed Scanning**

### Rationale

* Avoids rate limit and token management complexity
* Removes need for large backend infrastructure
* Avoids trust issues ("Papion said it's safe")
* Keeps results always fresh (scan at runtime)

### Consequence

* No guaranteed global index of results
* Requires client-side or CI execution

---

## Decision 2: Result storage

### Options

* Persist scan results centrally
* Do not persist, scan on demand

### Decision

**Do not store results centrally** (allow optional local/owner storage)

### Rationale

* Eliminates stale result problem
* Reduces infrastructure cost
* Improves trust model (results are reproducible)

### Consequence

* No historical comparison out of the box
* Requires caching strategy for performance

---

## Decision 3: Marketplace architecture

### Options

* Fully centralized marketplace with scan results
* Static-only tool without index
* Hybrid index + distributed scan

### Decision

Adopt **Hybrid Model**

* Central index (metadata only)
* Scan results hosted by owners or generated on demand

### Rationale

* Enables search/discovery
* Keeps scan cost distributed
* Aligns with GitHub ecosystem

### Consequence

* Trust must be communicated (owner vs Papion vs user scan)

---

## Decision 4: Hosting model

### Options

* Full backend SaaS
* Static-only distribution

### Decision

Start with **Static-first architecture**

### Components

* CLI
* Static web viewer
* GitHub Action integration

### Rationale

* Minimal infrastructure
* Easy adoption
* Works with GitHub Pages / CDN

---

## Decision 5: URL-based UX (papion.com)

### Decision

Adopt GitHub-style URL mapping:

```
https://github.com/owner/repo
→ https://papion.com/owner/repo
```

### Rationale

* Extremely low friction UX
* Familiar pattern (deepwiki, sourcegraph, etc.)
* Enables marketplace-like browsing

---

## Decision 6: Repository fetching strategy

### Options

* Full git clone
* GitHub API
* Archive download (tar/zip)

### Decision

Prefer **Archive download**

### Rationale

* Fast
* No history
* Matches GitHub Actions behavior
* Minimal complexity

---

## Decision 7: WASM vs JS vs Native

### Options

* JS only
* WASM only
* Multi-target

### Decision

Adopt **Multi-target build using MoonBit**

* Native backend → MoonBit native binary (Docker CLI fallback)
* JS/WASM backend → Cloudflare / browser

### Historical decision (kept for traceability)

Original direction before the CLI runtime change:

* JS backend → Cloudflare / browser
* WASM backend → Go CLI

This historical direction is superseded for CLI runtime by Decision 18.

### Rationale

* Keep CLI runtime simple via MoonBit native binaries
* Keep browser/edge runtime flexible via JS or WASM
* Enable future extensibility

### Rejected

* WASM-only (adds unnecessary CLI runtime coupling)
* JS-only (limits native CLI performance and portability)

---

## Decision 8: WASM role

### Decision

WASM is used as **optional portable runtime**, not mandatory for every host

### Rationale

* Keep I/O outside core
* Preserve portability for browser/edge targets while allowing native CLI execution

### Relation to Decision 7

This decision follows Decision 7 by clarifying that WASM remains a portable runtime for browser/edge targets.
After Decision 18, this still holds while CLI execution moves from Go+WASM to MoonBit native binaries.

---

## Decision 9: Host responsibilities vs Core responsibilities

### Decision

Strict separation

#### Host

* GitHub API calls
* File retrieval
* Auth/token
* Cache
* CLI/UI

#### Core (MoonBit)

* Parsing
* Normalization
* Rule evaluation
* Finding generation

### Rationale

* Enables reuse across environments
* Avoids host import complexity

---

## Decision 10: Host import strategy

### Options

* Provide generic fetch
* Provide high-level APIs
* No imports (pure core)

### Decision

Prefer **Pure Core (no host import)** for v1

### Rationale

* Simplifies multi-runtime support
* Improves safety
* Reduces complexity
* Host pre-resolves any API-dependent data (e.g. `RefKind` via `GET /repos/{owner}/{repo}/git/ref/tags/{ref}` and `.../heads/{ref}`) and passes it into core via data structures

### Future consideration (pre-v2)

If YAML fetching moves into core via a `fetch_yaml` host import, a `resolve_ref_kind` import becomes a natural and low-cost addition. In that model the host shrinks to a thin shell — WASM runtime + import function implementations only. This is a compelling architecture for v2's Cloudflare Worker target where minimising host-side logic reduces deployment surface. The async constraint (WASM imports are synchronous by default) must be resolved first, either via Asyncify or JSPI.

---

## Decision 11: Sandbox strategy

### Decision

Use WASM sandbox + host-controlled I/O

### Rationale

* Prevent unintended external access
* Enable safe processing of untrusted input

---

## Decision 12: File system usage

### Options

* Memory-only
* WASI filesystem

### Decision

Start with **Memory-only processing**

### Rationale

* Simpler
* Sufficient for action scanning

### Future

* Introduce WASI FS if needed

---

## Decision 13: GitHub integration strategy

### Decision

Leverage GitHub-native controls instead of runtime interception

* Allowed actions policy
* SHA pinning
* Runner isolation

### Rationale

* More robust than proxy interception
* Supported by platform

---

## Decision 14: Badge strategy

### Status

**Undecided** — options under consideration

### Options

* **GitHub Actions workflow badge** — built-in, zero effort, shows workflow pass/fail. Not Papion-specific branding.
  ```
  https://github.com/owner/repo/actions/workflows/papion.yml/badge.svg
  ```

* **Gist + shields.io** — CI writes JSON result to a Gist, shields.io renders a custom badge. No server needed. Requires a Gist token in CI secrets. Widely used pattern.
  ```
  https://img.shields.io/endpoint?url=https://gist.github.com/.../papion.json
  ```

* **Commit SVG to repo** — CI generates badge SVG and commits it back. Simple but creates noisy commits and requires write permissions.

* **GitHub Pages** — CI generates badge and deploys to `gh-pages`. Custom branding, no server, but slightly heavy for just a badge.

---

## Decision 15: Owner-hosted reports

### Decision

Encourage GitHub Pages hosting for reports

### Rationale

* Decentralized publishing
* Improves transparency

---

## Decision 16: Browser WASM usage

### Decision

Use browser execution as **optional runtime**, not primary

### Rationale

* Good for ad-hoc scanning
* Not required for core system

---

## Decision 17: YAML parsing strategy

### Options

* **Host-side YAML→JSON conversion** — host converts action.yml YAML to JSON before passing to core; core receives JSON strings only
* **MoonBit YAML parser in core** — core imports a MoonBit YAML library and parses raw YAML strings directly

### Decision

Use **MoonBit YAML parser in core** via `moonbit-community/yaml` v0.0.4

### Rationale

* Eliminates host-side YAML dependency
* Keeps parsing logic portable — same behaviour across CLI, browser, and Cloudflare Worker runtimes
* Simplifies host integration: host reads raw bytes and passes them unchanged
* `moonbit-community/yaml` is ported from yaml-rust2 and supports the YAML subset sufficient for action.yml

### Consequence

* `parse_action_yml` accepts a raw YAML string instead of a pre-converted JSON string
* Core module now depends on `moonbit-community/yaml`
* Host passes raw action.yml content directly to core
* Config (papion.toml / TOML) still converted to JSON by host — TOML is smaller scope and no MoonBit TOML library is required

### Relation to Decision 10

Core remains pure (no host imports). Decision 10's "no host import" principle is preserved — the YAML parser is a vendored MoonBit library, not a host import.

---

## Decision 18: CLI runtime transition (Go+WASM → MoonBit native)

### Context

Decision 7 originally used Go CLI + WASM backend. This is retained above for historical traceability.

### Decision

For current architecture, transition CLI runtime to **MoonBit native binaries**, with **Docker CLI as fallback**, replacing Go+WASM as the default CLI execution path.

### Rationale

* Removes an extra runtime boundary in CLI execution
* Simplifies CLI packaging and operational model
* Aligns CLI runtime with current MoonBit-native direction

### Consequence

* Go+WASM remains historical context, not the active default
* Browser and edge targets continue to use JS/WASM where appropriate

### Consequence (expanded)

* CLI host responsibilities (HTTP client, archive extraction, TOML loading) are implemented in MoonBit via C FFI and pure MoonBit libraries
* `path` in `owner/repo[/path]@ref` is resolved host-side: host fetches `<path>/action.yml` or `<path>/action.yaml` via the GitHub Contents API and passes raw YAML to core — `ScanTarget` stays as `{owner, repo, git_ref}`
* Docker fallback: a pre-built image published to `ghcr.io/maruloop/papion` for platforms where native binary is unavailable
* CI: `moon build --target native` added to CLI test workflow
* Browser and edge targets (JS/WASM) are unaffected

---

## Decision 19: CLI host integrations and integration-test strategy

### Options

* Keep the WS6 native host layer stubbed and defer end-to-end validation
* Implement native host features with C library dependencies (libcurl, libarchive) for HTTP and archive extraction
* Fetch the entire repository tarball and extract action.yml from it
* Fetch only the single `action.yml` / `action.yaml` file directly from the GitHub Contents API

### Decision

Adopt the fourth option — fetch only the single file via the GitHub Contents API:

* `GET https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={git_ref}` returns JSON with a base64-encoded `content` field
* Try `action.yml` first, fall back to `action.yaml`
* For ambiguous GitHub `/tree/<ref>/<path>` URLs in the native CLI, try at most two ref/path fallback rewrites before returning the original 404
* Decode base64 in pure MoonBit — no tar extraction needed at all
* Use `moonbitlang/async/http` for HTTPS — no `libarchive`, no extra build-time development headers, and only the runtime libraries required by the generated native binary
* `moonbitlang/async/tls` loads OpenSSL via `dlopen()` at runtime (typically available on GitHub-hosted runners and most desktop/server macOS/Linux environments, but not guaranteed in minimal or distroless images; no dev headers required)
* `bobzhang/toml` handles CLI config parsing in MoonBit
* CLI integration tests hit the real GitHub Contents API in CI (no fixture tarballs needed)

### Rationale

* Papion only needs a single file (`action.yml` or `action.yaml`) — fetching the whole tarball was wasteful
* The GitHub Contents API is simpler, faster, and requires no archive extraction
* `moonbitlang/async/http` + `dlopen()` TLS eliminates all C library build-time dependencies
* Pure MoonBit base64 decode is trivial and already available in `moonbitlang/core/encoding`
* Fewer moving parts: one HTTP GET replaces tarball download + decompression + tar parsing
* Capping ambiguous tree-ref fallback rewrites at `2` bounds worst-case native fetch traffic to 6 total GitHub Contents requests (`action.yml` + `action.yaml` for the initial parse, then for up to two fallback candidates)
* The cap of `2` still covers the practical slash-containing ref shapes we expect for now; deeper refs are a deliberate follow-up tradeoff rather than unbounded retry behavior

### Consequence

* Native CLI builds require no external development headers — `moon build --target native` works out of the box
* CI drops the `apt-get install libcurl4-openssl-dev libarchive-dev` step entirely
* `core/native/fileio.mbt` provides `fopen`/`fread` file I/O for config loading via libc — always available, no extra headers
* For browser WASM / edge JS targets, the host-side fetch/config boundary now lives in `core/wasm/github.mbt` and `core/wasm/config.mbt`
* The GitHub Contents API requires a valid `ref` (branch, tag, or full SHA) — all are supported
* Very deep slash-containing refs in pasted GitHub tree URLs may still fail native fallback resolution today; widening the cap remains an explicit future adjustment if real usage justifies the extra requests
* The CLI host layer is split into target-aware packages so target-specific dependencies are represented structurally instead of through keepalive references.

### Ref-kind resolution boundary

Papion now treats ref-kind resolution as a host responsibility rather than a pure rules concern.

The decision is:

* `core/rules` receives `RefKind` as input data and stays pure
* `core/engine.scan` accepts an injected `resolve_ref_kind` callback with a pure `classify_ref` fallback
* native hosts may use GitHub API calls to refine that classification before evaluation

This keeps the core contract honest:

* pure and WASM environments can still classify refs structurally with no I/O
* native hosts can verify whether a 40-character hex string actually exists as a commit SHA
* native hosts can treat immutable GitHub releases as equivalent to SHA pins for policy evaluation

### Immutable releases as SHA-equivalent pins

Papion's `sha-pinning` rule now accepts either:

* a verified commit SHA
* an immutable GitHub release tag

On native targets, the host checks:

* `git/commits/{sha}` to verify that SHA-like refs really exist
* `releases/tags/{tag}` and its `immutable` field to recognize immutable releases

The host checks in sequence: if the SHA lookup succeeds the ref is confirmed as `Sha`; if the release lookup succeeds it is confirmed as `ImmutableRelease`. Only if neither check confirms the ref does the host fall back to `Branch`, so Papion never grants a pass based on an unverifiable ref.

### CLI package boundaries

The CLI is packaged as:

* `core/cli`: target-agnostic argument parsing, orchestration, formatting selection, and exit-code policy
* `core/native`: native executable plus file I/O, env access, GitHub Contents fetch, and TOML config loading
* `core/wasm`: WASM/browser-facing stubs or host bindings

This lets MoonBit's package-level `unused_package` checks reflect real dependencies naturally and keeps target responsibilities easier to reason about.

---

## Decision 20: Recursive dependency scanning with cycle detection

### Context

Papion v0 scanned only the direct `uses:` references in the target action's own `action.yml`. Transitive dependencies (actions used by dependencies) were invisible to the scanner, creating a significant gap for security evaluation.

### Decision

Add recursive transitive scanning via `scan` in `core/engine`, with recursion enabled when a fetch callback is provided, keeping the existing layer boundaries:

* **Core engine** manages traversal state: BFS queue, visited set, depth counter, node counter
* **Host layer** continues to own I/O: `fetch_action_yml` is injected as a callback from the CLI into the engine
* **Core parsing and rules** remain unchanged and pure

### Safeguards

| Mechanism | Details |
|---|---|
| Cycle detection | Visited set keyed by `owner/repo[/path]@git_ref` |
| Max depth | `max_scan_depth = 10` (root = depth 0) |
| Max nodes | `max_scan_nodes = 100` unique nodes scheduled for traversal (including failed fetch attempts) |
| Fetch errors | Silently skipped — best-effort traversal |

### Design notes

* `scan` accepts `fetch_action_yml? : (owner, repo, git_ref, path?) -> Result[String, String]` as an optional dependency-injected callback. This keeps the core pure (no host imports) while enabling full traversal when the host supplies fetch support — consistent with Decision 10.
* Policy findings are generated for **every reference**, including repeated references to already-visited nodes. Only **traversal** (fetching) is deduplicated per identity.
* Transitive findings carry a `context` field set to `"via owner/repo@ref"` showing the **immediate parent** action where the dependency was found — not the full chain.
* Omitting `fetch_action_yml?` preserves the old root-only behavior for callers that do not require recursive traversal.
* The CLI `run_with_host` passes an adapted `engine_fetch` that wraps its host `fetch_action_yml` (stripping the resolved-ref return value and the `allow_ref_fallback` flag, which are CLI-only concerns).

### Relation to Decision 9 and Decision 10

The traversal logic lives in the engine (core layer) with a callback injection pattern, preserving the host/core boundary from Decisions 9 and 10. The host remains the sole owner of I/O; the engine manages only pure traversal state.

---

## Final Architecture Summary

Papion is:

* A **distributed scanner ecosystem**
* With a **portable core engine (MoonBit)**
* Executed via:

  * CLI (MoonBit native binary; Docker fallback)
  * Browser (JS/WASM)
  * Cloudflare Worker (JS)
* With a **lightweight central index**
* And **no mandatory central result storage**

---

## Future Considerations

### 1. Central scan-based marketplace

Papion may later evolve into a **true centralized marketplace** in addition to the distributed model.

In that model:

* Papion keeps a central searchable index
* Papion performs scans centrally
* Scan execution is triggered via **GitHub App installation by repository owners**
* Owners explicitly opt in by installing/configuring the GitHub App
* Papion uses **GitHub App tokens**, not the maintainer's personal token

#### Why this is interesting

* This enables a real marketplace experience:

  * searchable actions
  * latest verified scans
  * central trust signals
  * badges and comparison views
* It avoids dependence on the maintainer's personal token
* It provides a clearer trust model than arbitrary external result uploads
* It can support scheduled rescans, version tracking, and richer discovery

#### Trade-offs

* Requires backend infrastructure
* Requires queueing, storage, and result management
* Requires GitHub App ownership and operational maturity
* Reintroduces central trust and scaling concerns

#### Positioning

This is intentionally treated as a **future phase**, not the initial architecture.
The current direction is distributed scanning first, with a possible later expansion into an opt-in GitHub App-powered centralized marketplace.

### 2. Plugin system (WASM-based)

### 3. Policy language integration (OPA-like)

### 4. Optional centralized verification

### 5. Cross-repo analytics

---

## Summary

Papion deliberately avoids becoming a heavy centralized service and instead:

> Distributes execution, centralizes discovery, and preserves reproducibility.

---

## External Context: GitHub Actions 2026 Security Roadmap

Reference: https://github.blog/news-insights/product-news/whats-coming-to-our-github-actions-2026-security-roadmap/

GitHub announced a major security roadmap for GitHub Actions in 2026, covering:

* **Workflow-level dependency locking** — A `dependencies:` section in workflow YAML that locks all direct and transitive action references to commit SHAs (like `go.mod + go.sum`). Public preview in 3–6 months.
* **Policy-driven execution** — Centralized workflow execution policies via rulesets (who can trigger, which events are allowed).
* **Scoped secrets** — Credentials bound to specific execution contexts.
* **Actions Data Stream** — Near real-time execution telemetry.
* **Native egress firewall** — Layer 7 firewall for GitHub-hosted runners.

### Impact on Papion

**Where GitHub's roadmap overlaps with Papion:**

* SHA pinning for **workflow consumers** becomes a platform feature. Papion's value here is reduced once dependency locking ships.

**Where Papion remains differentiated:**

* **Action scanning (not workflow scanning)** — GitHub's lock file secures workflow consumers. Papion scans the action itself. If a composite action internally uses unpinned actions, GitHub's lock file doesn't catch that — Papion does.
* **Policy engine** — Allowed/disallowed lists for evaluating whether a third-party action is acceptable to use. GitHub's policies control execution context, not action selection.
* **Marketplace and discoverability (v3+)** — No GitHub-native public index of action safety signals exists. That is Papion's v3 opportunity.

### Strategic implication

Papion's SHA pinning rule for **action-internal dependencies** remains valid. The larger opportunity shifts toward the **policy engine and marketplace**. GitHub is securing the execution layer; Papion owns the **evaluation and discovery** layer.
