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

# Импорт PTP мониторинга
try:
    from intel_network_monitor import get_ptp_network_metrics, get_ptp_network_health, get_ptp_network_ptp_metrics, get_ptp_interface_metrics
    PTP_MONITORING_AVAILABLE = True
    print("✅ PTP мониторинг доступен")
except ImportError as e:
    PTP_MONITORING_AVAILABLE = False
    print(f"⚠️  PTP мониторинг недоступен - {e}")
# Импорт BMP280 мониторинга
try:
    from bmp280_monitor import get_bmp280_data, get_bmp280_info, is_bmp280_available
    BMP280_MONITORING_AVAILABLE = True
    print("✅ BMP280 мониторинг доступен")
except ImportError as e:
    BMP280_MONITORING_AVAILABLE = False
    print(f"⚠️  BMP280 мониторинг недоступен - {e}")

# Импорт INA219 мониторинга
try:
    from ina219_monitor import get_ina219_data, get_ina219_info, is_ina219_available
    INA219_MONITORING_AVAILABLE = True
    print("✅ INA219 мониторинг доступен")
except ImportError as e:
    INA219_MONITORING_AVAILABLE = False
    print(f"⚠️  INA219 мониторинг недоступен - {e}")

# PCT2075 мониторинг отключен - датчик неисправен
PCT2075_MONITORING_AVAILABLE = False
print("❌ PCT2075 мониторинг отключен - датчик неисправен")

# Импорт BNO055 мониторинга
try:
    from bno055_monitor import BNO055Monitor
    BNO055_MONITORING_AVAILABLE = True
    print("✅ BNO055 мониторинг доступен")
except ImportError as e:
    BNO055_MONITORING_AVAILABLE = False
    print(f"⚠️  BNO055 мониторинг недоступен - {e}")


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

# === Функция инициализации мультиплексора I2C ===
def initialize_i2c_mux():
    """
    Инициализация мультиплексора I2C для доступа ко всем датчикам
    """
    try:
        print("🔧 Инициализация мультиплексора I2C...")

        # Параметры мультиплексора
        I2C_BUS = 1
        MUX_ADDR = 0x70
        MUX_VALUE = 0x0F  # Активация всех шин

        # Команда для настройки мультиплексора
        cmd = f"i2cset -y {I2C_BUS} {MUX_ADDR:#x} {MUX_VALUE:#x}"

        print(f"   Выполнение: {cmd}")

        # Выполняем команду
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        if result.returncode == 0:
            print("✅ Мультиплексор I2C успешно настроен")
            print(f"   Активированы все шины мультиплексора (0x{MUX_VALUE:02X})")
        else:
            print(f"⚠️  Предупреждение: не удалось настроить мультиплексор: {result.stderr}")

        # Небольшая пауза для стабилизации
        time.sleep(0.5)

    except Exception as e:
        print(f"⚠️  Ошибка инициализации мультиплексора: {e}")
        print("   Продолжаем без настройки мультиплексора")

# === Инициализация ===
print("="*80)
print("🚀 Quantum-PCI Real Monitoring v2.0")
print("="*80)

