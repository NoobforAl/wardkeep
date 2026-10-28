// Command meshctl is a small control-protocol client for the Docker mesh test
// (tools/dockertest/mesh.py): it talks to a running omnitun-svc like the app
// does, so the test drives the core through the same calls the app makes.
//
//	meshctl -control /data/control.json connect "tailscale://KEY@hs:8080?scheme=http" 2080
//	meshctl -control /data/control.json call mesh_status
//	meshctl -control /data/control.json call mesh_ping '{"address":"100.64.0.2"}'
//
// connect imports the link and starts the profile in proxy mode (a SOCKS/HTTP
// port on 127.0.0.1), selected; call sends any method and prints the result as JSON.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/NoobforAl/omnitun/core/control"
	"github.com/NoobforAl/omnitun/core/importer"
)

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "meshctl: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	controlFile := flag.String("control", "control.json", "the daemon's control file")
	timeout := flag.Duration("timeout", 60*time.Second, "how long a call may take")
	flag.Parse()
	args := flag.Args()
	if len(args) < 2 {
		fail("usage: meshctl [-control file] connect <link> <port> | call <method> [json]")
	}
	raw, err := os.ReadFile(*controlFile)
	if err != nil {
		fail("%v", err)
	}
	var cf control.ControlFile
	if err := json.Unmarshal(raw, &cf); err != nil {
		fail("%s: %v", *controlFile, err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()
	client, err := control.Dial(ctx, cf.Addr, cf.Token)
	if err != nil {
		fail("%v", err)
	}
	defer client.Close()

	var result any
	switch args[0] {
	case "connect":
		if len(args) != 3 {
			fail("connect <link> <port>")
		}
		var port int
		if _, err := fmt.Sscan(args[2], &port); err != nil {
			fail("port: %v", err)
		}
		res, err := importer.Import(args[1])
		if err != nil || len(res.Profiles) != 1 {
			fail("import: %v", err)
		}
		p := res.Profiles[0]
		start := control.StartParams{Profiles: res.Profiles, Selected: p.ID, ListenPort: port, Mode: "proxy"}
		if err := client.Call(ctx, "start", start, &result); err != nil {
			fail("start: %v", err)
		}
	case "call":
		var params any
		if len(args) > 2 {
			if err := json.Unmarshal([]byte(args[2]), &params); err != nil {
				fail("params: %v", err)
			}
		}
		if err := client.Call(ctx, args[1], params, &result); err != nil {
			fail("%s: %v", args[1], err)
		}
	default:
		fail("unknown command %q", args[0])
	}
	out, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(out))
}
