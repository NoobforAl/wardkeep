package engine

import (
	"errors"
	"testing"
)

// A failure of one Tor stream is tried again; Tor being gone is not.
func TestTorStreamFailed(t *testing.T) {
	for text, want := range map[string]bool{
		"socks5: request rejected, code=1":                       true,
		"socks5: request rejected, TTL expired":                  true,
		"context deadline exceeded":                              true,
		"read tcp 127.0.0.1:5->127.0.0.1:6: i/o timeout":         true,
		"dial tcp 127.0.0.1:9050: connectex: connection refused": false,
		"profile p_1 is not running":                             false,
		"unexpected HTTP response status: 403 Forbidden":         false,
	} {
		if got := torStreamFailed(errors.New(text)); got != want {
			t.Errorf("torStreamFailed(%q) = %v, want %v", text, got, want)
		}
	}
}
