//go:build windows

package rvpn

import (
	"os/exec"
	"syscall"
)

// hideWindow keeps the rVPN helper's console window hidden on Windows.
func hideWindow(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000} // CREATE_NO_WINDOW
}
