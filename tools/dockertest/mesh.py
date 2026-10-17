#!/usr/bin/env python3
"""Docker end-to-end test of the mesh (Tailscale/Headscale) client of the core.

A Headscale control server, two of our cores (omnitun-svc built with the
with_tailscale tag, started with a tailscale:// link and driven through the
control protocol like the app does) and one stock Tailscale client, all in
containers on one Docker network. A fifth container, the "web", sits on a second
network that only the stock client can reach. The test shows that

  1. both of our cores join the network with the pre-auth key, and list each other
     and the stock client (name, MagicDNS name, address, online);
  2. our cores reach each other (Tailscale ping: latency, direct path);
  3. a core reaches a web server on the stock client by its MagicDNS name and by
     its address, through the core's local proxy port;
  4. the stock client reaches our core (tailscale ping);
  5. "use as exit": the web on the second network is unreachable for the core, then
     reachable through the stock client as an exit device (the web sees the
     exit's address), and unreachable again when the exit is cleared.

    python tools/dockertest/mesh.py              # everything
    python tools/dockertest/mesh.py --keep       # leave the containers running
    python tools/dockertest/mesh.py --no-build   # reuse the images
    python tools/dockertest/mesh.py --remove-images

Needs Docker, Go and Python 3. Everything it creates is called wk-mesh-*; it
removes only that. There is no NAT router between the nodes (they find each other
on the Docker network) and no DERP relay: path selection through NATs and relays is
not tested here.
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
BUILD = os.path.join(HERE, "build", "mesh")
TAGS = ("with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_acme,"
        "badlinkname,tfogo_checklinkname0,with_tailscale")

P = "wk-mesh-"
NET, NET2, NET3 = P + "net", P + "net2", P + "net3"
# "The internet" behind the exit device: the web sits on a third network, reached through a
# router that only the exit device can see. (An exit node does not forward to its own directly
# connected networks, nor to private or reserved ranges such as 198.18.0.0/15 or 203.0.113.0/24,
# so these are public addresses nobody uses (US DoD space, not routed); they exist only inside
# these containers.)
SUBNET, SUBNET2, SUBNET3 = "172.31.77.0/24", "11.77.77.0/24", "11.77.78.0/24"
HS, A, C, B, R, WEB = P + "hs", P + "a", P + "c", P + "b", P + "router", P + "web"
B_NET2_IP, R_NET2_IP, R_NET3_IP, WEB_IP = "11.77.77.2", "11.77.77.3", "11.77.78.2", "11.77.78.10"
CLIENT_IMAGE, WEB_IMAGE = P + "client", P + "web"
DOMAIN = "mesh.wk.test"
PROXY = 2080


def sh(*cmd, check=True, timeout=300):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    if check and r.returncode != 0:
        raise RuntimeError("%s\n%s%s" % (" ".join(cmd), r.stdout, r.stderr))
    return r


def dx(container, script, check=True, timeout=120):
    return sh("docker", "exec", container, "sh", "-c", script, check=check, timeout=timeout)


def build():
    os.makedirs(BUILD, exist_ok=True)
    env = dict(os.environ, GOOS="linux", GOARCH="amd64", CGO_ENABLED="0")
    print("building the Linux binaries (with the Tailscale tag)...")
    for name in ("omnitun-svc", "meshctl"):
        pkg = "./cmd/omnitun-svc" if name == "omnitun-svc" else "./tools/dockertest/meshctl"
        subprocess.run(["go", "build", "-tags", TAGS, "-trimpath", "-ldflags", "-s -w -checklinkname=0",
                        "-o", os.path.join(BUILD, name), pkg], cwd=ROOT, env=env, check=True)
    shutil.copy(os.path.join(HERE, "web.py"), os.path.join(BUILD, "web.py"))
    print("building the images...")
    sh("docker", "build", "-q", "-t", CLIENT_IMAGE, "-f", os.path.join(HERE, "Dockerfile.mesh"), BUILD, timeout=1200)
    sh("docker", "build", "-q", "-t", WEB_IMAGE, "-f", os.path.join(HERE, "Dockerfile.web"), BUILD, timeout=1200)
    for image in ("headscale/headscale:latest", "tailscale/tailscale:stable"):
        if sh("docker", "image", "inspect", image, check=False).returncode != 0:
            print("pulling", image)
            sh("docker", "pull", "-q", image, timeout=1200)


def cleanup(images=False):
    names = sh("docker", "ps", "-a", "--filter", "name=^" + P, "--format", "{{.Names}}", check=False).stdout.split()
    for c in names:
        if c.startswith(P):
            sh("docker", "rm", "-f", c, check=False)
    for n in (NET, NET2, NET3):
        sh("docker", "network", "rm", n, check=False)
    if images:
        for i in (CLIENT_IMAGE, WEB_IMAGE):
            sh("docker", "rmi", i, check=False)


def hs(*args):
    """Runs the headscale command line in its container."""
    return sh("docker", "exec", HS, "/ko-app/headscale", "-c", "/config.yaml", *args)


def hs_json(*args):
    return json.loads(hs("-o", "json", *args).stdout)


def start_headscale():
    sh("docker", "create", "--name", HS, "--network", NET, "--tmpfs", "/var/lib/headscale", "--tmpfs", "/var/run/headscale",
       "headscale/headscale:latest", "serve", "-c", "/config.yaml")
    sh("docker", "cp", os.path.join(HERE, "mesh-headscale.yaml"), HS + ":/config.yaml")
    sh("docker", "cp", os.path.join(HERE, "mesh-policy.json"), HS + ":/policy.json")
    sh("docker", "start", HS)
    for _ in range(40):
        time.sleep(1)
        if sh("docker", "exec", HS, "/ko-app/headscale", "-c", "/config.yaml", "health", check=False).returncode == 0:
            return
    print(sh("docker", "logs", HS, check=False).stdout[-2000:])
    raise RuntimeError("headscale did not start")


def preauth_key():
    hs("users", "create", "wk")
    uid = next(u["id"] for u in hs_json("users", "list") if u["name"] == "wk")
    out = hs_json("preauthkeys", "create", "--user", str(uid), "--reusable", "--expiration", "1h")
    return out["key"]


def link(key, hostname):
    return "tailscale://%s@%s:8080?scheme=http&hostname=%s#%s" % (key, HS, hostname, hostname)


def start_core(name, key, hostname):
    """One of our cores: the daemon, then the same calls the app makes (import, start)."""
    sh("docker", "run", "-d", "--name", name, "--network", NET, CLIENT_IMAGE, "sleep", "infinity")
    sh("docker", "exec", "-d", name, "sh", "-c",
       "omnitun-svc --control-file /data/control.json --data-dir /data --grace 24h > /var/log/svc.log 2>&1")
    wait_for(name, "test -s /data/control.json", "the daemon", 20)
    r = dx(name, "meshctl -control /data/control.json connect '%s' %d" % (link(key, hostname), PROXY), check=False)
    if r.returncode != 0:
        print(r.stdout, r.stderr)
        raise RuntimeError("connect failed on " + name)


def start_stock(key):
    """A stock Tailscale client (also the exit device and a web server)."""
    sh("docker", "run", "-d", "--name", B, "--network", NET, "--cap-add", "NET_ADMIN", "--device", "/dev/net/tun",
       "--sysctl", "net.ipv4.ip_forward=1", "--entrypoint", "sleep", "tailscale/tailscale:stable", "infinity")
    sh("docker", "network", "connect", "--ip", B_NET2_IP, NET2, B)
    sh("docker", "exec", "-d", B, "sh", "-c", "tailscaled --state=mem: > /tmp/tailscaled.log 2>&1")
    wait_for(B, "tailscale status >/dev/null 2>&1; test -S /var/run/tailscale/tailscaled.sock", "tailscaled", 20)
    r = dx(B, "tailscale up --login-server http://%s:8080 --authkey %s --hostname wk-b --advertise-exit-node "
              "--accept-dns=false 2>&1" % (HS, key), check=False, timeout=90)
    print("  stock client:", r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.returncode)
    dx(B, "ip route add %s via %s" % (SUBNET3, R_NET2_IP))
    # No web server in that image: answer every connection with one fixed page.
    sh("docker", "exec", "-d", B, "sh", "-c",
       "while true; do printf 'HTTP/1.0 200 OK\r\nContent-Length: 16\r\n\r\nhello from wk-b\n' | nc -l -p 8080; done")


def wait_for(container, script, what, seconds=30):
    for _ in range(seconds):
        if dx(container, script, check=False).returncode == 0:
            return True
        time.sleep(1)
    print("  timed out waiting for", what)
    return False


def ctl(container, method, params=None, check=True):
    cmd = "meshctl -control /data/control.json call %s" % method
    if params is not None:
        cmd += " '%s'" % json.dumps(params)
    r = dx(container, cmd, check=False)
    if r.returncode != 0:
        if check:
            raise RuntimeError("%s %s: %s%s" % (container, method, r.stdout, r.stderr))
        return None
    return json.loads(r.stdout)


def mesh_status(container):
    return ctl(container, "mesh_status", check=False)


def wait_running(container, seconds=60):
    st = None
    for _ in range(seconds):
        st = mesh_status(container)
        if st and st["state"] == "Running":
            return st
        time.sleep(1)
    print("  %s never reached Running: %s" % (container, st))
    return None


def wait_devices(container, names, seconds=60):
    st = None
    for _ in range(seconds):
        st = mesh_status(container)
        if st:
            online = {d["name"]: d for d in st["devices"] if d["online"]}
            if all(n in online for n in names):
                return st
        time.sleep(1)
    return st


def proxy_get(container, url, seconds=10, tries=1):
    """Fetches url through the core's local proxy port; a new path through the mesh can take a moment."""
    out = ""
    for _ in range(tries):
        r = dx(container, "curl -s --max-time %d --socks5-hostname 127.0.0.1:%d %s" % (seconds, PROXY, url), check=False, timeout=seconds + 20)
        out = r.stdout.strip()
        if out:
            break
    return out


