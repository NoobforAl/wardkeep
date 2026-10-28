# Logging and error notifications

One log format for every part of Wardkeep (Go core, Rust `omnitun-tor`, `omnitun-server`, the app), so
the process that reads a log can filter it, show it and tell the user when something failed that nothing
handled.

## 1. The record

One JSON object per line. Keys follow Go's `log/slog`; the context fields follow the OpenTelemetry log
model (who logged it, what was being done, which connection).

```json
{"time":"2026-10-29T01:02:03.456Z","level":"error","source":"tor","msg":"bootstrap stalled",
 "op":"connect","conn":"7f3a","profile":"p_19","code":"TOR_BLOCKED","err":"…","notify":true}
```

| Key | Type | When | Meaning |
|---|---|---|---|
| `time` | RFC 3339 string, UTC, milliseconds | always | when it happened |
| `level` | `trace` `debug` `info` `warn` `error` `fatal` | always | `fatal` = a panic or a crash of a process |
| `source` | `core` `sing-box` `tor` `dnstt` `dnscrypt` `server` `app` | always | the part that logged it |
| `msg` | string | always | what happened, in plain words |
| `target` | string | optional | finer origin: the Rust module (`tor_guardmgr`), the sing-box tag |
| `op` | string | optional | what was being done: `connect`, `bootstrap`, `import`, `subscription`, `test`, … |
| `conn` | string | optional | short random id of one connect attempt; every record of that attempt carries it, in every process |
| `profile` | string | optional | the profile's **id** (never its name or address) |
| `code` | string | errors | stable code (the engine's `ErrorCode` values, e.g. `TOR_TIMEOUT`); the app turns it into a translated message |
| `err` | string | errors | the error chain |
| `notify` | bool | errors | `true`: nothing handled this; the user should be told |
| `caller` | `file:line` | debug level, panics | where it was logged |
| `stack` | string | panics | the stack trace |
| `user` | string | server only | the VPN user's name (the admin's own data) |

Unknown keys are kept and shown as `key=value`; readers must accept records without the optional keys.

### Never in a log, at any level

Destinations (hosts, IPs, ports a user connects to), server addresses, keys, passwords, tokens, UUIDs,
subscription URLs, profile names. Errors from libraries that may contain them are passed through the
existing scrubbing (`engine/errors.go`) before they are logged.

## 2. Where the records travel

| From → to | Form |
|---|---|
| `omnitun-tor` → core | stdout line `{"event":"log", <record keys>}` (the record flattened next to `event`); the other events (`listening`, `bootstrap`, `ready`, `path`, `error`) are unchanged. stderr carries only unexpected output: the core logs each stderr line as `level:error, source:tor`. |
| core → app (control protocol) | push `{"event":"log","data":<record>}`. Older apps read `message`; the app reads `msg` and falls back to `message`. |
| `omnitun-server` → its log file | one record per line; `Tail` still reads old text lines. |
| server → admin | `GET /api/v1/logs?level=&since=&limit=`, `GET /api/v1/alerts`, `POST /api/v1/alerts/ack`; the TUI shows unacknowledged alerts; the web panel (PLAN.md §4.2) will read the same endpoints. |

## 3. Levels and build modes

| | Release build | Debug logging on (user setting) | Dev build |
|---|---|---|---|
| Records kept | `error`, `fatal` | the chosen level: `info`, `debug` or `trace` | `debug` |
| `caller` | panics only | yes | yes |
| sing-box level | `error` | same as chosen | `debug` |

* Build mode: Go `github.com/NoobforAl/omnitun/core/buildinfo.Mode`, `"dev"` unless set with
  `-ldflags "-X github.com/NoobforAl/omnitun/core/buildinfo.Mode=release"` (release workflow); Flutter
  `kReleaseMode`. `omnitun-tor` does not decide: the core passes `--log-level LEVEL`.
* A level that is off costs nothing: every layer checks the level before it formats a message.
* Control methods: `logging.get` → `{"level","default","mode","until"}`; `logging.set {"level","until"}`
  (`until` RFC 3339, optional; the core returns to the default level then). `level: ""` = default.
* The app's setting warns: debug logging slows connections, uses more battery and keeps more detail; it
  turns itself off after 24 hours.
* A level change reaches sing-box and Tor at their next start.

## 4. Panics

* Rust: a panic hook writes a `fatal` record with `caller` and `stack` to stdout (then the process exits).
* Go: long-running goroutines of the engine, the control server and the server runtime `recover`, log a
  `fatal` record with `stack` and `notify:true`, and end that work as an error instead of crashing.

## 5. When the user is told

A record with `notify:true` (always `error` or `fatal`) is shown to the user. Set it only where nothing
else handles the failure: a helper process (Tor, dnstt) that exits on its own, a sing-box fatal error, a
running connection that falls to the error state, a panic. Errors that are retried or failed over are
logged without it.

| Where | How | Setting (default) |
|---|---|---|
| App | red notice with "View logs" (opens the log page filtered by that `conn`) | `notifyPopup` (on) |
| Android | system notification on the VPN service's channel | `notifyOs` (on) |
| Desktop | system notification | `notifyOs` (on) |
| Server | alert in the TUI, the API and the web panel | `alerts` in the server config (on) |

The same `conn` + `code` notifies once.
