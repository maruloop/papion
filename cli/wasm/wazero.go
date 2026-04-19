package wasm

import (
	"context"
	_ "embed"
	"fmt"

	"github.com/tetratelabs/wazero"
)

//go:embed papion.wasm
var embeddedModule []byte

type WazeroScanner struct {
	module        []byte
	runtimeConfig wazero.RuntimeConfig
}

func NewWazeroScanner() *WazeroScanner {
	return &WazeroScanner{
		module:        embeddedModule,
		runtimeConfig: wazero.NewRuntimeConfig(),
	}
}

func (s *WazeroScanner) Scan(target ScanTarget, yamlContent string, policyJSON string) (*ScanResult, error) {
	return nil, fmt.Errorf("wazero scanner not implemented")
}

func (s *WazeroScanner) FormatHuman(result *ScanResult) (string, error) {
	return "", fmt.Errorf("wazero scanner not implemented")
}

func (s *WazeroScanner) FormatJSON(result *ScanResult) (string, error) {
	return "", fmt.Errorf("wazero scanner not implemented")
}

func (s *WazeroScanner) Close(ctx context.Context) error {
	return nil
}
