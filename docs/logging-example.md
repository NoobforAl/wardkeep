# Logging, by example

One connect attempt followed through the system, to show what [logging.md](logging.md) looks like in
practice. The user has turned on **debug** logging and connects the Tor profile `p_19`; the bridge is
blocked, Tor gives up, and the user is told. Every line below is one JSON object on one line (wrapped here
only where noted).

Example values: connect attempt `conn` = `7f3a`, profile id `p_19`. No address, bridge line or profile name
appears anywhere: those never go in a log. The keys, their order and the error codes are real; messages, `caller` line numbers and timings are illustrative.

## 1. What `wardkeep-tor` writes on its stdout

The Rust process writes **events** (`listening`, `bootstrap`, `ready`, `path`, `error`) and **log records**
(`"event":"log"`) on the same stdout, one per line. The core reads it line by line.

```jsonl
{"event":"log","time":"2026-11-01T10:15:00.120Z","level":"info","source":"tor","target":"wardkeep_tor","msg":"starting","caller":"src/main.rs:334"}
{"event":"listening","socks":"127.0.0.1:49152"}
{"event":"log","time":"2026-11-01T10:15:00.410Z","level":"debug","source":"tor","target":"tor_dirmgr","msg":"Looking for a consensus.","caller":"tor-dirmgr-0.47.0/src/bootstrap.rs:512"}
{"event":"bootstrap","percent":5,"status":"connecting to a bridge"}
{"event":"log","time":"2026-11-01T10:15:10.902Z","level":"warn","source":"tor","target":"tor_guardmgr","msg":"bridge connection timed out","attempt":1,"caller":"tor-guardmgr-0.47.0/src/lib.rs:1203"}
{"event":"log","time":"2026-11-01T10:15:21.344Z","level":"warn","source":"tor","target":"tor_guardmgr","msg":"bridge connection timed out","attempt":2,"caller":"tor-guardmgr-0.47.0/src/lib.rs:1203"}
{"event":"bootstrap","percent":5,"status":"connecting to a bridge","blocked":"bridge unreachable"}
{"event":"log","time":"2026-11-01T10:16:00.007Z","level":"error","source":"tor","target":"wardkeep_tor","msg":"bootstrap stalled","code":"TOR_BRIDGE_TIMEOUT","err":"tor: unable to connect to any bridge: timed out","caller":"src/main.rs:291"}
{"event":"error","message":"bootstrap stalled"}
```

Things to see:

* `target` is the Rust module that logged it. `tor_*` targets are **Arti's own logs**, which come through
  the same formatter, so they look like ours.
* `caller` is there only because the level is `debug`; a dependency's path is cut to `crate-version/src/...`
  so no build-machine path leaks.
* Extra fields (`attempt`) follow `msg`; a field that would clash with a record key (`msg`, `level`, ...)
  is written as `msg_`, `level_`, so it can never fake one.
* Tor does not know `conn` or `profile`; the core adds them (section 2).

## 2. What the core keeps (and forwards)

The core parses each `"event":"log"` line, **scrubs** `msg`, `err` and string fields, and stamps the
current connect attempt on it: `conn`, `profile`, and `op:"connect"` if the record had none. Its own records
look the same, with `source:"core"`. Go writes the keys in the contract's order: `time`, `level`, `source`,
`msg`, `target`, `op`, `conn`, `profile`, `code`, `err`, `notify`, `caller`, `stack`, `user`, then any
other keys, sorted.

```jsonl
{"time":"2026-11-01T10:15:00.050Z","level":"info","source":"core","msg":"connecting","op":"connect","conn":"7f3a","profile":"p_19","caller":"engine/engine.go:240"}
{"time":"2026-11-01T10:15:00.120Z","level":"info","source":"tor","msg":"starting","target":"wardkeep_tor","op":"connect","conn":"7f3a","profile":"p_19","caller":"src/main.rs:334"}
{"time":"2026-11-01T10:15:10.902Z","level":"warn","source":"tor","msg":"bridge connection timed out","target":"tor_guardmgr","op":"connect","conn":"7f3a","profile":"p_19","caller":"tor-guardmgr-0.47.0/src/lib.rs:1203","attempt":1}
{"time":"2026-11-01T10:16:00.007Z","level":"error","source":"tor","msg":"bootstrap stalled","target":"wardkeep_tor","op":"connect","conn":"7f3a","profile":"p_19","code":"TOR_BRIDGE_TIMEOUT","err":"tor: unable to connect to any bridge: timed out","caller":"src/main.rs:291"}
{"time":"2026-11-01T10:16:00.031Z","level":"error","source":"core","msg":"connection failed","op":"connect","conn":"7f3a","profile":"p_19","code":"TOR_BRIDGE_TIMEOUT","err":"tor: unable to connect to any bridge: timed out","notify":true,"caller":"engine/engine.go:318"}
```

