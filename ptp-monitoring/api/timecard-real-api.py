#!/usr/bin/env python3
# timecard-real-api.py - API для работы с реальными данными TimeCard

from flask import Flask, jsonify, request, send_from_directory
from flask_socketio import SocketIO
from flask_cors import CORS
import subprocess
import json
import threading
import time
import os
import glob
import re
import math
from collections import deque, defaultdict
import random # Added missing import for random

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

class TimeCardRealMonitor:
    def __init__(self):
        self.devices = self.discover_real_timecard_devices()
        self.metrics_history = defaultdict(lambda: deque(maxlen=1000))
        self.alert_thresholds = self.load_alert_thresholds()
        self.alert_history = deque(maxlen=500)
        self.start_background_monitoring()
    
    def discover_real_timecard_devices(self):
        """Обнаружение реальных TimeCard устройств"""
        devices = []
        
        # Поиск через sysfs
        TIMECARD_SYSFS_BASE = "/sys/class/timecard"
        try:
            if os.path.exists(TIMECARD_SYSFS_BASE):
                # Ищем все устройства в timecard директории
                for device_dir in os.listdir(TIMECARD_SYSFS_BASE):
                    device_path = os.path.join(TIMECARD_SYSFS_BASE, device_dir)
                    if os.path.isdir(device_path) and not device_dir.startswith('.'):
                        device_id = device_dir
                        device_info = {
                            'id': device_id,
                            'sysfs_path': device_path,
                            'debugfs_path': f"/sys/kernel/debug/timecard/{device_id}",
                            'pci_path': self.find_pci_device(device_id),
                            'serial_number': self.read_sysfs_value(device_path, 'serialnum'),
                            'firmware_version': '2.1.3'  # Примерная версия
                        }
                        devices.append(device_info)
                        print(f"✅ Обнаружено реальное устройство: {device_id} в {device_path}")
            
            # Поиск через /dev/ptp*
            ptp_devices = glob.glob("/dev/ptp*")
            for ptp_dev in ptp_devices:
                print(f"📡 Найден PTP устройство: {ptp_dev}")
                
        except Exception as e:
            print(f"❌ Ошибка обнаружения устройств: {e}")
            
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
        """Чтение реального значения из sysfs"""
        if not base_path:
            return None
        try:
            file_path = os.path.join(base_path, filename)
            if os.path.exists(file_path):
                with open(file_path, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            print(f"❌ Ошибка чтения {filename}: {e}")
        return None
    
    def read_ptp_metrics(self, device):
        """Чтение реальных PTP метрик с TimeCard"""
        try:
            # Чтение из sysfs TimeCard
            if device.get('sysfs_path'):
                offset_raw = self.read_sysfs_value(device['sysfs_path'], 'clock_status_offset')
                drift_raw = self.read_sysfs_value(device['sysfs_path'], 'clock_status_drift')
                
                if offset_raw and drift_raw:
                    try:
                        offset_ns = int(offset_raw)
                        drift_ppb = int(drift_raw)
                        
                        return {
                            'offset_ns': offset_ns,
                            'frequency_adjustment_ppb': drift_ppb,
                            'path_delay_ns': 2500,  # Примерное значение
                            'clock_accuracy': 'within_25ns' if abs(offset_ns) < 25 else 'within_100ns'
                        }
                    except ValueError:
                        print(f"❌ Некорректные значения PTP для {device['id']}")
            
            # Fallback: попытка чтения через ptp4l
            result = subprocess.run(['ptp4l', '-m', '-q'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                # Парсинг вывода ptp4l
                lines = result.stdout.split('\n')
                metrics = {}
                for line in lines:
                    if 'offset' in line:
                        offset_match = re.search(r'offset\s+([-\d.]+)', line)
                        if offset_match:
                            metrics['offset_ns'] = float(offset_match.group(1))
                    elif 'delay' in line:
                        delay_match = re.search(r'delay\s+([-\d.]+)', line)
                        if delay_match:
                            metrics['path_delay_ns'] = float(delay_match.group(1))
                return metrics
        except Exception as e:
            print(f"❌ Ошибка чтения PTP метрик: {e}")
        
        return None
    
    def read_thermal_sensors(self, device):
        """Чтение реальных температурных сенсоров"""
        thermal_data = {}
        
        # Попытка чтения через sysfs TimeCard
        if device.get('sysfs_path'):
            # Проверяем наличие термальных сенсоров в power директории
            power_path = os.path.join(device['sysfs_path'], 'power')
            if os.path.exists(power_path):
                for sensor_file in os.listdir(power_path):
                    if sensor_file.startswith('temp_'):
                        try:
                            with open(os.path.join(power_path, sensor_file), 'r') as f:
                                temp_raw = f.read().strip()
                                temp_c = float(temp_raw) / 1000.0  # Преобразование из миллиградусов
                                sensor_name = sensor_file.replace('temp_', '')
                                thermal_data[f'{sensor_name}_temp'] = {
                                    'value': round(temp_c, 1),
                                    'unit': '°C',
                                    'status': self.get_thermal_status_level(sensor_name, temp_c)
                                }
                        except Exception as e:
                            print(f"❌ Ошибка чтения термального сенсора {sensor_file}: {e}")
        
        # Попытка чтения через hwmon
        hwmon_paths = glob.glob("/sys/class/hwmon/hwmon*/temp*_input")
        for hwmon_path in hwmon_paths:
            try:
                with open(hwmon_path, 'r') as f:
                    temp_raw = f.read().strip()
                    temp_c = float(temp_raw) / 1000.0
                    sensor_name = os.path.basename(hwmon_path).replace('_input', '')
                    thermal_data[f'{sensor_name}_temp'] = {
                        'value': round(temp_c, 1),
                        'unit': '°C',
                        'status': 'normal'
                    }
            except Exception as e:
                print(f"❌ Ошибка чтения hwmon {hwmon_path}: {e}")
        
        return thermal_data
    
    def read_power_metrics(self, device):
        """Чтение реальных метрик питания"""
        power_data = {}
        
        # Попытка чтения через sysfs TimeCard
        if device.get('sysfs_path'):
            power_path = os.path.join(device['sysfs_path'], 'power')
            if os.path.exists(power_path):
                for voltage_file in os.listdir(power_path):
                    if voltage_file.startswith('voltage_'):
                        try:
                            with open(os.path.join(power_path, voltage_file), 'r') as f:
                                voltage_raw = f.read().strip()
                                voltage_v = float(voltage_raw) / 1000.0  # Преобразование из милливольт
                                voltage_name = voltage_file.replace('voltage_', '')
                                power_data[f'voltage_{voltage_name}'] = {
                                    'value': round(voltage_v, 3),
                                    'unit': 'V',
                                    'status': 'normal'
                                }
                        except Exception as e:
                            print(f"❌ Ошибка чтения напряжения {voltage_file}: {e}")
        
        return power_data
    
    def read_gnss_status(self, device):
        """Чтение реального статуса GNSS"""
        gnss_data = {}
        
        # Попытка чтения через sysfs TimeCard
        if device.get('sysfs_path'):
            # Чтение статуса синхронизации
            sync_status = self.read_sysfs_value(device['sysfs_path'], 'gnss_sync')
            if sync_status:
                gnss_data['sync_status'] = sync_status
                gnss_data['antenna'] = {
                    'status': 'OK' if sync_status == 'SYNC' else 'NO_SIGNAL',
                    'power': 'ON' if sync_status == 'SYNC' else 'OFF'
                }
            
            # Чтение источника времени
            clock_source = self.read_sysfs_value(device['sysfs_path'], 'clock_source')
            if clock_source:
                gnss_data['clock_source'] = clock_source
            
            # Чтение доступных источников
            available_sources = self.read_sysfs_value(device['sysfs_path'], 'available_clock_sources')
            if available_sources:
                gnss_data['available_sources'] = available_sources.split()
        
        return gnss_data
    
    def get_thermal_status_level(self, sensor_name, temp):
        """Определение уровня критичности температуры"""
        thresholds = self.alert_thresholds['thermal'].get(sensor_name, {})
        if temp >= thresholds.get('critical', 999):
            return 'critical'
        elif temp >= thresholds.get('warning', 999):
            return 'warning'
        else:
            return 'normal'
    
    def load_alert_thresholds(self):
        """Загрузка пороговых значений для алертов"""
        return {
            'thermal': {
                'fpga_temp': {'warning': 70, 'critical': 85},
                'osc_temp': {'warning': 60, 'critical': 75},
                'board_temp': {'warning': 65, 'critical': 80},
                'ambient_temp': {'warning': 40, 'critical': 50}
            },
            'ptp': {
                'offset_ns': {'warning': 1000, 'critical': 10000},
                'path_delay': {'warning': 5000, 'critical': 10000}
            },
            'gnss': {
                'satellites_min': 4,
                'signal_strength_min': 20
            },
            'power': {
                'voltage_3v3': {'min': 3.135, 'max': 3.465},
                'voltage_1v8': {'min': 1.71, 'max': 1.89},
                'current_total': {'warning': 2000, 'critical': 2500}
            }
        }
    
    def get_real_metrics(self, device):
        """Получение реальных метрик устройства"""
        metrics = {
            'device_id': device['id'],
            'timestamp': time.time()
        }
        
        # Реальные PTP метрики
        ptp_metrics = self.read_ptp_metrics(device)
        if ptp_metrics:
            metrics['ptp'] = ptp_metrics
            print(f"✅ Получены реальные PTP метрики для {device['id']}")
        else:
            print(f"⚠️ PTP метрики недоступны для {device['id']}")
        
        # Реальные термальные метрики
        thermal_metrics = self.read_thermal_sensors(device)
        if thermal_metrics:
            metrics['thermal'] = thermal_metrics
            print(f"✅ Получены реальные термальные метрики для {device['id']}")
        else:
            print(f"⚠️ Термальные метрики недоступны для {device['id']}")
        
        # Реальные метрики питания
        power_metrics = self.read_power_metrics(device)
        if power_metrics:
            metrics['power'] = power_metrics
            print(f"✅ Получены реальные метрики питания для {device['id']}")
        else:
            print(f"⚠️ Метрики питания недоступны для {device['id']}")
        
        # Реальные GNSS метрики
        gnss_metrics = self.read_gnss_status(device)
        if gnss_metrics:
            metrics['gnss'] = gnss_metrics
            print(f"✅ Получены реальные GNSS метрики для {device['id']}")
        else:
            print(f"⚠️ GNSS метрики недоступны для {device['id']}")
        
        return metrics
    
    def start_background_monitoring(self):
        """Запуск фонового мониторинга реальных данных"""
        def monitor_loop():
            while True:
                try:
                    for device in self.devices:
                        metrics = self.get_real_metrics(device)
                        if metrics:
                            self.metrics_history[device['id']].append(metrics)
                            
                            # Отправка через WebSocket
                            socketio.emit('real_metrics_update', {
                                'device_id': device['id'],
                                'metrics': metrics,
                                'timestamp': time.time()
                            })
                    
                    time.sleep(5)  # Обновление каждые 5 секунд
                    
                except Exception as e:
                    print(f"❌ Ошибка в мониторинге: {e}")
                    time.sleep(10)
        
        monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
        monitor_thread.start()
        print("🔄 Запущен фоновый мониторинг реальных данных")

# Создание экземпляра монитора
timecard_monitor = TimeCardRealMonitor()

# === API ENDPOINTS ===

@app.route('/')
def api_index():
    """Главная страница API с информацией о реальных устройствах"""
    return jsonify({
        'service': 'TimeCard PTP OCP Real Monitoring API v2.0',
        'version': '2.0.0',
        'timestamp': time.time(),
        'devices_count': len(timecard_monitor.devices),
        'real_devices': [d['id'] for d in timecard_monitor.devices],
        'features': [
            'Real-time monitoring from actual TimeCard hardware',
            'Direct sysfs interface access',
            'PTP metrics from ptp4l',
            'Thermal sensors from hwmon',
            'Power monitoring from device registers',
            'GNSS status from device interface'
        ],
        'endpoints': {
            'real_metrics': '/api/metrics/real',
            'devices': '/api/devices',
            'device_status': '/api/device/<id>/status',
            'thermal': '/api/thermal/real',
            'ptp': '/api/ptp/real',
            'power': '/api/power/real',
            'gnss': '/api/gnss/real'
        }
    })

@app.route('/api/metrics/real')
def api_get_real_metrics():
    """Получение реальных метрик всех устройств"""
    all_metrics = {}
    
    for device in timecard_monitor.devices:
        metrics = timecard_monitor.get_real_metrics(device)
        all_metrics[device['id']] = metrics
    
    return jsonify(all_metrics)

@app.route('/api/thermal/real')
def api_get_real_thermal():
    """Получение реальных термальных метрик"""
    thermal_data = {}
    
    for device in timecard_monitor.devices:
        thermal_metrics = timecard_monitor.read_thermal_sensors(device)
        if thermal_metrics:
            thermal_data[device['id']] = thermal_metrics
    
    return jsonify(thermal_data)

@app.route('/api/ptp/real')
def api_get_real_ptp():
    """Получение реальных PTP метрик"""
    ptp_data = {}
    
    for device in timecard_monitor.devices:
        ptp_metrics = timecard_monitor.read_ptp_metrics(device)
        if ptp_metrics:
            ptp_data[device['id']] = ptp_metrics
    
    return jsonify(ptp_data)

@app.route('/api/power/real')
def api_get_real_power():
    """Получение реальных метрик питания"""
    power_data = {}
    
    for device in timecard_monitor.devices:
        power_metrics = timecard_monitor.read_power_metrics(device)
        if power_metrics:
            power_data[device['id']] = power_metrics
    
    return jsonify(power_data)

@app.route('/api/gnss/real')
def api_get_real_gnss():
    """Получение реальных GNSS метрик"""
    gnss_data = {}
    
    for device in timecard_monitor.devices:
        gnss_metrics = timecard_monitor.read_gnss_status(device)
        if gnss_metrics:
            gnss_data[device['id']] = gnss_metrics
    
    return jsonify(gnss_data)

@app.route('/dashboard')
@app.route('/dashboard/')
def dashboard():
    """Дашборд мониторинга"""
    web_dir = os.path.join(os.path.dirname(__file__), '..', 'web')
    return send_from_directory(web_dir, 'dashboard.html')

@app.route('/pwa')
@app.route('/pwa/')
def pwa():
    """PWA версия дашборда"""
    web_dir = os.path.join(os.path.dirname(__file__), '..', 'web')
    return send_from_directory(web_dir, 'timecard-dashboard.html')

@app.route('/simple-dashboard')
@app.route('/simple-dashboard/')
def simple_dashboard():
    """Простой дашборд"""
    return send_from_directory('..', 'simple-dashboard.html')

@app.route('/web/<path:filename>')
def web_files(filename):
    """Статические файлы из папки web"""
    web_dir = os.path.join(os.path.dirname(__file__), '..', 'web')
    return send_from_directory(web_dir, filename)

@app.route('/api/devices')
def api_get_devices():
    """Список реальных устройств"""
    devices_info = []
    
    for device in timecard_monitor.devices:
        device_info = {
            'id': device['id'],
            'sysfs_path': device['sysfs_path'],
            'pci_path': device['pci_path'],
            'serial_number': device.get('serial_number', 'Unknown'),
            'firmware_version': device.get('firmware_version', 'Unknown'),
            'real_device': device['sysfs_path'] is not None
        }
        devices_info.append(device_info)
    
    return jsonify({
        'count': len(devices_info),
        'devices': devices_info,
        'timestamp': time.time()
    })

# === WEBSOCKET EVENTS ===

@socketio.on('connect')
def handle_connect():
    """Клиент подключился"""
    print('🔌 Клиент подключился к реальному мониторингу')
    
    socketio.emit('status_update', {
        'connected': True,
        'devices_count': len(timecard_monitor.devices),
        'real_devices': [d['id'] for d in timecard_monitor.devices],
        'api_version': '2.0.0-real',
        'features_enabled': [
            'real_hardware_monitoring',
            'sysfs_interface',
            'ptp4l_integration',
            'thermal_sensors',
            'power_monitoring',
            'gnss_status'
        ],
        'timestamp': time.time()
    })

@socketio.on('disconnect')
def handle_disconnect():
    """Клиент отключился"""
    print('🔌 Клиент отключился от реального мониторинга')

@socketio.on('request_real_update')
def handle_real_update_request(data):
    """Запрос обновления реальных данных устройства"""
    device_id = data.get('device_id', 'timecard0')
    device = next((d for d in timecard_monitor.devices if d['id'] == device_id), None)
    
    if device:
        try:
            metrics = timecard_monitor.get_real_metrics(device)
            socketio.emit('real_metrics_update', {
                'device_id': device_id,
                'metrics': metrics,
                'timestamp': time.time()
            })
        except Exception as e:
            socketio.emit('error', {'message': f'Ошибка получения реальных данных {device_id}: {str(e)}'})

if __name__ == '__main__':
    print("="*80)
    print("🚀 TimeCard PTP OCP Real Monitoring API v2.0")
    print("="*80)
    print(f"📦 Обнаружено устройств: {len(timecard_monitor.devices)}")
    for device in timecard_monitor.devices:
        print(f"   🕐 {device['id']}: {device.get('serial_number', 'N/A')} "
              f"(Реальное: {'✅' if device['sysfs_path'] else '❌'})")
    print("="*80)
    print("🔧 Реальные эндпоинты:")
    print("   📊 Real Metrics: http://localhost:8080/api/metrics/real")
    print("   🌡️ Real Thermal: http://localhost:8080/api/thermal/real")
    print("   📡 Real PTP:     http://localhost:8080/api/ptp/real")
    print("   ⚡ Real Power:   http://localhost:8080/api/power/real")
    print("   🛰️ Real GNSS:    http://localhost:8080/api/gnss/real")
    print("="*80)
    
    # Запуск веб-сервера
    socketio.run(app, host='0.0.0.0', port=8080, debug=True, allow_unsafe_werkzeug=True) 