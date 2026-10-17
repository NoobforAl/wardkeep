import socket
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/big"):
            # /big?mb=N[&kbps=R]: N megabytes, for a transfer that lasts long enough to watch. With kbps the server
            # itself paces the sending, so the traffic through a tunnel is steady (a client that only reads slowly
            # lets the kernel buffer megabytes first, and the tunnel carries them all at once).
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            mb = int(q.get("mb", ["1"])[0])
            kbps = int(q.get("kbps", ["0"])[0])
            self.send_response(200)
            self.send_header("Content-Length", str(mb << 20))
            self.end_headers()
            chunk = b"x" * (16384 if kbps else 65536)
            start, sent = time.monotonic(), 0
            try:
                for _ in range((mb << 20) // len(chunk)):
                    self.wfile.write(chunk)
                    sent += len(chunk)
                    if kbps:
                        ahead = sent / (kbps * 1024) - (time.monotonic() - start)
                        if ahead > 0:
                            time.sleep(ahead)
            except OSError:
                pass
            return
        body = ("client=%s\n" % self.client_address[0]).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


class V6(ThreadingHTTPServer):
    """The IPv6 side: a separate socket, so an IPv4 client is never seen as ::ffff:a.b.c.d."""
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        super().server_bind()


def serve_v6():
    try:
        V6(("::", 8080), H).serve_forever()
    except OSError as e:  # no IPv6 on this container's network
        print("no IPv6:", e, flush=True)


threading.Thread(target=serve_v6, daemon=True).start()
ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
