package links

import (
	"fmt"
	"net/url"

	"github.com/NoobforAl/omnitun/core/profile"
)

// tailscale is the share link of a mesh profile; see importer.parseTailscaleLink.
func tailscale(p *profile.Profile) (string, error) {
	o := p.Tailscale
	if o == nil {
		o = &profile.TailscaleOpts{}
	}
	q := &query{}
	host := ""
	if o.ControlURL != "" {
		u, err := url.Parse(o.ControlURL)
		if err != nil {
			return "", err
		}
		if u.Host == "" {
			return "", fmt.Errorf("the control server %q has no host", o.ControlURL)
		}
		host = u.Host
		if u.Scheme == "http" {
			q.add("scheme", "http")
		}
	}
	q.add("hostname", o.Hostname)
	q.add("exit", o.ExitNode)
	q.addFlag("routes", o.AcceptRoutes)
	q.addFlag("ephemeral", o.Ephemeral)
	return build("tailscale", url.PathEscape(p.Password), host, "", q, p.Name), nil
}
