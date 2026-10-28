package links

import (
	"fmt"
	"net/url"

	"github.com/NoobforAl/omnitun/core/profile"
)

// tailscale is the share link of a mesh profile; see importer.parseTailscaleLink.
func tailscale(prof *profile.Profile) (string, error) {
	opts := prof.Tailscale
	if opts == nil {
		opts = &profile.TailscaleOpts{}
	}
	params := &query{}
	host := ""
	if opts.ControlURL != "" {
		uri, err := url.Parse(opts.ControlURL)
		if err != nil {
			return "", err
		}
		if uri.Host == "" {
			return "", fmt.Errorf("the control server %q has no host", opts.ControlURL)
		}
		host = uri.Host
		if uri.Scheme == "http" {
			params.add("scheme", "http")
		}
	}
	params.add("hostname", opts.Hostname)
	params.add("exit", opts.ExitNode)
	params.addFlag("routes", opts.AcceptRoutes)
	params.addFlag("ephemeral", opts.Ephemeral)
	return build("tailscale", url.PathEscape(prof.Password), host, "", params, prof.Name), nil
}
