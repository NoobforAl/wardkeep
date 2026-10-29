#!/usr/bin/env python3
"""Docker end-to-end tests of the server's VPN protocols with real clients on real Linux.

A server container (this repo's Linux binary, with a TUN device and NAT) and client
containers with the standard client for each protocol: OpenVPN, WireGuard (wg-quick)
and AmneziaWG (our own client on a kernel TUN). A client reaches a "web" container on a network only the server can reach, through
the tunnel; the answer shows the address the web server saw, which proves the server's
NAT. Then the server's traffic accounting is read.

Three parts (each can be left out):

  single      one user at a time, per protocol: the tunnel, live connections and speed, and
              that the traffic was counted for the user and for the protocol
  concurrent  three users (alice, bob, carol) connected at the same time through three
              different protocols, each downloading a different amount: every user gets
              their own numbers (live and counted), then one user is disabled and another
              is reset while the third keeps working
  ipv6        the tunnels' IPv6 side (see the end of the output for what was and was not
              possible on this machine's Docker)

    python tools/dockertest/run.py                  # everything, every protocol
    python tools/dockertest/run.py wireguard amneziawg   # some protocols
    python tools/dockertest/run.py --only concurrent
    python tools/dockertest/run.py --keep           # leave the containers running

Names: containers and networks start with $E2E_PREFIX (default "e2e"), so a second copy
(or another project's) never meets this one.

Needs Docker, Go and Python 3. About 10 minutes the first time (images).
"""
import argparse
import concurrent.futures as cf
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

PREFIX = os.environ.get("E2E_PREFIX", "e2e")
NET_A, NET_B = PREFIX + "-a", PREFIX + "-b"   # clients + server / server + "internet"
SERVER, WEB = PREFIX + "-server", PREFIX + "-web"
IMG_SERVER, IMG_CLIENT, IMG_WEB = PREFIX + "-img-server", PREFIX + "-img-client", PREFIX + "-img-web"
SERVER_A, SERVER_B, WEB_B = "172.30.0.2", "198.18.0.2", "198.18.0.10"
# The same networks for IPv6. The "internet" side uses the documentation prefix 2001:db8::/32: the server's NAT
# refuses clients the unique local addresses (fc00::/7) of private networks, as it refuses 10/8 for IPv4.
V6_A, V6_B = "fdb0:e2e:a::/64", "2001:db8:e2e:b::/64"
SERVER_A6, SERVER_B6, WEB_B6 = "fdb0:e2e:a::2", "2001:db8:e2e:b::2", "2001:db8:e2e:b::10"
# What the tunnel's IPv6 address of each protocol starts with.
V6_PREFIX = {"wireguard": "fd30:0:0:1:", "amneziawg": "fd31:0:0:1:", "openvpn-udp": "fd18:0:0:1:",
             "openvpn-tcp": "fd19:0:0:1:"}
PROTOCOLS = ["openvpn-udp", "openvpn-tcp", "wireguard", "amneziawg"]
USERS = ["alice", "bob", "carol"]
# Who connects through what at the same time; a round with fewer than two chosen protocols is skipped.
ROUNDS = [["openvpn-udp", "wireguard", "amneziawg"], ["amneziawg", "openvpn-tcp", "wireguard"]]
MB = 1 << 20


def sh(*cmd, check=True, timeout=300):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    if check and r.returncode != 0:
        raise RuntimeError("%s\n%s%s" % (" ".join(cmd), r.stdout, r.stderr))
    return r


def dx(container, script, check=True, timeout=120):
    """Runs a shell script in a container."""
    return sh("docker", "exec", container, "sh", "-c", script, check=check, timeout=timeout)


def build():
    os.makedirs(BUILD, exist_ok=True)
    env = dict(os.environ, GOOS="linux", GOARCH="amd64", CGO_ENABLED="0")
    print("building the Linux binaries...")
    subprocess.run(["go", "build", "-tags", TAGS, "-trimpath", "-ldflags", "-s -w -checklinkname=0",
                    "-o", os.path.join(BUILD, "omnitun-server"), "./cmd/omnitun-server"], cwd=ROOT, env=env, check=True)
    subprocess.run(["go", "build", "-trimpath", "-o", os.path.join(BUILD, "awgclient"), "./tools/dockertest/awgclient"],
                   cwd=ROOT, env=env, check=True)
    shutil.copy(os.path.join(HERE, "web.py"), os.path.join(BUILD, "web.py"))
    print("building the images...")
    for tag, dockerfile in ((IMG_SERVER, "Dockerfile.server"), (IMG_CLIENT, "Dockerfile.client"), (IMG_WEB, "Dockerfile.web")):
        sh("docker", "build", "-q", "-t", tag, "-f", os.path.join(HERE, dockerfile), BUILD, timeout=1200)


