package cmd

import (
	"bytes"
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/maruloop/papion/cli/wasm"
)

type fakeClient struct {
	archive []byte
	err     error
}

func (f fakeClient) DownloadArchive(ctx context.Context, owner, repo, ref string) ([]byte, error) {
	if f.err != nil {
		return nil, f.err
	}
	return f.archive, nil
}

type fakeScanner struct {
	result *wasm.ScanResult
	err    error
}

func (f *fakeScanner) Scan(target wasm.ScanTarget, yamlContent string, policyJSON string) (*wasm.ScanResult, error) {
	if f.err != nil {
		return nil, f.err
	}
	return f.result, nil
}

func (f *fakeScanner) FormatHuman(result *wasm.ScanResult) (string, error) {
	return "human output", nil
}

func (f *fakeScanner) FormatJSON(result *wasm.ScanResult) (string, error) {
	return `{"ok":true}`, nil
}

func (f *fakeScanner) Close(ctx context.Context) error {
	return nil
}

func sampleResult(levels ...wasm.FindingLevel) *wasm.ScanResult {
	findings := make([]wasm.Finding, 0, len(levels))
	summary := wasm.Summary{}
	for i, level := range levels {
		findings = append(findings, wasm.Finding{
			Level:   level,
			Rule:    "sha-pinning",
			Target:  "actions/checkout@v4",
			Message: "message",
		})
		if level == wasm.FindingLevelFail {
			summary.Failures++
		}
		if level == wasm.FindingLevelWarn {
			summary.Warnings++
		}
		_ = i
	}
	return &wasm.ScanResult{
		Target:   wasm.ScanTarget{Owner: "actions", Repo: "checkout", GitRef: "v4"},
		Findings: findings,
		Summary:  summary,
	}
}

func TestExecuteRun_DefaultsAndCleanExit(t *testing.T) {
	stdout := &bytes.Buffer{}
	code, err := Execute(context.Background(), []string{"run", "actions/checkout@v4"}, Dependencies{
		Stdout:           stdout,
		Client:           fakeClient{archive: []byte("unused")},
		Scanner:          &fakeScanner{result: sampleResult()},
		LoadConfig:       func(flag string) (string, error) { return "", nil },
		ExtractActionYML: func(data []byte) (string, error) { return "name: test", nil },
	})
	if err != nil {
		t.Fatalf("Execute returned error: %v", err)
	}
	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if got := strings.TrimSpace(stdout.String()); got != "human output" {
		t.Fatalf("expected human output, got %q", got)
	}
}

func TestExecuteRun_JSONOutput(t *testing.T) {
	stdout := &bytes.Buffer{}
	code, err := Execute(context.Background(), []string{"run", "actions/checkout@v4", "--format", "json"}, Dependencies{
		Stdout:           stdout,
		Client:           fakeClient{archive: []byte("unused")},
		Scanner:          &fakeScanner{result: sampleResult()},
		LoadConfig:       func(flag string) (string, error) { return "", nil },
		ExtractActionYML: func(data []byte) (string, error) { return "name: test", nil },
	})
	if err != nil {
		t.Fatalf("Execute returned error: %v", err)
	}
	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if got := strings.TrimSpace(stdout.String()); got != `{"ok":true}` {
		t.Fatalf("expected json output, got %q", got)
	}
}

func TestExecuteRun_FailOnThresholds(t *testing.T) {
	tests := []struct {
		name   string
		args   []string
		result *wasm.ScanResult
		want   int
	}{
		{name: "fail threshold ignores warn", args: []string{"run", "actions/checkout@v4"}, result: sampleResult(wasm.FindingLevelWarn), want: 0},
		{name: "fail threshold triggers on fail", args: []string{"run", "actions/checkout@v4"}, result: sampleResult(wasm.FindingLevelFail), want: 1},
		{name: "warn threshold triggers on warn", args: []string{"run", "actions/checkout@v4", "--fail-on", "warn"}, result: sampleResult(wasm.FindingLevelWarn), want: 1},
		{name: "none never fails", args: []string{"run", "actions/checkout@v4", "--fail-on", "none"}, result: sampleResult(wasm.FindingLevelFail, wasm.FindingLevelWarn), want: 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			code, err := Execute(context.Background(), tt.args, Dependencies{
				Stdout:           bytes.NewBuffer(nil),
				Client:           fakeClient{archive: []byte("unused")},
				Scanner:          &fakeScanner{result: tt.result},
				LoadConfig:       func(flag string) (string, error) { return "", nil },
				ExtractActionYML: func(data []byte) (string, error) { return "name: test", nil },
			})
			if err != nil {
				t.Fatalf("Execute returned error: %v", err)
			}
			if code != tt.want {
				t.Fatalf("expected exit code %d, got %d", tt.want, code)
			}
		})
	}
}

func TestExecuteRun_InvalidTargetIsExitCode2(t *testing.T) {
	code, err := Execute(context.Background(), []string{"run", "not-a-target"}, Dependencies{
		Stdout:           bytes.NewBuffer(nil),
		Client:           fakeClient{archive: []byte("unused")},
		Scanner:          &fakeScanner{result: sampleResult()},
		LoadConfig:       func(flag string) (string, error) { return "", nil },
		ExtractActionYML: func(data []byte) (string, error) { return "name: test", nil },
	})
	if err == nil {
		t.Fatal("expected error for invalid target")
	}
	if code != 2 {
		t.Fatalf("expected exit code 2, got %d", code)
	}
}

func TestExecuteRun_ScanErrorIsExitCode2(t *testing.T) {
	code, err := Execute(context.Background(), []string{"run", "actions/checkout@v4"}, Dependencies{
		Stdout:           bytes.NewBuffer(nil),
		Client:           fakeClient{archive: []byte("unused")},
		Scanner:          &fakeScanner{err: errors.New("scan failed")},
		LoadConfig:       func(flag string) (string, error) { return "", nil },
		ExtractActionYML: func(data []byte) (string, error) { return "name: test", nil },
	})
	if err == nil {
		t.Fatal("expected scanner error")
	}
	if code != 2 {
		t.Fatalf("expected exit code 2, got %d", code)
	}
}
