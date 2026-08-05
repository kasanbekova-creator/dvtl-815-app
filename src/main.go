// Tiny web server for the DVTL-815 PoC (github-poc / env0 fork) — the demoable sample app that
// replaces the nginxdemos/hello placeholder. Its whole job is to make the deploy loop *visible*:
// edit the GREETING below (or anything in the HTML), push to dvtl-815-app, and once GitHub Actions
// builds the new image and commits the SHA into dvtl-815-resources, env0 deploys it and you should
// SEE the change at the app's URL.
//
// Two routes:
//   GET /         -> HTML page showing the greeting, the build version, and the pod hostname.
//   GET /healthz  -> 200 "ok" for the Kubernetes readiness/liveness probes (app.tf).
//
// `version` is injected at build time via -ldflags "-X main.version=<git-sha>" (see Dockerfile /
// .github/workflows/build.yml), so every image built by the workflow reports the exact commit it
// came from — the same immutable-SHA idea that makes the tofu plan diff meaningful.
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// Overridden at build time by -ldflags. "dev" is the local/unbuilt default.
var version = "dev"

// EDIT ME to prove the deploy loop: change this string, push, let env0 deploy, reload the page.
const greeting = "Hello from the DVTL-815 sample app! (env0 fork)"

// newMux builds the app's routing table. Extracted from main() so tests (main_test.go) exercise the
// REAL routes — including the /healthz closure — instead of a duplicate. main() is now just bind+serve.
func newMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("/", rootHandler)
	return mux
}

func main() {
	// Port is 8080 (not 80) so the container can run as a non-root user — a distroless/scratch
	// image has no privileged binder for ports <1024. The Service still fronts on 80 (app.tf).
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	addr := ":" + port
	log.Printf("dvtl-815 sample app version=%s listening on %s", version, addr)
	// http.Server with the mux; log.Fatal surfaces a bind failure loudly.
	log.Fatal(http.ListenAndServe(addr, newMux()))
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	// Only "/" itself serves the page; anything else is a 404 (so the path is unambiguous in demos).
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	host, _ := os.Hostname() // pod name in-cluster; harmless if it errors (empty string).

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, `<!doctype html>
<html><head><title>DVTL-815 sample app</title></head>
<body style="font-family: system-ui, sans-serif; max-width: 40rem; margin: 4rem auto;">
  <h1>%s</h1>
  <p>Build version: <code>%s</code></p>
  <p>Served by pod: <code>%s</code></p>
  <p style="color:#666">Change the greeting in <code>src/main.go</code>, push — GitHub Actions builds it and env0 deploys it, and this page updates.</p>
</body></html>
`, greeting, version, host)
}
