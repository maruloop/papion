# Papion Core

Pure MoonBit engine for scanning GitHub Actions. Core logic is portable and environment-agnostic. Host-specific I/O (GitHub API, file system) is injected via callbacks.

## Packages

| Package | Purpose |
|---------|---------|
| `papion` (root) | Core data types shared by all packages |
| `papion/parser` | Parse action.yml YAML into core types |
| `papion/config` | Parse policy configuration JSON, glob matching for allowed/disallowed lists |
| `papion/rules` | Evaluate policy rules against action references |
| `papion/format` | Format scan results as human-readable or JSON output |
| `papion/engine` | Orchestrate a full scan |
| `papion/cli` | Target-agnostic argument parsing, orchestration, formatting selection |
| `papion/native` | Native CLI executable, GitHub API integration, file I/O |
| `papion/wasm` | WASM/browser-facing stubs and host bindings |

## Data Model

### ActionRef

A parsed action reference from a `uses:` field.

```
ActionRef {
  owner : String       // e.g. "actions"
  repo : String        // e.g. "checkout"
  git_ref : String     // e.g. "v4" or "abc123..." (`ref` is reserved in MoonBit)
  path : String?       // e.g. "action" in "maruloop/papion/action@v1"
}
```

### RefKind

Classifies the type of ref.

```
RefKind = Sha | Tag | Branch | ImmutableRelease
```

### ActionYml

Parsed action.yml content.

```
ActionYml {
  name : String
  description : String?
  runs : Runs
}
```

### Runs

The `runs` section of action.yml.

```
Runs {
  runner : String                 // e.g. "composite", "node20" (`using` is reserved in MoonBit)
  steps : Array[CompositeStep]?  // present only for composite actions
}
```

### CompositeStep

A step in a composite action.

```
CompositeStep {
  uses : String?     // action reference string, if present
  run : String?      // shell command, if present
  name : String?
}
```

### FindingLevel

```
FindingLevel = Warn | Fail
```

### Finding

A single policy violation.

```
Finding {
  level : FindingLevel
  rule : String           // e.g. "sha-pinning", "allowed-list", "disallowed-list"
  target : String         // e.g. "actions/checkout@v4"
  context : String?       // e.g. "composite step \"setup\""
  message : String
  suggestion : String?    // e.g. "actions/checkout@abc123..."
}
```

### Policy

Scanning policy configuration.

```
Policy {
  sha_pinning : Bool              // default: true
  allowed : Array[String]         // glob patterns, e.g. ["actions/*"]
  disallowed : Array[String]      // glob patterns
}
```

### ScanTarget

The action being scanned.

```
ScanTarget {
  owner : String
  repo : String
  git_ref : String
}
```

### ScanResult

Complete scan output.

```
ScanResult {
  target : ScanTarget
  findings : Array[Finding]
  summary : Summary
}
```

### Summary

```
Summary {
  failures : Int
  warnings : Int
}
```

## Build Targets

```sh
moon build --target native   # Native CLI binary
moon build --target js       # JS for browser / Cloudflare Workers
moon build --target wasm-gc  # WASM (GC) for browser embedding
```