Things to see:

* Search for `"conn":"7f3a"` and you get the whole attempt, from **every** process (core, tor, sing-box).
* Only the **last** line has `notify:true`. The two `warn` lines were retries, and Tor's own `error` was
  still handled by the core; the core's "connection failed" is the moment nothing else will fix it, so that
  is the one the user is told about. The same `conn` + `code` notifies only once.
* `code` is stable (`TOR_BRIDGE_TIMEOUT`); the app turns it into a translated message. `err` is the
  technical chain, for the log page.

## 3. What the app receives

Over the control protocol each record is wrapped as `{"event":"log","data":<record>}`. The copy of `msg`
in `message` is for older apps. (Wrapped here for reading.)

```json
{"event":"log","data":{"time":"2026-11-01T10:16:00.031Z","level":"error","source":"core",
 "msg":"connection failed","op":"connect","conn":"7f3a","profile":"p_19","code":"TOR_BRIDGE_TIMEOUT",
 "err":"tor: unable to connect to any bridge: timed out","notify":true,"message":"connection failed"}}
```

Because `notify` is `true`, the app shows a red notice with **View logs** (opening the log page filtered to
`conn` `7f3a`). On Android this `op:"connect"` failure is left to the VPN service's own "Connection lost"
notification.

## 4. The same attempt in a release build

A release build keeps only `error` and `fatal`, and adds `caller` only to panics, so the whole story above
shrinks to:

```jsonl
{"time":"2026-11-01T10:16:00.007Z","level":"error","source":"tor","msg":"bootstrap stalled","target":"wardkeep_tor","op":"connect","conn":"7f3a","profile":"p_19","code":"TOR_BRIDGE_TIMEOUT","err":"tor: unable to connect to any bridge: timed out"}
{"time":"2026-11-01T10:16:00.031Z","level":"error","source":"core","msg":"connection failed","op":"connect","conn":"7f3a","profile":"p_19","code":"TOR_BRIDGE_TIMEOUT","err":"tor: unable to connect to any bridge: timed out","notify":true}
```

A level that is off costs nothing: the `debug` and `warn` lines are never even formatted.

## 5. A panic

If `wardkeep-tor` panics, its panic hook writes one `fatal` record (always with `caller`, `stack`,
`notify:true`) and the process exits. The stack is shortened here.

```jsonl
{"event":"log","time":"2026-11-01T10:20:42.518Z","level":"fatal","source":"tor","msg":"index out of bounds: the len is 3 but the index is 3","notify":true,"thread":"tokio-runtime-worker","caller":"src/main.rs:140","stack":"   0: std::backtrace::Backtrace::force_capture\n   1: wardkeep_tor::logging::install_panic_hook::{{closure}}\n   ..."}
```

The `\n` in `stack` is an escaped newline, so the record still takes one line. A Go panic in the core looks
the same, with `source:"core"`; the core recovers it and ends only that piece of work.

## 6. The server

`wardkeep-server` writes the same records to its log file, with `source:"server"` and, for things about one
VPN user, `user` (the admin's own data):

```jsonl
{"time":"2026-11-01T09:00:00.123Z","level":"info","source":"server","msg":"started","op":"start"}
{"time":"2026-11-01T09:42:17.880Z","level":"warn","source":"server","msg":"quota reached","op":"traffic","user":"alice"}
{"time":"2026-11-01T11:05:03.004Z","level":"error","source":"sing-box","msg":"inbound stopped","target":"vless-in","code":"PORT_IN_USE","err":"listen: address already in use","notify":true}
```

The `notify:true` line becomes an alert in the TUI and in `GET /api/v1/alerts`.

## Reading one record

| Key | In the panic example | Meaning |
|---|---|---|
| `event` | `log` | only on Tor's stdout: "this line is a log record, not an event" |
| `time` | `2026-11-01T10:20:42.518Z` | UTC, milliseconds |
| `level` | `fatal` | `trace` < `debug` < `info` < `warn` < `error` < `fatal` |
| `source` | `tor` | which part of Wardkeep |
| `msg` | `index out of bounds ...` | what happened, in plain words |
| `notify` | `true` | nothing handled it: tell the user |
| `thread` | `tokio-runtime-worker` | an extra key; readers show unknown keys as `key=value` |
| `caller` | `src/main.rs:140` | where |
| `stack` | `0: ...` | the stack trace |
