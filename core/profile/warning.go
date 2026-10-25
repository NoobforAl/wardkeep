package profile

import "slices"

// Warning levels. A "risk" warning means the choice weakens privacy or is easy
// for a network to recognise; an "info" warning is a side effect worth knowing.
const (
	WarnRisk = "risk"
	WarnInfo = "info"
)

// Warning tells the user about a weakness of a protocol or an option. Code is
// stable (apps translate by it); Text is the English fallback.
type Warning struct {
	Code  string `json:"code"`
	Level string `json:"level" enum:"risk,info"`
	Text  string `json:"text"`
}

// Warning codes.
const (
	WarnTLSInsecure   = "TLS_INSECURE"
	WarnNoTLS         = "NO_TLS"
	WarnVMessLegacy   = "VMESS_LEGACY"
	WarnSSPlain       = "SS_PLAIN"
	WarnHysteria1     = "HYSTERIA1"
	WarnDPIVisible    = "DPI_VISIBLE"
	WarnSSHVisible    = "SSH_VISIBLE"
	WarnDNSTTSlow     = "DNSTT_SLOW"
	WarnDNSTTOpen     = "DNSTT_OPEN"
	WarnMuxLossy      = "MUX_LOSSY"
	WarnFragmentSide  = "FRAGMENT_SIDE"
	WarnECHServer     = "ECH_SERVER"
	WarnWGChain       = "WG_CHAIN"
	WarnSubUnsigned   = "SUB_UNSIGNED"
	warnTextInsecure  = "The server's certificate is not checked. Anyone on the path can read or change your traffic."
	warnTextNoTLS     = "Traffic is not wrapped in TLS. It is easy to recognise and may be read on the way."
	warnTextVMess     = "VMess is an older protocol and is easy to recognise. VLESS with Reality is a better choice."
	warnTextSSPlain   = "Without a plugin such as shadow-tls the traffic looks like random bytes, and some networks block that pattern."
	warnTextHysteria1 = "Hysteria 1 is deprecated. Use Hysteria 2 when the server supports it."
	warnTextDPI       = "This protocol is easy to identify and is often blocked on strict networks."
	warnTextSSH       = "SSH tunnels are easy to identify."
	warnTextDNSTTSlow = "Slow (usually well under 1 Mbit/s) and TCP only. It sends many DNS queries that the network can see. Use it when nothing else works."
	warnTextDNSTTOpen = "No username or password: anyone with this link can use the server."
	warnTextMux       = "Multiplexing puts many connections on one. A bad link can slow all of them."
	warnTextFragment  = "Fragmenting the handshake helps against some filters, may break on others, and adds delay."
	warnTextECH       = "Needs a server that supports ECH. Otherwise the connection fails."
	warnTextWGChain   = "WireGuard inside a proxy: if the proxy is slow, the tunnel can stall. The proxy must carry UDP."
	warnTextUnsigned  = "This list is not signed, so a changed list cannot be detected."
)

var (
	wInsecure    = Warning{WarnTLSInsecure, WarnRisk, warnTextInsecure}
	wNoTLS       = Warning{WarnNoTLS, WarnRisk, warnTextNoTLS}
	wVMess       = Warning{WarnVMessLegacy, WarnRisk, warnTextVMess}
	wSSPlain     = Warning{WarnSSPlain, WarnRisk, warnTextSSPlain}
	wHysteria1   = Warning{WarnHysteria1, WarnRisk, warnTextHysteria1}
	wDPI         = Warning{WarnDPIVisible, WarnRisk, warnTextDPI}
	wSSH         = Warning{WarnSSHVisible, WarnRisk, warnTextSSH}
	wDNSTTSlow   = Warning{WarnDNSTTSlow, WarnRisk, warnTextDNSTTSlow}
	wDNSTTOpen   = Warning{WarnDNSTTOpen, WarnRisk, warnTextDNSTTOpen}
	wMux         = Warning{WarnMuxLossy, WarnInfo, warnTextMux}
	wFragment    = Warning{WarnFragmentSide, WarnInfo, warnTextFragment}
	wECH         = Warning{WarnECHServer, WarnRisk, warnTextECH}
	wWGChain     = Warning{WarnWGChain, WarnInfo, warnTextWGChain}
	wUnsignedSub = Warning{WarnSubUnsigned, WarnInfo, warnTextUnsigned}
)

// SubscriptionUnsigned is the note shown for a subscription with no signing key.
func SubscriptionUnsigned() Warning { return wUnsignedSub }

// WarningsForProtocol lists what is true of a protocol whatever its settings
// are. The editor shows these above the fields.
func WarningsForProtocol(protocol string) []Warning {
	switch protocol {
	case VMess:
		return []Warning{wVMess}
	case Shadowsocks:
		return []Warning{wSSPlain}
	case Hysteria:
		return []Warning{wHysteria1}
	case WireGuard, OpenVPN, IKEv2, SSTP:
		return []Warning{wDPI}
	case SSH:
		return []Warning{wSSH}
	}
	return nil
}

// WarningsFor lists the warnings of a saved profile: the protocol's own plus
// the ones its settings cause. Later settings (multiplexing, fragmenting, ECH,
// a proxy under WireGuard, a DNS tunnel) add theirs in warningsFromOptions.
func WarningsFor(p *Profile) []Warning {
	if p == nil {
		return nil
	}
	out := slices.Clone(WarningsForProtocol(p.Protocol))
	if p.Protocol == Shadowsocks && p.Plugin != "" {
		out = slices.DeleteFunc(out, func(w Warning) bool { return w.Code == WarnSSPlain })
	}
	add := func(w Warning) {
		if !slices.ContainsFunc(out, func(o Warning) bool { return o.Code == w.Code }) {
			out = append(out, w)
		}
	}
	switch p.Protocol {
	case VLESS, VMess, Trojan:
		if p.TLS == nil || !p.TLS.Enabled {
			add(wNoTLS)
		}
	}
	if p.TLS != nil && p.TLS.Insecure && p.Protocol != SSTP {
		add(wInsecure)
	}
	warningsFromOptions(p, add)
	return out
}

// warningsFromOptions is where the optional settings report themselves.
func warningsFromOptions(p *Profile, add func(Warning)) {}
