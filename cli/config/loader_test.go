package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func writeFile(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("MkdirAll failed: %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("WriteFile failed: %v", err)
	}
}

func decodeJSON(t *testing.T, s string) map[string]any {
	t.Helper()
	var out map[string]any
	if err := json.Unmarshal([]byte(s), &out); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}
	return out
}

func TestLoadConfig_ExplicitPath(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "custom.toml")
	writeFile(t, path, "[policy]\nsha_pinning = true\n")

	got, err := LoadConfig(path)
	if err != nil {
		t.Fatalf("LoadConfig returned error: %v", err)
	}
	if decodeJSON(t, got)["policy"] == nil {
		t.Fatalf("expected policy wrapper in %q", got)
	}
}

func TestLoadConfig_FallbackGithubPath(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, ".github", "papion.toml"), "[policy]\nallowed = [\"actions/*\"]\n")

	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd failed: %v", err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("Chdir failed: %v", err)
	}

	got, err := LoadConfig("")
	if err != nil {
		t.Fatalf("LoadConfig returned error: %v", err)
	}
	if decodeJSON(t, got)["policy"] == nil {
		t.Fatalf("expected policy wrapper in %q", got)
	}
}

func TestLoadConfig_FallbackRepoRootPath(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "papion.toml"), "[policy]\ndisallowed = [\"bad/*\"]\n")

	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd failed: %v", err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("Chdir failed: %v", err)
	}

	got, err := LoadConfig("")
	if err != nil {
		t.Fatalf("LoadConfig returned error: %v", err)
	}
	if decodeJSON(t, got)["policy"] == nil {
		t.Fatalf("expected policy wrapper in %q", got)
	}
}

func TestLoadConfig_NoConfigFound(t *testing.T) {
	dir := t.TempDir()

	oldwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd failed: %v", err)
	}
	defer func() { _ = os.Chdir(oldwd) }()
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("Chdir failed: %v", err)
	}

	got, err := LoadConfig("")
	if err != nil {
		t.Fatalf("LoadConfig returned error: %v", err)
	}
	if got != "" {
		t.Fatalf("expected empty config, got %q", got)
	}
}
