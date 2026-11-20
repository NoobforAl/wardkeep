//go:build !windows

package rvpn

import "os/exec"

func hideWindow(*exec.Cmd) {}
