package github

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestHTTPClientDownloadArchive_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.URL.Path; got != "/repos/actions/checkout/tarball/v4" {
			t.Fatalf("unexpected path: %s", got)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer test-token" {
			t.Fatalf("unexpected auth header: %q", got)
		}
		_, _ = w.Write([]byte("archive"))
	}))
	defer server.Close()

	client := &HTTPClient{
		BaseURL:    server.URL,
		HTTPClient: server.Client(),
		Token:      "test-token",
	}

	body, err := client.DownloadArchive(context.Background(), "actions", "checkout", "v4")
	if err != nil {
		t.Fatalf("DownloadArchive returned error: %v", err)
	}
	if string(body) != "archive" {
		t.Fatalf("unexpected body: %q", string(body))
	}
}

func TestHTTPClientDownloadArchive_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "missing", http.StatusNotFound)
	}))
	defer server.Close()

	client := &HTTPClient{
		BaseURL:    server.URL,
		HTTPClient: server.Client(),
	}

	_, err := client.DownloadArchive(context.Background(), "actions", "checkout", "v4")
	if err == nil || !strings.Contains(err.Error(), "404") {
		t.Fatalf("expected 404 error, got %v", err)
	}
}

func TestHTTPClientDownloadArchive_RateLimited(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "rate limited", http.StatusForbidden)
	}))
	defer server.Close()

	client := &HTTPClient{
		BaseURL:    server.URL,
		HTTPClient: server.Client(),
	}

	_, err := client.DownloadArchive(context.Background(), "actions", "checkout", "v4")
	if err == nil || !strings.Contains(strings.ToLower(err.Error()), "rate limit") {
		t.Fatalf("expected rate limit error, got %v", err)
	}
}

func TestHTTPClientDownloadArchive_NetworkError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	client := &HTTPClient{
		BaseURL:    server.URL,
		HTTPClient: &http.Client{Timeout: time.Second},
	}
	server.Close()

	_, err := client.DownloadArchive(context.Background(), "actions", "checkout", "v4")
	if err == nil {
		t.Fatal("expected network error")
	}
}
