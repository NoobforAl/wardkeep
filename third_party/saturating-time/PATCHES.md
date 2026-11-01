# Wardkeep patches to saturating-time

Upstream: the `saturating-time` crate 0.5.0 from Arti (https://gitlab.torproject.org/tpo/core/arti.git, as
published on crates.io). License: MIT OR Apache-2.0 (see `Cargo.toml`). `tor/Cargo.toml` uses this copy through
`[patch.crates-io]`.

1. `find_limit` (`src/internal.rs`) never ended on Windows. It looks for the earliest and latest `SystemTime` by
   adding or subtracting ever smaller steps and stops only when a 1 ns step fails; Windows' `SystemTime` counts
   in 100 ns intervals, so a step below that succeeds without moving the value, and the loop went on forever.
   Arti reaches it when it parses a consensus (`Preamble::validity_time_range`), so a Tor bootstrap on Windows
   stopped at "fetching a consensus" with one core busy. A step that does not move the value now counts as
   reaching the limit (the internal trait gains a `PartialEq` bound for it).

Drop this copy once upstream has the fix.