def diagnostics():
    print("--- diagnostics ---")
    for c in (A, C):
        print(c, dx(c, "tail -n 20 /var/log/svc.log", check=False).stdout[-1500:])
    print("headscale:", sh("docker", "logs", "--tail", "20", HS, check=False).stderr[-1500:])
    print("stock:", dx(B, "tail -n 15 /tmp/tailscaled.log", check=False).stdout[-1500:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", action="store_true", help="leave the containers running")
    ap.add_argument("--no-build", action="store_true")
    ap.add_argument("--remove-images", action="store_true", help="also remove the wk-mesh-* images at the end")
    args = ap.parse_args()
    if shutil.which("docker") is None or sh("docker", "info", check=False).returncode != 0:
        sys.exit("Docker is not running")
    if not args.no_build:
        build()
    cleanup()
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok)))
        print("  %-4s %s %s" % ("PASS" if ok else "FAIL", name, detail))

    try:
        sh("docker", "network", "create", "--subnet", SUBNET, NET)
        sh("docker", "network", "create", "--subnet", SUBNET2, NET2)
        sh("docker", "network", "create", "--subnet", SUBNET3, NET3)
        sh("docker", "run", "-d", "--name", WEB, "--network", NET3, "--ip", WEB_IP, WEB_IMAGE)
        # The router between the exit device's network and the web's: it hides the exit
        # device behind its own address, so the web's answer names the router.
        sh("docker", "run", "-d", "--name", R, "--network", NET3, "--ip", R_NET3_IP, "--cap-add", "NET_ADMIN",
           "--sysctl", "net.ipv4.ip_forward=1", CLIENT_IMAGE, "sleep", "infinity")
        sh("docker", "network", "connect", "--ip", R_NET2_IP, NET2, R)
        dx(R, "iptables -t nat -A POSTROUTING -d %s -j MASQUERADE" % SUBNET3)
        start_headscale()
        key = preauth_key()
        print("headscale is up, a pre-auth key is made")
        start_core(A, key, "wk-a")
        start_core(C, key, "wk-c")
        start_stock(key)

        # 1. joining and the device list
        sa, sc = wait_running(A), wait_running(C)
        check("both cores join the network with the pre-auth key", sa and sc, "")
        if not (sa and sc):
            raise RuntimeError("the cores did not join")
        # The stock client advertises an exit; the control server must approve it.
        nodes = hs_json("nodes", "list")
        b_node = next((n for n in nodes if n.get("given_name") == "wk-b" or n.get("name") == "wk-b"), None)
        if b_node:
            hs("nodes", "approve-routes", "-i", str(b_node["id"]), "-r", "0.0.0.0/0,::/0")
        st = wait_devices(A, ["wk-b", "wk-c"])
        online = {d["name"]: d for d in (st or {"devices": []})["devices"] if d["online"]}
        check("core A lists the other core and the stock client as online", "wk-b" in online and "wk-c" in online,
              "(%s)" % ", ".join(sorted(online)))
        b = online.get("wk-b", {})
        check("their addresses and MagicDNS names are given",
              b.get("addresses") and b["addresses"][0].startswith("100.64.") and b.get("dns_name", "").startswith("wk-b."),
              "wk-b = %s %s" % (b.get("addresses"), b.get("dns_name")))
        check("the network name and suffix are reported", st and st.get("domain", "").endswith(DOMAIN), "(%s)" % (st or {}).get("domain"))

        # 2. core to core
        c_addr = (online.get("wk-c") or {}).get("addresses", [None])[0]
        ping = ctl(A, "mesh_ping", {"address": c_addr}, check=False) if c_addr else None
        check("core A pings core C through the mesh", ping and not ping.get("error") and ping["latency_ms"] > 0,
              "(%s)" % (json.dumps(ping) if ping else "no answer"))

        # 3. a web on the stock client, by MagicDNS name and by address
        by_name = proxy_get(A, "http://%s:8080/" % b.get("dns_name", "wk-b." + DOMAIN), 8, 3)
        check("core A fetches the web on the stock client by its MagicDNS name", by_name == "hello from wk-b", "(%r)" % by_name)
        by_ip = proxy_get(A, "http://%s:8080/" % (b.get("addresses") or ["?"])[0])
        check("... and by its mesh address", by_ip == "hello from wk-b", "(%r)" % by_ip)

        # 4. the stock client reaches our core
        a_addr = ((st or {}).get("self") or {}).get("addresses", [None])[0]
        r = dx(B, "tailscale ping --c 3 --timeout 5s wk-a", check=False, timeout=60)
        check("the stock client pings core A", r.returncode == 0 and "pong" in r.stdout, "(%s)" % (r.stdout.strip().splitlines() or [""])[-1])

        # 5. use as exit
        before = proxy_get(A, "http://%s:8080/" % WEB_IP, 6)
        check("without an exit, the web on the second network is out of reach", before == "", "(%r)" % before)
        exit_id = b.get("id")
        res = ctl(A, "mesh_exit", {"id": exit_id}, check=False)
        exit_set = res and any(d.get("exit") for d in res["devices"])
        check("core A accepts the stock client as its exit", exit_set, "")
        time.sleep(3)
        via_exit = proxy_get(A, "http://%s:8080/" % WEB_IP, 8, 3)
        check("with the exit, the web answers (through the router behind the exit device)", via_exit == "client=%s" % R_NET3_IP, "(%r)" % via_exit)
        ctl(A, "mesh_exit", {"id": ""}, check=False)
        time.sleep(2)
        after = proxy_get(A, "http://%s:8080/" % WEB_IP, 6)
        check("clearing the exit puts the web out of reach again", after == "", "(%r)" % after)
        bad = ctl(A, "mesh_exit", {"id": (online.get("wk-c") or {}).get("id", "nope")}, check=False)
        check("a device that does not offer an exit is refused", bad is None, "")
    except Exception as e:  # noqa: BLE001
        print("  error:", e)
        results.append(("run", False))
        diagnostics()
    ok = bool(results) and all(r for _, r in results)
    if not ok:
        diagnostics()
    print("\n=== %s ===" % ("PASS" if ok else "FAIL"))
    if not args.keep:
        cleanup(images=args.remove_images)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
