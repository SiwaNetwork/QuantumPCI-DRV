#!/usr/bin/env python3
# app.py - Основное приложение с маршрутизацией для TimeCard мониторинга

from flask import Flask, send_from_directory, redirect, url_for, jsonify
from flask_socketio import SocketIO
from flask_cors import CORS
import os
import sys
import importlib.util
import time

# Создаем Flask приложение
app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

# Путь к файлам веб-интерфейса
WEB_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'web')
PWA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'pwa')

# Пытаемся импортировать расширенный API
extended_api_loaded = False
try:
    api_path = os.path.join(os.path.dirname(__file__), "timecard-extended-api.py")
    if os.path.exists(api_path):
        spec = importlib.util.spec_from_file_location("timecard_api", api_path)
        timecard_api = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(timecard_api)
        
        # Регистрируем маршруты из расширенного API
        extended_app = timecard_api.app
        extended_socketio = timecard_api.socketio
        
        # Переносим маршруты
        for rule in extended_app.url_map.iter_rules():
            if rule.endpoint != 'static' and not rule.rule.startswith('/static'):
                try:
                    app.add_url_rule(
                        rule.rule,
                        rule.endpoint + '_extended',  # Избегаем конфликтов имен
                        extended_app.view_functions[rule.endpoint],
                        methods=list(rule.methods)
                    )
                except Exception as e:
                    print(f"Warning: Could not register route {rule.rule}: {e}")
        
        # Переносим WebSocket обработчики
        for event_name in ['connect', 'disconnect', 'request_device_update']:
            try:
                handler = getattr(timecard_api, f'handle_{event_name}', None)
                if handler and callable(handler):
                    socketio.on_event(event_name, handler)
            except Exception as e:
                print(f"Warning: Could not register WebSocket handler {event_name}: {e}")
        
        extended_api_loaded = True
        print("✅ Extended TimeCard API loaded successfully")
        
except Exception as e:
    print(f"⚠️ Warning: Could not load extended API: {e}")
    print("🔄 Using fallback basic API...")

# Fallback базовый API, если расширенный не загрузился
if not extended_api_loaded:
    import random
    import math
    
    @app.route('/api/metrics')
    def get_basic_metrics():
        """Базовые метрики для совместимости"""
        offset = 150 + math.sin(time.time() / 30) * 100 + random.uniform(-50, 50)
        return jsonify({
            'offset': int(offset),
            'frequency': -12.5 + random.uniform(-10, 10),
            'driver_status': 1,
            'port_state': 8,
            'path_delay': 2500 + random.randint(-100, 100),
            'timestamp': time.time()
        })
    
    @app.route('/api/devices')
    def get_devices():
        """Список устройств"""
        return jsonify({
            'devices': [{
                'identification': {
                    'device_id': 'timecard0',
                    'serial_number': 'TC-2024-001',
                    'firmware_version': '2.1.3'
                }
            }],
            'count': 1,
            'timestamp': time.time()
        })
    
    @app.route('/api/device/timecard0/status')
    def get_device_status():
        """Статус устройства fallback"""
        return jsonify({
            'overall_health_score': 95,
            'alerts': [],
            'timestamp': time.time()
        })
    
    @app.route('/api/metrics/extended')
    def get_extended_metrics():
        """Расширенные метрики fallback"""
        return jsonify({
            'timecard0': {
                'offset': 150,
                'frequency': -12.5,
                'timestamp': time.time()
            }
        })

# Маршруты для веб-интерфейсов
@app.route('/')
def index():
    """Главная страница - перенаправление на dashboard"""
    return redirect(url_for('dashboard'))

@app.route('/dashboard')
def dashboard():
    """TimeCard расширенный dashboard"""
    try:
        if os.path.exists(os.path.join(WEB_DIR, 'timecard-dashboard.html')):
            return send_from_directory(WEB_DIR, 'timecard-dashboard.html')
        else:
            return send_from_directory(WEB_DIR, 'dashboard.html')
    except FileNotFoundError:
        return """
        <html>
        <head><title>TimeCard Dashboard</title></head>
        <body>
            <h1>🕐 TimeCard Dashboard</h1>
            <p>Dashboard files not found. Please check the web directory.</p>
            <p><a href="/api/">API Documentation</a></p>
        </body>
        </html>
        """, 404

@app.route('/pwa')
@app.route('/mobile')
def pwa():
    """PWA интерфейс"""
    try:
        return send_from_directory(PWA_DIR, 'index.html')
    except FileNotFoundError:
        return redirect(url_for('dashboard'))

@app.route('/manifest.json')
def manifest():
    """PWA manifest"""
    try:
        return send_from_directory(PWA_DIR, 'manifest.json')
    except FileNotFoundError:
        return jsonify({
            "name": "TimeCard Monitor",
            "short_name": "TimeCard",
            "display": "standalone",
            "background_color": "#667eea",
            "theme_color": "#667eea"
        })

