#!/usr/bin/env python3
# prometheus-exporter.py - Prometheus exporter для TimeCard PTP OCP

import time
import threading
import logging
from prometheus_client import start_http_server, Gauge, Counter, Info, Histogram
from prometheus_client.core import CollectorRegistry, REGISTRY
import requests
import json
import sys
import os

# Добавляем путь к нашему API
sys.path.append(os.path.dirname(__file__))

# Настройка логирования
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class TimeCardPrometheusExporter:
    def __init__(self, timecard_api_url='http://localhost:8080', port=9090):
        self.api_url = timecard_api_url
        self.port = port
        self.registry = CollectorRegistry()
        self.setup_metrics()
        
    def setup_metrics(self):
        """Настройка метрик Prometheus"""
        
        # === PTP Metrics ===
        self.ptp_offset = Gauge(
            'timecard_ptp_offset_nanoseconds',
            'PTP offset from master in nanoseconds',
            ['device_id'],
            registry=self.registry
        )
        
        self.ptp_path_delay = Gauge(
            'timecard_ptp_path_delay_nanoseconds',
            'PTP path delay in nanoseconds',
            ['device_id'],
            registry=self.registry
        )
        
        self.ptp_frequency_adjustment = Gauge(
            'timecard_ptp_frequency_adjustment_ppb',
            'PTP frequency adjustment in ppb',
            ['device_id'],
            registry=self.registry
        )
        
        self.ptp_path_delay_variance = Gauge(
            'timecard_ptp_path_delay_variance_nanoseconds',
            'PTP path delay variance in nanoseconds',
            ['device_id'],
            registry=self.registry
        )
        
        self.ptp_packet_loss = Gauge(
            'timecard_ptp_packet_loss_percent',
            'PTP packet loss percentage',
            ['device_id'],
            registry=self.registry
        )
        
        self.ptp_performance_score = Gauge(
            'timecard_ptp_performance_score',
            'PTP overall performance score (0-100)',
            ['device_id'],
            registry=self.registry
        )
        
        # PTP Packet counters
        self.ptp_packets = Counter(
            'timecard_ptp_packets_total',
            'Total PTP packets by type',
            ['device_id', 'packet_type', 'direction'],
            registry=self.registry
        )
        
        # === Thermal Metrics ===
        self.temperature = Gauge(
            'timecard_temperature_celsius',
            'Temperature readings in Celsius',
            ['device_id', 'sensor'],
            registry=self.registry
        )
        
        self.fan_speed = Gauge(
            'timecard_fan_speed_rpm',
            'Fan speed in RPM',
            ['device_id'],
            registry=self.registry
        )
        
        self.thermal_throttling = Gauge(
            'timecard_thermal_throttling',
            'Thermal throttling state (0=normal, 1=throttling)',
            ['device_id'],
            registry=self.registry
        )
        
        # === Power Metrics ===
        self.voltage = Gauge(
            'timecard_voltage_volts',
            'Voltage measurements',
            ['device_id', 'rail'],
            registry=self.registry
        )
        
        self.voltage_deviation = Gauge(
            'timecard_voltage_deviation_percent',
            'Voltage deviation from nominal in percent',
            ['device_id', 'rail'],
            registry=self.registry
        )
        
        self.current = Gauge(
            'timecard_current_milliamps',
            'Current consumption in milliamps',
            ['device_id', 'component'],
            registry=self.registry
        )
        
        self.power_consumption = Gauge(
            'timecard_power_consumption_watts',
            'Power consumption in watts',
            ['device_id', 'type'],
            registry=self.registry
        )
        
        self.power_efficiency = Gauge(
            'timecard_power_efficiency_percent',
            'Power efficiency percentage',
            ['device_id'],
            registry=self.registry
        )
        
        # === GNSS Metrics ===
        self.gnss_satellites = Gauge(
            'timecard_gnss_satellites',
            'GNSS satellite counts',
            ['device_id', 'constellation', 'type'],
            registry=self.registry
        )
        
        self.gnss_accuracy = Gauge(
            'timecard_gnss_accuracy',
            'GNSS accuracy measurements',
            ['device_id', 'type', 'unit'],
            registry=self.registry
        )
        
        self.gnss_signal_strength = Gauge(
            'timecard_gnss_signal_strength_db',
            'GNSS signal strength in dB',
            ['device_id'],
            registry=self.registry
        )
        
        self.gnss_antenna_status = Gauge(
            'timecard_gnss_antenna_status',
            'GNSS antenna status (0=bad, 1=ok)',
            ['device_id'],
            registry=self.registry
        )
        
        self.gnss_health_score = Gauge(
            'timecard_gnss_health_score',
            'GNSS overall health score (0-100)',
            ['device_id'],
            registry=self.registry
        )
        
        # === Oscillator Metrics ===
        self.oscillator_locked = Gauge(
            'timecard_oscillator_locked',
            'Oscillator lock status (0=unlocked, 1=locked)',
            ['device_id'],
            registry=self.registry
        )
        
        self.oscillator_frequency_error = Gauge(
            'timecard_oscillator_frequency_error_ppb',
            'Oscillator frequency error in ppb',
            ['device_id'],
            registry=self.registry
        )
        
        self.oscillator_allan_deviation = Gauge(
            'timecard_oscillator_allan_deviation',
            'Allan deviation measurements',
            ['device_id', 'tau_seconds'],
            registry=self.registry
        )
        
        self.oscillator_stability_score = Gauge(
            'timecard_oscillator_stability_score',
            'Oscillator stability grade (0=poor, 1=fair, 2=good, 3=excellent)',
            ['device_id'],
            registry=self.registry
        )
        
        self.oscillator_lock_duration = Gauge(
            'timecard_oscillator_lock_duration_seconds',
            'Duration of current lock in seconds',
            ['device_id'],
            registry=self.registry
        )
        
        # === Hardware Metrics ===
        self.led_status = Gauge(
            'timecard_led_status',
            'LED status (0=off, 1=green, 2=yellow, 3=red)',
            ['device_id', 'led'],
            registry=self.registry
        )
        
        self.sma_connector_status = Gauge(
            'timecard_sma_connector_status',
            'SMA connector status and signal strength',
            ['device_id', 'connector', 'type'],
            registry=self.registry
        )
        
        self.fpga_utilization = Gauge(
            'timecard_fpga_utilization_percent',
            'FPGA resource utilization percentage',
            ['device_id', 'resource_type'],
            registry=self.registry
        )
        
        self.network_port_status = Gauge(
            'timecard_network_port_status',
            'Network port status (0=down, 1=up)',
            ['device_id', 'port'],
            registry=self.registry
        )
        
        self.network_port_speed = Gauge(
            'timecard_network_port_speed_mbps',
            'Network port speed in Mbps',
            ['device_id', 'port'],
            registry=self.registry
        )
        
        # === System Health ===
        self.overall_health_score = Gauge(
            'timecard_overall_health_score',
            'Overall system health score (0-100)',
            ['device_id'],
            registry=self.registry
        )
        
        self.component_health_score = Gauge(
            'timecard_component_health_score',
            'Individual component health scores (0-100)',
            ['device_id', 'component'],
            registry=self.registry
        )
        
        # === Alert Metrics ===
        self.active_alerts = Gauge(
            'timecard_active_alerts',
            'Number of active alerts by severity',
            ['device_id', 'severity'],
            registry=self.registry
        )
        
        self.alert_history = Counter(
            'timecard_alerts_total',
            'Total alerts generated by type and severity',
            ['device_id', 'alert_type', 'severity'],
            registry=self.registry
        )
        
        # === Device Info ===
        self.device_info = Info(
            'timecard_device_info',
            'TimeCard device information',
            ['device_id'],
            registry=self.registry
        )
        
        # === Uptime ===
        self.uptime = Gauge(
            'timecard_uptime_seconds',
            'System uptime in seconds',
            ['device_id'],
            registry=self.registry
        )
        
        logger.info("✅ Prometheus metrics configured")
    
    def fetch_timecard_data(self):
        """Получение данных от TimeCard API"""
        try:
            # Получаем расширенные метрики
            response = requests.get(f"{self.api_url}/api/metrics/extended", timeout=10)
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"API returned status {response.status_code}")
                return None
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to fetch data from API: {e}")
            return None
    
    def fetch_alerts_data(self):
        """Получение данных об алертах"""
        try:
            response = requests.get(f"{self.api_url}/api/alerts", timeout=10)
            if response.status_code == 200:
                return response.json()
            else:
                return {'alerts': [], 'count': 0}
        except:
            return {'alerts': [], 'count': 0}
    
    def update_ptp_metrics(self, device_id, data):
        """Обновление PTP метрик"""
        ptp_data = data.get('ptp_advanced', {})
        
        if 'basic' in ptp_data:
            basic = ptp_data['basic']
            self.ptp_offset.labels(device_id=device_id).set(basic.get('offset_ns', 0))
            self.ptp_path_delay.labels(device_id=device_id).set(basic.get('path_delay_ns', 0))
            self.ptp_frequency_adjustment.labels(device_id=device_id).set(
                basic.get('frequency_adjustment_ppb', 0)
            )
        
        if 'delay_stats' in ptp_data:
            delay_stats = ptp_data['delay_stats']
            self.ptp_path_delay_variance.labels(device_id=device_id).set(
                delay_stats.get('path_delay_variance', 0)
            )
        
        if 'packet_stats' in ptp_data:
            packet_stats = ptp_data['packet_stats']
            self.ptp_packet_loss.labels(device_id=device_id).set(
                packet_stats.get('packet_loss_percent', 0)
            )
            
            # Обновляем счетчики пакетов
            packet_types = {
                'announce_rx': ('announce', 'rx'),
                'announce_tx': ('announce', 'tx'),
                'sync_rx': ('sync', 'rx'),
                'sync_tx': ('sync', 'tx'),
                'delay_req_tx': ('delay_req', 'tx'),
                'delay_resp_rx': ('delay_resp', 'rx')
            }
            
            for key, (packet_type, direction) in packet_types.items():
                count = packet_stats.get(key, 0)
                self.ptp_packets.labels(
                    device_id=device_id, 
                    packet_type=packet_type, 
                    direction=direction
                )._value._value = count
        
        self.ptp_performance_score.labels(device_id=device_id).set(
            ptp_data.get('performance_score', 0)
        )
    
    def update_thermal_metrics(self, device_id, data):
        """Обновление тепловых метрик"""
        thermal_data = data.get('thermal', {})
        
        # Температурные сенсоры
        sensors = ['fpga_temp', 'osc_temp', 'board_temp', 'ambient_temp', 'pll_temp', 'ddr_temp']
        for sensor in sensors:
            if sensor in thermal_data and isinstance(thermal_data[sensor], dict):
                temp_value = thermal_data[sensor].get('value', 0)
                self.temperature.labels(device_id=device_id, sensor=sensor).set(temp_value)
        
        # Охлаждение
        if 'cooling' in thermal_data:
            cooling = thermal_data['cooling']
            self.fan_speed.labels(device_id=device_id).set(cooling.get('fan_speed', 0))
            self.thermal_throttling.labels(device_id=device_id).set(
                1 if cooling.get('thermal_throttling', False) else 0
            )
    
    def update_power_metrics(self, device_id, data):
        """Обновление метрик питания"""
        power_data = data.get('power', {})
        
        # Напряжения
        voltage_rails = ['voltage_3v3', 'voltage_1v8', 'voltage_1v2', 'voltage_12v']
        for rail in voltage_rails:
            if rail in power_data and isinstance(power_data[rail], dict):
                rail_data = power_data[rail]
                rail_name = rail.replace('voltage_', '')
                
                self.voltage.labels(device_id=device_id, rail=rail_name).set(
                    rail_data.get('value', 0)
                )
                self.voltage_deviation.labels(device_id=device_id, rail=rail_name).set(
                    rail_data.get('deviation_percent', 0)
                )
        
        # Токи
        current_components = ['current_fpga', 'current_osc', 'current_ddr', 'current_phy', 'current_total']
        for component in current_components:
            if component in power_data and isinstance(power_data[component], dict):
                component_name = component.replace('current_', '')
                self.current.labels(device_id=device_id, component=component_name).set(
                    power_data[component].get('value', 0)
                )
        
        # Потребление мощности
        if 'power_consumption' in power_data:
            consumption = power_data['power_consumption']
            self.power_consumption.labels(device_id=device_id, type='total').set(
                consumption.get('total_watts', 0)
            )
            self.power_consumption.labels(device_id=device_id, type='heat_dissipation').set(
                consumption.get('heat_dissipation', 0)
            )
            self.power_efficiency.labels(device_id=device_id).set(
                consumption.get('efficiency_percent', 0)
            )
    
    def update_gnss_metrics(self, device_id, data):
        """Обновление GNSS метрик"""
        gnss_data = data.get('gnss', {})
        
        # Спутники
        if 'fix' in gnss_data:
            fix = gnss_data['fix']
            self.gnss_satellites.labels(
                device_id=device_id, constellation='all', type='used'
            ).set(fix.get('satellites_used', 0))
            
            self.gnss_satellites.labels(
                device_id=device_id, constellation='all', type='visible'
            ).set(fix.get('satellites_visible', 0))
            
            self.gnss_satellites.labels(
                device_id=device_id, constellation='all', type='tracked'
            ).set(fix.get('satellites_tracked', 0))
        
        # Созвездия
        if 'constellations' in gnss_data:
            constellations = gnss_data['constellations']
            for constellation, count in constellations.items():
                self.gnss_satellites.labels(
                    device_id=device_id, constellation=constellation, type='used'
                ).set(count)
        
        # Точность
        if 'accuracy' in gnss_data:
            accuracy = gnss_data['accuracy']
            
            self.gnss_accuracy.labels(
                device_id=device_id, type='horizontal', unit='meters'
            ).set(accuracy.get('horizontal_accuracy', 0))
            
            self.gnss_accuracy.labels(
                device_id=device_id, type='vertical', unit='meters'
            ).set(accuracy.get('vertical_accuracy', 0))
            
            self.gnss_accuracy.labels(
                device_id=device_id, type='time', unit='nanoseconds'
            ).set(accuracy.get('time_accuracy', 0))
            
            self.gnss_accuracy.labels(
                device_id=device_id, type='pdop', unit='dilution'
            ).set(accuracy.get('pdop', 0))
        
        # Антенна
        if 'antenna' in gnss_data:
            antenna = gnss_data['antenna']
            self.gnss_antenna_status.labels(device_id=device_id).set(
                1 if antenna.get('status') == 'OK' else 0
            )
            
            self.gnss_signal_strength.labels(device_id=device_id).set(
                antenna.get('signal_strength_db', 0)
            )
        
        # Общее здоровье GNSS
        self.gnss_health_score.labels(device_id=device_id).set(
            gnss_data.get('overall_health', 0)
        )
    
    def update_oscillator_metrics(self, device_id, data):
        """Обновление метрик осциллятора"""
        osc_data = data.get('oscillator', {})
        
        if 'basic' in osc_data:
            basic = osc_data['basic']
            self.oscillator_locked.labels(device_id=device_id).set(
                1 if basic.get('locked', False) else 0
            )
            self.oscillator_lock_duration.labels(device_id=device_id).set(
                basic.get('lock_duration_seconds', 0)
            )
        
        if 'frequency' in osc_data:
            frequency = osc_data['frequency']
            self.oscillator_frequency_error.labels(device_id=device_id).set(
                frequency.get('frequency_error_ppb', 0)
            )
        
        # Allan deviation
        if 'allan_deviation' in osc_data:
            allan = osc_data['allan_deviation']
            tau_values = {'1s': 1, '10s': 10, '100s': 100, '1000s': 1000}
            
            for tau_key, tau_seconds in tau_values.items():
                allan_key = f'tau_{tau_key}'
                if allan_key in allan:
                    self.oscillator_allan_deviation.labels(
                        device_id=device_id, tau_seconds=str(tau_seconds)
                    ).set(allan[allan_key])
        
        # Стабильность
        stability_map = {'poor': 0, 'fair': 1, 'good': 2, 'excellent': 3}
        stability = osc_data.get('overall_stability', 'poor')
        self.oscillator_stability_score.labels(device_id=device_id).set(
            stability_map.get(stability, 0)
        )
    
    def update_hardware_metrics(self, device_id, data):
        """Обновление аппаратных метрик"""
        hw_data = data.get('hardware', {})
        
        # LED статусы
        if 'leds' in hw_data:
            led_map = {'off': 0, 'green': 1, 'yellow': 2, 'red': 3}
            for led_name, status in hw_data['leds'].items():
                self.led_status.labels(device_id=device_id, led=led_name).set(
                    led_map.get(status, 0)
                )
        
        # FPGA утилизация
        if 'fpga' in hw_data:
            fpga = hw_data['fpga']
            self.fpga_utilization.labels(
                device_id=device_id, resource_type='overall'
            ).set(fpga.get('utilization_percent', 0))
            
            self.fpga_utilization.labels(
                device_id=device_id, resource_type='logic'
            ).set(fpga.get('logic_utilization', 0))
            
            self.fpga_utilization.labels(
                device_id=device_id, resource_type='memory'
            ).set(fpga.get('memory_utilization', 0))
        
        # Сетевые порты
        if 'phy' in hw_data:
            for port_name, port_data in hw_data['phy'].items():
                self.network_port_status.labels(device_id=device_id, port=port_name).set(
                    1 if port_data.get('link_up', False) else 0
                )
                self.network_port_speed.labels(device_id=device_id, port=port_name).set(
                    port_data.get('speed_mbps', 0)
                )
    
    def update_health_metrics(self, device_id, data):
        """Обновление метрик здоровья системы"""
        # Общий health score (если есть в данных устройства)
        if 'overall_health_score' in data:
            self.overall_health_score.labels(device_id=device_id).set(
                data['overall_health_score']
            )
        
        # Health score компонентов
        component_scores = {
            'gnss': data.get('gnss', {}).get('overall_health', 0),
            'ptp': data.get('ptp_advanced', {}).get('performance_score', 0),
            'hardware': data.get('hardware', {}).get('overall_health', 0)
        }
        
        for component, score in component_scores.items():
            self.component_health_score.labels(
                device_id=device_id, component=component
            ).set(score)
    
    def update_alert_metrics(self, alerts_data):
        """Обновление метрик алертов"""
        alerts = alerts_data.get('alerts', [])
        
        # Сброс счетчиков активных алертов
        for device_id in self.get_device_ids():
            for severity in ['critical', 'warning', 'info']:
                self.active_alerts.labels(device_id=device_id, severity=severity).set(0)
        
        # Подсчет активных алертов
        alert_counts = {}
        for alert in alerts:
            device_id = alert.get('device_id', 'unknown')
            severity = alert.get('severity', 'info')
            alert_type = alert.get('type', 'unknown')
            
            # Активные алерты
            key = (device_id, severity)
            alert_counts[key] = alert_counts.get(key, 0) + 1
            
            # История алертов (инкремент счетчика)
            self.alert_history.labels(
                device_id=device_id, 
                alert_type=alert_type, 
                severity=severity
            ).inc()
        
        # Установка значений активных алертов
        for (device_id, severity), count in alert_counts.items():
            self.active_alerts.labels(device_id=device_id, severity=severity).set(count)
    
    def update_device_info(self, device_id, data):
        """Обновление информации об устройстве"""
        device_info_data = data.get('device_info', {})
        if 'identification' in device_info_data:
            identification = device_info_data['identification']
            
            info_dict = {
                'serial_number': identification.get('serial_number', ''),
                'firmware_version': identification.get('firmware_version', ''),
                'hardware_revision': identification.get('hardware_revision', ''),
                'vendor': identification.get('vendor', '')
            }
            
            self.device_info.labels(device_id=device_id).info(info_dict)
    
    def get_device_ids(self):
        """Получение списка ID устройств"""
        try:
            response = requests.get(f"{self.api_url}/api/devices", timeout=5)
            if response.status_code == 200:
                devices_data = response.json()
                return [d['identification']['device_id'] for d in devices_data.get('devices', [])]
            return ['timecard0']  # fallback
        except:
            return ['timecard0']  # fallback
    
    def collect_metrics(self):
        """Сбор всех метрик"""
        data = self.fetch_timecard_data()
        if not data:
            logger.warning("No data received from TimeCard API")
            return
        
        alerts_data = self.fetch_alerts_data()
        
        # Обновляем метрики для каждого устройства
        for device_id, device_data in data.items():
            logger.debug(f"Updating metrics for device {device_id}")
            
            try:
                self.update_ptp_metrics(device_id, device_data)
                self.update_thermal_metrics(device_id, device_data)
                self.update_power_metrics(device_id, device_data)
                self.update_gnss_metrics(device_id, device_data)
                self.update_oscillator_metrics(device_id, device_data)
                self.update_hardware_metrics(device_id, device_data)
                self.update_health_metrics(device_id, device_data)
                self.update_device_info(device_id, device_data)
                
                # Uptime (время работы API)
                self.uptime.labels(device_id=device_id).set(device_data.get('timestamp', time.time()))
                
            except Exception as e:
                logger.error(f"Error updating metrics for {device_id}: {e}")
        
        # Обновляем метрики алертов
        self.update_alert_metrics(alerts_data)
        
        logger.debug("Metrics collection completed")
    
    def start_collector(self, interval=30):
        """Запуск сборщика метрик"""
        def collect_loop():
            while True:
                try:
                    self.collect_metrics()
                    time.sleep(interval)
                except Exception as e:
                    logger.error(f"Error in collection loop: {e}")
                    time.sleep(interval)
        
        collector_thread = threading.Thread(target=collect_loop, daemon=True)
        collector_thread.start()
        logger.info(f"✅ Metrics collector started (interval: {interval}s)")
    
    def run(self, collect_interval=30):
        """Запуск Prometheus exporter"""
        logger.info(f"🚀 Starting Quantum-PCI TimeCard Prometheus Exporter on port {self.port}")
        
        # Запускаем HTTP сервер для метрик
        start_http_server(self.port, registry=self.registry)
        logger.info(f"📊 Prometheus metrics available at http://localhost:{self.port}/metrics")
        
        # Запускаем сборщик метрик
        self.start_collector(collect_interval)
        
        # Первый сбор метрик
        self.collect_metrics()
        
        logger.info("✅ TimeCard Prometheus Exporter is running")
        logger.info(f"🔗 TimeCard API: {self.api_url}")
        logger.info(f"⏱️  Collection interval: {collect_interval}s")
        
        try:
            # Держим процесс живым
            while True:
                time.sleep(60)
                logger.debug("Exporter is running...")
        except KeyboardInterrupt:
            logger.info("👋 Shutting down TimeCard Prometheus Exporter")

