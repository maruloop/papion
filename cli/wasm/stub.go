package wasm

import (
	"context"
	"encoding/json"
	"fmt"
)

type StubScanner struct{}

func (s *StubScanner) Scan(target ScanTarget, yamlContent string, policyJSON string) (*ScanResult, error) {
	contextValue := "stub scanner"
	suggestion := fmt.Sprintf("%s/%s@0000000000000000000000000000000000000000", target.Owner, target.Repo)
	return &ScanResult{
		Target: target,
		Findings: []Finding{
			{
				Level:      FindingLevelWarn,
				Rule:       "stub",
				Target:     fmt.Sprintf("%s/%s@%s", target.Owner, target.Repo, target.GitRef),
				Context:    &contextValue,
				Message:    "Stub scanner result",
				Suggestion: &suggestion,
			},
		},
		Summary: Summary{
			Warnings: 1,
		},
	}, nil
}

func (s *StubScanner) FormatHuman(result *ScanResult) (string, error) {
	if result == nil {
		return "", fmt.Errorf("result is nil")
	}
	return fmt.Sprintf("%d findings (%d failure, %d warning)", len(result.Findings), result.Summary.Failures, result.Summary.Warnings), nil
}

func (s *StubScanner) FormatJSON(result *ScanResult) (string, error) {
	if result == nil {
		return "", fmt.Errorf("result is nil")
	}
	data, err := json.Marshal(result)
	if err != nil {
		return "", fmt.Errorf("marshal result: %w", err)
	}
	return string(data), nil
}

func (s *StubScanner) Close(ctx context.Context) error {
	return nil
}