@app.route('/sw.js')
def service_worker():
    """Service Worker"""
    try:
        return send_from_directory(PWA_DIR, 'sw.js')
    except FileNotFoundError:
        return "// Service Worker not found", 404

# Статические файлы
@app.route('/static/<path:filename>')
def static_files(filename):
    """Статические файлы"""
    try:
        return send_from_directory(WEB_DIR, filename)
    except FileNotFoundError:
        return "File not found", 404

# Иконки PWA (заглушки)
@app.route('/icon-<size>.png')
def pwa_icons(size):
    """PWA иконки (заглушка)"""
    return "Icon not found", 404

# Информация о системе
@app.route('/info')
def system_info():
    """Информация о системе мониторинга"""
    return jsonify({
        'system': 'TimeCard PTP OCP Monitoring System',
        'version': '2.0.0',
        'extended_api_loaded': extended_api_loaded,
        'features': {
            'basic_ptp_monitoring': True,
            'thermal_monitoring': extended_api_loaded,
            'gnss_tracking': extended_api_loaded,
            'oscillator_disciplining': extended_api_loaded,
            'hardware_monitoring': extended_api_loaded,
            'power_monitoring': extended_api_loaded,
            'advanced_alerting': extended_api_loaded,
            'websocket_updates': True
        },
        'endpoints': {
            'dashboard': '/dashboard',
            'pwa': '/pwa',
            'api_root': '/api/',
            'basic_metrics': '/api/metrics',
            'extended_metrics': '/api/metrics/extended' if extended_api_loaded else None,
            'devices': '/api/devices',
            'alerts': '/api/alerts' if extended_api_loaded else None
        },
        'timestamp': time.time()
    })

# Обработчики ошибок
@app.errorhandler(404)
def not_found(error):
    """Обработчик 404"""
    return jsonify({
        'error': 'Not Found',
        'message': 'The requested resource was not found',
        'available_endpoints': [
            '/',
            '/dashboard',
            '/pwa',
            '/api/',
            '/api/metrics',
            '/info'
        ]
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Обработчик 500"""
    return jsonify({
        'error': 'Internal Server Error',
        'message': 'An internal server error occurred',
        'timestamp': time.time()
    }), 500

# WebSocket обработчики (базовые, если расширенные не загружены)
if not extended_api_loaded:
    @socketio.on('connect')
    def handle_connect():
        """Базовый обработчик подключения"""
        print('Client connected (basic mode)')
        socketio.emit('status_update', {
            'connected': True,
            'mode': 'basic',
            'timestamp': time.time()
        })

    @socketio.on('disconnect')
    def handle_disconnect():
        """Базовый обработчик отключения"""
        print('Client disconnected (basic mode)')

if __name__ == '__main__':
    print("="*80)
    print("🚀 TimeCard PTP OCP Monitoring System v2.0")
    print("="*80)
    
    if extended_api_loaded:
        print("✅ Mode: EXTENDED - Full TimeCard monitoring capabilities")
        print("📊 Extended Dashboard: http://localhost:8080/dashboard")
        print("📱 Mobile PWA:         http://localhost:8080/pwa") 
        print("🔧 Extended API:       http://localhost:8080/api/")
        print("="*80)
        print("✨ Extended Features Available:")
        print("   🌡️  Complete thermal monitoring (6 sensors)")
        print("   ⚡  Power analysis (4 voltage rails + currents)")
        print("   🛰️  GNSS constellation tracking (GPS+GLONASS+Galileo+BeiDou)")
        print("   ⚡  Oscillator disciplining with Allan deviation")
        print("   📡  Advanced PTP metrics & packet analysis")
        print("   🔧  Hardware status (LEDs, SMA, FPGA, PHY)")
        print("   🚨  Intelligent alerting with threshold monitoring")
        print("   📊  Health scoring & comprehensive assessment")
        print("   📈  Historical data storage & trending")
        print("   🔌  WebSocket live updates")
    else:
        print("⚠️  Mode: BASIC - Limited monitoring capabilities")
        print("📊 Basic Dashboard:    http://localhost:8080/dashboard")
        print("🔧 Basic API:          http://localhost:8080/api/")
        print("="*80)
        print("📋 Basic Features Available:")
        print("   📊  Basic PTP metrics")
        print("   🔌  WebSocket updates")
        print("   📱  Web interface")
    
    print("="*80)
    print("🏠 Main Page:          http://localhost:8080/")
    print("ℹ️  System Info:       http://localhost:8080/info")
    print("="*80)
    
    # Запуск веб-сервера
    try:
        socketio.run(app, host='0.0.0.0', port=8080, debug=True, allow_unsafe_werkzeug=True)
    except KeyboardInterrupt:
        print("\n👋 Shutting down TimeCard monitoring system...")
    except Exception as e:
        print(f"❌ Error starting server: {e}")
        sys.exit(1)