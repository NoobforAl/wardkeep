package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/manager"
	"github.com/NoobforAl/omnitun/server/store"
)

// tempDir is t.TempDir with a cleanup that retries: on Windows a virus
// scanner or a just-released file lock can briefly keep a file open, which
// fails t.TempDir's own cleanup.
func tempDir(t *testing.T) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "omnitun-test-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		for i := 0; i < 40 && os.RemoveAll(dir) != nil; i++ {
			time.Sleep(50 * time.Millisecond)
		}
	})
	return dir
}

const token = "test-token"

type client struct {
	t      *testing.T
	srv    *httptest.Server
	reload int
}

func newClient(t *testing.T) *client {
	t.Helper()
	m := manager.New(store.Open(tempDir(t)))
	if _, err := m.Init(manager.InitOptions{PublicHost: "203.0.113.7"}); err != nil {
		t.Fatal(err)
	}
	c := &client{t: t}
	c.srv = httptest.NewServer(New(Options{Manager: m, Token: func() string { return token }, Reload: func() error { c.reload++; return nil }}))
	t.Cleanup(c.srv.Close)
	return c
}

// do sends a request with the token and returns the status and body.
func (c *client) do(method, path string, body any, auth string) (int, []byte) {
	c.t.Helper()
	var r *bytes.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		r = bytes.NewReader(b)
	} else {
		r = bytes.NewReader(nil)
	}
	req, _ := http.NewRequest(method, c.srv.URL+path, r)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		c.t.Fatal(err)
	}
	defer resp.Body.Close()
	var buf bytes.Buffer
	buf.ReadFrom(resp.Body)
	return resp.StatusCode, buf.Bytes()
}

func (c *client) ok(method, path string, body any, want int) []byte {
	c.t.Helper()
	status, b := c.do(method, path, body, "Bearer "+token)
	if status != want {
		c.t.Fatalf("%s %s = %d, want %d: %s", method, path, status, want, b)
	}
	return b
}

func TestAuth(t *testing.T) {
	c := newClient(t)
	if status, _ := c.do("GET", "/health", nil, ""); status != 200 {
		t.Fatalf("health without token = %d", status)
	}
	for _, auth := range []string{"", "Bearer wrong", "Basic " + token, token} {
		if status, _ := c.do("GET", "/api/v1/users", nil, auth); status != 401 {
			t.Errorf("auth %q = %d, want 401", auth, status)
		}
	}
	c.ok("GET", "/api/v1/users", nil, 200)
}

func TestUserLifecycle(t *testing.T) {
	c := newClient(t)

	var u manager.UserInfo
	json.Unmarshal(c.ok("POST", "/api/v1/users", map[string]any{"name": "alice", "days": 10, "quota_gb": 5}, 201), &u)
	if u.Name != "alice" || u.Status != "active" || u.ExpiresAt == nil || u.QuotaGB != 5 {
		t.Fatalf("created = %+v", u)
	}
	if status, _ := c.do("POST", "/api/v1/users", map[string]any{"name": "alice"}, "Bearer "+token); status != 409 {
		t.Errorf("duplicate = %d, want 409", status)
	}
	if status, _ := c.do("POST", "/api/v1/users", map[string]any{"name": "bad name!"}, "Bearer "+token); status != 422 {
		t.Errorf("invalid name = %d, want 422", status)
	}

	u = manager.UserInfo{} // the JSON omits expires_at once it is cleared
	json.Unmarshal(c.ok("PATCH", "/api/v1/users/alice", map[string]any{"enabled": false, "expire_days": 0, "note": "paused"}, 200), &u)
	if u.Status != "disabled" || u.ExpiresAt != nil || u.Note != "paused" {
		t.Fatalf("patched = %+v", u)
	}

	var links manager.LinkSet
	json.Unmarshal(c.ok("GET", "/api/v1/users/alice/links", nil, 200), &links)
	if links.User != "alice" || len(links.Links) == 0 || !strings.HasPrefix(links.Subscription, "http://203.0.113.7:") {
		t.Fatalf("links = %+v", links)
	}
	old := links.Subscription
	c.ok("POST", "/api/v1/users/alice/reset", nil, 200)
	json.Unmarshal(c.ok("GET", "/api/v1/users/alice/links", nil, 200), &links)
	if links.Subscription == old {
		t.Error("reset kept the old subscription URL")
	}

	if ovpn := string(c.ok("GET", "/api/v1/users/alice/ovpn/udp", nil, 200)); !strings.Contains(ovpn, "remote 203.0.113.7") {
		t.Errorf("ovpn = %q", ovpn)
	}

	c.ok("POST", "/api/v1/users/alice/usage/reset", nil, 200)
	if status, _ := c.do("POST", "/api/v1/users/ghost/usage/reset", nil, "Bearer "+token); status != 404 {
		t.Errorf("usage reset of a missing user = %d, want 404", status)
	}

	var list []manager.UserInfo
	json.Unmarshal(c.ok("GET", "/api/v1/users", nil, 200), &list)
	if len(list) != 1 {
		t.Fatalf("list = %v", list)
	}
	c.ok("DELETE", "/api/v1/users/alice", nil, 204)
	if status, _ := c.do("GET", "/api/v1/users/alice", nil, "Bearer "+token); status != 404 {
		t.Errorf("deleted user = %d, want 404", status)
	}
}

