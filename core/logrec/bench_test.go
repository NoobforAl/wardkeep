package logrec

import (
	"strings"
	"testing"
)

// Lines like the ones Scrub gets: every sing-box and Tor record passes through it.
var scrubLines = map[string]string{
	"connection": "outbound/vless[p_1]: open connection to example.com:443 using outbound/vless[p_1]: dial tcp 192.0.2.1:443: i/o timeout",
	"network":    "network: updated network environment: gateway [192.168.1.1 fe80::4c9b:55ff:fe21:3a7a fe80::e03a:2e61:6427:2a14], gateway_mac [30:a2:20:63:fc:32 30:a2:20:63:fc:32]",
	"plain":      "router: updated rule set geosite-private with 12 rules in 3ms",
	"long":       strings.Repeat("read tcp 10.0.0.2:50122->203.0.113.7:443: wsarecv: connection reset by peer; ", 20),
}

func BenchmarkScrub(b *testing.B) {
	for name, line := range scrubLines {
		b.Run(name, func(b *testing.B) {
			b.ReportAllocs()
			b.SetBytes(int64(len(line)))
			for b.Loop() {
				_ = Scrub(line)
			}
		})
	}
}
