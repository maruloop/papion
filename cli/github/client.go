package github

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
)

type Client interface {
	DownloadArchive(ctx context.Context, owner, repo, ref string) ([]byte, error)
}

type HTTPClient struct {
	BaseURL    string
	HTTPClient *http.Client
	Token      string
}

func NewHTTPClient(client *http.Client) *HTTPClient {
	if client == nil {
		client = http.DefaultClient
	}
	return &HTTPClient{
		BaseURL:    "https://api.github.com",
		HTTPClient: client,
		Token:      os.Getenv("GITHUB_TOKEN"),
	}
}

func (c *HTTPClient) DownloadArchive(ctx context.Context, owner, repo, ref string) ([]byte, error) {
	baseURL := c.BaseURL
	if baseURL == "" {
		baseURL = "https://api.github.com"
	}
	httpClient := c.HTTPClient
	if httpClient == nil {
		httpClient = http.DefaultClient
	}

	url := fmt.Sprintf("%s/repos/%s/%s/tarball/%s", baseURL, owner, repo, ref)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}
	req.Header.Set("Accept", "application/vnd.github+json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("download archive: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read archive response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		if resp.StatusCode == http.StatusForbidden {
			return nil, fmt.Errorf("github api rate limit or access denied (status 403): %s", string(body))
		}
		return nil, fmt.Errorf("github api returned status %d: %s", resp.StatusCode, string(body))
	}

	return body, nil
}
