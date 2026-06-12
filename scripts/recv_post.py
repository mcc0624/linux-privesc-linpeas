#!/usr/bin/env python3
"""Simple HTTP POST receiver — 接收目标机用 curl POST 传来的文件."""
import http.server
import sys
import os

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 9997
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/recv_file.txt"

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(length)
        with open(OUT, 'wb') as f:
            f.write(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')
        print(f"[+] 收到 {len(data)} bytes → {OUT}")
        # 只处理一次请求后退出
        os._exit(0)

    def log_message(self, fmt, *args):
        print(f"[*] {args}")

print(f"[*] 监听 0.0.0.0:{PORT}，等待 POST...")
httpd = http.server.HTTPServer(('0.0.0.0', PORT), Handler)
httpd.handle_request()