func TestProtocolsAndServer(t *testing.T) {
	c := newClient(t)
	var protos []manager.ProtocolInfo
	json.Unmarshal(c.ok("GET", "/api/v1/protocols", nil, 200), &protos)
	if len(protos) != len(store.AllProtocols) {
		t.Fatalf("protocols = %d", len(protos))
	}
	if protos[0].Key != "vless-reality" || protos[0].Name != "VLESS + Reality" || protos[0].Description == "" || protos[0].DefaultPort != 443 || !protos[0].ShareLink {
		t.Fatalf("protocol metadata missing: %+v", protos[0])
	}
	var p manager.ProtocolInfo
	json.Unmarshal(c.ok("PATCH", "/api/v1/protocols/trojan", map[string]any{"enabled": false, "port": 9443}, 200), &p)
	if p.Enabled || p.Port != 9443 {
		t.Fatalf("patched = %+v", p)
	}
	if status, _ := c.do("PATCH", "/api/v1/protocols/nope", map[string]any{"enabled": true}, "Bearer "+token); status != 404 {
		t.Errorf("unknown protocol = %d, want 404", status)
	}
	if status, _ := c.do("PATCH", "/api/v1/protocols/trojan", map[string]any{"port": 70000}, "Bearer "+token); status != 422 {
		t.Errorf("bad port = %d, want 422", status)
	}
	var info manager.ServerInfo
	json.Unmarshal(c.ok("GET", "/api/v1/server", nil, 200), &info)
	if info.PublicHost != "203.0.113.7" || info.Protocols != len(store.DefaultEnabled())-1 {
		t.Fatalf("server = %+v", info)
	}
}

func TestImportXray(t *testing.T) {
	c := newClient(t)
	cfg := `{"inbounds":[{"port":443,"protocol":"vless","settings":{"clients":[{"id":"11111111-1111-4111-8111-111111111111","email":"erin@x.org"}]}}]}`
	var res manager.ImportXrayResult
	json.Unmarshal(c.ok("POST", "/api/v1/import/xray", map[string]any{"config": cfg}, 200), &res)
	if len(res.UsersAdded) != 1 || res.UsersAdded[0] != "erin" {
		t.Fatalf("result = %+v", res)
	}
	if status, _ := c.do("POST", "/api/v1/import/xray", map[string]any{"config": "not json at all"}, "Bearer "+token); status != 422 {
		t.Errorf("garbage config = %d, want 422", status)
	}
	if status, _ := c.do("POST", "/api/v1/import/xray", map[string]any{"config": cfg}, ""); status != 401 {
		t.Errorf("without a token = %d, want 401", status)
	}
}

func TestBackupDownload(t *testing.T) {
	c := newClient(t)
	if status, _ := c.do("GET", "/api/v1/backup", nil, ""); status != 401 {
		t.Fatalf("backup without a token = %d", status)
	}
	data := c.ok("GET", "/api/v1/backup", nil, 200)
	dst := manager.New(store.Open(tempDir(t)))
	if err := dst.Restore(bytes.NewReader(data), false); err != nil {
		t.Fatalf("the downloaded backup does not restore: %v", err)
	}
	if info, err := dst.Server(); err != nil || info.PublicHost != "203.0.113.7" {
		t.Fatalf("restored server = %+v err = %v", info, err)
	}
}

func TestReloadAndDocs(t *testing.T) {
	c := newClient(t)
	c.ok("POST", "/api/v1/reload", nil, 204)
	if c.reload != 1 {
		t.Fatalf("reload called %d times", c.reload)
	}
	spec := string(c.ok("GET", "/openapi.json", nil, 200)) // public: describes the API only
	for _, want := range []string{"/api/v1/users/{name}", "list-users", `"bearer"`} {
		if !strings.Contains(spec, want) {
			t.Errorf("openapi.json lacks %s", want)
		}
	}
}

