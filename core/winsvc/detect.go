package winsvc

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/NoobforAl/omnitun/core/control"
)

// ReadControlFile reads the control file of a running core.
func ReadControlFile(path string) (control.ControlFile, error) {
	data, err := os.ReadFile(path) //nolint:gosec // G304: the core's control file at a fixed location
	if err != nil {
		return control.ControlFile{}, err
	}
	var cf control.ControlFile
	if err := json.Unmarshal(data, &cf); err != nil {
		return control.ControlFile{}, fmt.Errorf("%s: %w", path, err)
	}
	if cf.Addr == "" || cf.Token == "" {
		return control.ControlFile{}, fmt.Errorf("%s: no address or token", path)
	}
	return cf, nil
}

// Detect reports whether a core answers to the control file at path: the file
// must be readable by this user, and the address must accept this token. A
// stale file (the service stopped or crashed) fails here, so a caller that
// prefers the service falls back to its own daemon.
func Detect(ctx context.Context, path string) (control.ControlFile, error) {
	cf, err := ReadControlFile(path)
	if err != nil {
		return cf, err
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	c, err := control.Dial(ctx, cf.Addr, cf.Token)
	if err != nil {
		return cf, fmt.Errorf("the core in %s does not answer: %w", path, err)
	}
	c.Close()
	return cf, nil
}
