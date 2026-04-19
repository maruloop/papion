package wasm

import "context"

type Scanner interface {
	Scan(target ScanTarget, yamlContent string, policyJSON string) (*ScanResult, error)
	FormatHuman(result *ScanResult) (string, error)
	FormatJSON(result *ScanResult) (string, error)
	Close(ctx context.Context) error
}
