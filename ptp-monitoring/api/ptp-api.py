#!/usr/bin/env python3
# ptp-api.py - Простой API сервер для PTP мониторинга

from flask import Flask, jsonify, request
from flask_socketio import SocketIO
import subprocess
import json
import threading
import time
import os

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

# API endpoints
@app.route('/api/metrics')
def get_metrics():
    """Получение текущих метрик PTP"""
    try:
        # Чтение метрик из Prometheus textfile
        metrics = {}
        metrics_file = '/var/lib/prometheus/node-exporter/ptp.prom'
        
        # Если файл метрик не существует, создаем демо-данные
        if not os.path.exists(metrics_file):
            metrics = {
                'offset': 150,
                'frequency': -45,
                'driver_status': 1,
                'port_state': 8,
                'path_delay': 2500
            }
            return jsonify(metrics)
            
        with open(metrics_file, 'r') as f:
            for line in f:
                if line.startswith('ptp_'):
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        metric_name = parts[0]
                        metric_value = parts[1]
                        if metric_name == 'ptp_offset_ns':
                            metrics['offset'] = int(float(metric_value))
                        elif metric_name == 'ptp_frequency_adjustment':
                            metrics['frequency'] = int(float(metric_value))
                        elif metric_name == 'ptp_driver_status':
                            metrics['driver_status'] = int(float(metric_value))
                        elif 'ptp_port_state' in metric_name:
                            metrics['port_state'] = int(float(metric_value))
                        elif 'ptp_path_delay' in metric_name:
                            metrics['path_delay'] = int(float(metric_value))
        
        return jsonify(metrics)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/restart/<service>', methods=['POST'])
def restart_service(service):
    """Перезапуск сервиса"""
    if service not in ['ptp4l', 'phc2sys']:
        return jsonify({'error': 'Invalid service'}), 400
    
    try:
        result = subprocess.run(['systemctl', 'restart', f'{service}.service'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({'status': 'success', 'message': f'{service} restarted'})
        else:
            return jsonify({'error': result.stderr}), 500
    except subprocess.CalledProcessError as e:
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        return jsonify({'error': f'Permission denied or service not found: {str(e)}'}), 500

@app.route('/api/config')
def get_config():
    """Получение конфигурации"""
    try:
        config_file = '/etc/ptp4l.conf'
        if not os.path.exists(config_file):
            # Возвращаем примерную конфигурацию
            demo_config = """[global]
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
            return demo_config, 200, {'Content-Type': 'text/plain'}
            
        with open(config_file, 'r') as f:
            config = f.read()
        return config, 200, {'Content-Type': 'text/plain'}
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs/export')
def export_logs():
    """Экспорт логов"""
    try:
        result = subprocess.run(['journalctl', '-u', 'ptp4l', '--no-pager', '-n', '1000'], 
                               capture_output=True, text=True)
        if result.returncode != 0:
            # Возвращаем демо логи если нет реального сервиса
            demo_logs = """Dec 20 10:30:00 server ptp4l[1234]: [ptp4l.0.config] port 1: LISTENING to MASTER on ANNOUNCE_RECEIPT_TIMEOUT_EXPIRES
Dec 20 10:30:01 server ptp4l[1234]: [ptp4l.0.config] selected best master clock 001122.fffe.334455
Dec 20 10:30:02 server ptp4l[1234]: [ptp4l.0.config] assuming the grand master role
Dec 20 10:30:03 server ptp4l[1234]: [ptp4l.0.config] port 1: MASTER to LISTENING on ANNOUNCE_RECEIPT_TIMEOUT_EXPIRES
"""
            return demo_logs, 200, {
                'Content-Type': 'text/plain',
                'Content-Disposition': 'attachment; filename=ptp4l.log'
            }
            
        return result.stdout, 200, {
            'Content-Type': 'text/plain',
            'Content-Disposition': 'attachment; filename=ptp4l.log'
        }
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/')
def index():
    """Главная страница - перенаправление на dashboard"""
    return '<h1>PTP Monitoring API</h1><p>Dashboard: <a href="http://localhost:8080/dashboard">http://localhost:8080/dashboard</a></p>'

def log_monitor():
    """Мониторинг логов в реальном времени"""
    try:
        process = subprocess.Popen(['journalctl', '-u', 'ptp4l', '-f', '--no-pager'],
                                  stdout=subprocess.PIPE, text=True)
        
        for line in iter(process.stdout.readline, ''):
            if line:
                socketio.emit('log', line.strip())
    except Exception as e:
        print(f"Log monitoring error: {e}")
        # Эмитим демо логи каждые 5 секунд
        while True:
            time.sleep(5)
            demo_log = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] ptp4l: Demo log message - system running"
            socketio.emit('log', demo_log)

if __name__ == '__main__':
    print("Starting PTP Monitoring API server...")
    print("Dashboard will be available at: http://localhost:8080/dashboard")
    print("API endpoints at: http://localhost:8080/api/")
    
    # Запуск мониторинга логов в отдельном потоке
    log_thread = threading.Thread(target=log_monitor, daemon=True)
    log_thread.start()
    
    # Запуск веб-сервера
    socketio.run(app, host='0.0.0.0', port=8080, debug=True)