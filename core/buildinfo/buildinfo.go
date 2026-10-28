// Package buildinfo says how this binary was built. Release builds set Mode with
//
//	-ldflags "-X github.com/NoobforAl/omnitun/core/buildinfo.Mode=release"
//
// (the release workflow does); every other build is a development build.
package buildinfo

// Mode is "release" in release builds and "dev" otherwise.
var Mode = "dev"

// Release reports whether this is a release build.
func Release() bool { return Mode == "release" }
