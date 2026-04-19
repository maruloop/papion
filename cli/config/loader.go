package config

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/BurntSushi/toml"
)

func LoadConfig(configFlag string) (string, error) {
	path := configFlag
	if path == "" {
		for _, candidate := range []string{".github/papion.toml", "papion.toml"} {
			if _, err := os.Stat(candidate); err == nil {
				path = candidate
				break
			}
		}
	}

	if path == "" {
		return "", nil
	}

	var doc map[string]any
	if _, err := toml.DecodeFile(path, &doc); err != nil {
		return "", fmt.Errorf("decode config %s: %w", path, err)
	}

	data, err := json.Marshal(doc)
	if err != nil {
		return "", fmt.Errorf("marshal config %s to json: %w", path, err)
	}

	return string(data), nil
}
