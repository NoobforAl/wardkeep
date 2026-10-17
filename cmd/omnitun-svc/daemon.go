package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/NoobforAl/omnitun/core/control"
	"github.com/NoobforAl/omnitun/core/killswitch"
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
	Logger      *log.Logger
	// Exit receives the reason to shut down (a signal, a stop request).
	Exit chan string
	// OnReady is called with the listening address once the control file is written.
	OnReady func(addr string)
}

// runDaemon serves the control protocol until something arrives on c.Exit, the
// parent process exits or the server fails; then it stops the tunnel.
func runDaemon(c daemonConfig) error {
	srv, err := control.NewServer(control.ServerConfig{
		DataDir:    c.DataDir,
		Grace:      c.Grace,
		Logf:       c.Logger.Printf,
		KillSwitch: killswitch.NewManager(),
	})
	if err != nil {
		return err
	}
	addr, err := srv.Listen(c.Listen)
	if err != nil {
		return err
	}
	if err := srv.WriteControlFile(c.ControlFile); err != nil {
		srv.Close()
		return err
	}
	defer os.Remove(c.ControlFile)
	if c.OnReady != nil {
		c.OnReady(addr.String())
	}

	if c.ParentPID > 0 {
		go func() {
			if err := waitProcess(c.ParentPID); err != nil {
				c.Exit <- fmt.Sprintf("cannot watch parent %d: %v", c.ParentPID, err)
				return
			}
			c.Exit <- fmt.Sprintf("parent %d exited", c.ParentPID)
		}()
	}
	go func() {
		if err := srv.Serve(); err != nil {
			c.Exit <- err.Error()
		}
	}()

	c.Logger.Printf("listening on %s, shutting down: %s", addr, <-c.Exit)
	srv.Close()
	return nil
}
