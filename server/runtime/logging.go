package runtime

import (
	"fmt"
	"log"
	"regexp"
	"strings"
	"time"

	sblog "github.com/sagernet/sing-box/log"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/serverconf"
	"github.com/NoobforAl/omnitun/server/tlsfiles"
)

// sbLog is the platform log writer sing-box needs before it creates its
// traffic manager; it also turns sing-box's messages into records in
// server.log. sing-box hands it every message, whatever its own level, so
// the log's level is checked first.
type sbLog struct{ log *logs.Log }

// singBoxLevel maps sing-box's levels to the records'. sing-box's info
// messages are one per connection and name the client's address, so they
// are debug records (client addresses only appear at debug).
func singBoxLevel(level sblog.Level) logs.Level {
	switch level {
	case sblog.LevelPanic, sblog.LevelFatal:
		return logs.LevelFatal
	case sblog.LevelError:
		return logs.LevelError
	case sblog.LevelWarn:
		return logs.LevelWarn
	case sblog.LevelInfo, sblog.LevelDebug:
		return logs.LevelDebug
	}
	return logs.LevelTrace
}

func (w sbLog) WriteMessage(level sblog.Level, message string) {
	ours := singBoxLevel(level)
	if !w.log.Enabled(ours) {
		return
	}
	rec := parseSingBox(message)
	if ours < logs.LevelWarn && strings.HasPrefix(rec.Target, "dns") {
		return // the names users look up
	}
	if ours >= logs.LevelWarn {
		rec.Msg = logs.Scrub(rec.Msg)
	} else {
		rec.Msg = logs.HideDestinations(rec.Msg)
	}
	switch {
	case ours == logs.LevelFatal:
		rec.Code, rec.Notify = "SINGBOX_FATAL", true
	case ours == logs.LevelError && acmeMessage(rec):
		// certmagic retries on its own; it is told when it gives up.
		rec.Op, rec.Code = "acme", "ACME_FAILED"
		lower := strings.ToLower(rec.Msg)
		rec.Notify = strings.Contains(lower, "giving up") || strings.Contains(lower, "final attempt") || strings.Contains(lower, "unable to")
	}
	w.log.Log(ours, rec)
}

var (
	ansiCodes = regexp.MustCompile(`\x1b\[[0-9;]*[A-Za-z]`)
	// levelPrefix is sing-box's "INFO[0012] " (or "INFO ").
	levelPrefix = regexp.MustCompile(`^[A-Z]+(\[\d+\])? `)
	// connPrefix is the connection id and age: "[3912418562 15ms] ".
	connPrefix = regexp.MustCompile(`^\[(\d+) [^\]]*\] `)
	// userPrefix is the user an inbound names: "[alice] ".
	userPrefix = regexp.MustCompile(`^\[([^\]\s]+)\] `)
)

// parseSingBox splits sing-box's formatted message into a record:
// "INFO[0012] [3912 15ms] inbound/vless[vless]: [alice] inbound connection from …"
// becomes conn 3912, target inbound/vless[vless], user alice and the rest as msg.
func parseSingBox(message string) logs.Record {
	if strings.IndexByte(message, 0x1b) >= 0 {
		message = ansiCodes.ReplaceAllString(message, "")
	}
	rec := logs.Record{Source: logs.SourceSingBox}
	if match := levelPrefix.FindString(message); match != "" {
		message = message[len(match):]
	}
	if match := connPrefix.FindStringSubmatch(message); match != nil {
		rec.Conn, message = match[1], message[len(match[0]):]
	}
	if tag, rest, ok := strings.Cut(message, ": "); ok && tag != "" && !strings.ContainsAny(tag, " \t") {
		rec.Target, message = tag, rest
	}
	if match := userPrefix.FindStringSubmatch(message); match != nil {
		rec.User, message = match[1], message[len(match[0]):]
	}
	rec.Msg = strings.TrimSpace(message)
	return rec
}

// acmeMessage reports whether a sing-box record is about getting or renewing the ACME certificate.
func acmeMessage(rec logs.Record) bool {
	if strings.Contains(rec.Target, serverconf.ACMETag) {
		return true
	}
	lower := strings.ToLower(rec.Msg)
	return strings.Contains(lower, "certificate") && (strings.Contains(lower, "obtain") || strings.Contains(lower, "renew") || strings.Contains(lower, "acme"))
}

// httpErrorLog turns net/http's own messages (TLS handshake errors, panics
// it recovered) into warn records; they name client addresses, so the text is scrubbed.
func (s *Server) httpErrorLog(target string) *log.Logger {
	return log.New(lineFunc(func(line string) {
		if s.log.Enabled(logs.LevelWarn) {
			s.log.Log(logs.LevelWarn, logs.Record{Target: target, Msg: logs.Scrub(strings.TrimSpace(line))})
		}
	}), "", 0)
}

// hostLogf receives the host protocols' own error messages (AmneziaWG,
// DNSCrypt): warn records, scrubbed of addresses.
func (s *Server) hostLogf(format string, args ...any) {
	if s.log.Enabled(logs.LevelWarn) {
		s.log.Log(logs.LevelWarn, logs.Record{Msg: logs.Scrub(fmt.Sprintf(format, args...))})
	}
}

// dnsttLogf receives the DNS tunnel's messages: one or more per session, so debug records.
func (s *Server) dnsttLogf(format string, args ...any) {
	if s.log.Enabled(logs.LevelDebug) {
		s.log.Log(logs.LevelDebug, logs.Record{Source: "dnstt", Msg: logs.Scrub(fmt.Sprintf(format, args...))})
	}
}

// certificateCheckEvery is how often checkCertificate looks; acmeGrace is how
// long a new ACME setup may take before its missing certificate is an alert.
var (
	certificateCheckEvery = time.Hour
	acmeGrace             = time.Hour
)

// checkCertificate raises an alert when the ACME certificate is not renewed in
// time (less than a tenth of its lifetime left) or none was issued an hour
// after the server started: sing-box retries by itself, but nothing tells
// the admin that it keeps failing.
func (s *Server) checkCertificate() {
	s.mu.Lock()
	due := time.Since(s.certChecked) >= certificateCheckEvery
	if due {
		s.certChecked = time.Now()
	}
	started := s.started
	s.mu.Unlock()
	if !due {
		return
	}
	st, err := s.store.Load()
	if err != nil || !st.Server.ACMEActive() {
		return
	}
	src := tlsfiles.New(serverconf.ACMEDir(s.store), st.Server.ACME.Domain, s.store.Path(st.Server.CertFile), s.store.Path(st.Server.KeyFile))
	info, err := src.Info()
	now := time.Now()
	switch {
	case err == nil && info.Source == "acme":
		lifetime, left := info.NotAfter.Sub(info.NotBefore), info.NotAfter.Sub(now)
		if left < lifetime/10 {
			s.failed(true, logs.Record{
				Msg:    "the ACME certificate was not renewed; it expires " + info.NotAfter.UTC().Format(time.RFC3339),
				Target: "certificate", Op: "acme", Code: "ACME_RENEW_FAILED",
			}, nil)
		}
	case now.Sub(started) >= acmeGrace:
		s.failed(true, logs.Record{
			Msg:    "no ACME certificate was issued; clients get the self-signed one (see the sing-box errors in the log)",
			Target: "certificate", Op: "acme", Code: "ACME_NOT_ISSUED",
		}, err)
	}
}
