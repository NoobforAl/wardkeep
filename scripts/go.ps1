# Runs a go command with the project's sing-box build tags (Windows equivalent of the Makefile).
# Usage: ./scripts/go.ps1 test ./...    |    ./scripts/go.ps1 build -o bin/ ./cmd/...
$tags = 'with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_acme,badlinkname,tfogo_checklinkname0'
$cmd = $args[0]
$rest = @($args | Select-Object -Skip 1)
# $env:OMNITUN_BUILD_MODE = 'release' (the release workflow) builds with release log levels (core/buildinfo).
$ldflags = '-checklinkname=0'
if ($env:OMNITUN_BUILD_MODE -eq 'release') {
    $ldflags += ' -X github.com/NoobforAl/omnitun/core/buildinfo.Mode=release'
}
if ($cmd -in 'build', 'test', 'run', 'install') {
    & go $cmd "-tags=$tags" "-ldflags=$ldflags" @rest
} else {
    & go $cmd "-tags=$tags" @rest
}
exit $LASTEXITCODE
