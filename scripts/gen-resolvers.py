#!/usr/bin/env python3
"""Regenerate app/lib/state/dns_resolvers.dart, the bundled list of DNSCrypt
resolvers and Anonymized DNSCrypt relays.

The lists are the public ones from the DNSCrypt project
(https://github.com/DNSCrypt/dnscrypt-resolvers). Each is downloaded together
with its minisign signature and is used only if the signature is valid for the
project's published public key; a list that fails the check stops the script.
The app bundles the result, because GitHub (where the lists live) may be
blocked on the user's network.

  python scripts/gen-resolvers.py                 # download, verify, write
  python scripts/gen-resolvers.py --offline DIR   # use DIR/public-resolvers.md(.minisig) and relays.md(.minisig)
  python scripts/gen-resolvers.py --check         # download and verify only

Only standard-library Python is needed (the Ed25519 check is written out
below, from RFC 8032; it verifies one signature in a few milliseconds).

What is kept: DNSCrypt servers that declare DNSSEC, no logging and no
filtering, reachable over IPv4, at most MAX_PER_OPERATOR per operator so one
operator's many nodes do not fill the list; and IPv4 relays, at most
MAX_RELAYS_PER_OPERATOR per operator. The country comes from the list's
description of each entry (the lists have no country field); an anycast
service has none.
"""

import argparse
import base64
import hashlib
import os
import re
import struct
import sys
import urllib.request
from datetime import datetime, timezone

BASE = "https://download.dnscrypt.info/resolvers-list/v3/"
LISTS = ("public-resolvers.md", "relays.md")
# Published at https://github.com/DNSCrypt/dnscrypt-resolvers and in every
# list's header ("minisign_key"); the same key signs both lists.
PUBLIC_KEY = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
MAX_PER_OPERATOR = 4
MAX_RELAYS_PER_OPERATOR = 3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "lib", "state", "dns_resolvers.dart")


# ---------------------------------------------------------------- Ed25519 ---
# RFC 8032, section 6 (verification only).

