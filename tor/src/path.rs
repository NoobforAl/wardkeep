//! The circuit a stream rides, as the app shows it: relay by relay, each with a role and a country.
//!
//! Only roles and country codes leave this process (no addresses, no fingerprints): the core puts them in
//! the connection state, and the UI draws the route on the globe.

use serde_json::{Value, json};

/// The role of hop `index` of `hops`: the first is the bridge when bridges are on, else the guard; the last
/// is the exit; whatever lies between is a middle relay.
pub fn role(index: usize, hops: usize, bridged: bool) -> &'static str {
    if index == 0 {
        if bridged { "bridge" } else { "guard" }
    } else if index + 1 == hops {
        "exit"
    } else {
        "middle"
    }
}

/// The `path` event for the core: one entry per hop, `country` null when it is not known (a bridge behind
/// Snowflake or a front has no real address to look up).
pub fn event(countries: &[Option<impl AsRef<str>>], bridged: bool) -> Value {
    let hops: Vec<Value> = countries
        .iter()
        .enumerate()
        .map(|(index, country)| {
            let role = role(index, countries.len(), bridged);
            json!({"role": role, "country": country.as_ref().map(AsRef::as_ref)})
        })
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
        let path = event(&[Some("DE"), None, Some("NL")], true);
        assert_eq!(
            path,
            json!({"event": "path", "hops": [
                {"role": "bridge", "country": "DE"},
                {"role": "middle", "country": null},
                {"role": "exit", "country": "NL"},
            ]})
        );
    }
}
