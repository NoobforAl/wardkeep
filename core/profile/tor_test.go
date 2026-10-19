package profile

import (
	"strings"
	"testing"
)

const testBridgeFingerprint = "0123456789ABCDEF0123456789ABCDEF01234567"

func TestTorBridgesAreChecked(t *testing.T) {
	for name, tc := range map[string]struct {
		opts TorOpts
		want string // a part of the error; empty for none
	}{
		"direct":               {TorOpts{}, ""},
		"built-in snowflake":   {TorOpts{Builtin: "snowflake"}, ""},
		"built-in meek":        {TorOpts{Builtin: "meek"}, ""},
		"unknown built-in":     {TorOpts{Builtin: "conjure"}, "unknown built-in bridge kind"},
		"obfs4 with print":     {TorOpts{Bridges: []string{"obfs4 192.0.2.5:443 " + testBridgeFingerprint + " cert=x iat-mode=0"}}, ""},
		"torrc prefix":         {TorOpts{Bridges: []string{"Bridge obfs4 192.0.2.5:443 " + testBridgeFingerprint + " cert=x"}}, ""},
		"lower case print":     {TorOpts{Bridges: []string{"obfs4 192.0.2.5:443 " + strings.ToLower(testBridgeFingerprint) + " cert=x"}}, ""},
		"no fingerprint":       {TorOpts{Bridges: []string{"obfs4 192.0.2.5:443 cert=x iat-mode=0"}}, "bridge line 1 has no relay fingerprint"},
		"second line is wrong": {TorOpts{Bridges: []string{"obfs4 192.0.2.5:443 " + testBridgeFingerprint, "obfs4 192.0.2.6:443"}}, "bridge line 2"},
		"short fingerprint":    {TorOpts{Bridges: []string{"obfs4 192.0.2.5:443 0123456789ABCDEF cert=x"}}, "no relay fingerprint"},
		"empty line":           {TorOpts{Bridges: []string{"  "}}, "bridge line 1 is empty"},
	} {
		t.Run(name, func(t *testing.T) {
			opts := tc.opts
			err := (&Profile{Name: "Tor", Protocol: Tor, Tor: &opts}).Validate()
			switch {
			case tc.want == "" && err != nil:
				t.Fatalf("unexpected error: %v", err)
			case tc.want != "" && (err == nil || !strings.Contains(err.Error(), tc.want)):
				t.Fatalf("error = %v, want one containing %q", err, tc.want)
			}
		})
	}
}
