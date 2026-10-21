// Package pprofsrv serves Go's runtime profiles (net/http/pprof) on a loopback
// address, for finding CPU, heap, goroutine and lock problems in a running
// daemon. It is off unless a --pprof flag asks for it, and it refuses any
// address that is not loopback: profiles show the process's memory layout.
package pprofsrv

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/pprof"
	"runtime"
	"time"
)

// Serve listens on addr (host:port, loopback only) until ctx ends. It also
// turns on block and mutex profiling, which cost nothing while they are off.
// logf may be nil.
func Serve(ctx context.Context, addr string, logf func(string, ...any)) error {
	ln, err := Listen(addr)
	if err != nil {
		return err
	}
	return ServeListener(ctx, ln, logf)
}

// Listen opens the profiling listener; it fails for a non-loopback address.
func Listen(addr string) (net.Listener, error) {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return nil, fmt.Errorf("pprof address %q: %w", addr, err)
	}
	if ip := net.ParseIP(host); host != "localhost" && (ip == nil || !ip.IsLoopback()) {
		return nil, fmt.Errorf("pprof address %q is not loopback", addr)
	}
	return net.Listen("tcp", addr)
}

// ServeListener serves the profiles on ln until ctx ends.
func ServeListener(ctx context.Context, ln net.Listener, logf func(string, ...any)) error {
	runtime.SetBlockProfileRate(1000) // one sample per microsecond blocked
	runtime.SetMutexProfileFraction(100)
	mux := http.NewServeMux()
	mux.HandleFunc("/debug/pprof/", pprof.Index)
	mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
	// No WriteTimeout: /profile?seconds=60 and /trace hold the response open.
	srv := &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if srv.Shutdown(shutdown) != nil {
			srv.Close()
		}
	}()
	if logf != nil {
		logf("pprof on http://%s/debug/pprof/", ln.Addr())
	}
	if err := srv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