# Сначала инициализируем мультиплексор I2C
initialize_i2c_mux()

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
        self.start_time = time.time()
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
        utc_tai_offset_raw = self._read_sysfs(device['sysfs_path'], 'utc_tai_offset')
        tod_correction_raw = self._read_sysfs(device['sysfs_path'], 'tod_correction')
        
        # Парсинг значений
        try:
            metrics['offset_ns'] = int(offset_raw) if offset_raw else 0
        except (ValueError, TypeError):
            metrics['offset_ns'] = 0
            
        try:
            metrics['drift_ppb'] = int(drift_raw) if drift_raw else 0
        except (ValueError, TypeError):
            metrics['drift_ppb'] = 0
            
        try:
            metrics['utc_tai_offset'] = int(utc_tai_offset_raw) if utc_tai_offset_raw else 0
        except (ValueError, TypeError):
            metrics['utc_tai_offset'] = 0
            
        try:
            metrics['tod_correction'] = int(tod_correction_raw) if tod_correction_raw else 0
        except (ValueError, TypeError):
            metrics['tod_correction'] = 0
            
        # Настраиваемые параметры
        irig_b_mode_raw = self._read_sysfs(device['sysfs_path'], 'irig_b_mode')
        ts_window_adjust_raw = self._read_sysfs(device['sysfs_path'], 'ts_window_adjust')
        
        try:
            metrics['irig_b_mode'] = int(irig_b_mode_raw) if irig_b_mode_raw else 0
        except (ValueError, TypeError):
            metrics['irig_b_mode'] = 0
            
        try:
            metrics['ts_window_adjust'] = int(ts_window_adjust_raw) if ts_window_adjust_raw else 0
        except (ValueError, TypeError):
            metrics['ts_window_adjust'] = 0
            
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
        available_sma_inputs = self._read_sysfs(device['sysfs_path'], 'available_sma_inputs')
        available_sma_outputs = self._read_sysfs(device['sysfs_path'], 'available_sma_outputs')
        
        return {
            'device_id': device['id'],
            'serial_number': device['serial'] or 'UNKNOWN',
            'type': device['type'],
            'driver': 'ptp_ocp',
            'available_clock_sources': available_sources.split(',') if available_sources else [],
            'available_sma_inputs': available_sma_inputs.split(',') if available_sma_inputs else [],
            'available_sma_outputs': available_sma_outputs.split(',') if available_sma_outputs else [],
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
def main_page():
    """Главная страница - красивый дашборд"""
    # Получаем абсолютный путь к папке с API
    api_dir = os.path.dirname(os.path.abspath(__file__))
    return send_from_directory(api_dir, 'realistic-dashboard.html')

@app.route('/api/')
def api_index():
    """API информация с disclaimer"""
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
        'roadmap_url': 'https://github.com/SiwaNetwork/QuantumPCI-DRV/blob/main/quantum-pci-monitoring/ROADMAP.md',
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
    
    # Добавляем INA219 данные если доступны
    if INA219_MONITORING_AVAILABLE:
        try:
            ina219_data = get_ina219_data()
            all_metrics['ina219'] = ina219_data
        except Exception as e:
            all_metrics['ina219'] = {'error': f'Ошибка чтения INA219: {e}'}
    
    # Добавляем BMP280 данные если доступны
    if BMP280_MONITORING_AVAILABLE:
        try:
            bmp280_data = get_bmp280_data()
            all_metrics['bmp280'] = bmp280_data
        except Exception as e:
            all_metrics['bmp280'] = {'error': f'Ошибка чтения BMP280: {e}'}
    
    # Добавляем BNO055 данные если доступны
    if BNO055_MONITORING_AVAILABLE:
        try:
            bno055_monitor = BNO055Monitor()
            bno055_data = bno055_monitor.get_sensor_data()
            all_metrics['bno055'] = bno055_data
        except Exception as e:
            all_metrics['bno055'] = {'error': f'Ошибка чтения BNO055: {e}'}
    
    return jsonify({
        'metrics': all_metrics,
        'note': 'Реальные метрики из ptp_ocp драйвера + INA219 + BMP280 + BNO055',
        'timestamp': time.time()
    })

@app.route('/api/ina219')
def api_ina219():
    """Данные INA219 датчиков"""
    if not INA219_MONITORING_AVAILABLE:
        return jsonify({'error': 'INA219 мониторинг недоступен'})
    
    try:
        data = get_ina219_data()
        info = get_ina219_info()
        return jsonify({
            'data': data,
            'info': info,
            'timestamp': time.time()
        })
    except Exception as e:
        return jsonify({'error': f'Ошибка чтения INA219: {e}'})



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

@app.route('/realistic-dashboard')
def realistic_dashboard():
    """Реалистичный дашборд с честными возможностями"""
    # Получаем абсолютный путь к папке с API
    api_dir = os.path.dirname(os.path.abspath(__file__))
    return send_from_directory(api_dir, 'realistic-dashboard.html')

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

# === PTP Network Monitoring API ===

@app.route('/api/ptp-network')
def api_ptp_network():
    """API для получения метрик сетевых карт с PTP"""
    if not PTP_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'PTP мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        metrics = get_ptp_network_metrics()
        return jsonify(metrics)
    except Exception as e:
        return jsonify({
            'error': 'Ошибка получения метрик PTP',
            'message': str(e)
        }), 500

@app.route('/api/ptp-network/health')
def api_ptp_network_health():
    """API для получения статуса здоровья PTP сетевых карт"""
    if not PTP_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'PTP мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        health = get_ptp_network_health()
        return jsonify(health)
    except Exception as e:
        return jsonify({
            'error': 'Ошибка получения статуса здоровья PTP',
            'message': str(e)
        }), 500

@app.route('/api/ptp-network/ptp')
def api_ptp_network_ptp():
    """API для получения PTP метрик сетевых карт"""
    if not PTP_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'PTP мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        ptp_metrics = get_ptp_network_ptp_metrics()
        return jsonify(ptp_metrics)
    except Exception as e:
        return jsonify({
            'error': 'Ошибка получения PTP метрик',
            'message': str(e)
        }), 500

@app.route('/api/ptp-network/interface/<interface>')
def api_ptp_interface(interface):
    """API для получения метрик конкретного PTP интерфейса"""
    if not PTP_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'PTP мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        metrics = get_ptp_interface_metrics(interface)
        return jsonify(metrics)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения метрик интерфейса {interface}',
            'message': str(e)
        }), 500