// A rotated or removed token must stop working on a running server at once.
func TestTokenIsReadPerRequest(t *testing.T) {
	m := manager.New(store.Open(tempDir(t)))
	if _, err := m.Init(manager.InitOptions{PublicHost: "203.0.113.7"}); err != nil {
		t.Fatal(err)
	}
	current := "first"
	srv := httptest.NewServer(New(Options{Manager: m, Token: func() string { return current }}))
	defer srv.Close()
	get := func(tok string) int {
		req, _ := http.NewRequest("GET", srv.URL+"/api/v1/server", nil)
		req.Header.Set("Authorization", "Bearer "+tok)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		return resp.StatusCode
	}
	if get("first") != 200 {
		t.Fatal("current token rejected")
	}
	current = "second"
	if get("first") != 401 || get("second") != 200 {
		t.Fatal("rotating the token did not revoke the old one")
	}
	current = ""
	if get("second") != 401 || get("") != 401 {
		t.Fatal("an empty token (API disabled) accepted a request")
	}
}

func TestLogsEndpoint(t *testing.T) {
	m := manager.New(store.Open(tempDir(t)))
	if _, err := m.Init(manager.InitOptions{PublicHost: "203.0.113.7"}); err != nil {
		t.Fatal(err)
	}
	lg := logs.Open(m.Store.Dir)
	for i := range 5 {
		lg.Write("info", "line "+string(rune('a'+i)))
	}
	lg.Close()
	srv := httptest.NewServer(New(Options{Manager: m, Token: func() string { return token }}))
	defer srv.Close()
	c := &client{t: t, srv: srv}

	// The older form: lines answers text lines.
	var lines []string
	json.Unmarshal(c.ok("GET", "/api/v1/logs?lines=3", nil, 200), &lines)
	if len(lines) != 3 || !strings.HasSuffix(lines[2], "line e") || !strings.HasSuffix(lines[0], "line c") {
		t.Fatalf("lines = %q", lines)
	}
	if status, _ := c.do("GET", "/api/v1/logs?lines=0", nil, "Bearer "+token); status != 422 {
		t.Errorf("lines=0 -> %d, want 422", status)
	}
	if status, _ := c.do("GET", "/api/v1/logs", nil, ""); status != 401 {
		t.Errorf("without a token -> %d, want 401", status)
	}

	// Records, filtered.
	lg = logs.Open(m.Store.Dir)
	lg.SetLevel(logs.LevelTrace)
	lg.Log(logs.LevelError, logs.Record{Msg: "trojan did not start", Target: "trojan", Code: "START_FAILED", Err: "busy"})
	lg.Close()
	var records []logs.Record
	json.Unmarshal(c.ok("GET", "/api/v1/logs", nil, 200), &records)
	if len(records) != 6 || records[0].Msg != "line a" || records[5].Code != "START_FAILED" || records[5].Level != "error" {
		t.Fatalf("records = %+v", records)
	}
	records = nil
	json.Unmarshal(c.ok("GET", "/api/v1/logs?level=warn&limit=10", nil, 200), &records)
	if len(records) != 1 || records[0].Target != "trojan" || records[0].Err != "busy" || records[0].Source != "server" {
		t.Fatalf("errors = %+v", records)
	}
	records = nil
	json.Unmarshal(c.ok("GET", "/api/v1/logs?limit=2", nil, 200), &records)
	if len(records) != 2 || records[1].Code != "START_FAILED" {
		t.Fatalf("limit = %+v", records)
	}
	since := url.QueryEscape(time.Now().Add(time.Hour).Format(time.RFC3339))
	if body := c.ok("GET", "/api/v1/logs?since="+since, nil, 200); strings.TrimSpace(string(body)) != "[]" {
		t.Fatalf("since = %s", body)
	}
	for _, bad := range []string{"level=loud", "limit=0", "limit=5001", "since=yesterday"} {
		if status, _ := c.do("GET", "/api/v1/logs?"+bad, nil, "Bearer "+token); status != 422 {
			t.Errorf("%s -> %d, want 422", bad, status)
		}
	}
}