def main():
    """Главная функция"""
    import argparse
    
    parser = argparse.ArgumentParser(description='TimeCard Prometheus Exporter')
    parser.add_argument('--api-url', default='http://localhost:8080',
                       help='TimeCard API URL (default: http://localhost:8080)')
    parser.add_argument('--port', type=int, default=9090,
                       help='Prometheus exporter port (default: 9090)')
    parser.add_argument('--interval', type=int, default=30,
                       help='Collection interval in seconds (default: 30)')
    parser.add_argument('--log-level', default='INFO',
                       choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                       help='Logging level (default: INFO)')
    
    args = parser.parse_args()
    
    # Настройка логирования
    logging.getLogger().setLevel(getattr(logging, args.log_level))
    
    print("="*80)
    print("🚀 TimeCard PTP OCP Prometheus Exporter v2.0")
    print("="*80)
    print(f"📊 Exporter URL:       http://localhost:{args.port}/metrics")
    print(f"🔗 TimeCard API:       {args.api_url}")
    print(f"⏱️  Collection interval: {args.interval}s")
    print(f"📝 Log level:          {args.log_level}")
    print("="*80)
    print("✨ Exported Metrics:")
    print("   📡 PTP metrics (offset, path delay, packet stats)")
    print("   🌡️  Thermal metrics (6 sensors + cooling)")
    print("   ⚡ Power metrics (4 voltage rails + currents)")
    print("   🛰️  GNSS metrics (4 constellations + accuracy)")
    print("   ⚡ Oscillator metrics (Allan deviation + stability)")
    print("   🔧 Hardware metrics (LEDs, SMA, FPGA, network)")
    print("   🚨 Alert metrics (active + historical)")
    print("   📊 Health metrics (system + components)")
    print("="*80)
    
    # Создание и запуск exporter
    exporter = TimeCardPrometheusExporter(
        timecard_api_url=args.api_url,
        port=args.port
    )
    
    exporter.run(collect_interval=args.interval)

if __name__ == '__main__':
    main()