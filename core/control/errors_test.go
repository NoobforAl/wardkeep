package control

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"testing"

	"github.com/NoobforAl/wardkeep/core/engine"
	"github.com/NoobforAl/wardkeep/core/importer"
	"github.com/NoobforAl/wardkeep/core/profile"
	"github.com/NoobforAl/wardkeep/core/subscription"
)

func TestEditorProblemsKeepTheirCodeAndArguments(t *testing.T) {
	_, err := profile.FromValues("trojan", map[string]string{"server": "example.com"})
	e := badRequest(err)
	if e.Code != profile.FormRequired || e.Args["label"] == "" || e.Message == "" {
		t.Fatalf("missing field: %+v", e)
	}
	_, err = profile.FromValues("trojan", map[string]string{"server": "example.com", "port": "abc", "password": "x"})
	if e := badRequest(err); e.Code != profile.FormNotNumber || e.Args["label"] != "Port" {
		t.Fatalf("bad number: %+v", e)
	}
	// Anything else stays a plain bad request.
	if e := badRequest(errors.New("something else")); e.Code != CodeBadRequest || e.Args != nil {
		t.Fatalf("other: %+v", e)
	}
	if e := badRequest(fmt.Errorf("wrapped: %w", err)); e.Code != profile.FormNotNumber {
		t.Fatalf("a wrapped editor problem lost its code: %+v", e)
	}
}

func TestImportFailuresHaveCodes(t *testing.T) {
	cases := []struct {
		text, code, scheme string
	}{
		{"   ", CodeImportUnsupported, ""},
		{"hello world", CodeImportNothing, ""},
		{"nope://example.com", CodeImportNothing, ""},
		{"vless://not-valid", CodeImportNothing, ""},
		{`{"inbounds":[{"port":443,"protocol":"vless","settings":{"clients":[{"id":"x"}]}}],"outbounds":[]}`, CodeImportXrayServer, ""},
	}
	for _, c := range cases {
		_, err := importer.Import(c.text)
		if err == nil {
			t.Errorf("%q imported", c.text)
			continue
		}
		e := importError(err)
		if e.Code != c.code || e.Args["scheme"] != c.scheme {
			t.Errorf("%q: %+v (%v)", c.text, e, err)
		}
	}
}

func TestJSONImportFailuresSayWhereAndWhat(t *testing.T) {
	for _, c := range []struct {
		name, text, code string
		args             map[string]string
	}{
		{"syntax", "{\n  \"outbounds\": [\n    {\"type\": \"vless\" x}\n  ]\n}", CodeImportJSONSyntax,
			map[string]string{"line": "3", "column": "22", "found": "'x'"}},
		{"cut off", `{"outbounds": [`, CodeImportJSONEnd, map[string]string{"line": "1", "column": "16"}},
		{"no server", `{"outbounds":[{"protocol":"freedom"}]}`, CodeImportJSONNoServer, map[string]string{"found": "outbounds: freedom"}},
		{"empty list", `[]`, CodeImportJSONNoServer, map[string]string{"found": ""}},
		{"too large", strings.Repeat("a", importer.MaxTextSize+1), CodeImportTooLarge, map[string]string{"limit": "8"}},
	} {
		_, err := importer.Import(c.text)
		if err == nil {
			t.Errorf("%s: imported", c.name)
			continue
		}
		e := importError(err)
		if e.Code != c.code {
			t.Errorf("%s: code %s, want %s (%v)", c.name, e.Code, c.code, err)
		}
		for k, v := range c.args {
			if e.Args[k] != v {
				t.Errorf("%s: arg %s = %q, want %q", c.name, k, e.Args[k], v)
			}
		}
	}
}

func TestImportFailureCarriesTheReasons(t *testing.T) {
	// a server that is found but wrong: the reason must reach the UI, not only the fact
	res, err := importer.Import(`{"outbounds": [{"tag": "bad", "protocol": "vless", "settings": {"address": "example.com", "port": 443}}]}`)
	e := importFailure(err, res)
	if e.Code != CodeImportNothing || !strings.Contains(e.Args["details"], "bad") {
		t.Fatalf("%+v (%v)", e, err)
	}
	// and no more than the limit
	many := &importer.Result{}
	for range 25 {
		many.Errors = append(many.Errors, "x")
	}
	if got := strings.Count(importFailure(err, many).Args["details"], "\n") + 1; got != maxImportDetails {
		t.Fatalf("%d reasons, want %d", got, maxImportDetails)
	}
	if e := importFailure(importer.ErrXrayServer, nil); e.Args != nil {
		t.Fatalf("no reasons, but args: %+v", e.Args)
	}
}