func TestAlertsEndpoints(t *testing.T) {
	m := manager.New(store.Open(tempDir(t)))
	if _, err := m.Init(manager.InitOptions{PublicHost: "203.0.113.7"}); err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(New(Options{Manager: m, Token: func() string { return token }}))
	defer srv.Close()
	c := &client{t: t, srv: srv}

	var list AlertList
	json.Unmarshal(c.ok("GET", "/api/v1/alerts", nil, 200), &list)
	if list.Unacknowledged != 0 || list.Alerts == nil || len(list.Alerts) != 0 {
		t.Fatalf("empty = %+v", list)
	}
	lg := logs.Open(m.Store.Dir)
	lg.SetAlerts(logs.OpenAlerts(m.Store.Dir))
	lg.Log(logs.LevelError, logs.Record{Msg: "dnstt stopped", Target: "dnstt", Code: "STOPPED", Notify: true})
	lg.Log(logs.LevelError, logs.Record{Msg: "nat failed", Target: "nat", Code: "NAT_FAILED", Notify: true})
	lg.Close()
	json.Unmarshal(c.ok("GET", "/api/v1/alerts", nil, 200), &list)
	if list.Unacknowledged != 2 || len(list.Alerts) != 2 || list.Alerts[0].Target != "nat" {
		t.Fatalf("alerts = %+v", list)
	}

	var result AckResult
	json.Unmarshal(c.ok("POST", "/api/v1/alerts/ack", map[string]any{"ids": []string{list.Alerts[1].ID}}, 200), &result)
	if result.Acknowledged != 1 || result.Unacknowledged != 1 {
		t.Fatalf("ack one = %+v", result)
	}
	json.Unmarshal(c.ok("POST", "/api/v1/alerts/ack", map[string]any{"all": true}, 200), &result)
	if result.Acknowledged != 1 || result.Unacknowledged != 0 {
		t.Fatalf("ack all = %+v", result)
	}
	if status, _ := c.do("POST", "/api/v1/alerts/ack", map[string]any{}, "Bearer "+token); status != 422 {
		t.Errorf("an empty ack -> %d, want 422", status)
	}
	for _, path := range []string{"/api/v1/alerts", "/api/v1/logging"} {
		if status, _ := c.do("GET", path, nil, ""); status != 401 {
			t.Errorf("%s without a token -> %d", path, status)
		}
	}
	if status, _ := c.do("POST", "/api/v1/alerts/ack", map[string]any{"all": true}, ""); status != 401 {
		t.Errorf("ack without a token -> %d", status)
	}

	// The log settings.
	var info manager.LoggingInfo
	json.Unmarshal(c.ok("PATCH", "/api/v1/logging", map[string]any{"level": "warn", "alerts": false}, 200), &info)
	if info.Level != "warn" || info.Alerts {
		t.Fatalf("logging = %+v", info)
	}
	if status, _ := c.do("PATCH", "/api/v1/logging", map[string]any{"level": "loud"}, "Bearer "+token); status != 422 {
		t.Errorf("a bad level -> %d", status)
	}
}

// A handler that panics answers 500 and leaves a fatal record and an alert.
func TestPanicIsLogged(t *testing.T) {
	m := manager.New(store.Open(tempDir(t)))
	if _, err := m.Init(manager.InitOptions{PublicHost: "203.0.113.7"}); err != nil {
		t.Fatal(err)
	}
	lg := logs.Open(m.Store.Dir)
	lg.SetAlerts(logs.OpenAlerts(m.Store.Dir))
	defer lg.Close()
	handler := New(Options{Manager: m, Token: func() string { panic("token store broke") }, Log: lg})
	srv := httptest.NewServer(handler)
	defer srv.Close()
	c := &client{t: t, srv: srv}
	if status, _ := c.do("GET", "/api/v1/server", nil, "Bearer x"); status != 500 {
		t.Fatalf("status %d", status)
	}
	records, _ := logs.Query(m.Store.Dir, logs.Filter{Level: logs.LevelFatal, Limit: 1})
	if len(records) != 1 || !records[0].Notify || records[0].Target != "api" || !strings.Contains(records[0].Err, "token store broke") {
		t.Fatalf("records = %+v", records)
	}
	if alerts, _ := m.Alerts(); len(alerts) != 1 {
		t.Fatalf("alerts = %+v", alerts)
	}
}

// The OpenAPI document describes the log and alert endpoints.
func TestOpenAPIDescribesLogsAndAlerts(t *testing.T) {
	c := newClient(t)
	_, raw := c.do("GET", "/openapi.json", nil, "")
	var doc struct {
		Paths map[string]map[string]struct {
			Parameters []struct {
				Name string `json:"name"`
			} `json:"parameters"`
			Responses map[string]struct {
				Content map[string]struct {
					Schema map[string]any `json:"schema"`
				} `json:"content"`
			} `json:"responses"`
		} `json:"paths"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		t.Fatal(err)
	}
	getLogs := doc.Paths["/api/v1/logs"]["get"]
	var params []string
	for _, p := range getLogs.Parameters {
		params = append(params, p.Name)
	}
	if strings.Join(params, ",") != "level,since,limit,lines" {
		t.Errorf("logs parameters = %q", params)
	}
	if _, ok := getLogs.Responses["200"].Content["application/json"].Schema["oneOf"]; !ok {
		t.Errorf("logs response = %+v", getLogs.Responses["200"])
	}
	for path, method := range map[string]string{"/api/v1/alerts": "get", "/api/v1/alerts/ack": "post", "/api/v1/logging": "patch"} {
		if _, ok := doc.Paths[path][method]; !ok {
			t.Errorf("%s %s is not described", method, path)
		}
	}
}
