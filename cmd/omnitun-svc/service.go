package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/NoobforAl/omnitun/core/singbox"
	"github.com/NoobforAl/omnitun/core/winsvc"
)

func isService() bool { return winsvc.IsService() }

// maxLogSize is when the service's log starts over; one run's log is small.
const maxLogSize = 5 << 20

func openServiceLog(path string) (io.WriteCloser, error) {
	flags := os.O_CREATE | os.O_WRONLY | os.O_APPEND
	if st, err := os.Stat(path); err == nil && st.Size() > maxLogSize {
		flags = os.O_CREATE | os.O_WRONLY | os.O_TRUNC
	}
	return os.OpenFile(path, flags, 0o600)
}

// runAsService is the entry point when Windows starts us as the service.
func runAsService() int {
	l := winsvc.DefaultLayout()
	var logW io.Writer = io.Discard
	// The log goes into %ProgramData%\omnitun, which must be locked first (any
	// user could have created the directory). If that fails there is no log;
	// serve fails with the same error and the service manager shows it.
	if winsvc.SecureRoot(l) == nil {
		if f, err := openServiceLog(l.Log); err == nil {
			defer f.Close()
			logW = f
		}
	}
	logger := log.New(logW, "omnitun-svc: ", log.LstdFlags)

	err := winsvc.RunService(func(stop <-chan struct{}) error {
		return serve(logger, l, stop)
	})
	if err != nil {
		logger.Print(err)
		return 1
	}
	return 0
}

// serve is the service's life: prepare, clean up after a crash, serve the
// control protocol, clean up again.
func serve(logger *log.Logger, l winsvc.Layout, stop <-chan struct{}) error {
	cfg, err := winsvc.LoadConfig(l.Config)
	if err != nil {
		return err
	}
	if err := cfg.Validate(); err != nil {
		return fmt.Errorf("the service is not set up (run \"omnitun-svc install\"): %w", err)
	}
	// Lock the directories before anything secret is written to them.
	if err := winsvc.PrepareDirs(l, cfg); err != nil {
		return err
	}

	// Nothing of ours can be running yet (a single instance owns the service),
	// so anything with our adapter's name is a leftover.
	runCleanup(logger.Printf)
	defer runCleanup(logger.Printf)

	exit := make(chan string, 2)
	go func() {
		<-stop
		exit <- "the service was asked to stop"
	}()
	logger.Printf("starting; allowed accounts: %d", len(cfg.AllowedSIDs))
	return runDaemon(daemonConfig{
		Listen:      "127.0.0.1:0",
		ControlFile: l.ControlFile,
		DataDir:     l.DataDir,
		Grace:       5 * time.Second,
		Logger:      logger,
		Exit:        exit,
	})
}

// runCleanup removes what a crashed run left (core/winsvc has the list).
func runCleanup(logf func(string, ...any)) winsvc.Report {
	rep := winsvc.RunCleanup(winsvc.CleanupSteps(singbox.WindowsTunName))
	for _, s := range rep {
		switch {
		case s.Err != nil:
			logf("cleanup: %s failed: %v", s.Name, s.Err)
		case s.Done != "":
			logf("cleanup: %s: %s", s.Name, s.Done)
		}
	}
	return rep
}
