// Unit tests for the DVTL-815 sample app. Stdlib only — net/http/httptest against the REAL routing
// table from newMux(), so a route regression (a handler unwired, /healthz broken, "/" no longer
// 404-ing unknown paths) fails here before an image is ever built. Wired into the app build via
// `go test ./src/...` in .github/workflows/build.yml.
package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// get issues an in-process GET against the app's mux and returns the recorded response + body.
// No network, no server bind — httptest.NewRecorder captures what the handler writes.
func get(t *testing.T, path string) (*http.Response, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	rec := httptest.NewRecorder()
	newMux().ServeHTTP(rec, req)
	res := rec.Result()
	body, err := io.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("reading response body for %q: %v", path, err)
	}
	_ = res.Body.Close()
	return res, string(body)
}

// GET / -> 200, HTML, and the greeting is present (the thing you edit to prove the deploy loop).
func TestRootServesGreeting(t *testing.T) {
	res, body := get(t, "/")

	if res.StatusCode != http.StatusOK {
		t.Errorf("GET / status = %d, want %d", res.StatusCode, http.StatusOK)
	}
	if ct := res.Header.Get("Content-Type"); !strings.HasPrefix(ct, "text/html") {
		t.Errorf("GET / Content-Type = %q, want text/html*", ct)
	}
	if !strings.Contains(body, greeting) {
		t.Errorf("GET / body does not contain greeting %q", greeting)
	}
	// The page renders the build version; "dev" is the un-built default (overridden by -ldflags).
	if !strings.Contains(body, version) {
		t.Errorf("GET / body does not contain version %q", version)
	}
}

// Any path other than "/" must 404 — the handler's explicit r.URL.Path != "/" branch, which keeps
// the demo URL unambiguous. Table-driven so adding a case is one line.
func TestNonRootPathsReturn404(t *testing.T) {
	for _, path := range []string{"/nope", "/index.html", "/foo/bar"} {
		res, _ := get(t, path)
		if res.StatusCode != http.StatusNotFound {
			t.Errorf("GET %q status = %d, want %d", path, res.StatusCode, http.StatusNotFound)
		}
	}
}

// GET /healthz -> 200 "ok" — the endpoint the readiness/liveness probes hit (app.tf). Health is
// deliberately decoupled from the "/" demo page, so this is its own case.
func TestHealthzOK(t *testing.T) {
	res, body := get(t, "/healthz")

	if res.StatusCode != http.StatusOK {
		t.Errorf("GET /healthz status = %d, want %d", res.StatusCode, http.StatusOK)
	}
	if got := strings.TrimSpace(body); got != "ok" {
		t.Errorf("GET /healthz body = %q, want %q", got, "ok")
	}
}
