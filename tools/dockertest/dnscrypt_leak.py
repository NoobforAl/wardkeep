#!/usr/bin/env python3
"""Docker leak test of DNSCrypt through the VPN, on a real Linux TUN.

Four containers (names and networks start with "wkdnsc"):

    client --- net A --- server --- net B --- resolver (omnitun-server's own DNSCrypt resolver)
                                       |
                                      web   (the only name anyone asks for)

The client runs this repo's core engine (`omnitun run -tun -dns sdns://...`) in TUN mode, with a
Shadowsocks profile of the server. Its /etc/resolv.conf names an address (203.0.113.53) that
nothing answers: a lookup that is not caught by the VPN can only leave through the network card.
The resolver and the web server are on a network the client cannot reach at all.

What it checks, with tcpdump on the client's network card for the whole run:

  control    without the VPN the same lookup leaves as plain DNS (so the capture can see a leak)
  answer     with the VPN, the name is resolved (to the web server) and the page is fetched
  leak       nothing else leaves the card: every packet is to or from the VPN server; no port 53,
             and nothing to the resolver's or the web server's address
  resolver   on the resolver, the queries arrive from the VPN server's address, never the client's

It does not test Anonymized DNSCrypt (that needs a relay container; core/dnscrypt's tests cover the
relay path in process).

    python tools/dockertest/dnscrypt_leak.py          # build, run, clean up
    python tools/dockertest/dnscrypt_leak.py --keep   # leave the containers running

Needs Docker (Linux containers with /dev/net/tun), Go and Python 3. Nothing on the host is touched
except Docker objects named wkdnsc-*; the exit code is 1 if any check fails.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD = os.path.join(HERE, "build")
TAGS = "with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_acme,badlinkname,tfogo_checklinkname0"

P = "wkdnsc"
NET_A, NET_B = P + "-a", P + "-b"
CLIENT, SERVER, RESOLVER, WEB = P + "-client", P + "-server", P + "-resolver", P + "-web"
IMG, IMG_WEB = P + "-img", P + "-img-web"
CLIENT_A, SERVER_A, SERVER_B, RESOLVER_B, WEB_B = "172.31.7.10", "172.31.7.2", "198.19.7.2", "198.19.7.5", "198.19.7.10"
NOWHERE = "203.0.113.53"  # the "DNS server" in the client's resolv.conf: a documentation address, outside the LAN ranges the VPN leaves alone
NAME = P + "-web"          # the Docker name of the web server, which the resolver's Docker DNS knows

failures = []


def sh(*cmd, check=True, timeout=300):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    if check and r.returncode != 0:
        raise RuntimeError("%s\n%s%s" % (" ".join(cmd), r.stdout, r.stderr))
    return r


def dx(container, script, check=True, timeout=120):
    return sh("docker", "exec", container, "sh", "-c", script, check=check, timeout=timeout)


def check(ok, what, detail=""):
    print("  %s  %s%s" % ("ok  " if ok else "FAIL", what, ("  (" + detail + ")") if detail else ""))
    if not ok:
        failures.append(what)


def cleanup():
    out = sh("docker", "ps", "-a", "--filter", "name=^%s-" % P, "--format", "{{.Names}}", check=False).stdout
    for c in out.split():
        sh("docker", "rm", "-f", c, check=False)
    for n in (NET_A, NET_B):
        sh("docker", "network", "rm", n, check=False)


def build():
    os.makedirs(BUILD, exist_ok=True)
    env = dict(os.environ, GOOS="linux", GOARCH="amd64", CGO_ENABLED="0")
    print("building the Linux binaries...")
    for name, pkg in (("omnitun-server", "./cmd/omnitun-server"), ("omnitun", "./cmd/omnitun")):
        subprocess.run(["go", "build", "-tags", TAGS, "-trimpath", "-ldflags", "-s -w -checklinkname=0",
                        "-o", os.path.join(BUILD, name), pkg], cwd=ROOT, env=env, check=True)
    shutil.copy(os.path.join(HERE, "web.py"), os.path.join(BUILD, "web.py"))
    print("building the images...")
    sh("docker", "build", "-q", "-t", IMG, "-f", os.path.join(HERE, "Dockerfile.dnsc"), BUILD, timeout=1200)
    sh("docker", "build", "-q", "-t", IMG_WEB, "-f", os.path.join(HERE, "Dockerfile.web"), BUILD, timeout=1200)


def wait_for(container, path, text, seconds=60):
    log = ""
    for _ in range(seconds * 2):
        time.sleep(0.5)
        log = dx(container, "cat %s" % path, check=False).stdout
        if text in log:
            return log
    return log


def start_world():
    cleanup()
    sh("docker", "network", "create", "--subnet", "172.31.7.0/24", NET_A)
    sh("docker", "network", "create", "--subnet", "198.19.7.0/24", NET_B)
    sh("docker", "run", "-d", "--name", WEB, "--network", NET_B, "--ip", WEB_B, IMG_WEB)

    # The resolver: the server's own DNSCrypt resolver, alone on network B. Its upstream is
    # Docker's DNS, which knows the web server's name.
    sh("docker", "run", "-d", "--name", RESOLVER, "--network", NET_B, "--ip", RESOLVER_B, "--cap-add", "NET_ADMIN", IMG, "sleep", "infinity")
    dx(RESOLVER, "omnitun-server --data /data init --host %s --protocols dnscrypt" % RESOLVER_B)
    sh("docker", "exec", "-d", RESOLVER, "sh", "-c", "omnitun-server --data /data run > /run.log 2>&1")
    log = wait_for(RESOLVER, "/run.log", "serving dnscrypt")
    print("resolver:", [l for l in log.splitlines() if "dnscrypt" in l][:2])
    stamp = dx(RESOLVER, "omnitun-server --data /data link --stamp").stdout.strip()

    # The VPN server: Shadowsocks only, on both networks.
    sh("docker", "run", "-d", "--name", SERVER, "--network", NET_A, "--ip", SERVER_A, "--cap-add", "NET_ADMIN", IMG, "sleep", "infinity")
    sh("docker", "network", "connect", "--ip", SERVER_B, NET_B, SERVER)
    dx(SERVER, "omnitun-server --data /data init --host %s --protocols shadowsocks --first-user alice" % SERVER_A)
    sh("docker", "exec", "-d", SERVER, "sh", "-c", "omnitun-server --data /data run > /run.log 2>&1")
    wait_for(SERVER, "/run.log", "Ctrl+C")
    d = json.loads(dx(SERVER, "omnitun-server --data /data link alice --json").stdout)
    link = next(l["url"] for l in d["links"] if l["protocol"] == "shadowsocks")

    # The client: only on network A, TUN allowed, and a resolv.conf that names a dead end.
    sh("docker", "run", "-d", "--name", CLIENT, "--network", NET_A, "--ip", CLIENT_A, "--cap-add", "NET_ADMIN",
       "--device", "/dev/net/tun", IMG, "sleep", "infinity")
    dx(CLIENT, "echo 'nameserver %s' > /etc/resolv.conf" % NOWHERE)
    return stamp, link


def capture_start(container, name, expr=""):
    dx(container, "rm -f /%s.pcap" % name)
    sh("docker", "exec", "-d", container, "sh", "-c", "tcpdump -i eth0 -nn -U -w /%s.pcap %s 2>/%s.err" % (name, expr, name))
    time.sleep(1.5)


def capture_stop(container, name):
    time.sleep(1)
    dx(container, "pkill tcpdump; sleep 0.5", check=False)


def packets(container, name, expr):
    out = dx(container, "tcpdump -nn -r /%s.pcap %s 2>/dev/null" % (name, expr), check=False).stdout
    return [l for l in out.splitlines() if l.strip()]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--keep", action="store_true", help="leave the containers running")
    args = ap.parse_args()
    try:
        build()
        stamp, link = start_world()
        print("DNS stamp of the resolver:", stamp)

        print("\ncontrol: the same lookup without the VPN")
        capture_start(CLIENT, "control", "")
        dx(CLIENT, "getent hosts %s" % NAME, check=False, timeout=60)
        capture_stop(CLIENT, "control")
        plain = packets(CLIENT, "control", "udp and dst host %s and dst port 53" % NOWHERE)
        check(len(plain) > 0, "the capture sees a plain DNS query leaving the card", "%d packets" % len(plain))

        print("\nthe VPN: omnitun run -tun -dns <stamp>")
        capture_start(CLIENT, "vpn", "")
        capture_start(RESOLVER, "resolver", "port 5443")
        sh("docker", "exec", "-d", CLIENT, "sh", "-c", "omnitun run -tun -dns '%s' '%s' > /omnitun.log 2>&1" % (stamp, link))
        log = wait_for(CLIENT, "/omnitun.log", "state: connected", 90)
        up = "state: connected" in log
        check(up, "the tunnel is up", "" if up else log[-600:])
        if up:
            time.sleep(2)
            r = dx(CLIENT, "getent hosts %s" % NAME, check=False, timeout=60)
            check(WEB_B in r.stdout, "the name resolves through DNSCrypt to the web server", r.stdout.strip() or r.stderr.strip())
            r = dx(CLIENT, "curl -s -m 20 http://%s:8080/" % NAME, check=False, timeout=60)
            check("client=" in r.stdout, "the page is fetched by that name", r.stdout.strip())
            for n in ("a", "b", "c"):
                dx(CLIENT, "getent hosts %s" % NAME, check=False, timeout=60)
            print("engine log:", [l for l in dx(CLIENT, "cat /omnitun.log").stdout.splitlines() if "DNS" in l][:3])
        capture_stop(CLIENT, "vpn")
        capture_stop(RESOLVER, "resolver")

        print("\nleak check on the client's network card")
        total = packets(CLIENT, "vpn", "ip")
        via_server = packets(CLIENT, "vpn", "ip and host %s" % SERVER_A)
        other = packets(CLIENT, "vpn", "ip and not host %s" % SERVER_A)
        check(len(via_server) > 0, "the VPN traffic is there", "%d IPv4 packets to or from the VPN server" % len(via_server))
        # The first seconds, before the tunnel is up, may hold the lookup of the control step's retries; those
        # carry the dead-end address and are in the control capture, not this one (it started afterwards).
        check(len(other) == 0, "every IPv4 packet is to or from the VPN server", "; ".join(other[:3]))
        dns53 = packets(CLIENT, "vpn", "port 53")
        check(len(dns53) == 0, "no packet on port 53", "; ".join(dns53[:3]))
        to_resolver = packets(CLIENT, "vpn", "host %s or host %s or host %s" % (RESOLVER_B, WEB_B, NOWHERE))
        check(len(to_resolver) == 0, "nothing to the resolver, the web server or the dead-end DNS address", "; ".join(to_resolver[:3]))
        v6 = [l for l in packets(CLIENT, "vpn", "ip6 and not icmp6")]
        check(len(v6) == 0, "no IPv6 data packets", "; ".join(v6[:3]))

        print("\nthe resolver's side")
        seen = packets(RESOLVER, "resolver", "dst port 5443")
        sources = sorted({l.split(" IP ")[1].split(" > ")[0].rsplit(".", 1)[0] for l in seen if " IP " in l})
        check(len(seen) > 0, "the resolver was asked", "%d packets" % len(seen))
        check(sources == [SERVER_B], "the queries come from the VPN server only", "sources: %s" % sources)
        print("\n%d packets on the client card in all, %d to or from the VPN server" % (len(total), len(via_server)))
    finally:
        if args.keep:
            print("containers left running (names start with %s-)" % P)
        else:
            cleanup()
    print("\nRESULT:", "FAILED: " + "; ".join(failures) if failures else "all checks passed")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
