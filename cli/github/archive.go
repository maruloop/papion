package github

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"path"
)

func ExtractActionYml(tarballBytes []byte) (string, error) {
	gzr, err := gzip.NewReader(bytes.NewReader(tarballBytes))
	if err != nil {
		return "", fmt.Errorf("open gzip archive: %w", err)
	}
	defer gzr.Close()

	tr := tar.NewReader(gzr)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", fmt.Errorf("read tar archive: %w", err)
		}
		if hdr.Typeflag != tar.TypeReg {
			continue
		}

		base := path.Base(hdr.Name)
		if base != "action.yml" && base != "action.yaml" {
			continue
		}

		content, err := io.ReadAll(tr)
		if err != nil {
			return "", fmt.Errorf("read %s: %w", hdr.Name, err)
		}
		return string(content), nil
	}

	return "", fmt.Errorf("action.yml or action.yaml not found in archive")
}