# === Intel Network Monitoring API (обратная совместимость) ===

@app.route('/api/intel-network')
def api_intel_network():
    """API для получения метрик Intel сетевых карт (обратная совместимость)"""
    if not PTP_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'PTP мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        from intel_network_monitor import get_intel_network_metrics
        metrics = get_intel_network_metrics()
        return jsonify(metrics)
    except Exception as e:
        return jsonify({
            'error': 'Ошибка получения метрик Intel',
            'message': str(e)
        }), 500

@app.route('/api/intel-network/health')
def api_intel_network_health():
    """API для получения статуса здоровья Intel сетевых карт (обратная совместимость)"""
    if not PTP_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'Intel мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        health = get_intel_network_health()
        return jsonify(health)
    except Exception as e:
        return jsonify({
            'error': 'Ошибка получения статуса здоровья Intel',
            'message': str(e)
        }), 500

@app.route('/api/intel-network/ptp')
def api_intel_network_ptp():
    """API для получения PTP метрик Intel сетевых карт"""
    if not INTEL_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'Intel мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        ptp_metrics = get_intel_ptp_metrics()
        return jsonify(ptp_metrics)
    except Exception as e:
        return jsonify({
            'error': 'Ошибка получения PTP метрик Intel',
            'message': str(e)
        }), 500

@app.route('/api/intel-network/interface/<interface>')
def api_intel_interface(interface):
    """API для получения метрик конкретного Intel интерфейса"""
    if not INTEL_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'Intel мониторинг недоступен',
            'message': 'Модуль intel_network_monitor не найден'
        }), 503
    
    try:
        from intel_network_monitor import get_intel_interface_metrics
        metrics = get_intel_interface_metrics(interface)
        return jsonify(metrics)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения метрик интерфейса {interface}',
            'message': str(e)
        }), 500

# === BMP280 Sensor API Endpoints ===

@app.route('/api/bmp280')
def api_bmp280_data():
    """API для получения данных с датчика BMP280"""
    if not BMP280_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BMP280 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        data = get_bmp280_data()
        return jsonify(data)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения данных BMP280: {str(e)}',
            'available': False
        }), 500

@app.route('/api/bmp280/info')
def api_bmp280_info():
    """API для получения информации о датчике BMP280"""
    if not BMP280_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BMP280 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        info = get_bmp280_info()
        return jsonify(info)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения информации BMP280: {str(e)}',
            'available': False
        }), 500

@app.route('/api/bmp280/temperature')
def api_bmp280_temperature():
    """API для получения только температуры с BMP280"""
    if not BMP280_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BMP280 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        from bmp280_monitor import bmp280_monitor
        temperature = bmp280_monitor.get_temperature_only()
        if temperature is not None:
            return jsonify({
                'temperature_c': temperature,
                'timestamp': time.time(),
                'available': True
            })
        else:
            return jsonify({
                'error': 'Не удалось получить температуру',
                'available': False
            }), 500
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения температуры: {str(e)}',
            'available': False
        }), 500

@app.route('/api/bmp280/pressure')
def api_bmp280_pressure():
    """API для получения только давления с BMP280"""
    if not BMP280_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BMP280 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        from bmp280_monitor import bmp280_monitor
        pressure = bmp280_monitor.get_pressure_only()
        if pressure is not None:
            return jsonify({
                'pressure_pa': pressure,
                'pressure_hpa': pressure / 100,
                'pressure_mbar': pressure / 100,
                'timestamp': time.time(),
                'available': True
            })
        else:
            return jsonify({
                'error': 'Не удалось получить давление',
                'available': False
            }), 500
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения давления: {str(e)}',
            'available': False
        }), 500

@app.route('/api/bno055')
def api_bno055_data():
    """API для получения данных с датчика BNO055"""
    if not BNO055_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BNO055 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        bno055_monitor = BNO055Monitor()
        data = bno055_monitor.get_sensor_data()
        return jsonify(data)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения данных BNO055: {str(e)}',
            'available': False
        }), 500