def containers():
    out = sh("docker", "ps", "-a", "--filter", "name=^%s-" % PREFIX, "--format", "{{.Names}}", check=False).stdout
    return [n for n in out.split() if n]


def cleanup():
    for c in containers():
        sh("docker", "rm", "-f", c, check=False)
    for n in (NET_A, NET_B):
        sh("docker", "network", "rm", n, check=False)


# Whether Docker gave the networks IPv6; the answer decides what the ipv6 part can do.
IPV6 = {"networks": False, "why": ""}


def create_network(name, subnet, subnet6):
    r = sh("docker", "network", "create", "--subnet", subnet, "--ipv6", "--subnet", subnet6, name, check=False)
    if r.returncode == 0:
        return True
    IPV6["why"] = (r.stderr or r.stdout).strip()[-300:]
    sh("docker", "network", "create", "--subnet", subnet, name)
    return False


def start_world(first_user="alice"):
    cleanup()
    ok_a = create_network(NET_A, "172.30.0.0/24", V6_A)
    ok_b = create_network(NET_B, "198.18.0.0/24", V6_B)
    IPV6["networks"] = ok_a and ok_b
    if not IPV6["networks"]:  # one of them has no IPv6: use neither, so the addresses below are consistent
        cleanup()
        sh("docker", "network", "create", "--subnet", "172.30.0.0/24", NET_A)
        sh("docker", "network", "create", "--subnet", "198.18.0.0/24", NET_B)
        IPV6["networks"] = False
    ip6 = lambda a: ["--ip6", a] if IPV6["networks"] else []
    sh("docker", "run", "-d", "--name", WEB, "--network", NET_B, "--ip", WEB_B, *ip6(WEB_B6), IMG_WEB)
    sh("docker", "run", "-d", "--name", SERVER, "--network", NET_A, "--ip", SERVER_A, *ip6(SERVER_A6),
       "--cap-add", "NET_ADMIN", "--device", "/dev/net/tun", "--sysctl", "net.ipv4.ip_forward=1",
       "--sysctl", "net.ipv6.conf.all.forwarding=1", "--sysctl", "net.ipv6.conf.all.disable_ipv6=0",
       IMG_SERVER, "sleep", "infinity")
    sh("docker", "network", "connect", "--ip", SERVER_B, *ip6(SERVER_B6), NET_B, SERVER)
    protos = ",".join(PROTOCOLS)
    print(dx(SERVER, "omnitun-server --data /data init --host %s --protocols %s --first-user %s" % (SERVER_A, protos, first_user)).stdout[-300:])
    for u in USERS:
        if u != first_user:
            dx(SERVER, "omnitun-server --data /data user add %s" % u)
    sh("docker", "exec", "-d", SERVER, "sh", "-c", "omnitun-server --data /data run > /var/log/run.log 2>&1")
    log = ""
    for _ in range(40):
        time.sleep(1)
        log = dx(SERVER, "cat /var/log/run.log", check=False).stdout
        if "Ctrl+C" in log:
            break
    print("--- server log ---")
    print(log.strip())
    print("------------------")
    print("IPv6 on the Docker networks:", "yes" if IPV6["networks"] else "NO (%s)" % IPV6["why"])


# ------------------------------------------------------------------ the server's side


def cli(*args, check=False):
    return dx(SERVER, "omnitun-server --data /data " + " ".join(args), check=check)


def cli_json(*args):
    r = cli("--json", *args)
    try:
        return json.loads(r.stdout)
    except ValueError:
        return None


def user_row(name):
    return next((u for u in (cli_json("user", "list") or []) if u["name"] == name), None)


def proto_row(key):
    return next((p for p in (cli_json("proto", "list") or []) if p["key"] == key), None)


def month_bytes(name):
    return (user_row(name) or {"usage": {"month_bytes": 0}})["usage"]["month_bytes"]


