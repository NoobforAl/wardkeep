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
	uri, err := url.Parse(link)
	if err != nil {
		return nil, err
	}
	query := uri.Query()
	key := uri.User.Username()
	if pw, ok := uri.User.Password(); ok {
		key += ":" + pw
	}
	if key == "" {
		key = query.Get("authkey")
	}
	opts := &profile.TailscaleOpts{
		Hostname:     query.Get("hostname"),
		ExitNode:     firstNonEmpty(query.Get("exit"), query.Get("exit_node")),
		AcceptRoutes: truthy(query.Get("routes")),
		Ephemeral:    truthy(query.Get("ephemeral")),
	}
	if uri.Host != "" {
		scheme := "https"
		if strings.EqualFold(query.Get("scheme"), "http") {
			scheme = "http"
		}
		opts.ControlURL = scheme + "://" + uri.Host
	}
	name := fragmentName(uri)
	if name == "" {
		name = "Tailscale"
		if uri.Hostname() != "" {
			name = uri.Hostname()
		}
	}
	return &profile.Profile{Name: name, Protocol: profile.Tailscale, Password: key, Tailscale: opts}, nil
}
