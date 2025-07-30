#!/usr/bin/env python3
import http.server
import socketserver
import os

PORT = 8081

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"🚀 PWA сервер запущен на http://localhost:{PORT}")
        print(f"📱 PWA доступен по адресу: http://localhost:{PORT}/index.html")
        print("🛑 Для остановки нажмите Ctrl+C")
        httpd.serve_forever() 