_P = 2**255 - 19
_L = 2**252 + 27742317777372353535851937790883648493
_D = -121665 * pow(121666, _P - 2, _P) % _P
_I = pow(2, (_P - 1) // 4, _P)


def _recover_x(y, sign):
    if y >= _P:
        return None
    x2 = (y * y - 1) * pow(_D * y * y + 1, _P - 2, _P) % _P
    if x2 == 0:
        return None if sign else 0
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P != 0:
        x = x * _I % _P
    if (x * x - x2) % _P != 0:
        return None
    if (x & 1) != sign:
        x = _P - x
    return x


_GY = 4 * pow(5, _P - 2, _P) % _P
_GX = _recover_x(_GY, 0)
_G = (_GX, _GY, 1, _GX * _GY % _P)


def _add(a, b):
    A = (a[1] - a[0]) * (b[1] - b[0]) % _P
    B = (a[1] + a[0]) * (b[1] + b[0]) % _P
    C = 2 * a[3] * b[3] * _D % _P
    D = 2 * a[2] * b[2] % _P
    E, F, G, H = B - A, D - C, D + C, B + A
    return (E * F % _P, G * H % _P, F * G % _P, E * H % _P)


def _mul(s, p):
    q = (0, 1, 1, 0)
    while s > 0:
        if s & 1:
            q = _add(q, p)
        p = _add(p, p)
        s >>= 1
    return q


def _encode(p):
    zi = pow(p[2], _P - 2, _P)
    x, y = p[0] * zi % _P, p[1] * zi % _P
    return int.to_bytes(y | ((x & 1) << 255), 32, "little")


def _decode(s):
    if len(s) != 32:
        return None
    y = int.from_bytes(s, "little")
    sign = y >> 255
    y &= (1 << 255) - 1
    x = _recover_x(y, sign)
    if x is None:
        return None
    return (x, y, 1, x * y % _P)


def ed25519_verify(public, message, signature):
    if len(public) != 32 or len(signature) != 64:
        return False
    a = _decode(public)
    r = _decode(signature[:32])
    if a is None or r is None:
        return False
    s = int.from_bytes(signature[32:], "little")
    if s >= _L:
        return False
    h = int.from_bytes(hashlib.sha512(signature[:32] + public + message).digest(), "little") % _L
    return _encode(_mul(s, _G)) == _encode(_add(r, _mul(h, a)))


# --------------------------------------------------------------- minisign ---


def minisign_verify(public_key_b64, message, sig_file_text):
    """Check a minisign signature file against message; returns the trusted comment."""
    pk = base64.b64decode(public_key_b64)
    if len(pk) != 42 or pk[:2] != b"Ed":
        raise ValueError("not a minisign public key")
    key_id, key = pk[2:10], pk[10:]

    lines = sig_file_text.replace("\r", "").split("\n")
    if len(lines) < 4 or not lines[0].startswith("untrusted comment:"):
        raise ValueError("not a minisign signature file")
    sig = base64.b64decode(lines[1])
    if len(sig) != 74:
        raise ValueError("bad signature length")
    algo, sig_key_id, signature = sig[:2], sig[2:10], sig[10:]
    if sig_key_id != key_id:
        raise ValueError("signed with a different key (id %s, expected %s)" % (sig_key_id.hex(), key_id.hex()))
    if algo == b"ED":  # pre-hashed variant
        signed = hashlib.blake2b(message, digest_size=64).digest()
    elif algo == b"Ed":
        signed = message
    else:
        raise ValueError("unknown signature algorithm")
    if not ed25519_verify(key, signed, signature):
        raise ValueError("the signature of the list is NOT valid")

    prefix = "trusted comment: "
    if not lines[2].startswith(prefix):
        raise ValueError("no trusted comment")
    trusted = lines[2][len(prefix):]
    global_sig = base64.b64decode(lines[3])
    if not ed25519_verify(key, signature + trusted.encode(), global_sig):
        raise ValueError("the trusted comment is NOT signed")
    return trusted


# ------------------------------------------------------------ list parsing ---


def fetch(name, offline):
    if offline:
        with open(os.path.join(offline, name), "rb") as f:
            body = f.read()
        with open(os.path.join(offline, name + ".minisig"), "r", encoding="utf-8") as f:
            sig = f.read()
        return body, sig
    def get(url):
        req = urllib.request.Request(url, headers={"User-Agent": "wardkeep-gen-resolvers"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read()
    return get(BASE + name), get(BASE + name + ".minisig").decode("utf-8")


def parse_list(text):
    entries = []
    for block in re.split(r"^## ", text, flags=re.M)[1:]:
        lines = block.split("\n")
        name = lines[0].strip()
        stamps = [l.strip() for l in lines[1:] if l.strip().startswith("sdns://")]
        desc = " ".join(l.strip() for l in lines[1:] if l.strip() and not l.strip().startswith("sdns://"))
        entries.append((name, desc, stamps))
    return entries


def decode_stamp(stamp):
    """Returns (kind, props, addr, provider) for DNSCrypt stamps, (0x81, 0, addr, '') for relays, else None."""
    s = stamp[len("sdns://"):]
    raw = base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))
    kind = raw[0]
    pos = 1

    def lp():
        nonlocal pos
        n = raw[pos]
        v = raw[pos + 1:pos + 1 + n]
        if len(v) != n:
            raise ValueError("truncated stamp")
        pos += 1 + n
        return v

    if kind == 0x01:
        props = struct.unpack("<Q", raw[1:9])[0]
        pos = 9
        addr = lp().decode()
        key = lp()
        provider = lp().decode()
        if len(key) != 32 or pos != len(raw):
            raise ValueError("bad DNSCrypt stamp")
        return kind, props, addr, provider
    if kind == 0x81:
        addr = lp().decode()
        if pos != len(raw):
            raise ValueError("bad relay stamp")
        return kind, 0, addr, ""
    return None


COUNTRIES = {
    "Albania": "AL", "Andorra": "AD", "Argentina": "AR", "Armenia": "AM", "Australia": "AU", "Austria": "AT",
    "Bangladesh": "BD", "Belgium": "BE", "Brazil": "BR", "Bulgaria": "BG", "Canada": "CA", "Chile": "CL",
    "China": "CN", "Colombia": "CO", "Croatia": "HR", "Cyprus": "CY", "Czech": "CZ", "Denmark": "DK",
    "Estonia": "EE", "Finland": "FI", "France": "FR", "Georgia": "GE", "Germany": "DE", "Greece": "GR",
    "Hong Kong": "HK", "Hungary": "HU", "Iceland": "IS", "India": "IN", "Indonesia": "ID", "Ireland": "IE",
    "Israel": "IL", "Italy": "IT", "Japan": "JP", "Kenya": "KE", "Latvia": "LV", "Lithuania": "LT",
    "Luxembourg": "LU", "Malaysia": "MY", "Mexico": "MX", "Moldova": "MD", "Netherlands": "NL",
    "New Zealand": "NZ", "Nigeria": "NG", "Norway": "NO", "Pakistan": "PK", "Peru": "PE",
    "Philippines": "PH", "Poland": "PL", "Portugal": "PT", "Romania": "RO", "Russia": "RU",
    "Serbia": "RS", "Singapore": "SG", "Slovakia": "SK", "Slovenia": "SI", "South Africa": "ZA",
    "South Korea": "KR", "Korea": "KR", "Spain": "ES", "Sweden": "SE", "Switzerland": "CH",
    "Taiwan": "TW", "Thailand": "TH", "Turkey": "TR", "Ukraine": "UA", "United Kingdom": "GB",
    "England": "GB", "Scotland": "GB", "UK": "GB", "United States": "US", "USA": "US", "US": "US",
    "Vietnam": "VN",
}
US_STATES = set("AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC".split())
ANYCAST = re.compile(r"multiple locations|around the world|anycast|global", re.I)


def country_of(desc):
    if ANYCAST.search(desc):
        return ""
    best, at = "", len(desc) + 1
    for name, code in COUNTRIES.items():
        m = re.search(r"\b" + re.escape(name) + r"\b", desc)
        if m and m.start() < at:
            best, at = code, m.start()
    if not best and re.search(r",\s*(%s)\b" % "|".join(sorted(US_STATES)), desc):
        best = "US"
    return best


# Names often carry the country (a TLD or a short code) when the description does not.
NAME_HINTS = {
    "au": "AU", "at": "AT", "be": "BE", "ca": "CA", "ch": "CH", "de": "DE", "es": "ES", "fi": "FI", "fr": "FR",
    "it": "IT", "jp": "JP", "mx": "MX", "nl": "NL", "pl": "PL", "ru": "RU", "se": "SE", "sg": "SG", "uk": "GB",
    "ams": "NL", "conoha": "JP", "adelaide": "AU", "swiss": "CH",
}


def country_of_name(name, desc):
    c = country_of(desc)
    if c or ANYCAST.search(desc):
        return c
    for token in re.split(r"[-.]", name.lower()):
        if token in NAME_HINTS:
            return NAME_HINTS[token]
    return ""


def operator(name):
    n = re.sub(r"^(anon-|doh-)", "", name)
    return re.sub(r"\d+$", "", re.split(r"[-.]", n)[0].lower())


def resolvers(entries):
    out, seen, per_op = [], set(), {}
    for name, desc, stamps in entries:
        if not stamps:
            continue
        try:
            dec = decode_stamp(stamps[0])
        except Exception:
            continue
        if not dec or dec[0] != 0x01:
            continue
        _, props, addr, provider = dec
        if props & 7 != 7 or addr.startswith("["):
            continue
        if provider in seen:
            continue
        op = operator(name)
        if per_op.get(op, 0) >= MAX_PER_OPERATOR:
            continue
        per_op[op] = per_op.get(op, 0) + 1
        seen.add(provider)
        out.append((name, country_of_name(name, desc), props, stamps[0]))
    out.sort(key=lambda r: (r[1] == "", r[1], r[0]))
    return out


def relays(entries):
    out, seen, per_op = [], set(), {}
    for name, desc, stamps in entries:
        if not stamps:
            continue
        try:
            dec = decode_stamp(stamps[0])
        except Exception:
            continue
        if not dec or dec[0] != 0x81 or dec[2].startswith("["):
            continue
        if dec[2] in seen:
            continue
        op = operator(name)
        if per_op.get(op, 0) >= MAX_RELAYS_PER_OPERATOR:
            continue
        per_op[op] = per_op.get(op, 0) + 1
        seen.add(dec[2])
        out.append((name, country_of_name(name, desc), 0, stamps[0]))
    out.sort(key=lambda r: (r[1] == "", r[1], r[0]))
    return out


def dart_string(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def render(res, rel, meta):
    lines = [
        "// GENERATED by scripts/gen-resolvers.py. Do not edit by hand.",
        "//",
        "// Public DNSCrypt resolvers and Anonymized DNSCrypt relays from",
        "// https://github.com/DNSCrypt/dnscrypt-resolvers, each list checked against its",
        "// minisign signature (key %s) before it was written here." % PUBLIC_KEY,
        "// Resolvers: DNSSEC, no logging, no filtering, IPv4. Countries come from the lists' descriptions.",
    ]
    for name, sha, trusted in meta:
        lines.append("// %s  sha256 %s  signed: %s" % (name, sha, trusted))
    lines += [
        "",
        "/// One entry of the bundled lists: a resolver (or relay) and its DNS stamp.",
        "class DnsListEntry {",
        "  const DnsListEntry(this.name, this.country, this.props, this.stamp);",
        "",
        "  /// The list's name for it, e.g. `scaleway-fr`.",
        "  final String name;",
        "",
        "  /// ISO 3166 country code, empty when the service is anycast or unknown.",
        "  final String country;",
        "",
        "  /// Declared properties: bit 0 DNSSEC, bit 1 no logs, bit 2 no filtering.",
        "  final int props;",
        "",
        "  /// The `sdns://` stamp.",
        "  final String stamp;",
        "",
        "  bool get dnssec => props & 1 != 0;",
        "  bool get noLog => props & 2 != 0;",
        "  bool get noFilter => props & 4 != 0;",
        "}",
        "",
        "/// When the lists were signed (UTC, from the signed comment of the resolvers list).",
        "const String kDnsListsSigned = %s;" % dart_string(meta[0][2]),
        "",
        "/// DNSCrypt resolvers: DNSSEC, no logs, no filtering.",
        "const List<DnsListEntry> kDnsCryptResolvers = [",
    ]
    for n, c, p, s in res:
        lines.append("  DnsListEntry(%s, %s, %d, %s)," % (dart_string(n), dart_string(c), p, dart_string(s)))
    lines += ["];", "", "/// Anonymized DNSCrypt relays.", "const List<DnsListEntry> kDnsRelays = ["]
    for n, c, p, s in rel:
        lines.append("  DnsListEntry(%s, %s, %d, %s)," % (dart_string(n), dart_string(c), p, dart_string(s)))
    lines += ["];", ""]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--offline", metavar="DIR", help="read the lists and signatures from DIR instead of downloading")
    ap.add_argument("--check", action="store_true", help="verify only, write nothing")
    args = ap.parse_args()

    parsed, meta = {}, []
    for name in LISTS:
        body, sig = fetch(name, args.offline)
        try:
            trusted = minisign_verify(PUBLIC_KEY, body, sig)
        except ValueError as e:
            sys.exit("%s: %s" % (name, e))
        sha = hashlib.sha256(body).hexdigest()
        stamp = ""
        m = re.search(r"timestamp:(\d+)", trusted)
        if m:
            stamp = datetime.fromtimestamp(int(m.group(1)), timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
        print("%s: signature OK (%s, %s)" % (name, trusted, sha[:12]))
        meta.append((name, sha, stamp or trusted))
        parsed[name] = parse_list(body.decode("utf-8", "replace"))
    res = resolvers(parsed["public-resolvers.md"])
    rel = relays(parsed["relays.md"])
    print("%d resolvers, %d relays kept" % (len(res), len(rel)))
    if not res or not rel:
        sys.exit("nothing usable in the lists; refusing to write an empty table")
    if args.check:
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(res, rel, meta))
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