@app.route('/api/bno055/info')
def api_bno055_info():
    """API для получения информации о датчике BNO055"""
    if not BNO055_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BNO055 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        bno055_monitor = BNO055Monitor()
        info = bno055_monitor.get_device_info()
        return jsonify(info)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения информации BNO055: {str(e)}',
            'available': False
        }), 500

@app.route('/api/bno055/calibration')
def api_bno055_calibration():
    """API для получения статуса калибровки BNO055"""
    if not BNO055_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BNO055 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        bno055_monitor = BNO055Monitor()
        calibration = bno055_monitor.get_calibration_status()
        return jsonify(calibration)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения статуса калибровки BNO055: {str(e)}',
            'available': False
        }), 500

@app.route('/api/bno055/mode')
def api_bno055_mode():
    """API для получения режима работы BNO055"""
    if not BNO055_MONITORING_AVAILABLE:
        return jsonify({
            'error': 'BNO055 мониторинг недоступен',
            'available': False
        }), 503
    
    try:
        bno055_monitor = BNO055Monitor()
        mode = bno055_monitor.get_operation_mode()
        return jsonify(mode)
    except Exception as e:
        return jsonify({
            'error': f'Ошибка получения режима работы BNO055: {str(e)}',
            'available': False
        }), 500

@app.route('/api/logs')
def api_logs():
    """API для получения логов системы"""
    try:
        # Читаем последние 100 строк из лога
        log_file = "/home/shiwa-time/QuantumPCI-DRV/ptp-monitoring/monitoring.log"
        if os.path.exists(log_file):
            with open(log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                recent_lines = lines[-100:] if len(lines) > 100 else lines
                return jsonify({
                    'logs': [line.strip() for line in recent_lines],
                    'total_lines': len(lines),
                    'recent_lines': len(recent_lines)
                })
        else:
            return jsonify({
                'logs': ['No log file found'],
                'total_lines': 0,
                'recent_lines': 0
            })
    except Exception as e:
        return jsonify({
            'error': f'Error reading logs: {str(e)}',
            'logs': []
        }), 500

@app.route('/api/export')
def api_export():
    """API для экспорта данных"""
    try:
        export_data = {
            'timestamp': time.time(),
            'devices': monitor.devices,
            'system_info': {
                'api_version': CONFIG['version'],
                'uptime': time.time() - monitor.start_time if hasattr(monitor, 'start_time') else 0
            }
        }
        
        # Добавляем BMP280 данные если доступны
        if BMP280_MONITORING_AVAILABLE:
            try:
                export_data['bmp280'] = get_bmp280_data()
            except:
                pass
        
        return jsonify(export_data)
    except Exception as e:
        return jsonify({
            'error': f'Error exporting data: {str(e)}'
        }), 500

# === WebSocket Events ===

@socketio.on('connect')
def handle_connect():
    """Клиент подключился"""
    print('Client connected to realistic API')
    
    # Подготавливаем данные для отправки
    status_data = {
        'connected': True,
        'devices_count': len(monitor.devices),
        'api_version': CONFIG['version'],
        'realistic_monitoring': True,
        'limitations_warning': 'Доступны только базовые метрики из ptp_ocp драйвера',
        'timestamp': time.time()
    }
    
    # Добавляем PTP данные если есть устройства
    if monitor.devices:
        device = monitor.devices[0]
        ptp_data = monitor.get_ptp_metrics(device)
        status_data['current_offset'] = ptp_data.get('offset_ns', 0)
    
    # Добавляем BMP280 данные если доступны
    if BMP280_MONITORING_AVAILABLE:
        try:
            bmp280_data = get_bmp280_data()
            status_data['bmp280_available'] = bmp280_data.get('available', False)
            if bmp280_data.get('available'):
                status_data['bmp280_temperature'] = bmp280_data.get('temperature_c')
                status_data['bmp280_pressure'] = bmp280_data.get('pressure_hpa')
        except Exception as e:
            status_data['bmp280_error'] = str(e)
            status_data['bmp280_available'] = False
    else:
        status_data['bmp280_available'] = False
    
    socketio.emit('status_update', status_data)

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
    print(f"📊 Realistic Dashboard: http://localhost:8080/realistic-dashboard")
    print(f"🔧 API: http://localhost:8080/api/")
    print(f"🗺️  Roadmap: http://localhost:8080/api/roadmap")
    print("="*80)
    print(f"📦 Обнаружено устройств: {len(monitor.devices)}")
    for device in monitor.devices:
        print(f"   🕐 {device['id']}: {device.get('serial', 'N/A')}")
    print("="*80)
    
    socketio.run(app, host='0.0.0.0', port=CONFIG['server']['port'], debug=False)
