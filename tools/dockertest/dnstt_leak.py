#!/usr/bin/env python3
"""Docker test of the DNS tunnel (dnstt) on a real Linux TUN.

Three containers (names and networks start with "wkdnst"):

    client --- net A --- server --- net B --- web
                (UDP 53)  (omnitun-server, the DNS tunnel on)

The client runs this repo's core engine (`omnitun run -tun -select <id> <dnstt link>`) in TUN mode. The
link names the server as its resolver (all a resolver does is pass the queries to the zone's server).
The web server is on a network the client cannot reach.

What it checks, with tcpdump on the client's network card and on its TUN device for the whole run:

  control    without the VPN the client cannot reach the web server
  answer     with the tunnel, the web page is fetched
  card       every packet on the card is DNS to or from the server (UDP port 53): the tunnel's own
             sockets leave through the network, and nothing else does (no TCP, no other port, nothing
             to the web server)
  loop       the tunnel's DNS packets never enter the TUN device (the tunnel does not run inside the
             VPN it serves)
  server     the server's log shows a session and a stream

    python tools/dockertest/dnstt_leak.py          # build, run, clean up
    python tools/dockertest/dnstt_leak.py --keep   # leave the containers running

Needs Docker (Linux containers with /dev/net/tun), Go and Python 3. Nothing on the host is touched except
Docker objects named wkdnst-*; the exit code is 1 if any check fails.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD = os.path.join(HERE, "build")
TAGS = "with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_acme,badlinkname,tfogo_checklinkname0"

P = "wkdnst"
NET_A, NET_B = P + "-a", P + "-b"
CLIENT, SERVER, WEB = P + "-client", P + "-server", P + "-web"
IMG, IMG_WEB = P + "-img", P + "-img-web"
CLIENT_A, SERVER_A, SERVER_B, WEB_B = "172.31.8.10", "172.31.8.2", "198.19.8.2", "198.19.8.10"
DOMAIN = "t.example.com"

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
    sh("docker", "network", "create", "--subnet", "172.31.8.0/24", NET_A)
    sh("docker", "network", "create", "--subnet", "198.19.8.0/24", NET_B)
    sh("docker", "run", "-d", "--name", WEB, "--network", NET_B, "--ip", WEB_B, IMG_WEB)

    # The server: on both networks; the DNS tunnel on UDP port 53 (it runs as root here, so it may bind it).
    sh("docker", "run", "-d", "--name", SERVER, "--network", NET_A, "--ip", SERVER_A, "--cap-add", "NET_ADMIN", IMG, "sleep", "infinity")
    sh("docker", "network", "connect", "--ip", SERVER_B, NET_B, SERVER)
    dx(SERVER, "omnitun-server --data /data init --host %s --protocols shadowsocks --first-user alice" % SERVER_A)
    dx(SERVER, "omnitun-server --data /data dnstt domain %s && omnitun-server --data /data proto enable dnstt" % DOMAIN)
    sh("docker", "exec", "-d", SERVER, "sh", "-c", "omnitun-server --data /data run > /run.log 2>&1")
    log = wait_for(SERVER, "/run.log", "serving the DNS tunnel")
    print("server:", [l for l in log.splitlines() if "DNS tunnel" in l][:2])
    d = json.loads(dx(SERVER, "omnitun-server --data /data link alice --json").stdout)
    link = next(l["url"] for l in d["links"] if l["protocol"] == "dnstt")
    # The client has no internet: its resolver is the server itself.
    u = urllib.parse.urlsplit(link)
    q = [(k, v) for k, v in urllib.parse.parse_qsl(u.query) if k != "resolver"]
    q.append(("resolver", "udp://%s:53" % SERVER_A))
    link = urllib.parse.urlunsplit((u.scheme, u.netloc, u.path, urllib.parse.urlencode(q), u.fragment))

    # The client: only on network A, TUN allowed.
    sh("docker", "run", "-d", "--name", CLIENT, "--network", NET_A, "--ip", CLIENT_A, "--cap-add", "NET_ADMIN",
       "--device", "/dev/net/tun", IMG, "sleep", "infinity")
    return link


def capture_start(container, name, iface, expr=""):
    dx(container, "rm -f /%s.pcap" % name)
    sh("docker", "exec", "-d", container, "sh", "-c", "tcpdump -i %s -nn -U -w /%s.pcap %s 2>/%s.err" % (iface, name, expr, name))
    time.sleep(1.5)


def capture_stop(container):
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
        link = start_world()
        profile = json.loads(dx(CLIENT, "omnitun import - <<'EOF'\n%s\nEOF" % link).stdout)
        pid = profile[0]["id"]
        print("the profile:", pid, profile[0].get("name"))

        print("\ncontrol: without the VPN")
        r = dx(CLIENT, "curl -s -m 5 http://%s:8080/" % WEB_B, check=False, timeout=30)
        check("client=" not in r.stdout, "the client cannot reach the web server by itself", r.stdout.strip()[:80])

        print("\nthe tunnel: omnitun run -tun -select <id>")
        capture_start(CLIENT, "card", "eth0")
        sh("docker", "exec", "-d", CLIENT, "sh", "-c", "omnitun run -tun -select %s '%s' > /omnitun.log 2>&1" % (pid, link))
        log = wait_for(CLIENT, "/omnitun.log", "state: connected", 120)
        up = "state: connected" in log
        check(up, "the tunnel is up", "" if up else log[-800:])
        if up:
            tun = dx(CLIENT, "ip -o link show | grep -o 'tun[0-9]*' | head -1", check=False).stdout.strip() or "tun0"
            capture_start(CLIENT, "tun", tun)
            time.sleep(1)
            r = dx(CLIENT, "curl -s -m 60 http://%s:8080/" % WEB_B, check=False, timeout=90)
            check("client=" in r.stdout, "the page is fetched through the DNS tunnel", r.stdout.strip()[:120])
            r = dx(CLIENT, "curl -s -m 60 http://%s:8080/" % WEB_B, check=False, timeout=90)
            check("client=" in r.stdout, "and again", r.stdout.strip()[:120])
            capture_stop(CLIENT)

            print("\nthe client's network card")
            on_card = packets(CLIENT, "card", "ip")
            to_server_dns = packets(CLIENT, "card", "udp and host %s and port 53" % SERVER_A)
            other = packets(CLIENT, "card", "ip and not (udp and host %s and port 53)" % SERVER_A)
            check(len(to_server_dns) > 0, "the tunnel's DNS packets are there", "%d packets" % len(to_server_dns))
            check(len(other) == 0, "every IPv4 packet is DNS to or from the server", "; ".join(other[:3]))
            leak = packets(CLIENT, "card", "host %s" % WEB_B)
            check(len(leak) == 0, "nothing to the web server", "; ".join(leak[:3]))
            v6 = packets(CLIENT, "card", "ip6 and not icmp6")
            check(len(v6) == 0, "no IPv6 data packets", "; ".join(v6[:3]))

            print("\nthe TUN device")
            inside = packets(CLIENT, "tun", "host %s" % SERVER_A)
            check(len(inside) == 0, "the tunnel's own DNS packets never enter the VPN", "; ".join(inside[:3]))
            through = packets(CLIENT, "tun", "host %s" % WEB_B)
            check(len(through) > 0, "the page's packets do go through the VPN", "%d packets" % len(through))

            print("\nthe server")
            slog = dx(SERVER, "cat /run.log").stdout
            check("begin session" in slog and "begin stream" in slog, "the server saw a session and a stream")
            print("\n%d IPv4 packets on the client card in all, %d of them the tunnel's DNS" % (len(on_card), len(to_server_dns)))
        else:
            capture_stop(CLIENT)
    finally:
        if args.keep:
            print("containers left running (names start with %s-)" % P)
        else:
            cleanup()
    print("\nRESULT:", "FAILED: " + "; ".join(failures) if failures else "all checks passed")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
