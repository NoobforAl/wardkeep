package main

import (
	"fmt"
	"io"
	"os"
	"time"

	"github.com/NoobforAl/omnitun/core/logrec"
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
	layout := winsvc.DefaultLayout()
	var logW io.Writer = io.Discard
	// The log goes into %ProgramData%\omnitun, which must be locked first (any
	// user could have created the directory). If that fails there is no log;
	// serve fails with the same error and the service manager shows it.
	if winsvc.SecureRoot(layout) == nil {
		if f, err := openServiceLog(layout.Log); err == nil {
			defer f.Close()
			logW = f
		}
	}
	logger := logrec.NewLogger(logW, logrec.SourceCore)

	err := winsvc.RunService(func(stop <-chan struct{}) error {
		return serve(logger, layout, stop)
	})
	if err != nil {
		logger.Errorf("%v", err)
		return 1
	}
	return 0
}

// serve is the service's life: prepare, clean up after a crash, serve the
// control protocol, clean up again.
func serve(logger *logrec.Logger, layout winsvc.Layout, stop <-chan struct{}) error {
	cfg, err := winsvc.LoadConfig(layout.Config)
	if err != nil {
		return err
	}
	if err := cfg.Validate(); err != nil {
		return fmt.Errorf("the service is not set up (run \"omnitun-svc install\"): %w", err)
	}
	// Lock the directories before anything secret is written to them.
	if err := winsvc.PrepareDirs(layout, cfg); err != nil {
		return err
	}

	// Nothing of ours can be running yet (a single instance owns the service),
	// so anything with our adapter's name is a leftover.
	runCleanup(logger)
	defer runCleanup(logger)

	exit := make(chan string, 2)
	go func() {
		<-stop
		exit <- "the service was asked to stop"
	}()
	logger.Printf("starting; allowed accounts: %d", len(cfg.AllowedSIDs))
	return runDaemon(daemonConfig{
		Listen:      "127.0.0.1:0",
		ControlFile: layout.ControlFile,
		DataDir:     layout.DataDir,
		Grace:       5 * time.Second,
		Logger:      logger,
		Exit:        exit,
	})
}

// runCleanup removes what a crashed run left (core/winsvc has the list).
func runCleanup(logger *logrec.Logger) winsvc.Report {
	rep := winsvc.RunCleanup(winsvc.CleanupSteps(singbox.WindowsTunName))
	for _, svc := range rep {
		switch {
		case svc.Err != nil:
			logger.Errorf("cleanup: %s failed: %v", svc.Name, svc.Err)
		case svc.Done != "":
			logger.Printf("cleanup: %s: %s", svc.Name, svc.Done)
		}
	}
	return rep
}
