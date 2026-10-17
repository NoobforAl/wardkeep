package importer

import (
	"net/url"
	"strings"

	"github.com/NoobforAl/omnitun/core/profile"
)

// parseTailscaleLink reads a mesh link:
//
//	tailscale://<auth key>@<control server>[:port]?scheme=http&hostname=<name>&exit=<device>&routes=1&ephemeral=1#<name>
//
// The control server is a Headscale (or other) address; without one the
// profile uses Tailscale's own. The scheme is https unless the link says http.
func parseTailscaleLink(link string) (*profile.Profile, error) {
	u, err := url.Parse(link)
	if err != nil {
		return nil, err
	}
	q := u.Query()
	key := u.User.Username()
	if pw, ok := u.User.Password(); ok {
		key += ":" + pw
	}
	if key == "" {
		key = q.Get("authkey")
	}
	o := &profile.TailscaleOpts{
		Hostname:     q.Get("hostname"),
		ExitNode:     firstNonEmpty(q.Get("exit"), q.Get("exit_node")),
		AcceptRoutes: truthy(q.Get("routes")),
		Ephemeral:    truthy(q.Get("ephemeral")),
	}
	if u.Host != "" {
		scheme := "https"
		if strings.EqualFold(q.Get("scheme"), "http") {
			scheme = "http"
		}
		o.ControlURL = scheme + "://" + u.Host
	}
	name := fragmentName(u)
	if name == "" {
		name = "Tailscale"
		if u.Hostname() != "" {
			name = u.Hostname()
		}
	}
	return &profile.Profile{Name: name, Protocol: profile.Tailscale, Password: key, Tailscale: o}, nil
}
