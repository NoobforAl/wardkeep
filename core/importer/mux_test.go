package importer

import (
	"testing"

	"github.com/NoobforAl/omnitun/core/profile"
)

func wantMux(t *testing.T, p *profile.Profile, want profile.Mux) {
	t.Helper()
	if p.Multiplex == nil || *p.Multiplex != want {
		t.Fatalf("%s: multiplex = %+v, want %+v", p.Name, p.Multiplex, want)
	}
}

func TestMuxFromLinks(t *testing.T) {
	const uuid = "b831381d-6324-4d53-ad4f-8cda48b30811"
	p, err := ParseLink("trojan://pw@example.com:443?mux=yamux&muxpad=1&muxconn=4&muxmin=8#t")
	if err != nil {
		t.Fatal(err)
	}
	wantMux(t, p, profile.Mux{Protocol: "yamux", Padding: true, MaxConnections: 4, MinStreams: 8})

	p, err = ParseLink("vless://" + uuid + "@example.com:443?security=tls&mux=smux&muxmax=16#v")
	if err != nil {
		t.Fatal(err)
	}
	wantMux(t, p, profile.Mux{Protocol: "smux", MaxStreams: 16})

	p, err = ParseLink("ss://MjAyMi1ibGFrZTMtYWVzLTEyOC1nY206c2VydmVya2V5OnVzZXJrZXk@203.0.113.7:8388?mux=h2mux#s")
	if err != nil {
		t.Fatal(err)
	}
	wantMux(t, p, profile.Mux{Protocol: "h2mux"})

	// What the protocol cannot do is dropped, the server is kept.
	p, err = ParseLink("vless://" + uuid + "@example.com:443?security=reality&flow=xtls-rprx-vision&pbk=k&mux=smux#v")
	if err != nil || p.Multiplex != nil {
		t.Fatalf("a VLESS flow and multiplexing cannot go together; got err=%v multiplex=%+v", err, p.Multiplex)
	}
	p, err = ParseLink("trojan://pw@example.com:443?mux=quic#t")
	if err != nil || p.Multiplex != nil {
		t.Fatalf("an unknown multiplexing protocol should be dropped; got err=%v multiplex=%+v", err, p.Multiplex)
	}
	// The most streams replaces the two counts it cannot be combined with.
	p, err = ParseLink("trojan://pw@example.com:443?mux=smux&muxconn=4&muxmax=8#t")
	if err != nil {
		t.Fatal(err)
	}
	wantMux(t, p, profile.Mux{Protocol: "smux", MaxStreams: 8})
}

func TestMuxFromClash(t *testing.T) {
	res, err := Import(`proxies:
  - {name: a, type: trojan, server: a.example.com, port: 443, password: pw, smux: {enabled: true, protocol: yamux, max-connections: 4, min-streams: 8, padding: true}}
  - {name: b, type: trojan, server: b.example.com, port: 443, password: pw, smux: {enabled: false, protocol: yamux}}
  - {name: c, type: hysteria2, server: c.example.com, port: 443, password: pw, smux: {enabled: true}}
`)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Profiles) != 3 {
		t.Fatalf("got %d profiles, errors %v", len(res.Profiles), res.Errors)
	}
	wantMux(t, res.Profiles[0], profile.Mux{Protocol: "yamux", MaxConnections: 4, MinStreams: 8, Padding: true})
	if res.Profiles[1].Multiplex != nil || res.Profiles[2].Multiplex != nil {
		t.Error("a disabled smux, or one on a protocol that cannot multiplex, should not be kept")
	}
}

func TestMuxFromSingBoxJSON(t *testing.T) {
	res, err := Import(`{"outbounds": [
	  {"type": "trojan", "tag": "a", "server": "a.example.com", "server_port": 443, "password": "pw",
	   "tls": {"enabled": true}, "multiplex": {"enabled": true, "protocol": "h2mux", "max_streams": 8, "padding": true}},
	  {"type": "shadowsocks", "tag": "b", "server": "b.example.com", "server_port": 8388, "method": "aes-128-gcm", "password": "pw",
	   "multiplex": {"enabled": true}}
	]}`)
	if err != nil {
		t.Fatal(err)
	}
	wantMux(t, res.Profiles[0], profile.Mux{Protocol: "h2mux", MaxStreams: 8, Padding: true})
	wantMux(t, res.Profiles[1], profile.Mux{Protocol: "smux"})
}
