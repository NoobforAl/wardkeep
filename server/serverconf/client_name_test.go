package serverconf

import (
	"net/http/httptest"
	"testing"
)

// A client gets the sing-box configuration when it says it is this app, under its present name or the
// one older versions of the app still send, or one of the other sing-box clients.
func TestWantsSingBoxRecognisesTheAppUnderBothNames(t *testing.T) {
	for ua, want := range map[string]bool{
		"Wardkeep/0.1 v2rayN/7.0": true,
		"wardkeep/0.2":            true,
		"Omnitun/0.1 v2rayN/7.0":  true, // versions before the rename
		"sing-box 1.14.3":         true,
		"SFA/1.0":                 true,
		"v2rayN/7.0":              false,
		"Mozilla/5.0":             false,
	} {
		r := httptest.NewRequest("GET", "/sub", nil)
		r.Header.Set("User-Agent", ua)
		if got := wantsSingBox(r); got != want {
			t.Errorf("User-Agent %q: got %v, want %v", ua, got, want)
		}
	}
	r := httptest.NewRequest("GET", "/sub?format=links", nil)
	r.Header.Set("User-Agent", "Wardkeep/0.1")
	if wantsSingBox(r) {
		t.Error("an explicit format=links must win over the User-Agent")
	}
}
