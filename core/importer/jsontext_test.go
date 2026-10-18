package importer

import (
	"errors"
	"strings"
	"testing"
)

const (
	vlessOutbound = `{"tag": "one", "protocol": "vless",
     "settings": {"vnext": [{"address": "203.0.113.7", "port": 443,
       "users": [{"id": "b831381d-6324-4d53-ad4f-8cda48b30811", "encryption": "none"}]}]},
     "streamSettings": {"network": "ws", "security": "tls", "tlsSettings": {"serverName": "example.com"},
       "wsSettings": {"path": "/ws"}}}`
	singboxTrojan = `{"type": "trojan", "tag": "tj", "server": "tj.example.com", "server_port": 443, "password": "pw",
     "tls": {"enabled": true, "server_name": "tj.example.com"}}`
)

func TestImportBareOutbound(t *testing.T) {
	for name, text := range map[string]string{"xray": vlessOutbound, "sing-box": singboxTrojan} {
		res, err := Import(text)
		if err != nil || len(res.Profiles) != 1 {
			t.Fatalf("%s: res=%+v err=%v", name, res, err)
		}
	}
	res, _ := Import(vlessOutbound)
	if p := res.Profiles[0]; p.Server != "203.0.113.7" || p.Port != 443 || p.Name != "one" {
		t.Errorf("profile = %+v", p)
	}
}

func TestImportJSONList(t *testing.T) {
	// what v2rayN-style exports look like: an array of whole configs, and outbounds, and links
	text := `[
  {"remarks": "first", "outbounds": [` + vlessOutbound + `]},
  ` + singboxTrojan + `,
  "trojan://pw@t2.example.com:443?sni=t2.example.com#t2"
]`
	res, err := Import(text)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Profiles) != 3 || len(res.Errors) != 0 {
		t.Fatalf("profiles=%d errors=%v", len(res.Profiles), res.Errors)
	}
}

func TestImportJSONListPartial(t *testing.T) {
	text := `[` + vlessOutbound + `, 42, {"hello": "world"}, "not a link"]`
	res, err := Import(text)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Profiles) != 1 || len(res.Errors) != 3 {
		t.Fatalf("profiles=%d errors=%v", len(res.Profiles), res.Errors)
	}
	for _, e := range res.Errors {
		if !strings.HasPrefix(e, "#") {
			t.Errorf("error %q does not say which entry it is", e)
		}
	}
}

func TestImportJSONComments(t *testing.T) {
	text := "// exported from a client\n{\n  /* the proxy */\n  \"outbounds\": [\n    " + vlessOutbound + ", // trailing comma follows\n  ],\n}\n"
	res, err := Import(text)
	if err != nil || len(res.Profiles) != 1 {
		t.Fatalf("res=%+v err=%v", res, err)
	}
	// a comment marker inside a string stays
	res, err = Import(`{"outbounds":[{"tag":"a//b, /* c */","protocol":"vless","settings":{"address":"example.com","port":443,"id":"b831381d-6324-4d53-ad4f-8cda48b30811"}}]}`)
	if err != nil || len(res.Profiles) != 1 || res.Profiles[0].Name != "a//b, /* c */" {
		t.Fatalf("res=%+v err=%v", res, err)
	}
}

func TestImportJSONFenced(t *testing.T) {
	for _, text := range []string{"```json\n" + vlessOutbound + "\n```", "```\n" + singboxTrojan + "\n```\n"} {
		res, err := Import(text)
		if err != nil || len(res.Profiles) != 1 {
			t.Fatalf("%q: res=%+v err=%v", text[:12], res, err)
		}
	}
}

