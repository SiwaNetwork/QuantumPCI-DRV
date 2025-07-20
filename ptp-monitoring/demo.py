#!/usr/bin/env python3
"""
Демо скрипт для тестирования PTP Monitoring API
Запускается без установки зависимостей, используя только стандартную библиотеку
"""

import http.server
import socketserver
import json
import os
from urllib.parse import urlparse, parse_qs
import time
import random

PORT = 8080

class PTPMonitoringHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/':
            self.serve_main_page()
        elif parsed_path.path == '/dashboard':
            self.serve_file('web/dashboard.html')
        elif parsed_path.path == '/pwa':
            self.serve_file('pwa/index.html')
        elif parsed_path.path == '/manifest.json':
            self.serve_file('pwa/manifest.json')
        elif parsed_path.path == '/sw.js':
            self.serve_file('pwa/sw.js')
        elif parsed_path.path == '/api/metrics':
            self.serve_metrics()
        elif parsed_path.path == '/api/config':
            self.serve_config()
        elif parsed_path.path == '/api/logs/export':
            self.serve_logs()
        else:
            self.send_error(404, "Not Found")
    
    def do_POST(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path.startswith('/api/restart/'):
            service = parsed_path.path.split('/')[-1]
            self.serve_restart(service)
        else:
            self.send_error(404, "Not Found")
    
    def serve_main_page(self):
        """Главная страница"""
        html = '''
        <!DOCTYPE html>
        <html>
        <head>
            <title>PTP Monitor Demo</title>
            <style>
                body { font-family: Arial; margin: 40px; background: #f5f5f5; text-align: center; }
                .container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
                .links a { display: inline-block; margin: 10px; padding: 15px 30px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; font-size: 16px; }
                .links a:hover { background: #0056b3; }
                .status { background: #e7f3ff; padding: 20px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #007bff; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🕐 PTP OCP Monitoring System (Demo)</h1>
                <div class="status">
                    <h3>Доступные интерфейсы:</h3>
                    <p><strong>⚠️ Демо версия:</strong> Работает без Flask, WebSocket недоступен</p>
                </div>
                <div class="links">
                    <a href="/dashboard">💻 Desktop Dashboard</a>
                    <a href="/pwa">📱 Mobile PWA</a>
                    <a href="/api/metrics">📊 API Metrics</a>
                </div>
            </div>
        </body>
        </html>
        '''
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def serve_file(self, filepath):
        """Обслуживание статических файлов"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Определяем тип контента
            if filepath.endswith('.html'):
                content_type = 'text/html'
            elif filepath.endswith('.json'):
                content_type = 'application/json'
            elif filepath.endswith('.js'):
                content_type = 'application/javascript'
            else:
                content_type = 'text/plain'
            
            self.send_response(200)
            self.send_header('Content-type', content_type)
            self.end_headers()
            self.wfile.write(content.encode())
        
        except FileNotFoundError:
            self.send_error(404, f"File not found: {filepath}")
    
    def serve_metrics(self):
        """API метрик с демо данными"""
        # Генерируем реалистичные демо данные
        metrics = {
            'offset': random.randint(-500, 500),
            'frequency': random.randint(-100, 100),
            'driver_status': 1,
            'port_state': 8,
            'path_delay': random.randint(2000, 3000)
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(metrics).encode())
    
    def serve_config(self):
        """API конфигурации"""
        config = """[global]
tx_timestamp_timeout    1
logAnnounceInterval     1
logSyncInterval         0
logMinDelayReqInterval  0
logMinPdelayReqInterval 0
announceReceiptTimeout  3
syncReceiptTimeout      0
delayAsymmetry          0
fault_reset_interval    4
neighborPropDelayThresh 20000000
twoStepFlag             1
"""
        
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(config.encode())
    
    def serve_logs(self):
        """API логов"""
        logs = f"""Dec 20 {time.strftime('%H:%M:%S')} server ptp4l[1234]: [demo] PTP system running
Dec 20 {time.strftime('%H:%M:%S')} server ptp4l[1234]: [demo] Port state: SLAVE
Dec 20 {time.strftime('%H:%M:%S')} server ptp4l[1234]: [demo] Offset: {random.randint(-200, 200)}ns
Dec 20 {time.strftime('%H:%M:%S')} server ptp4l[1234]: [demo] Master clock selected
"""
        
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.send_header('Content-Disposition', 'attachment; filename=ptp4l-demo.log')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(logs.encode())
    
    def serve_restart(self, service):
        """API перезапуска сервиса"""
        if service in ['ptp4l', 'phc2sys']:
            response = {'status': 'success', 'message': f'{service} restarted (demo)'}
        else:
            response = {'error': 'Invalid service'}
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

def main():
    print("="*60)
    print("🚀 PTP Monitoring System Demo Server")
    print("="*60)
    print("⚠️  ДЕМО РЕЖИМ: Работает без Flask/SocketIO")
    print("📊 Desktop Dashboard: http://localhost:8080/dashboard")
    print("📱 Mobile PWA:        http://localhost:8080/pwa") 
    print("🔧 API Endpoints:     http://localhost:8080/api/")
    print("🏠 Main Page:         http://localhost:8080/")
    print("="*60)
    print("ℹ️  Ограничения демо:")
    print("   - Нет WebSocket (real-time логи)")
    print("   - Демо данные вместо реальных метрик")
    print("   - Нет перезапуска реальных сервисов")
    print("="*60)
    
    try:
        with socketserver.TCPServer(("", PORT), PTPMonitoringHandler) as httpd:
            print(f"🎯 Server started at http://localhost:{PORT}")
            print("Press Ctrl+C to stop")
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Server stopped")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()