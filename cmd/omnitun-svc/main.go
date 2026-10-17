// Command omnitun-svc is the core daemon the UI talks to. It owns the tunnel
// and guarantees it never outlives the UI: the tunnel stops when no UI is
// connected, and the daemon exits when its parent process dies.
//
// Without a subcommand it runs as a per-user daemon (what the app launches).
// On Windows it can also run as a service with system rights, so the VPN mode
// works from an app that is not elevated:
//
//	omnitun-svc install [--user NAME]...   register the service (elevated)
//	omnitun-svc uninstall [--purge]        remove it (elevated)
//	omnitun-svc start | stop               (elevated)
//	omnitun-svc status                     works for any user
//	omnitun-svc cleanup [--force]          remove leftovers of a crashed run (elevated)
//	omnitun-svc killswitch-selftest --yes  try the kill switch for a few seconds (elevated)
//
// The service itself runs as "omnitun-svc service", started by Windows.
package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"
)

func defaultDir() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = os.TempDir()
	}
	return filepath.Join(dir, "omnitun")
}

func main() {
	if len(os.Args) > 1 {
		if run, ok := subcommands[os.Args[1]]; ok {
			os.Exit(run(os.Args[2:]))
		}
	}
	if isService() {
		os.Exit(runAsService())
	}
	os.Exit(runPerUser(os.Args[1:]))
}

// runPerUser is the daemon the app launches (and the development default).
func runPerUser(args []string) int {
	fs := newFlagSet("omnitun-svc")
	listen := fs.String("listen", "127.0.0.1:0", "control address (loopback only)")
	controlFile := fs.String("control-file", filepath.Join(defaultDir(), "control.json"), "where to write the address and token")
	dataDir := fs.String("data-dir", defaultDir(), "engine data directory")
	parentPID := fs.Int("parent-pid", 0, "exit when this process exits (0 = don't watch)")
	grace := fs.Duration("grace", 5*time.Second, "how long the tunnel survives without a connected UI")
	cleanup := fs.Bool("cleanup", false, "first remove leftovers of a crashed run (needs administrator rights; never use it next to the service)")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	logger := log.New(os.Stderr, "omnitun-svc: ", log.LstdFlags)
	if *cleanup {
		runCleanup(logger.Printf)
	}
	exit := make(chan string, 2)
	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
		exit <- (<-sig).String()
	}()
	err := runDaemon(daemonConfig{
		Listen:      *listen,
		ControlFile: *controlFile,
		DataDir:     *dataDir,
		Grace:       *grace,
		ParentPID:   *parentPID,
		Logger:      logger,
		Exit:        exit,
		// The UI reads this line to learn the address when it launched us.
		OnReady: func(addr string) { fmt.Printf("READY %s\n", addr) },
	})
	if err != nil {
		logger.Print(err)
		return 1
	}
	return 0
}