def proto_bytes(key):
    return (proto_row(key) or {}).get("month_bytes", 0)


def credentials(user):
    """The subscription URL and the password of a user, as the server hands them out now."""
    d = json.loads(dx(SERVER, "omnitun-server --data /data link %s --json" % user).stdout)
    # No link of the protocols under test carries the password (OpenVPN signs in with it), so it is read from the state.
    state = json.loads(dx(SERVER, "cat /data/state.json").stdout)
    # A signed subscription link ends in "#pk=<key>"; the config files are paths under the link without it.
    return d["subscription"].split("#", 1)[0], next(u["password"] for u in state["users"] if u["name"] == user)


def wait_reload(mark, seconds=40):
    """Waits until the running server has applied the changes made after log line `mark`: it saw a state change, started
    everything again, and then stayed quiet for a few seconds."""
    seen, last, quiet_since = False, 0, time.time()
    for _ in range(seconds * 2):
        lines = dx(SERVER, "cat /var/log/run.log", check=False).stdout.splitlines()[mark:]
        if len(lines) != last:
            last, quiet_since = len(lines), time.time()
        reload_at = [i for i, l in enumerate(lines) if "state changed, reloading" in l]
        seen = bool(reload_at) and any("serving " in l for l in lines[reload_at[-1]:])
        if seen and time.time() - quiet_since >= 5:
            return True
        time.sleep(0.5)
    return False


def server_log_lines():
    return len(dx(SERVER, "cat /var/log/run.log", check=False).stdout.splitlines())


# ------------------------------------------------------------------ the clients


class Client:
    """One client container: a user connecting through a protocol."""

    def __init__(self, user, proto):
        self.user, self.proto = user, proto
        self.name = "%s-client-%s" % (PREFIX, user)
        self.sub = self.pw = None
        self.v6 = False  # also route the IPv6 test network into the tunnel

    def start(self):
        """The clients open a TUN device and set its addresses and routes."""
        sh("docker", "rm", "-f", self.name, check=False)
        sh("docker", "run", "-d", "--name", self.name, "--network", NET_A, "--cap-add", "NET_ADMIN", "--device", "/dev/net/tun",
           "--sysctl", "net.ipv6.conf.all.disable_ipv6=0", IMG_CLIENT, "sleep", "infinity")
        self.refresh()

    def refresh(self):
        self.sub, self.pw = credentials(self.user)

    def dx(self, script, **kw):
        return dx(self.name, script, **kw)

    def bg(self, script):
        sh("docker", "exec", "-d", self.name, "sh", "-c", script)

    def wait_for(self, script, what, seconds=25):
        for _ in range(seconds):
            if self.dx(script, check=False).returncode == 0:
                return True
            time.sleep(1)
        print("  [%s] timed out waiting for %s" % (self.user, what))
        return False

    def fetch(self, path, dest):
        return self.dx("curl -sfk %s -o %s" % (path, dest))

    def stop_tunnel(self):
        """Ends whatever the client runs, so it can connect again (with what it has in /tmp)."""
        self.dx("timeout 10 wg-quick down /tmp/wg0.conf >/dev/null 2>&1; "
                "pkill -x openvpn; pkill -x awgclient; sleep 1; "
                "ip -br link | awk '{print $1}' | grep -E '^(omnitun|wg)' | xargs -r -n1 ip link del; "
                "rm -f /tmp/*.log; true", check=False)

    def through_tunnel(self, seconds=8, v6=False):
        url = "http://[%s]:8080/" % WEB_B6 if v6 else "http://%s:8080/" % WEB_B
        return self.dx("curl -s %s --max-time %d %s" % ("-6" if v6 else "", seconds, url), check=False).stdout.strip()

    def tunnel_ok(self, seconds=8):
        return self.through_tunnel(seconds) == "client=%s" % SERVER_B


