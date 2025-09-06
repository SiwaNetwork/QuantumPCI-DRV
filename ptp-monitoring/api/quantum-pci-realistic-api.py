#!/usr/bin/env python3
"""
Quantum-PCI Realistic Monitoring API
Мониторинг ТОЛЬКО реальных метрик, доступных в ptp_ocp драйвере
"""

from flask import Flask, jsonify, request, send_from_directory
from flask_socketio import SocketIO
from flask_cors import CORS
import subprocess
import threading
import time
import os
import glob
from collections import deque, defaultdict
from pathlib import Path

# === Конфигурация ===
CONFIG = {
    'version': '2.0.0-realistic',
    'server': {
        'port': 8080,
        'cors_allowed_origins': ['http://localhost:8080', 'http://127.0.0.1:8080']
    },
    'monitoring': {
        'update_interval_seconds': 5,
        'history_maxlen': 1000,
    },
    'alerts': {
        'ptp': {
            'offset_ns': {'warning': 1000, 'critical': 10000},
            'drift_ppb': {'warning': 100, 'critical': 1000},
        }
    }
}

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": CONFIG['server']['cors_allowed_origins']}})
socketio = SocketIO(app, cors_allowed_origins=CONFIG['server']['cors_allowed_origins'])

class QuantumPCIRealisticMonitor:
    """
    Мониторинг ТОЛЬКО тех метрик, которые реально доступны в ptp_ocp драйвере
    
    РЕАЛЬНЫЕ возможности драйвера:
    - clock_status_offset (нс)
    - clock_status_drift (ppb) 
    - gnss_sync (статус)
    - clock_source (источник)
    - serialnum (серийный номер)
    - sma1-4 (конфигурация SMA)
    - temperature_table (только для ART Card)
    """
    
    def __init__(self):
        self.devices = self.discover_devices()
        self.metrics_history = defaultdict(lambda: deque(maxlen=CONFIG['monitoring']['history_maxlen']))
        self.alert_history = deque(maxlen=100)
        self.start_monitoring()
        
    def discover_devices(self):
        """Обнаружение реальных Quantum-PCI устройств"""
        devices = []
        timecard_path = "/sys/class/timecard"
        
        try:
            if os.path.exists(timecard_path):
                for device_dir in glob.glob(f"{timecard_path}/*"):
                    device_id = os.path.basename(device_dir)
                    devices.append({
                        'id': device_id,
                        'sysfs_path': device_dir,
                        'serial': self._read_sysfs(device_dir, 'serialnum'),
                        'type': 'Quantum-PCI TimeCard'
                    })
                    print(f"✅ Обнаружено устройство: {device_id}")
        except Exception as e:
            print(f"❌ Ошибка поиска устройств: {e}")
            
        if not devices:
            print("⚠️  Quantum-PCI устройства не найдены")
            print("   Убедитесь что:")
            print("   - Драйвер ptp_ocp загружен: lsmod | grep ptp_ocp")
            print("   - Устройство видно: ls /sys/class/timecard/")
            
        return devices
    
    def _read_sysfs(self, device_path, attribute):
        """Безопасное чтение из sysfs"""
        try:
            file_path = os.path.join(device_path, attribute)
            if os.path.exists(file_path):
                with open(file_path, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            print(f"Ошибка чтения {attribute}: {e}")
        return None
    
    def get_ptp_metrics(self, device):
        """Получение реальных PTP метрик из драйвера"""
        metrics = {}
        
        # РЕАЛЬНЫЕ метрики из ptp_ocp драйвера
        offset_raw = self._read_sysfs(device['sysfs_path'], 'clock_status_offset')
        drift_raw = self._read_sysfs(device['sysfs_path'], 'clock_status_drift')
        clock_source = self._read_sysfs(device['sysfs_path'], 'clock_source')
        
        # Парсинг значений
        try:
            metrics['offset_ns'] = int(offset_raw) if offset_raw else 0
        except (ValueError, TypeError):
            metrics['offset_ns'] = 0
            
        try:
            metrics['drift_ppb'] = int(drift_raw) if drift_raw else 0
        except (ValueError, TypeError):
            metrics['drift_ppb'] = 0
            
        metrics['clock_source'] = clock_source or 'UNKNOWN'
        
        # Статус на основе реальных пороговых значений
        offset_abs = abs(metrics['offset_ns'])
        if offset_abs > CONFIG['alerts']['ptp']['offset_ns']['critical']:
            metrics['status'] = 'critical'
        elif offset_abs > CONFIG['alerts']['ptp']['offset_ns']['warning']:
            metrics['status'] = 'warning'
        else:
            metrics['status'] = 'ok'
            
        return metrics
    
    def get_gnss_status(self, device):
        """Получение статуса GNSS (ограниченные данные из драйвера)"""
        gnss_sync = self._read_sysfs(device['sysfs_path'], 'gnss_sync')
        
        status = {
            'sync_status': gnss_sync or 'UNKNOWN',
            'available': gnss_sync is not None
        }
        
        # Простая классификация статуса
        if gnss_sync:
            if 'SYNC' in gnss_sync.upper():
                status['status'] = 'ok'
            elif 'LOST' in gnss_sync.upper():
                status['status'] = 'critical'
            else:
                status['status'] = 'warning'
        else:
            status['status'] = 'unknown'
            
        return status
    
    def get_sma_status(self, device):
        """Получение статуса SMA разъемов"""
        sma_status = {}
        
        for i in range(1, 5):  # SMA1-4
            sma_config = self._read_sysfs(device['sysfs_path'], f'sma{i}')
            sma_status[f'sma{i}'] = {
                'config': sma_config or 'unknown',
                'available': sma_config is not None
            }
            
        # Доступные опции
        available_inputs = self._read_sysfs(device['sysfs_path'], 'available_sma_inputs')
        available_outputs = self._read_sysfs(device['sysfs_path'], 'available_sma_outputs')
        
        sma_status['available_inputs'] = available_inputs.split(',') if available_inputs else []
        sma_status['available_outputs'] = available_outputs.split(',') if available_outputs else []
        
        return sma_status
    
    def get_device_info(self, device):
        """Получение информации об устройстве"""
        available_sources = self._read_sysfs(device['sysfs_path'], 'available_clock_sources')
        
        return {
            'device_id': device['id'],
            'serial_number': device['serial'] or 'UNKNOWN',
            'type': device['type'],
            'driver': 'ptp_ocp',
            'available_clock_sources': available_sources.split(',') if available_sources else [],
            'sysfs_path': device['sysfs_path']
        }
    
    def get_limited_temperature(self, device):
        """
        Получение ограниченных температурных данных
        ВНИМАНИЕ: Доступно только для некоторых устройств (ART Card)
        """
        temp_data = {}
        
        # Проверяем наличие temperature_table (только ART Card)
        temp_table_path = os.path.join(device['sysfs_path'], 'temperature_table')
        if os.path.exists(temp_table_path):
            temp_data['temperature_table_available'] = True
            temp_data['note'] = 'Temperature table available (ART Card only)'
        else:
            temp_data['temperature_table_available'] = False
            temp_data['note'] = 'Temperature monitoring not available for this device'
            
        return temp_data
    
    def generate_alerts(self, device_data):
        """Генерация алертов на основе реальных данных"""
        alerts = []
        
        ptp_data = device_data.get('ptp', {})
        if ptp_data.get('status') == 'critical':
            alerts.append({
                'type': 'ptp_offset_critical',
                'message': f"PTP offset критический: {ptp_data.get('offset_ns', 0)} нс",
                'severity': 'critical',
                'timestamp': time.time()
            })
        elif ptp_data.get('status') == 'warning':
            alerts.append({
                'type': 'ptp_offset_warning', 
                'message': f"PTP offset предупреждение: {ptp_data.get('offset_ns', 0)} нс",
                'severity': 'warning',
                'timestamp': time.time()
            })
            
        gnss_data = device_data.get('gnss', {})
        if gnss_data.get('status') == 'critical':
            alerts.append({
                'type': 'gnss_sync_lost',
                'message': f"GNSS синхронизация потеряна: {gnss_data.get('sync_status', 'UNKNOWN')}",
                'severity': 'critical', 
                'timestamp': time.time()
            })
            
        return alerts
    
    def start_monitoring(self):
        """Запуск фонового мониторинга"""
        def monitor_loop():
            while True:
                try:
                    for device in self.devices:
                        # Сбор ТОЛЬКО реальных данных
                        device_data = {
                            'ptp': self.get_ptp_metrics(device),
                            'gnss': self.get_gnss_status(device),
                            'sma': self.get_sma_status(device),
                            'device_info': self.get_device_info(device),
                            'temperature': self.get_limited_temperature(device),
                            'timestamp': time.time()
                        }
                        
                        # Генерация алертов
                        alerts = self.generate_alerts(device_data)
                        device_data['alerts'] = alerts
                        
                        # Сохранение в историю
                        self.metrics_history[device['id']].append(device_data)
                        
                        # WebSocket обновления
                        socketio.emit('device_update', {
                            'device_id': device['id'],
                            'ptp_offset': device_data['ptp']['offset_ns'],
                            'ptp_drift': device_data['ptp']['drift_ppb'],
                            'gnss_status': device_data['gnss']['sync_status'],
                            'timestamp': time.time()
                        })
                        
                except Exception as e:
                    print(f"Ошибка в цикле мониторинга: {e}")
                    
                time.sleep(CONFIG['monitoring']['update_interval_seconds'])
        
        monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
        monitor_thread.start()

# Создание экземпляра монитора
monitor = QuantumPCIRealisticMonitor()

# === API ROUTES ===

@app.route('/')
def api_index():
    """Главная страница API с disclaimer"""
    return jsonify({
        'api_name': 'Quantum-PCI Realistic Monitoring API',
        'version': CONFIG['version'],
        'description': 'Мониторинг ТОЛЬКО реальных метрик из ptp_ocp драйвера',
        'disclaimer': {
            'limitations': [
                'Нет детального мониторинга температуры (только temperature_table для ART Card)',
                'Нет мониторинга питания и напряжений',
                'Нет детального GNSS мониторинга (спутники, качество сигнала)',
                'Нет мониторинга LED индикаторов и FPGA состояния',
                'Доступны только базовые PTP/GNSS/SMA метрики из sysfs'
            ],
            'available_metrics': [
                'PTP offset/drift из clock_status_*',
                'GNSS sync статус из gnss_sync',
                'SMA конфигурация из sma1-4',
                'Источники времени из clock_source',
                'Серийный номер из serialnum'
            ]
        },
        'endpoints': {
            'devices': '/api/devices',
            'device_status': '/api/device/<device_id>/status', 
            'real_metrics': '/api/metrics/real',
            'alerts': '/api/alerts',
            'roadmap': '/api/roadmap'
        },
        'detected_devices': len(monitor.devices),
        'timestamp': time.time()
    })

@app.route('/api/roadmap')
def api_roadmap():
    """Эндпоинт с дорожной картой развития проекта"""
    return jsonify({
        'title': 'Дорожная карта проекта Quantum-PCI Monitoring',
        'current_version': '2.0 - Realistic Baseline',
        'current_capabilities': {
            'ptp_monitoring': 'Базовый мониторинг offset/drift',
            'gnss_status': 'Статус синхронизации GNSS',
            'sma_configuration': 'Конфигурация SMA разъемов',
            'web_interface': 'Реалистичный веб-интерфейс',
            'api': 'REST API с честной документацией'
        },
        'upcoming_releases': {
            'v2.1': {
                'timeline': '3-4 недели',
                'features': ['Расширенная PTP аналитика', 'Улучшенная система алертов', 'Оптимизация производительности']
            },
            'v2.2': {
                'timeline': '2-3 недели',
                'features': ['Интерактивные графики', 'Dashboard customization', 'Mobile optimization']
            },
            'v2.3': {
                'timeline': '2-3 недели', 
                'features': ['Prometheus integration', 'Configuration management', 'Authentication & Security']
            }
        },
        'long_term_vision': {
            'v3.0': 'Driver Enhancement Research',
            'v3.1': 'Advanced GNSS Features',
            'v3.2': 'Network Time Integration',
            'v4.0+': 'Enterprise Features & Cloud Integration'
        },
        'how_to_contribute': {
            'bug_reports': 'GitHub Issues для багов и тестирования',
            'code_contributions': 'Pull requests для новых фичей',
            'documentation': 'Помощь с документацией и переводами',
            'research': 'Исследование новых возможностей драйвера'
        },
        'roadmap_url': 'https://github.com/SiwaNetwork/QuantumPCI-DRV/blob/main/ptp-monitoring/ROADMAP.md',
        'timestamp': time.time()
    })

@app.route('/api/devices')
def api_devices():
    """Список обнаруженных устройств"""
    devices_info = []
    for device in monitor.devices:
        device_info = monitor.get_device_info(device)
        devices_info.append(device_info)
    
    return jsonify({
        'count': len(monitor.devices),
        'devices': devices_info,
        'note': 'Показаны только устройства с загруженным драйвером ptp_ocp',
        'timestamp': time.time()
    })

@app.route('/api/device/<device_id>/status')
def api_device_status(device_id):
    """Статус конкретного устройства"""
    device = next((d for d in monitor.devices if d['id'] == device_id), None)
    if not device:
        return jsonify({'error': 'Device not found'}), 404
    
    device_data = {
        'ptp': monitor.get_ptp_metrics(device),
        'gnss': monitor.get_gnss_status(device),
        'sma': monitor.get_sma_status(device),
        'device_info': monitor.get_device_info(device),
        'temperature': monitor.get_limited_temperature(device),
        'timestamp': time.time()
    }
    
    device_data['alerts'] = monitor.generate_alerts(device_data)
    return jsonify(device_data)

@app.route('/api/metrics/real')
def api_real_metrics():
    """Реальные метрики всех устройств"""
    all_metrics = {}
    
    for device in monitor.devices:
        all_metrics[device['id']] = {
            'ptp': monitor.get_ptp_metrics(device),
            'gnss': monitor.get_gnss_status(device),
            'sma': monitor.get_sma_status(device),
            'timestamp': time.time()
        }
    
    return jsonify({
        'metrics': all_metrics,
        'note': 'Только реальные метрики из ptp_ocp драйвера',
        'timestamp': time.time()
    })

@app.route('/api/alerts')
def api_alerts():
    """Активные алерты"""
    all_alerts = []
    
    for device in monitor.devices:
        device_data = {
            'ptp': monitor.get_ptp_metrics(device),
            'gnss': monitor.get_gnss_status(device)
        }
        
        alerts = monitor.generate_alerts(device_data)
        for alert in alerts:
            alert['device_id'] = device['id']
            all_alerts.append(alert)
    
    return jsonify({
        'alerts': all_alerts,
        'count': len(all_alerts),
        'timestamp': time.time()
    })

@app.route('/dashboard')
def dashboard():
    """Основной дашборд"""
    return send_from_directory('.', 'dashboard.html')

@app.route('/web/<path:filename>')
def web_files(filename):
    """Статические веб-файлы"""
    return send_from_directory('web', filename)

@app.route('/health')
def health():
    """Health check"""
    return jsonify({
        'status': 'ok',
        'devices': len(monitor.devices),
        'version': CONFIG['version'],
        'realistic_monitoring': True,
        'timestamp': time.time()
    })

# === WebSocket Events ===

@socketio.on('connect')
def handle_connect():
    """Клиент подключился"""
    print('Client connected to realistic API')
    
    if monitor.devices:
        device = monitor.devices[0]
        ptp_data = monitor.get_ptp_metrics(device)
        
        socketio.emit('status_update', {
            'connected': True,
            'devices_count': len(monitor.devices),
            'current_offset': ptp_data.get('offset_ns', 0),
            'api_version': CONFIG['version'],
            'realistic_monitoring': True,
            'limitations_warning': 'Доступны только базовые метрики из ptp_ocp драйвера',
            'timestamp': time.time()
        })

@socketio.on('disconnect')
def handle_disconnect():
    """Клиент отключился"""
    print('Client disconnected')

if __name__ == '__main__':
    print("="*80)
    print("🚀 Quantum-PCI REALISTIC Monitoring API v2.0")
    print("="*80)
    print("⚠️  ВАЖНО: Система мониторинга ограничена возможностями ptp_ocp драйвера")
    print("")
    print("✅ ДОСТУПНЫЕ метрики:")
    print("   📊 PTP offset/drift из sysfs")
    print("   🛰️  GNSS sync статус")
    print("   🔌 SMA конфигурация")
    print("   📋 Информация об устройстве")
    print("")
    print("❌ НЕ ДОСТУПНЫЕ метрики:")
    print("   🌡️  Детальный мониторинг температуры")
    print("   ⚡ Мониторинг питания и напряжений")
    print("   🛰️  Детальный GNSS (спутники, качество)")
    print("   🔧 Состояние LED/FPGA/аппаратуры")
    print("="*80)
    print(f"📊 Dashboard: http://localhost:8080/dashboard")
    print(f"🔧 API: http://localhost:8080/api/")
    print(f"⚠️  Limitations: http://localhost:8080/api/limitations")
    print("="*80)
    print(f"📦 Обнаружено устройств: {len(monitor.devices)}")
    for device in monitor.devices:
        print(f"   🕐 {device['id']}: {device.get('serial', 'N/A')}")
    print("="*80)
    
    socketio.run(app, host='0.0.0.0', port=CONFIG['server']['port'], debug=False)
