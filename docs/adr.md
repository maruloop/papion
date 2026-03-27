# Papion Architecture Decision Record (ADR)

## Status

Draft (v0 design direction agreed)

---

## Milestones

### v1.0.0 — CLI + GitHub Actions

* Go CLI with WASM core
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
cli/         # Go CLI                                     [v1+]
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

* JS backend → Cloudflare / browser
* WASM backend → Go CLI

### Rationale

* Combine ease of JS with portability of WASM
* Avoid runtime dependency for CLI
* Enable future extensibility

### Rejected

* WASM-only (too complex early)
* JS-only (limits CLI portability and sandboxing)

---

## Decision 8: WASM role

### Decision

WASM is used as **portable core engine**, not full application

### Rationale

* Keep I/O outside core
* Improve portability and testability

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

Prefer **Pure Core (no host import)** initially

### Rationale

* Simplifies multi-runtime support
* Improves safety
* Reduces complexity

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

### Decision

Use **CI-generated static badges**

### Rationale

* No server dependency
* Reproducible
* Aligns with distributed model

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

## Final Architecture Summary

Papion is:

* A **distributed scanner ecosystem**
* With a **portable core engine (MoonBit)**
* Executed via:

  * CLI (Go + WASM)
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
