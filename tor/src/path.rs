//! The circuit a stream rides, as the app shows it: relay by relay, each with a role and a country.
//!
//! Only roles and country codes leave this process (no addresses, no fingerprints): the core puts them in
//! the connection state, and the UI draws the route on the globe.

use serde_json::{Value, json};

/// The role of hop `i` of `n`: the first is the bridge when bridges are on, else the guard; the last is the
/// exit; whatever lies between is a middle relay.
pub fn role(i: usize, n: usize, bridged: bool) -> &'static str {
    if i == 0 {
        if bridged { "bridge" } else { "guard" }
    } else if i + 1 == n {
        "exit"
    } else {
        "middle"
    }
}

/// The `path` event for the core: one entry per hop, `country` null when it is not known (a bridge behind
/// Snowflake or a front has no real address to look up).
pub fn event(countries: &[Option<String>], bridged: bool) -> Value {
    let n = countries.len();
    let hops: Vec<Value> = countries
        .iter()
        .enumerate()
        .map(|(i, c)| json!({"role": role(i, n, bridged), "country": c}))
        .collect();
    json!({"event": "path", "hops": hops})
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_relays_are_guard_middle_exit() {
        let roles: Vec<_> = (0..3).map(|i| role(i, 3, false)).collect();
        assert_eq!(roles, ["guard", "middle", "exit"]);
    }

    #[test]
    fn a_bridge_replaces_the_guard() {
        let roles: Vec<_> = (0..3).map(|i| role(i, 3, true)).collect();
        assert_eq!(roles, ["bridge", "middle", "exit"]);
    }

    #[test]
    fn a_longer_path_has_many_middles() {
        let roles: Vec<_> = (0..4).map(|i| role(i, 4, false)).collect();
        assert_eq!(roles, ["guard", "middle", "middle", "exit"]);
    }

    #[test]
    fn the_event_carries_only_roles_and_countries() {
        let v = event(&[Some("DE".into()), None, Some("NL".into())], true);
        assert_eq!(
            v,
            json!({"event": "path", "hops": [
                {"role": "bridge", "country": "DE"},
                {"role": "middle", "country": null},
                {"role": "exit", "country": "NL"},
            ]})
        );
    }
}
