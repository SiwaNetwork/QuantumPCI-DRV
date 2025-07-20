#!/usr/bin/env python3
# app.py - Основное Flask приложение для PTP мониторинга

from flask import Flask, send_from_directory, redirect, url_for
from flask_socketio import SocketIO
import os
import sys

# Добавляем текущую директорию в путь для импорта модулей
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Импортируем наш API модуль  
import importlib.util
import os
api_path = os.path.join(os.path.dirname(__file__), "ptp-api.py")
spec = importlib.util.spec_from_file_location("ptp_api", api_path)
ptp_api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ptp_api)
ptp_app = ptp_api.app
socketio = ptp_api.socketio

# Путь к файлам веб-интерфейса
WEB_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'web')
PWA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'pwa')

# Маршруты для веб-интерфейсов
@ptp_app.route('/dashboard')
def dashboard():
    """Главный dashboard"""
    return send_from_directory(WEB_DIR, 'dashboard.html')

@ptp_app.route('/pwa')
@ptp_app.route('/mobile')
def pwa():
    """PWA интерфейс"""
    return send_from_directory(PWA_DIR, 'index.html')

@ptp_app.route('/manifest.json')
def manifest():
    """PWA manifest"""
    return send_from_directory(PWA_DIR, 'manifest.json')

@ptp_app.route('/sw.js')
def service_worker():
    """Service Worker"""
    return send_from_directory(PWA_DIR, 'sw.js')

# Статические файлы для PWA
@ptp_app.route('/icon-<size>.png')
def pwa_icons(size):
    """PWA иконки"""
    # Пока возвращаем заглушку
    return "Icon not found", 404

@ptp_app.route('/')
def index():
    """Главная страница - перенаправление на dashboard"""
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>PTP Monitor</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { 
                font-family: Arial, sans-serif; 
                margin: 40px; 
                background: #f5f5f5; 
                text-align: center;
            }
            .container { 
                background: white; 
                padding: 40px; 
                border-radius: 10px; 
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                max-width: 600px;
                margin: 0 auto;
            }
            .links { margin: 30px 0; }
            .links a { 
                display: inline-block; 
                margin: 10px; 
                padding: 15px 30px; 
                background: #007bff; 
                color: white; 
                text-decoration: none; 
                border-radius: 5px; 
                font-size: 16px;
            }
            .links a:hover { background: #0056b3; }
            .status { 
                background: #e7f3ff; 
                padding: 20px; 
                border-radius: 5px; 
                margin: 20px 0;
                border-left: 4px solid #007bff;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🕐 PTP OCP Monitoring System</h1>
            <div class="status">
                <h3>Доступные интерфейсы:</h3>
            </div>
            <div class="links">
                <a href="/dashboard">💻 Desktop Dashboard</a>
                <a href="/pwa">📱 Mobile PWA</a>
                <a href="/api/metrics">📊 API Metrics</a>
            </div>
            <div class="status">
                <p><strong>API Endpoints:</strong></p>
                <ul style="text-align: left; display: inline-block;">
                    <li><code>GET /api/metrics</code> - Получить метрики PTP</li>
                    <li><code>POST /api/restart/&lt;service&gt;</code> - Перезапустить сервис</li>
                    <li><code>GET /api/config</code> - Получить конфигурацию</li>
                    <li><code>GET /api/logs/export</code> - Экспорт логов</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
    '''

if __name__ == '__main__':
    print("="*60)
    print("🚀 PTP Monitoring System Starting...")
    print("="*60)
    print("📊 Desktop Dashboard: http://localhost:8080/dashboard")
    print("📱 Mobile PWA:        http://localhost:8080/pwa") 
    print("🔧 API Endpoints:     http://localhost:8080/api/")
    print("🏠 Main Page:         http://localhost:8080/")
    print("="*60)
    
    # Запуск с поддержкой WebSocket
    socketio.run(ptp_app, host='0.0.0.0', port=8080, debug=True)