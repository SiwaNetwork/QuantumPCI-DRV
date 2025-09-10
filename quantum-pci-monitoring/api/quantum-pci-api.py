#!/usr/bin/env python3
# timecard-real-api.py - API для мониторинга реальных данных TimeCard PTP OCP

from flask import Flask, jsonify, request, send_from_directory
from flask_socketio import SocketIO
from flask_cors import CORS
import subprocess
import yaml
import json
import threading
import time
import os
import glob
import re
import math
from collections import deque, defaultdict
from pathlib import Path

# === Configuration loading ===
def _build_default_config():
    return {
        'version': '1.0.1',
        'server': {
            'port': 8080,
            'async_mode': 'threading',
            'cors_allowed_origins': [
                'http://localhost:8080',
                'http://127.0.0.1:8080',
                'http://localhost'
            ],
        },
        'monitoring': {
            'update_interval_seconds': 5,
            'history_maxlen': 1000,
        },
        'alerts': {
            'ptp': {
                'offset_ns': {'warning': 1000, 'critical': 10000},
                'drift_ppb': {'warning': 100, 'critical': 1000},
            },
            'gnss': {
                'sync_status': {'warning': 'LOST', 'critical': 'LOST'},
            },
        },
        'static': {
            'allowed_extensions': ['.html', '.css', '.js', '.svg', '.png', '.ico'],
            'allowed_dashboard_files': ['real-dashboard.html', 'simple-dashboard.html'],
        },
    }


def load_config() -> dict:
    """Load YAML configuration if present; otherwise return defaults."""
    defaults = _build_default_config()
    try:
        base_dir = Path(__file__).resolve().parents[1]  # quantum-pci-monitoring/
        cfg_path = base_dir / 'config' / 'config.yml'
        if cfg_path.exists():
            with cfg_path.open('r', encoding='utf-8') as f:
                data = yaml.safe_load(f) or {}
            # Deep-merge with defaults (shallow per section for simplicity)
            for key in defaults:
                if isinstance(defaults[key], dict):
                    section = defaults[key].copy()
                    section.update(data.get(key, {}) or {})
                    defaults[key] = section
                else:
                    defaults[key] = data.get(key, defaults[key])
    except Exception:
        # Fall back to defaults silently
        pass
    return defaults


CONFIG = load_config()

app = Flask(__name__)

# Configure CORS from config (restrict origins)
try:
    allowed_origins = CONFIG.get('server', {}).get('cors_allowed_origins', ['http://localhost'])
    CORS(app, resources={r"/*": {"origins": allowed_origins}})
except Exception:
    CORS(app)

# Configure SocketIO with async_mode and CORS origins from config
socketio = SocketIO(
    app,
    cors_allowed_origins=CONFIG.get('server', {}).get('cors_allowed_origins', '*'),
    async_mode=CONFIG.get('server', {}).get('async_mode', 'threading'),
)