func TestImportJSONSyntaxError(t *testing.T) {
	text := "{\n  \"outbounds\": [\n    {\"protocol\": \"vless\" \"settings\": {}}\n  ]\n}"
	_, err := Import(text)
	var je *JSONError
	if !errors.As(err, &je) {
		t.Fatalf("err = %v, want a *JSONError", err)
	}
	// the second string, which has no comma before it, is the thing that does not belong
	wantCol := strings.Index(strings.Split(text, "\n")[2], `"settings"`) + 1
	if je.Line != 3 || je.Col != wantCol || je.Found != `'"'` {
		t.Errorf("error = %+v, want line 3 column %d found '\"'", je, wantCol)
	}
	if !strings.Contains(je.Error(), "line 3") {
		t.Errorf("message = %q", je.Error())
	}
}

func TestImportJSONSyntaxErrorUnicodeColumn(t *testing.T) {
	// the column counts characters: two Persian letters before the error are two columns, not four
	_, err := Import(`{"a": "سل", x}`)
	var je *JSONError
	if !errors.As(err, &je) || je.Line != 1 || je.Col != 13 || je.Found != "'x'" {
		t.Fatalf("err = %v (%+v)", err, je)
	}
}

func TestImportJSONCutOff(t *testing.T) {
	text := "{\n  \"outbounds\": [\n    {\"protocol\": \"vless\",\n"
	_, err := Import(text)
	var je *JSONError
	if !errors.As(err, &je) || je.Found != "" {
		t.Fatalf("err = %v, want a JSONError for text that ends too early", err)
	}
	if je.Line != 3 {
		t.Errorf("line = %d, want the line of the last thing read (3)", je.Line)
	}
}

func TestImportJSONWithoutServers(t *testing.T) {
	cases := map[string]string{
		`{"outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole"}]}`: "outbounds: blackhole, freedom",
		`{"log": {}, "outbounds": [{"type": "direct"}, {"type": "block"}]}`:   "outbounds: block, direct",
		`{"hello": "world"}`: "",
		`[]`:                 "",
		`{"outbounds": []}`:  "",
		`{"inbounds": [{"protocol": "socks"}], "outbounds": [{"protocol": "freedom"}]}`: "outbounds: freedom; inbounds: socks",
	}
	for text, found := range cases {
		_, err := Import(text)
		var ns *NoServerError
		if !errors.As(err, &ns) {
			t.Errorf("%s: err = %v, want a *NoServerError", text, err)
			continue
		}
		if ns.Found != found {
			t.Errorf("%s: found %q, want %q", text, ns.Found, found)
		}
	}
}

func TestImportJSONBadServerKeepsReasons(t *testing.T) {
	// a vless outbound without a user id: valid JSON, a server that is wrong, and the reason comes with it
	text := `{"outbounds": [{"tag": "bad", "protocol": "vless", "settings": {"address": "example.com", "port": 443}}]}`
	res, err := Import(text)
	if !errors.Is(err, ErrNoProfiles) {
		t.Fatalf("err = %v, want ErrNoProfiles", err)
	}
	if res == nil || len(res.Errors) != 1 || !strings.Contains(res.Errors[0], "bad") {
		t.Fatalf("errors = %+v, want the reason for the bad server", res)
	}
}

func TestImportXrayServerConfigStillRefused(t *testing.T) {
	_, err := Import(`{"inbounds": [{"protocol": "vless", "port": 443, "settings": {"clients": []}}]}`)
	if !errors.Is(err, ErrXrayServer) {
		t.Fatalf("err = %v, want ErrXrayServer", err)
	}
}

func TestImportTooLarge(t *testing.T) {
	_, err := Import(strings.Repeat("a", MaxTextSize+1))
	if !errors.Is(err, ErrTooLarge) {
		t.Fatalf("err = %v, want ErrTooLarge", err)
	}
}

func TestRelaxJSONKeepsPositions(t *testing.T) {
	in := "{\"a\": 1, // note\n \"b\": [1, 2, /* x\n y */ ],\n}"
	out := relaxJSON(in)
	if len(out) != len(in) || strings.Count(out, "\n") != strings.Count(in, "\n") {
		t.Fatalf("relaxJSON changed the layout: %q", out)
	}
	if err := jsonSyntax(out); err != nil {
		t.Fatalf("%v: %q", err, out)
	}
}
