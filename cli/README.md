# Papion CLI Host Layer

`cli/` is the Go host for the Papion MoonBit core. The host is responsible for I/O, process wiring, and the user-facing command line. The core remains responsible for parsing policy and action content, evaluating rules, and formatting findings.

## Responsibilities

Host layer responsibilities:

- Parse `papion run org/repo@ref`
- Resolve configuration from `--config`, `.github/papion.toml`, or `papion.toml`
- Convert TOML policy input into JSON for the core
- Download action source archives from the GitHub tarball API
- Extract `action.yml` or `action.yaml` from the archive
- Marshal request data into JSON strings for the WASM boundary
- Select human or JSON output mode
- Return the correct process exit code

Core responsibilities:

- Parse `action.yml`
- Parse policy JSON
- Evaluate rules
- Build `ScanResult`
- Format findings as human or JSON output

## Package Layout

- `main.go`: process entry point
- `cmd/`: Cobra commands and CLI orchestration
- `github/`: GitHub archive download client and archive extraction
- `config/`: config lookup and TOML-to-JSON conversion
- `wasm/`: Go mirror types, scanner interface, stub scanner, and wazero skeleton

## Request Flow

1. Parse `owner/repo@ref`
2. Load TOML config and convert it to JSON
3. Download the repository tarball from GitHub
4. Extract `action.yml` or `action.yaml`
5. Call the scanner with:
   - target as JSON-serializable Go structs
   - raw YAML content
   - policy JSON
6. Format the result for stdout
7. Compute the exit code from `--fail-on`

## Interfaces

`github.Client` abstracts archive download:

```go
type Client interface {
    DownloadArchive(ctx context.Context, owner, repo, ref string) ([]byte, error)
}
```

`wasm.Scanner` abstracts the MoonBit core:

```go
type Scanner interface {
    Scan(target ScanTarget, yamlContent string, policyJSON string) (*ScanResult, error)
    FormatHuman(result *ScanResult) (string, error)
    FormatJSON(result *ScanResult) (string, error)
    Close(ctx context.Context) error
}
```

## WASM Boundary Contract

The MoonBit core exports a string-based contract:

- `scan(ScanTarget, String, String) -> Result[ScanResult, String]`
- `format_human(ScanResult) -> String`
- `format_json(ScanResult) -> String`

The Go host serializes structured data with `encoding/json` before crossing the boundary:

- `ScanTarget` is serialized to JSON
- policy TOML is converted into JSON and passed as a raw JSON string
- `action.yml` is passed as raw YAML text
- `ScanResult` is serialized/deserialized as JSON

This keeps the host decoupled from MoonBit internals and makes the scanner interface easy to stub in tests.

## Testing Strategy

- `github/client_test.go`: HTTP behavior with `httptest.Server`
- `github/archive_test.go`: tarball extraction behavior
- `config/loader_test.go`: config lookup precedence and JSON conversion
- `wasm/wazero_test.go`: type JSON round-trips and stub scanner behavior
- `cmd/run_test.go`: CLI parsing, formatting, and exit code behavior with injected doubles

The current milestone uses `StubScanner` in tests. Real wazero integration stays behind `WazeroScanner` and can be completed once the final WASM artifact is available.
