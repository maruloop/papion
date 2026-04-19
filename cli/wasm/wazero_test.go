package wasm

import (
	"encoding/json"
	"testing"
)

func strptr(s string) *string {
	return &s
}

func TestScanResultJSONRoundTrip(t *testing.T) {
	original := ScanResult{
		Target: ScanTarget{
			Owner:  "actions",
			Repo:   "checkout",
			GitRef: "v4",
		},
		Findings: []Finding{
			{
				Level:      FindingLevelWarn,
				Rule:       "sha-pinning",
				Target:     "actions/checkout@v4",
				Context:    strptr("composite step \"setup\""),
				Message:    "Referenced by tag, not pinned to a SHA.",
				Suggestion: strptr("actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683"),
			},
		},
		Summary: Summary{
			Failures: 0,
			Warnings: 1,
		},
	}

	data, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	var decoded ScanResult
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal failed: %v", err)
	}

	if decoded.Target != original.Target {
		t.Fatalf("target mismatch: %#v != %#v", decoded.Target, original.Target)
	}
	if len(decoded.Findings) != 1 {
		t.Fatalf("expected 1 finding, got %d", len(decoded.Findings))
	}
	if decoded.Findings[0].Level != FindingLevelWarn {
		t.Fatalf("unexpected finding level: %q", decoded.Findings[0].Level)
	}
	if decoded.Findings[0].Context == nil || *decoded.Findings[0].Context != *original.Findings[0].Context {
		t.Fatalf("context mismatch: %#v", decoded.Findings[0].Context)
	}
	if decoded.Findings[0].Suggestion == nil || *decoded.Findings[0].Suggestion != *original.Findings[0].Suggestion {
		t.Fatalf("suggestion mismatch: %#v", decoded.Findings[0].Suggestion)
	}
}

func TestStubScannerReturnsCannedResult(t *testing.T) {
	scanner := &StubScanner{}
	target := ScanTarget{Owner: "actions", Repo: "checkout", GitRef: "v4"}

	result, err := scanner.Scan(target, "name: checkout", `{"policy":{}}`)
	if err != nil {
		t.Fatalf("Scan returned error: %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.Target != target {
		t.Fatalf("target mismatch: %#v != %#v", result.Target, target)
	}
	if len(result.Findings) == 0 {
		t.Fatal("expected canned findings")
	}

	human, err := scanner.FormatHuman(result)
	if err != nil {
		t.Fatalf("FormatHuman returned error: %v", err)
	}
	if human == "" {
		t.Fatal("expected non-empty human output")
	}

	jsonOut, err := scanner.FormatJSON(result)
	if err != nil {
		t.Fatalf("FormatJSON returned error: %v", err)
	}
	if !json.Valid([]byte(jsonOut)) {
		t.Fatalf("expected valid json output, got %q", jsonOut)
	}
}