func TestUnsupportedLinkNamesItsScheme(t *testing.T) {
	_, err := importer.ParseLink("nope://example.com")
	if e := importError(err); e.Code != CodeImportUnsupported || e.Args["scheme"] != "nope" {
		t.Fatalf("%+v (%v)", e, err)
	}
}

// A failed download names its kind (so the app can translate it) and never carries the link, whose path or
// query holds the user's token.
func TestSubscriptionDownloadFailureHasReasonAndNoLink(t *testing.T) {
	const link = "https://provider.example/sub/SECRET-TOKEN?x=1"
	for _, c := range []struct {
		err    error
		reason string
	}{
		{&url.Error{Op: "Get", URL: link, Err: errors.New("dial tcp 203.0.113.1:443: connect: connection refused")}, engine.ErrRefused},
		{&url.Error{Op: "Get", URL: link, Err: context.DeadlineExceeded}, engine.ErrTimeout},
		{&url.Error{Op: "Get", URL: link, Err: errors.New("dial tcp: lookup provider.example: no such host")}, engine.ErrDNS},
		{&url.Error{Op: "Get", URL: link, Err: errors.New("something nobody has seen")}, ""},
		// A word of the link must not decide the kind of failure: "REALITY" in the query is not a handshake error.
		{&url.Error{Op: "Get", URL: "https://provider.example/sub/SECRET-TOKEN?protocol=REALITY", Err: errors.New("dial tcp 203.0.113.1:443: connect: connection refused")}, engine.ErrRefused},
		// A host whose last label is also a file suffix (.so) is not scrubbed as a host: the request's own is removed.
		{&url.Error{Op: "Get", URL: "https://provider.so/sub/SECRET-TOKEN", Err: errors.New("dial tcp: lookup provider.so: no such host")}, engine.ErrDNS},
		// A redirect whose Location cannot be parsed echoes that path, which is as secret as the link.
		{&url.Error{Op: "Get", URL: link, Err: errors.New(`failed to parse Location header "/sub/SECRET-TOKEN/%zz": parse "/sub/SECRET-TOKEN/%zz": invalid URL escape "%zz"`)}, ""},
	} {
		e := subscriptionError(fmt.Errorf("download subscription: %w", c.err))
		if e.Code != CodeSubscriptionFailed || e.Args["reason"] != c.reason {
			t.Errorf("%v: %+v, want reason %q", c.err, e, c.reason)
		}
		if strings.Contains(e.Message, "SECRET-TOKEN") || strings.Contains(e.Message, "provider.example/sub") {
			t.Errorf("the link is in the message: %q", e.Message)
		}
		// Nor the server's address or the host a lookup failed for, which the library puts in its own words.
		if strings.Contains(e.Message, "203.0.113.1") || strings.Contains(e.Message, "provider.example") || strings.Contains(e.Message, "provider.so") {
			t.Errorf("an address is in the message: %q", e.Message)
		}
	}
}

// The address FetchVia rejects is the user's link, token and all: the code stays, the address does not.
func TestBadSubscriptionURLKeepsItsCodeButNotTheAddress(t *testing.T) {
	err := fmt.Errorf("%w %q", subscription.ErrBadURL, "ftp://provider.example/sub/SECRET-TOKEN")
	e := subscriptionError(err)
	if e.Code != CodeSubBadURL {
		t.Fatalf("code %q", e.Code)
	}
	if strings.Contains(e.Message, "SECRET-TOKEN") || strings.Contains(e.Message, "provider.example") {
		t.Errorf("the address is in the message: %q", e.Message)
	}
}

func TestSubscriptionFailuresHaveCodes(t *testing.T) {
	for _, c := range []struct {
		err    error
		code   string
		status string
	}{
		{fmt.Errorf("%w (HTTP 401)", subscription.ErrAuth), CodeAuthFailed, ""},
		{&subscription.HTTPError{Status: 502}, CodeSubHTTP, "502"},
		{subscription.ErrTooLarge, CodeSubTooLarge, ""},
		{fmt.Errorf("%w %q", subscription.ErrBadURL, "x"), CodeSubBadURL, ""},
		{errors.New("download subscription: dial tcp: refused"), CodeSubscriptionFailed, ""},
	} {
		e := subscriptionError(c.err)
		if e.Code != c.code || e.Args["status"] != c.status {
			t.Errorf("%v: %+v", c.err, e)
		}
	}
}