def t_openvpn(proto):
    def run(c, fetch=True):
        if fetch:
            c.fetch(c.sub + "/%s.ovpn" % proto, "/tmp/c.ovpn")
            c.dx("printf '%s\\n%s\\n' > /tmp/auth && chmod 600 /tmp/auth" % (c.user, c.pw))
        c.dx("openvpn --config /tmp/c.ovpn --auth-user-pass /tmp/auth --daemon --log /tmp/ovpn.log "
             "--pull-filter ignore redirect-gateway --pull-filter ignore dhcp-option "
             "--route 198.18.0.0 255.255.255.0 %s--verb 3" % ("--route-ipv6 %s " % V6_B if c.v6 else ""))
        return c.wait_for("grep -q 'Initialization Sequence Completed' /tmp/ovpn.log", "OpenVPN to come up", 30)
    return run


def t_wireguard(c, fetch=True):
    if fetch:
        c.fetch(c.sub + "/wireguard.conf", "/tmp/wg0.conf")
        routes = "198.18.0.0/24" + (", " + V6_B if c.v6 else "")
        c.dx("sed -i '/^DNS/d;s#^AllowedIPs.*#AllowedIPs = %s#' /tmp/wg0.conf" % routes)
    r = c.dx("wg-quick up /tmp/wg0.conf 2>&1", check=False)
    if r.returncode != 0:
        print(r.stdout)
        return False
    return True


def t_amneziawg(c, fetch=True):
    if fetch:
        c.fetch(c.sub + "/amneziawg.conf", "/tmp/awg.conf")
    c.bg("awgclient -conf /tmp/awg.conf -route 198.18.0.0/24%s > /tmp/awg.log 2>&1" % ("," + V6_B if c.v6 else ""))
    return c.wait_for("grep -q 'awgclient: up' /tmp/awg.log", "the AmneziaWG client", 15)


CLIENTS = {
    "openvpn-udp": t_openvpn("openvpn-udp"), "openvpn-tcp": t_openvpn("openvpn-tcp"),
    "wireguard": t_wireguard, "amneziawg": t_amneziawg,
}


def connect(c, fetch=True):
    """Connects and checks that a request reaches the web server through the server's NAT."""
    ok = CLIENTS[c.proto](c, fetch)
    answer = c.through_tunnel() if ok else ""
    print("  [%s via %s] through the tunnel: %r (want client=%s)" % (c.user, c.proto, answer, SERVER_B))
    return ok and answer == "client=%s" % SERVER_B


def download(c, mb, rate_kb, loop_seconds=0):
    """Starts a download of mb megabytes in the client, paced by the web server to rate_kb KB/s (or, with loop_seconds,
    repeated for that long); the result lands in /tmp/dl.result as 'bytes exit-code'."""
    one = "curl -s -o /dev/null -w '%%{size_download}' \"http://%s:8080/big?mb=%d&kbps=%d\"" % (WEB_B, mb, rate_kb)
    if loop_seconds:
        c.bg("rm -f /tmp/dl.result; timeout %d sh -c 'while true; do %s >/dev/null; done'; echo done > /tmp/dl.result" % (loop_seconds, one))
    else:
        c.bg("rm -f /tmp/dl.result; r=$(%s); echo \"$r $?\" > /tmp/dl.result" % one)


def download_result(c, wait=60):
    for _ in range(wait):
        r = c.dx("cat /tmp/dl.result 2>/dev/null", check=False).stdout.split()
        if r:
            return r
        time.sleep(1)
    return None


def diagnostics(c):
    print("--- diagnostics for %s (%s) ---" % (c.user, c.proto))
    print(c.dx("ip -br addr; ip route; tail -n 25 /tmp/*.log 2>/dev/null", check=False).stdout[-2500:])
    print(dx(SERVER, "tail -n 25 /data/server.log; tail -n 15 /var/log/run.log", check=False).stdout[-2500:])


# ------------------------------------------------------------------ part 1: one user at a time


