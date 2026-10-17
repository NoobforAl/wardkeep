//go:build !windows

package killswitch

const supported = false

type stubBackend struct{}

func (stubBackend) Apply([]Rule) error { return ErrUnsupported }
func (stubBackend) Remove() error      { return nil }

func newBackend() Backend { return stubBackend{} }

func tunLUID(string) (uint64, error) { return 0, ErrUnsupported }

// Cleanup removes leftovers of an earlier run; there are none here.
func Cleanup() error { return nil }