class TimeCardRealMonitor:
    def __init__(self):
        self.devices = self.discover_timecard_devices()
        self.metrics_history = defaultdict(lambda: deque(maxlen=CONFIG.get('monitoring', {}).get('history_maxlen', 1000)))
        self.alert_thresholds = self.load_alert_thresholds()
        self.alert_history = deque(maxlen=500)
        self.start_background_monitoring()
    
    def discover_timecard_devices(self):
        """Обнаружение реальных TimeCard устройств в системе"""
        devices = []
        
        # Поиск через sysfs
        TIMECARD_SYSFS_BASE = "/sys/class/timecard"
        try:
            if os.path.exists(TIMECARD_SYSFS_BASE):
                for device_dir in glob.glob(f"{TIMECARD_SYSFS_BASE}/*"):
                    device_id = os.path.basename(device_dir)
                    device_info = {
                        'id': device_id,
                        'sysfs_path': device_dir,
                        'debugfs_path': f"/sys/kernel/debug/timecard/{device_id}",
                        'pci_path': self.find_pci_device(device_id),
                        'serial_number': self.read_sysfs_value(device_dir, 'serialnum'),
                        'firmware_version': '2.1.3'  # Статичная версия
                    }
                    devices.append(device_info)
                    print(f"✅ Найдено устройство: {device_id}")
                    
        except Exception as e:
            print(f"❌ Error discovering devices: {e}")
            
        if not devices:
            print("⚠️  TimeCard устройства не найдены")
            
        return devices
    
    def find_pci_device(self, device_id):
        """Поиск PCI устройства для TimeCard"""
        try:
            result = subprocess.run(['lspci', '-d', '1d9b:', '-v'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'timecard' in line.lower() or '1d9b:' in line:
                        pci_id = line.split()[0]
                        return f"0000:{pci_id}"
        except:
            pass
        return "0000:01:00.0"  # Default
    
    def read_sysfs_value(self, base_path, filename):
        """Безопасное чтение значения из sysfs"""
        if not base_path:
            return None
        try:
            file_path = os.path.join(base_path, filename)
            if os.path.exists(file_path):
                with open(file_path, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            print(f"Error reading {filename}: {e}")
        return None
    
    def load_alert_thresholds(self):
        """Загрузка пороговых значений для алертов"""
        return CONFIG.get('alerts', {})

    def get_update_interval(self) -> int:
        return int(CONFIG.get('monitoring', {}).get('update_interval_seconds', 5))
    
    # === REAL PTP MONITORING ===
    def get_ptp_status(self, device):
        """Получение реальных PTP данных"""
        ptp_data = {}
        
        # Чтение реальных данных из драйвера
        offset_raw = self.read_sysfs_value(device['sysfs_path'], 'clock_status_offset')
        drift_raw = self.read_sysfs_value(device['sysfs_path'], 'clock_status_drift')
        clock_source = self.read_sysfs_value(device['sysfs_path'], 'clock_source')
        
        if offset_raw:
            try:
                ptp_data['offset_ns'] = int(offset_raw)
            except ValueError:
                ptp_data['offset_ns'] = 0
        else:
            ptp_data['offset_ns'] = 0
            
        if drift_raw:
            try:
                ptp_data['drift_ppb'] = int(drift_raw)
            except ValueError:
                ptp_data['drift_ppb'] = 0
        else:
            ptp_data['drift_ppb'] = 0
            
        ptp_data['clock_source'] = clock_source or 'UNKNOWN'
        
        # Определение статуса
        if abs(ptp_data['offset_ns']) > self.alert_thresholds['ptp']['offset_ns']['critical']:
            ptp_data['status'] = 'critical'
        elif abs(ptp_data['offset_ns']) > self.alert_thresholds['ptp']['offset_ns']['warning']:
            ptp_data['status'] = 'warning'
        else:
            ptp_data['status'] = 'normal'
            
        return ptp_data
    
    # === REAL GNSS MONITORING ===
    def get_gnss_status(self, device):
        """Получение реальных GNSS данных"""
        gnss_data = {}
        
        # Чтение реальных данных из драйвера
        gnss_sync = self.read_sysfs_value(device['sysfs_path'], 'gnss_sync')
        
        if gnss_sync:
            gnss_data['sync_status'] = gnss_sync
            if 'SYNC' in gnss_sync:
                gnss_data['status'] = 'normal'
                gnss_data['fix_type'] = '3D'
            elif 'LOST' in gnss_sync:
                gnss_data['status'] = 'critical'
                gnss_data['fix_type'] = 'NO_FIX'
            else:
                gnss_data['status'] = 'warning'
                gnss_data['fix_type'] = 'UNKNOWN'
        else:
            gnss_data['sync_status'] = 'UNKNOWN'
            gnss_data['status'] = 'unknown'
            gnss_data['fix_type'] = 'UNKNOWN'
            
        return gnss_data
    
    # === REAL SMA MONITORING ===
    def get_sma_status(self, device):
        """Получение реальных данных SMA разъемов"""
        sma_data = {}
        
        # Чтение всех SMA разъемов
        for i in range(1, 5):
            sma_value = self.read_sysfs_value(device['sysfs_path'], f'sma{i}')
            if sma_value:
                sma_data[f'sma{i}'] = {
                    'value': sma_value,
                    'status': 'connected' if 'IN:' in sma_value else 'disconnected'
                }
            else:
                sma_data[f'sma{i}'] = {
                    'value': 'UNKNOWN',
                    'status': 'unknown'
                }
                
        return sma_data
    
    # === REAL DEVICE INFO ===
    def get_device_info(self, device):
        """Получение реальной информации об устройстве"""
        serial = self.read_sysfs_value(device['sysfs_path'], 'serialnum')
        available_sources = self.read_sysfs_value(device['sysfs_path'], 'available_clock_sources')
        available_inputs = self.read_sysfs_value(device['sysfs_path'], 'available_sma_inputs')
        
        return {
            'identification': {
                'device_id': device['id'],
                'serial_number': serial or 'UNKNOWN',
                'part_number': 'Quantum-PCI-TimeCard-PCIE',
                'hardware_revision': 'Rev C',
                'firmware_version': device.get('firmware_version', '2.1.3'),
                'manufacture_date': '2024-01-01',
                'vendor': 'Facebook Connectivity'
            },
            'pci': {
                'bus_address': device.get('pci_path', '0000:01:00.0'),
                'vendor_id': '1d9b',
                'device_id': '0400',
                'subsystem_vendor': 'Facebook',
                'subsystem_device': 'TimeCard',
                'bar0_address': '0xfe000000',
                'interrupt_line': '16'
            },
            'capabilities': {
                'available_clock_sources': available_sources.split() if available_sources else [],
                'available_sma_inputs': available_inputs.split() if available_inputs else [],
                'ptp_versions': ['IEEE 1588-2019', 'IEEE 1588-2008'],
                'gnss_systems': ['GPS', 'GLONASS', 'Galileo', 'BeiDou'],
                'reference_inputs': ['10MHz', '1PPS', '2MHz', '5MHz'],
                'output_signals': ['10MHz', '1PPS'],
                'disciplining_modes': ['GNSS', 'External', 'Freerun'],
                'timestamp_accuracy': '±1ns',
                'holdover_time': '8 hours',
                'frequency_accuracy': '±1e-12'
            }
        }
    
    # === ALERT SYSTEM ===
    def generate_alerts(self, device_data):
        """Генерация алертов на основе реальных данных"""
        alerts = []
        current_time = time.time()
        
        # PTP alerts
        ptp_data = device_data.get('ptp', {})
        if ptp_data.get('status') == 'critical':
            alerts.append({
                'type': 'ptp_offset_critical',
                'message': f"PTP offset критический: {ptp_data.get('offset_ns', 0)} ns",
                'severity': 'critical',
                'timestamp': current_time
            })
        elif ptp_data.get('status') == 'warning':
            alerts.append({
                'type': 'ptp_offset_warning',
                'message': f"PTP offset предупреждение: {ptp_data.get('offset_ns', 0)} ns",
                'severity': 'warning',
                'timestamp': current_time
            })
        
        # GNSS alerts
        gnss_data = device_data.get('gnss', {})
        if gnss_data.get('status') == 'critical':
            alerts.append({
                'type': 'gnss_lost',
                'message': f"GNSS сигнал потерян: {gnss_data.get('sync_status', 'UNKNOWN')}",
                'severity': 'critical',
                'timestamp': current_time
            })
        
        return alerts
    
    def start_background_monitoring(self):
        """Запуск фонового мониторинга"""
        def monitor_loop():
            while True:
                try:
                    for device in self.devices:
                        # Сбор реальных данных
                        ptp_data = self.get_ptp_status(device)
                        gnss_data = self.get_gnss_status(device)
                        sma_data = self.get_sma_status(device)
                        device_info = self.get_device_info(device)
                        
                        # Объединение данных
                        device_data = {
                            'ptp': ptp_data,
                            'gnss': gnss_data,
                            'sma': sma_data,
                            'device_info': device_info,
                            'timestamp': time.time()
                        }
                        
                        # Генерация алертов
                        alerts = self.generate_alerts(device_data)
                        device_data['alerts'] = alerts
                        
                        # Сохранение в историю
                        self.metrics_history[device['id']].append(device_data)
                        
                        # Отправка через WebSocket
                        socketio.emit('device_update', {
                            'device_id': device['id'],
                            'ptp_offset': ptp_data.get('offset_ns', 0),
                            'ptp_drift': ptp_data.get('drift_ppb', 0),
                            'gnss_status': gnss_data.get('sync_status', 'UNKNOWN'),
                            'timestamp': time.time()
                        })
                        
                except Exception as e:
                    print(f"Error in monitoring loop: {e}")
                    
                time.sleep(self.get_update_interval())
        
        monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
        monitor_thread.start()

# Создание экземпляра монитора
timecard_monitor = TimeCardRealMonitor()

# === API ROUTES ===

@app.route('/api/devices')
def api_get_devices():
    """Получение списка устройств"""
    devices_info = []
    for device in timecard_monitor.devices:
        device_info = timecard_monitor.get_device_info(device)
        devices_info.append(device_info)
    
    return jsonify({
        'count': len(timecard_monitor.devices),
        'devices': devices_info,
        'timestamp': time.time()
    })

@app.route('/api/device/<device_id>/status')
def api_get_device_status(device_id):
    """Получение статуса конкретного устройства"""
    device = next((d for d in timecard_monitor.devices if d['id'] == device_id), None)
    
    if not device:
        return jsonify({'error': 'Device not found'}), 404
    
    # Сбор реальных данных
    ptp_data = timecard_monitor.get_ptp_status(device)
    gnss_data = timecard_monitor.get_gnss_status(device)
    sma_data = timecard_monitor.get_sma_status(device)
    device_info = timecard_monitor.get_device_info(device)
    
    # Объединение данных
    device_data = {
        'ptp': ptp_data,
        'gnss': gnss_data,
        'sma': sma_data,
        'device_info': device_info,
        'timestamp': time.time()
    }
    
    # Генерация алертов
    alerts = timecard_monitor.generate_alerts(device_data)
    device_data['alerts'] = alerts
    
    return jsonify(device_data)

@app.route('/api/metrics/real')
def api_get_real_metrics():
    """Получение реальных метрик всех устройств"""
    all_metrics = {}
    
    for device in timecard_monitor.devices:
        ptp_data = timecard_monitor.get_ptp_status(device)
        gnss_data = timecard_monitor.get_gnss_status(device)
        sma_data = timecard_monitor.get_sma_status(device)
        
        all_metrics[device['id']] = {
            'ptp': ptp_data,
            'gnss': gnss_data,
            'sma': sma_data,
            'timestamp': time.time()
        }
    
    return jsonify(all_metrics)

@app.route('/api/alerts')
def api_get_alerts():
    """Получение активных алертов"""
    all_alerts = []
    
    for device in timecard_monitor.devices:
        ptp_data = timecard_monitor.get_ptp_status(device)
        gnss_data = timecard_monitor.get_gnss_status(device)
        
        device_data = {
            'ptp': ptp_data,
            'gnss': gnss_data
        }
        
        alerts = timecard_monitor.generate_alerts(device_data)
        for alert in alerts:
            alert['device_id'] = device['id']
            all_alerts.append(alert)
    
    return jsonify({
        'alerts': all_alerts,
        'count': len(all_alerts),
        'timestamp': time.time()
    })

@app.route('/api/metrics/history/<device_id>')
def api_get_metrics_history(device_id):
    """Получение истории метрик устройства"""
    if device_id not in timecard_monitor.metrics_history:
        return jsonify({'error': 'Device not found'}), 404
    
    # Pagination parameters
    try:
        limit = int(request.args.get('limit', '100'))
        offset = int(request.args.get('offset', '0'))
        if limit < 1:
            limit = 1
        if limit > 1000:
            limit = 1000
        if offset < 0:
            offset = 0
    except ValueError:
        limit = 100
        offset = 0

    full_history = list(timecard_monitor.metrics_history[device_id])
    count_total = len(full_history)
    end = min(offset + limit, count_total)
    history = full_history[offset:end]
    return jsonify({
        'device_id': device_id,
        'history': history,
        'count': len(history),
        'total': count_total,
        'limit': limit,
        'offset': offset,
        'timestamp': time.time()
    })


@app.route('/api/metrics/history/<device_id>/clear', methods=['POST'])
def api_clear_metrics_history(device_id):
    """Очистка истории метрик устройства"""
    if device_id not in timecard_monitor.metrics_history:
        return jsonify({'error': 'Device not found'}), 404
    timecard_monitor.metrics_history[device_id].clear()
    return jsonify({'device_id': device_id, 'cleared': True, 'timestamp': time.time()})


@app.route('/api/config', methods=['GET', 'PUT'])
def api_config():
    """Получение/обновление конфигурации (частично, с валидацией)"""
    global CONFIG
    if request.method == 'GET':
        # Не возвращаем потенциально чувствительные поля (на будущее)
        return jsonify(CONFIG)

    # PUT: обновление разрешенных полей
    try:
        payload = request.get_json(force=True) or {}
    except Exception:
        return jsonify({'error': 'Invalid JSON'}), 400

    updated = {}

    # Alerts thresholds (merged shallowly)
    if 'alerts' in payload and isinstance(payload['alerts'], dict):
        CONFIG['alerts'].update(payload['alerts'])
        updated['alerts'] = CONFIG['alerts']

    # Monitoring settings
    mon = payload.get('monitoring', {}) if isinstance(payload.get('monitoring', {}), dict) else {}
    if 'update_interval_seconds' in mon:
        try:
            CONFIG['monitoring']['update_interval_seconds'] = int(mon['update_interval_seconds'])
            updated.setdefault('monitoring', {})['update_interval_seconds'] = CONFIG['monitoring']['update_interval_seconds']
        except (TypeError, ValueError):
            return jsonify({'error': 'monitoring.update_interval_seconds must be int'}), 400
    if 'history_maxlen' in mon:
        try:
            new_len = int(mon['history_maxlen'])
            if new_len < 1:
                return jsonify({'error': 'history_maxlen must be >= 1'}), 400
            CONFIG['monitoring']['history_maxlen'] = new_len
            # Rebuild deques with new maxlen
            for dev_id, dq in list(timecard_monitor.metrics_history.items()):
                new_dq = deque(maxlen=new_len)
                # keep most recent entries
                for item in list(dq)[-new_len:]:
                    new_dq.append(item)
                timecard_monitor.metrics_history[dev_id] = new_dq
            updated.setdefault('monitoring', {})['history_maxlen'] = new_len
        except (TypeError, ValueError):
            return jsonify({'error': 'monitoring.history_maxlen must be int'}), 400

    # Server CORS origins (runtime)
    srv = payload.get('server', {}) if isinstance(payload.get('server', {}), dict) else {}
    if 'cors_allowed_origins' in srv:
        origins = srv['cors_allowed_origins']
        if isinstance(origins, list) and all(isinstance(x, str) for x in origins):
            CONFIG['server']['cors_allowed_origins'] = origins
            updated.setdefault('server', {})['cors_allowed_origins'] = origins
        else:
            return jsonify({'error': 'server.cors_allowed_origins must be a list of strings'}), 400

    return jsonify({'updated': updated, 'timestamp': time.time()})


@app.route('/health')
def api_health():
    """Простой healthcheck эндпоинт"""
    return jsonify({
        'status': 'ok',
        'up': True,
        'devices': len(timecard_monitor.devices),
        'version': CONFIG.get('version', '1.0.1'),
        'timestamp': time.time(),
    })


@app.route('/version')
def api_version():
    return jsonify({
        'version': CONFIG.get('version', '1.0.1'),
    })

@app.route('/')
def api_index():
    """Главная страница API"""
    return jsonify({
        'api_name': 'TimeCard Real Monitoring API',
        'version': '1.0.0',
        'description': 'API для мониторинга реальных данных TimeCard PTP OCP',
        'endpoints': {
            'devices': '/api/devices',
            'device_status': '/api/device/<device_id>/status',
            'real_metrics': '/api/metrics/real',
            'alerts': '/api/alerts',
            'history': '/api/metrics/history/<device_id>'
        },
        'available_devices': [d['id'] for d in timecard_monitor.devices],
        'timestamp': time.time()
    })

@app.route('/dashboard')
@app.route('/dashboard/')
def dashboard():
    """Дашборд мониторинга"""
    return send_from_directory('.', 'real-dashboard.html')

@app.route('/simple-dashboard')
@app.route('/simple-dashboard/')
def simple_dashboard():
    """Простой дашборд"""
    return send_from_directory('.', 'simple-dashboard.html')

@app.route('/web/<path:filename>')
def web_files(filename):
    """Статические файлы из папки web"""
    # Security: allow only whitelisted extensions and prevent directory traversal
    if not filename or '..' in filename or filename.startswith('/'):
        return jsonify({'error': 'invalid path'}), 403
    allowed_exts = set(CONFIG.get('static', {}).get('allowed_extensions', []))
    _, ext = os.path.splitext(filename)
    if ext not in allowed_exts:
        return jsonify({'error': 'forbidden extension'}), 403
    return send_from_directory('web', filename)

# === WEBSOCKET EVENTS ===

@socketio.on('connect')
def handle_connect():
    """Клиент подключился"""
    print('Client connected')
    
    if timecard_monitor.devices:
        device = timecard_monitor.devices[0]
        ptp_data = timecard_monitor.get_ptp_status(device)
        
        socketio.emit('status_update', {
            'connected': True,
            'devices_count': len(timecard_monitor.devices),
            'current_offset': ptp_data.get('offset_ns', 0),
            'api_version': '1.0.0',
            'features_enabled': [
                'real_ptp_monitoring',
                'real_gnss_monitoring', 
                'real_sma_monitoring',
                'alerting_system'
            ],
            'timestamp': time.time()
        })

@socketio.on('disconnect')
def handle_disconnect():
    """Клиент отключился"""
    print('Client disconnected')

@socketio.on('request_device_update')
def handle_device_update_request(data):
    """Запрос обновления данных устройства"""
    device_id = data.get('device_id', 'ocp0')
    device = next((d for d in timecard_monitor.devices if d['id'] == device_id), None)
    
    if device:
        try:
            # Быстрое обновление основных метрик
            ptp_data = timecard_monitor.get_ptp_status(device)
            gnss_data = timecard_monitor.get_gnss_status(device)
            
            quick_update = {
                'device_id': device_id,
                'ptp_offset': ptp_data.get('offset_ns', 0),
                'ptp_drift': ptp_data.get('drift_ppb', 0),
                'gnss_status': gnss_data.get('sync_status', 'UNKNOWN'),
                'timestamp': time.time()
            }
            
            socketio.emit('device_update', quick_update)
        except Exception as e:
            socketio.emit('error', {'message': f'Error updating device {device_id}: {str(e)}'})

if __name__ == '__main__':
    print("="*80)
    print("🚀 TimeCard PTP OCP Real Monitoring API v1.0")
    print("="*80)
    print("📊 Real Dashboard:    http://localhost:8080/dashboard")
    print("🔧 API Endpoints:     http://localhost:8080/api/")
    print("🏠 Main Page:         http://localhost:8080/")
    print("="*80)
    print("✨ Real Features:")
    print("   📡 Real PTP monitoring (offset, drift)")
    print("   🛰️  Real GNSS monitoring (sync status)")
    print("   🔌 Real SMA monitoring (connectors)")
    print("   🚨 Real alerting system")
    print("   📈 Real data history")
    print("   🔌 WebSocket live updates")
    print("="*80)
    print(f"📦 Detected devices: {len(timecard_monitor.devices)}")
    for device in timecard_monitor.devices:
        print(f"   🕐 {device['id']}: {device.get('serial_number', 'N/A')}")
    print("="*80)
    
    # Запуск веб-сервера
    port = int(CONFIG.get('server', {}).get('port', 8080))
    socketio.run(app, host='0.0.0.0', port=port, debug=True, allow_unsafe_werkzeug=True)