def watch_live(user, seconds=24):
    """Slow downloads run; while they do, the server must show the user's connection and speed."""
    best = {"connections": 0, "speed": 0}
    for _ in range(seconds // 3):
        time.sleep(3)
        u = user_row(user)
        if u:
            us = u["usage"]
            best["connections"] = max(best["connections"], us["connections"])
            best["speed"] = max(best["speed"], us["up_bps"] + us["down_bps"])
    return best


def part_single(protos, quick):
    rows = []
    for name in protos:
        print("\n=== single user: %s ===" % name)
        c = Client("alice", name)
        c.start()
        tunnel = live_ok = counted_ok = False
        try:
            before_user, before_proto = month_bytes("alice"), proto_bytes(name)
            tunnel = connect(c)
            if tunnel and not quick:
                download(c, 2, 300, loop_seconds=24)
                live = watch_live("alice")
                for _ in range(40):
                    if c.dx("pgrep -x curl", check=False).returncode != 0:
                        break
                    time.sleep(1)
                sh("docker", "rm", "-f", c.name, check=False)  # the client leaves
                time.sleep(13)  # the server counts, then saves its stats file
                attributed = month_bytes("alice") - before_user
                counted_proto = proto_bytes(name) - before_proto
                live_ok = live["connections"] >= 1 and live["speed"] > 0
                counted_ok = attributed >= 2 * MB
                print("  live while downloading: %d connection(s), %.0f KB/s" % (live["connections"], live["speed"] / 1024))
                print("  counted for alice: %.1f MB; for the protocol: %.1f MB (each download was 2 MB)" % (attributed / MB, counted_proto / MB))
        except Exception as e:  # noqa: BLE001
            print("  error:", e)
        if not tunnel:
            diagnostics(c)
        sh("docker", "rm", "-f", c.name, check=False)
        rows.append((name, tunnel, None if quick else live_ok, None if quick else counted_ok))
    return rows


# ------------------------------------------------------------------ part 2: three users at once


class Check:
    """A list of named results; every failure is kept and printed in the end."""

    def __init__(self):
        self.rows = []

    def __call__(self, name, ok, detail=""):
        self.rows.append((name, bool(ok), detail))
        print("  %s %s%s" % ("PASS" if ok else "FAIL", name, (": " + detail) if detail else ""))
        return ok


def sample_live(users, seconds, every=2.0):
    """Reads the users' live numbers while the downloads run: the best of each, and whether all of them were connected at once."""
    best = {u: {"connections": 0, "speed": 0} for u in users}
    together = 0
    t_end = time.time() + seconds
    while time.time() < t_end:
        rows = {r["name"]: r["usage"] for r in (cli_json("user", "list") or [])}
        if all(rows.get(u, {}).get("connections", 0) >= 1 for u in users):
            together += 1
        for u in users:
            us = rows.get(u)
            if us:
                best[u]["connections"] = max(best[u]["connections"], us["connections"])
                best[u]["speed"] = max(best[u]["speed"], us["up_bps"] + us["down_bps"])
        time.sleep(every)
    return best, together


def part_concurrent(group, check, quick):
    """Three clients at the same time, each a different user on a different protocol."""
    clients = [Client(u, p) for u, p in zip(USERS, group)]
    print("\n=== at the same time: %s ===" % ", ".join("%s via %s" % (c.user, c.proto) for c in clients))
    try:
        for c in clients:
            c.start()
        with cf.ThreadPoolExecutor(len(clients)) as pool:
            up = list(pool.map(connect, clients))
        for c, ok in zip(clients, up):
            check("%s connects via %s with the others" % (c.user, c.proto), ok)
            if not ok:
                diagnostics(c)
        if not all(up):
            return
        # The web server saw them all come from the server's address, so tell the clients apart by what they moved.
        alive = [c.tunnel_ok() for c in clients]
        check("all %d tunnels carry traffic together" % len(clients), all(alive))
        if quick:
            return

        # --- every user gets their own numbers
        # MB; the same duration for all (about 38 s). The server's stats file, which the CLI reads, is written every
        # 10 seconds, so a download has to outlast several of them for the live numbers to show.
        sizes = {"alice": 8, "bob": 4, "carol": 2}
        base_user = {c.user: month_bytes(c.user) for c in clients}
        base_proto = {c.proto: proto_bytes(c.proto) for c in clients}
        for c in clients:
            download(c, sizes[c.user], sizes[c.user] * 27)
        best, together = sample_live([c.user for c in clients], 36, every=1.0)
        results = {c.user: download_result(c) for c in clients}
        for c in clients:
            r = results[c.user]
            check("%s downloaded %d MB" % (c.user, sizes[c.user]), r is not None and r[-1] == "0" and int(r[0]) == sizes[c.user] * MB, str(r))
        check("the server showed all of them connected at once", together >= 1, "%d samples" % together)
        for c in clients:
            check("%s has live connection and speed" % c.user, best[c.user]["connections"] >= 1 and best[c.user]["speed"] > 0,
                  "%d connection(s), %.0f KB/s" % (best[c.user]["connections"], best[c.user]["speed"] / 1024))
        time.sleep(13)  # the server counts, then saves its stats file
        got = {c.user: month_bytes(c.user) - base_user[c.user] for c in clients}
        for c in clients:
            want = sizes[c.user] * MB
            # Counted bytes are the tunnel's packets both ways: the download plus headers and acknowledgements.
            check("%s is counted for their own %d MB" % (c.user, sizes[c.user]), want <= got[c.user] <= want * 1.4 + MB // 2,
                  "%.2f MB counted" % (got[c.user] / MB))
            by_proto = proto_bytes(c.proto) - base_proto[c.proto]
            check("%s is counted for %s too" % (c.user, c.proto), want <= by_proto <= want * 1.4 + MB // 2, "%.2f MB" % (by_proto / MB))
        check("the numbers are told apart (alice > bob > carol)", got["alice"] > got["bob"] > got["carol"],
              ", ".join("%s %.1f MB" % (u, got[u] / MB) for u in USERS))

        # --- one user disabled, another reset, the third works on
        if len(clients) == 3:
            isolate(clients, check)
    finally:
        for c in clients:
            sh("docker", "rm", "-f", c.name, check=False)


def isolate(clients, check):
    alice, bob, carol = clients
    print("  -- bob is disabled and carol is reset while alice downloads")
    download(alice, 8, 200)                         # about 40 s
    download(bob, 2, 100, loop_seconds=120)
    download(carol, 2, 100, loop_seconds=120)
    time.sleep(5)
    mark = server_log_lines()
    cli("user", "disable", "bob", check=True)
    time.sleep(3)
    cli("user", "reset", "carol", check=True)
    reloaded = wait_reload(mark)
    check("the server applied both changes", reloaded)

    # alice: did her transfer survive?
    r = download_result(alice, 90)
    survived = r is not None and r[-1] == "0" and int(r[0]) == 8 * MB
    print("  note: alice's %d MB transfer %s" % (8, "finished: the restart that applies the changes did not interrupt her" if survived
          else "did not finish (%s): the restart that applies the changes interrupts connected users" % (r,)))
    if not alice.tunnel_ok(10):
        # A client that does not reconnect by itself is started again, like a person would.
        alice.stop_tunnel()
        check("alice connects again with what she had", connect(alice, fetch=False))
    else:
        check("alice carries traffic after the changes", True)
    for c in (bob, carol):
        c.dx("pkill -f '[w]hile true'; pkill -x curl; true", check=False)

    # bob and carol: cut off, and the old credentials do not come back in
    bob.stop_tunnel()
    check("disabled bob cannot connect", not connect(bob, fetch=False))
    carol.stop_tunnel()
    check("carol cannot connect with her old credentials", not connect(carol, fetch=False))
    bob.stop_tunnel()
    carol.stop_tunnel()

    # and the way back: enabling gives bob the same credentials back, a reset gave carol new ones
    mark = server_log_lines()
    cli("user", "enable", "bob", check=True)
    wait_reload(mark)
    check("alice can still reach the web server", alice.tunnel_ok(10) or (alice.stop_tunnel() or connect(alice, fetch=False)))
    check("enabled bob connects with his old credentials", connect(bob, fetch=False))
    carol.refresh()
    check("carol connects with her new credentials", connect(carol, fetch=True))


# ------------------------------------------------------------------ part 3: IPv6


def v6_addresses(c):
    """The global IPv6 addresses the tunnel gave the client: those of every interface but the container's own address
    on the Docker network."""
    out = c.dx("ip -6 -o addr show scope global | awk '{print $4}'", check=False).stdout.split()
    return [a for a in out if not a.startswith(V6_A.split("/")[0][:-2])]


def part_ipv6(protos, check, quick):
    """IPv6 inside the tunnels: the server hands out the addresses, forwards and masquerades IPv6, and counts it for the user."""
    print("\n=== IPv6 ===")
    if not check("the Docker networks have IPv6", IPV6["networks"], IPV6["why"]):
        print("  NOT TESTED: this Docker has no IPv6 on user-defined networks")
        return
    # A server with IPv6 off hands out no IPv6 address.
    sub, _ = credentials("alice")
    conf = dx(SERVER, "curl -s %s/wireguard.conf" % sub, check=False).stdout
    check("with IPv6 off the WireGuard config has no IPv6 address", "Address" in conf and ":" not in conf.split("Address", 1)[1].split("\n", 1)[0], "")
    mark = server_log_lines()
    cli("proto", "ipv6", "on", check=True)
    check("the server applies the IPv6 setting", wait_reload(mark))

    sizes_mb = 2
    for name in protos:
        c = Client("alice", name)
        c.v6 = True
        print("\n  -- %s" % name)
        c.start()
        try:
            up = connect(c)
            check("%s connects with IPv6 on" % name, up)
            if not up:
                diagnostics(c)
                continue
            addrs = v6_addresses(c)
            check("%s gets an IPv6 address in the tunnel" % name, any(a.startswith(V6_PREFIX[name]) for a in addrs), ", ".join(addrs))
            answer = c.through_tunnel(10, v6=True)
            check("%s reaches the IPv6 web server through the tunnel, behind the server's address" % name,
                  answer == "client=%s" % SERVER_B6, repr(answer))
            if answer == "client=%s" % SERVER_B6 and not quick:
                base = month_bytes("alice")
                r = c.dx("curl -s -6 -o /dev/null --max-time 40 -w '%%{size_download}' http://[%s]:8080/big?mb=%d" % (WEB_B6, sizes_mb), check=False).stdout
                time.sleep(13)
                counted = month_bytes("alice") - base
                check("%s: %d MB over IPv6 is counted for the user" % (name, sizes_mb), r == str(sizes_mb * MB) and sizes_mb * MB <= counted <= sizes_mb * MB * 1.4 + MB // 2,
                      "downloaded %s, counted %.2f MB" % (r, counted / MB))
            check("%s still carries IPv4" % name, c.tunnel_ok())
        finally:
            sh("docker", "rm", "-f", c.name, check=False)
    cli("proto", "ipv6", "off", check=True)


# ------------------------------------------------------------------ main


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("protocols", nargs="*", default=PROTOCOLS)
    ap.add_argument("--keep", action="store_true", help="leave the containers running")
    ap.add_argument("--no-build", action="store_true")
    ap.add_argument("--quick", action="store_true", help="only check the tunnels, not the server's live numbers and accounting")
    ap.add_argument("--only", choices=["single", "concurrent", "ipv6"], help="run one part")
    args = ap.parse_args()
    if shutil.which("docker") is None or sh("docker", "info", check=False).returncode != 0:
        sys.exit("Docker is not running")
    unknown = [p for p in args.protocols if p not in PROTOCOLS]
    if unknown:
        sys.exit("unknown protocol(s) %s (have: %s)" % (", ".join(unknown), ", ".join(PROTOCOLS)))
    parts = [args.only] if args.only else ["single", "concurrent", "ipv6"]
    if not args.no_build:
        build()
    start_world()
    ok = True
    try:
        if "single" in parts:
            rows = part_single(args.protocols, args.quick)
            print("\n=== one user at a time ===")
            print("  %-12s %-8s %-18s %s" % ("protocol", "tunnel", "live conn + speed", "counted for the user"))
            mark = lambda v: "-" if v is None else ("PASS" if v else "FAIL")
            for name, tunnel, live_ok, counted_ok in rows:
                print("  %-12s %-8s %-18s %s" % (name, mark(tunnel), mark(live_ok), mark(counted_ok)))
                ok = ok and tunnel and live_ok is not False and counted_ok is not False
        if "concurrent" in parts:
            check = Check()
            for group in ROUNDS:
                group = [p for p in group if p in args.protocols]
                if len(group) >= 2:
                    part_concurrent(group, check, args.quick)
            print("\n=== at the same time ===")
            for name, passed, detail in check.rows:
                print("  %s %s" % ("PASS" if passed else "FAIL", name))
            ok = ok and all(p for _, p, _ in check.rows) and bool(check.rows)
        if "ipv6" in parts:
            check = Check()
            part_ipv6([p for p in PROTOCOLS if p in args.protocols], check, args.quick)
            print("\n=== IPv6 ===")
            for name, passed, detail in check.rows:
                print("  %s %s" % ("PASS" if passed else "FAIL", name))
            ok = ok and all(p for _, p, _ in check.rows)
    finally:
        if not args.keep:
            cleanup()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
