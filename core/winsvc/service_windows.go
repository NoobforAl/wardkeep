//go:build windows

package winsvc

import (
	"errors"
	"fmt"
	"time"

	"golang.org/x/sys/windows/svc"
)

// IsService reports whether this process was started by the Service Control Manager.
func IsService() bool {
	ok, err := svc.IsWindowsService()
	return err == nil && ok
}

// stopWait is how long the service gives run to return after a stop request
// before it reports the stop anyway (the SCM kills a service that does not
// answer in about 30 seconds).
const stopWait = 20 * time.Second

type handler struct {
	run func(stop <-chan struct{}) error
}

// Execute implements svc.Handler: it runs h.run until the SCM asks the
// service to stop or shut down, or run returns on its own.
func (h *handler) Execute(_ []string, requests <-chan svc.ChangeRequest, status chan<- svc.Status) (bool, uint32) {
	const accepted = svc.AcceptStop | svc.AcceptShutdown
	status <- svc.Status{State: svc.StartPending}

	stop := make(chan struct{})
	done := make(chan error, 1)
	go func() { done <- h.run(stop) }()
	status <- svc.Status{State: svc.Running, Accepts: accepted}

	for {
		select {
		case err := <-done:
			// run ended by itself: a failure to start or an internal error.
			if err != nil {
				return true, 1 // service-specific exit code 1
			}
			return false, 0
		case c := <-requests:
			switch c.Cmd {
			case svc.Interrogate:
				status <- c.CurrentStatus
			case svc.Stop, svc.Shutdown:
				status <- svc.Status{State: svc.StopPending}
				close(stop)
				select {
				case <-done:
				case <-time.After(stopWait):
				}
				return false, 0
			}
		}
	}
}

// RunService hands the process to the Service Control Manager and calls run;
// run must return once stop is closed.
func RunService(run func(stop <-chan struct{}) error) error {
	if run == nil {
		return errors.New("winsvc: no function to run")
	}
	if err := svc.Run(ServiceName, &handler{run: run}); err != nil {
		return fmt.Errorf("run as a service: %w", err)
	}
	return nil
}
