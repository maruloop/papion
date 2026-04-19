package github

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"strings"
	"testing"
)

func buildTarball(t *testing.T, files map[string]string) []byte {
	t.Helper()

	var raw bytes.Buffer
	gz := gzip.NewWriter(&raw)
	tw := tar.NewWriter(gz)
	for name, content := range files {
		hdr := &tar.Header{
			Name: name,
			Mode: 0o644,
			Size: int64(len(content)),
		}
		if err := tw.WriteHeader(hdr); err != nil {
			t.Fatalf("WriteHeader failed: %v", err)
		}
		if _, err := tw.Write([]byte(content)); err != nil {
			t.Fatalf("Write failed: %v", err)
		}
	}
	if err := tw.Close(); err != nil {
		t.Fatalf("tar close failed: %v", err)
	}
	if err := gz.Close(); err != nil {
		t.Fatalf("gzip close failed: %v", err)
	}

	return raw.Bytes()
}

func TestExtractActionYml_FindsActionYml(t *testing.T) {
	tarball := buildTarball(t, map[string]string{
		"actions-checkout-sha/action.yml": "name: checkout\nruns:\n  using: composite\n",
	})

	got, err := ExtractActionYml(tarball)
	if err != nil {
		t.Fatalf("ExtractActionYml returned error: %v", err)
	}
	if !strings.Contains(got, "name: checkout") {
		t.Fatalf("unexpected action content: %q", got)
	}
}

func TestExtractActionYml_FindsActionYaml(t *testing.T) {
	tarball := buildTarball(t, map[string]string{
		"actions-checkout-sha/action.yaml": "name: checkout-yaml\n",
	})

	got, err := ExtractActionYml(tarball)
	if err != nil {
		t.Fatalf("ExtractActionYml returned error: %v", err)
	}
	if !strings.Contains(got, "checkout-yaml") {
		t.Fatalf("unexpected action content: %q", got)
	}
}

func TestExtractActionYml_MissingActionFile(t *testing.T) {
	tarball := buildTarball(t, map[string]string{
		"actions-checkout-sha/README.md": "no action here",
	})

	_, err := ExtractActionYml(tarball)
	if err == nil || !strings.Contains(err.Error(), "action.yml") {
		t.Fatalf("expected missing action.yml error, got %v", err)
	}
}
