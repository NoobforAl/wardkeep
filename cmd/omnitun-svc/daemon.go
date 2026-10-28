package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/NoobforAl/omnitun/core/control"
	"github.com/NoobforAl/omnitun/core/killswitch"
	"github.com/NoobforAl/omnitun/core/logrec"
)

func newFlagSet(name string) *flag.FlagSet { return flag.NewFlagSet(name, flag.ContinueOnError) }

// daemonConfig is what runDaemon needs; the per-user daemon and the service
// differ only in these values.
type daemonConfig struct {
	Listen      string
	ControlFile string
	DataDir     string
	Grace       time.Duration
	ParentPID   int
	Logger      *logrec.Logger
	// Exit receives the reason to shut down (a signal, a stop request).
	Exit chan string
	// OnReady is called with the listening address once the control file is written.
	OnReady func(addr string)
}

// runDaemon serves the control protocol until something arrives on cfg.Exit, the
// parent process exits or the server fails; then it stops the tunnel.
func runDaemon(cfg daemonConfig) error {
	srv, err := control.NewServer(control.ServerConfig{
		DataDir:    cfg.DataDir,
		Grace:      cfg.Grace,
		OnLog:      cfg.Logger.Emit,
		KillSwitch: killswitch.NewManager(),
	})
	if err != nil {
		return err
	}
	addr, err := srv.Listen(cfg.Listen)
	if err != nil {
		return err
	}
	if err := srv.WriteControlFile(cfg.ControlFile); err != nil {
		srv.Close()
		return err
	}
	defer os.Remove(cfg.ControlFile)
	if cfg.OnReady != nil {
		cfg.OnReady(addr.String())
	}

	if cfg.ParentPID > 0 {
		go func() {
			if err := waitProcess(cfg.ParentPID); err != nil {
				cfg.Exit <- fmt.Sprintf("cannot watch parent %d: %v", cfg.ParentPID, err)
				return
			}
			cfg.Exit <- fmt.Sprintf("parent %d exited", cfg.ParentPID)
		}()
	}
	go func() {
		if err := srv.Serve(); err != nil {
			cfg.Exit <- err.Error()
		}
	}()

	cfg.Logger.Printf("listening on %s, shutting down: %s", addr, <-cfg.Exit)
	srv.Close()
	return nil
}
