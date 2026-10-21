# Contributing

Wardkeep is a small beta project, and most of what follows is about its temperament rather than about process.
There is no CLA, no template to fill in and no review board. There is an expectation that a change arrives
explained.

Before anything else: [`README.md`](README.md) has how to build and test each part, and
[`docs/release.md`](docs/release.md) has how a release is made. A change that quietly weakens what the app promises
(that traffic goes through the tunnel, that DNS does not leak, that secrets stay on the device or the server) is the
one kind of change that will simply be reverted.

## AI is used here, and that is fine

Part of this codebase was written with AI assistance, and a contributor using it is welcome to. There is nothing to
declare and no separate standard to meet.

What is not welcome is **unread output**. Whoever opens the pull request is the person answering for what is in
it, every line, including the ones they did not type. If a reviewer asks why something is the way it is, "the model
wrote it" is not an answer; it is the point at which the change stops.

The practical test is simple: can you explain what each hunk does, and what would break if it were removed? If not,
that hunk is not ready, whatever produced it.

## Run the tests before opening anything

```bash
make test        # the Go code: core and server
make app-test    # the Flutter app: flutter analyze and flutter test
make tor         # the Rust Tor module (only if you touched tor/)
```

Go always builds with the sing-box feature tags, so use `make` (or `./scripts/go.ps1` on Windows) and not a plain
`go test`; a plain one fails or tests something different.

```bash
make fix
```

Formats and auto-fixes the Go, Dart and Rust code, then re-lints. Run it last, before committing.

CI runs the same things (Go on Windows, Rust, Flutter, and a license check of every dependency that
ships). It is the **second** check, not the first: a red CI on a pull request that was never run locally wastes a
reviewer's attention on something the author could have seen in a minute.

If a change touches the server, a protocol or the tunnel, also run the end-to-end suite, which needs Docker:

```bash
make docker-e2e
```

If you changed dependencies, run `make notices` and commit the regenerated license list.

## Be careful, and say what you changed

Much of this codebase is load-bearing in ways that are not local. The parts where a small change reaches furthest:

- **`core/singbox` and `core/engine`**: they turn profiles into the sing-box configuration and run it. A mistake
  here does not break a connection, it makes one that goes around the VPN: a DNS query, an IPv6 packet or a bypass
  rule that leaves outside the tunnel. Anything that can do that is a security change, whatever else it is.
- **`core/control`**: the UI talks to the core over loopback with a token. What it accepts, and who can reach it,
  is a security boundary.
- **`core/importer` and `core/links`**: they parse share links, subscriptions and config files from strangers.
  Treat every input as hostile and keep a test for the odd one.
- **`core/winsvc` and `core/killswitch`**: they run as administrator on Windows. They have been unit-tested but
  never exercised with real elevation, so read the code twice and say what you could not run.
- **`server/` and `cmd/omnitun-server`**: users, quotas, the web API and the firewall and NAT setup. Anything
  that touches credentials, tokens or what the API exposes needs its reasoning written down.
- **`third_party/veepin`**: a patched copy of a library. Changes go in `PATCHES.md` too, so the patch can be
  carried to a newer upstream.
- **Credentials and keys**: never commit a keystore, a `.env` or a password. `scripts/android-keystore.sh` and the
  release docs say where they live and that they are git-ignored.

A change in those places wants its reasoning in the **commit message**, not only in the diff. `git log` is where
this project keeps the "why": say what was wrong, what was done about it, and what was considered and rejected.
Subject lines are short, start with the area (`Core:`, `Server:`, `App:`, `CI:`, `Installer:`) and say what
changed, not how.

Comments follow the same rule. Explain what the code cannot say for itself: the constraint, the failure that
motivated it, the option that looks better and is not. Do not narrate the line below.

## Say what you did not try

This project is tested in code, in Docker and on one real Android phone, and nothing more. Say in the pull request
what you ran and on what, and what you did not (another Android version, a real server, IPv6, an elevated Windows
run). "Not tried" is a perfectly good thing to write; an untested claim is not.

## Translations

The 13 languages live in `app/lib/l10n/*.arb`. Eight of them were machine-written and have not been reviewed by
native speakers, so a correction from one is among the most useful things you can send. Change the `.arb` file and
leave the generated `app_localizations_*.dart` to `flutter gen-l10n`.

## License

Contributions are under the **MIT license**, the same as the rest. There is nothing to sign; opening a pull request
is the agreement. The software comes with **no warranty**, and that includes your contribution.

## Security

Do not open a public issue or pull request for a vulnerability. Report it privately to the maintainer (use the
repository's Security tab, "Report a vulnerability", or contact the owner through their GitHub profile), and give
the project a chance to fix it before it is published.
