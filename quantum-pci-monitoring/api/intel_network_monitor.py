#!/usr/bin/env python3
"""
Интеграция мониторинга Intel сетевых карт I210, I225, I226 с системой мониторинга Quantum-PCI
Автор: AI Assistant
Дата: $(date)
"""

import subprocess
import json
import time
import os
import sys
from datetime import datetime
from typing import Dict, List, Optional, Any
import logging

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/intel-monitoring.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class PTPNetworkMonitor:
    """Мониторинг сетевых карт с поддержкой PTP hardware timestamping"""
    
    def __init__(self):
        self.interfaces = []
        self.quantum_pci_path = "/sys/class/timecard/ocp0"
        self.metrics = {}
        
    def detect_ptp_interfaces(self) -> List[str]:
        """Обнаружение сетевых интерфейсов с поддержкой PTP hardware timestamping"""
        try:
            # Получение списка интерфейсов
            result = subprocess.run(['ip', 'link', 'show'], 
                                  capture_output=True, text=True, check=True)
            
            interfaces = []
            for line in result.stdout.split('\n'):
                if ': eth' in line or ': en' in line:
                    interface = line.split(':')[1].strip()
                    # Проверка поддержки PTP hardware timestamping
                    try:
                        timestamping_result = subprocess.run(['ethtool', '-T', interface], 
                                                          capture_output=True, text=True)
                        # Проверяем наличие PTP Hardware Clock в выводе
                        if 'PTP Hardware Clock:' in timestamping_result.stdout:
                            interfaces.append(interface)
                    except subprocess.CalledProcessError:
                        continue
            
            self.interfaces = interfaces
            logger.info(f"Найдены PTP интерфейсы: {interfaces}")
            return interfaces
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Ошибка обнаружения интерфейсов: {e}")
            return []
    
    def get_interface_info(self, interface: str) -> Dict[str, Any]:
        """Получение информации об интерфейсе"""
        info = {
            'interface': interface,
            'timestamp': datetime.now().isoformat(),
            'status': 'unknown',
            'speed': 'unknown',
            'timestamping': {},
            'statistics': {},
            'ptp_support': False
        }
        
        try:
            # Статус интерфейса
            result = subprocess.run(['ip', 'link', 'show', interface], 
                                  capture_output=True, text=True, check=True)
            if 'state UP' in result.stdout:
                info['status'] = 'up'
            elif 'state DOWN' in result.stdout:
                info['status'] = 'down'
            
            # Информация о драйвере
            try:
                ethtool_i_result = subprocess.run(['ethtool', '-i', interface], 
                                                capture_output=True, text=True, check=True)
                for line in ethtool_i_result.stdout.split('\n'):
                    if 'driver:' in line:
                        info['driver'] = line.split(':')[1].strip()
                        break
            except subprocess.CalledProcessError:
                logger.warning(f"Не удалось получить информацию о драйвере для {interface}")
                info['driver'] = 'Unknown'
            
            # Информация о скорости
            ethtool_result = subprocess.run(['ethtool', interface], 
                                          capture_output=True, text=True, check=True)
            for line in ethtool_result.stdout.split('\n'):
                if 'Speed:' in line:
                    info['speed'] = line.split(':')[1].strip()
            
            # Hardware timestamping
            timestamping_result = subprocess.run(['ethtool', '-T', interface], 
                                               capture_output=True, text=True, check=True)
            timestamping_info = {}
            for line in timestamping_result.stdout.split('\n'):
                if 'SOF timestamping:' in line:
                    timestamping_info['sof'] = line.split(':')[1].strip()
                elif 'SYS timestamping:' in line:
                    timestamping_info['sys'] = line.split(':')[1].strip()
                elif 'HW timestamping:' in line:
                    timestamping_info['hw'] = line.split(':')[1].strip()
                elif 'PTP Hardware Clock:' in line:
                    info['ptp_support'] = True
                    info['ptp_clock'] = line.split(':')[1].strip()
            
            info['timestamping'] = timestamping_info
            
            # Статистика
            stats_result = subprocess.run(['ethtool', '-S', interface], 
                                        capture_output=True, text=True, check=True)
            statistics = {}
            for line in stats_result.stdout.split('\n'):
                if ':' in line and not line.startswith('NIC statistics'):
                    key, value = line.split(':', 1)
                    key = key.strip()
                    value = value.strip()
                    try:
                        statistics[key] = int(value)
                    except ValueError:
                        statistics[key] = value
            
            info['statistics'] = statistics
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Ошибка получения информации об интерфейсе {interface}: {e}")
        
        return info
    
    def get_quantum_pci_status(self) -> Dict[str, Any]:
        """Получение статуса Quantum-PCI"""
        status = {
            'timestamp': datetime.now().isoformat(),
            'present': False,
            'serial': 'unknown',
            'gnss_sync': False,
            'clock_source': 'unknown',
            'available_sources': [],
            'clock_status_drift': 0,
            'clock_status_offset': 0,
            'tod_correction': 0,
            'utc_tai_offset': 0,
            'source_specific_metrics': {}
        }
        
        if os.path.exists(self.quantum_pci_path):
            status['present'] = True
            
            try:
                # Серийный номер
                with open(os.path.join(self.quantum_pci_path, 'serialnum'), 'r') as f:
                    status['serial'] = f.read().strip()
                
                # Статус GNSS
                with open(os.path.join(self.quantum_pci_path, 'gnss_sync'), 'r') as f:
                    status['gnss_sync'] = f.read().strip() == '1'
                
                # Доступные источники времени
                with open(os.path.join(self.quantum_pci_path, 'available_clock_sources'), 'r') as f:
                    status['available_sources'] = f.read().strip().split()
                
                # Источник времени
                with open(os.path.join(self.quantum_pci_path, 'clock_source'), 'r') as f:
                    status['clock_source'] = f.read().strip()
                
                # Clock status drift (активно только для PTP)
                with open(os.path.join(self.quantum_pci_path, 'clock_status_drift'), 'r') as f:
                    status['clock_status_drift'] = int(f.read().strip())
                
                # Clock status offset (активно только для PTP)
                with open(os.path.join(self.quantum_pci_path, 'clock_status_offset'), 'r') as f:
                    status['clock_status_offset'] = int(f.read().strip())
                
                # TOD correction
                with open(os.path.join(self.quantum_pci_path, 'tod_correction'), 'r') as f:
                    status['tod_correction'] = int(f.read().strip())
                
                # UTC TAI offset
                with open(os.path.join(self.quantum_pci_path, 'utc_tai_offset'), 'r') as f:
                    status['utc_tai_offset'] = int(f.read().strip())
                
                # Специфичные метрики в зависимости от источника
                status['source_specific_metrics'] = self._get_source_specific_metrics(status['clock_source'])
                    
            except (IOError, OSError) as e:
                logger.error(f"Ошибка чтения статуса Quantum-PCI: {e}")
        
        return status
    
    def _get_source_specific_metrics(self, clock_source: str) -> Dict[str, Any]:
        """Получение специфичных метрик в зависимости от источника времени"""
        metrics = {
            'source': clock_source,
            'description': self._get_source_description(clock_source),
            'active_metrics': [],
            'inactive_metrics': []
        }
        
        if clock_source == 'PTP':
            metrics['active_metrics'] = ['clock_status_drift', 'clock_status_offset']
            metrics['inactive_metrics'] = ['gnss_sync', 'pps_status']
            metrics['ptp_info'] = self._get_ptp_info()
        elif clock_source == 'PPS':
            metrics['active_metrics'] = ['gnss_sync', 'pps_status']
            metrics['inactive_metrics'] = ['clock_status_drift', 'clock_status_offset']
            metrics['pps_info'] = self._get_pps_info()
        elif clock_source == 'GNSS' or clock_source == 'TOD':
            metrics['active_metrics'] = ['gnss_sync', 'tod_correction']
            metrics['inactive_metrics'] = ['clock_status_drift', 'clock_status_offset']
            metrics['gnss_info'] = self._get_gnss_info()
        else:
            metrics['active_metrics'] = ['utc_tai_offset']
            metrics['inactive_metrics'] = ['clock_status_drift', 'clock_status_offset', 'gnss_sync']
        
        return metrics
    
    def _get_source_description(self, source: str) -> str:
        """Получение описания источника времени"""
        descriptions = {
            'PTP': 'Precision Time Protocol - синхронизация по сети',
            'PPS': 'Pulse Per Second - синхронизация по PPS сигналу',
            'GNSS': 'Global Navigation Satellite System - GPS/ГЛОНАСС',
            'TOD': 'Time of Day - время суток',
            'IRIG': 'IRIG-B - стандарт временных сигналов',
            'DCF': 'DCF77 - радиосигнал времени',
            'RTC': 'Real Time Clock - встроенные часы',
            'NONE': 'Источник не выбран',
            'REGS': 'Регистры устройства',
            'EXT': 'Внешний источник'
        }
        return descriptions.get(source, f'Неизвестный источник: {source}')
    
    def _get_ptp_info(self) -> Dict[str, Any]:
        """Получение информации о PTP"""
        try:
            # Проверяем PTP устройство
            ptp_link = os.path.join(self.quantum_pci_path, 'ptp')
            if os.path.exists(ptp_link):
                ptp_path = os.readlink(ptp_link)
                ptp_device = os.path.basename(ptp_path)
                return {
                    'device': f'/dev/{ptp_device}',
                    'status': 'available',
                    'description': 'PTP hardware clock доступен'
                }
        except (OSError, IOError):
            pass
        
        return {
            'device': 'none',
            'status': 'unavailable',
            'description': 'PTP устройство недоступно'
        }
    
    def _get_pps_info(self) -> Dict[str, Any]:
        """Получение информации о PPS"""
        try:
            # Проверяем PPS устройство
            pps_link = os.path.join(self.quantum_pci_path, 'pps')
            if os.path.exists(pps_link):
                pps_path = os.readlink(pps_link)
                pps_device = os.path.basename(pps_path)
                return {
                    'device': f'/dev/{pps_device}',
                    'status': 'available',
                    'description': 'PPS устройство доступно'
                }
        except (OSError, IOError):
            pass
        
        return {
            'device': 'none',
            'status': 'unavailable',
            'description': 'PPS устройство недоступно'
        }
    
    def _get_gnss_info(self) -> Dict[str, Any]:
        """Получение информации о GNSS"""
        return {
            'sync_status': 'unknown',
            'description': 'GNSS информация требует дополнительной настройки'
        }
    
    def get_ptp_status(self) -> Dict[str, Any]:
        """Получение статуса PTP"""
        ptp_status = {
            'timestamp': datetime.now().isoformat(),
            'devices': [],
            'running': False
        }
        
        # Поиск PTP устройств
        try:
            result = subprocess.run(['ls', '/dev/ptp*'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                ptp_devices = result.stdout.strip().split('\n')
                for device in ptp_devices:
                    if device:
                        device_info = {
                            'device': device,
                            'time': None,
                            'frequency': None
                        }
                        
                        try:
                            # Получение времени PTP
                            time_result = subprocess.run(['sudo', 'testptp', '-d', device, '-g'], 
                                                       capture_output=True, text=True)
                            if time_result.returncode == 0:
                                device_info['time'] = time_result.stdout.strip()
                            
                            # Получение частоты PTP
                            freq_result = subprocess.run(['sudo', 'testptp', '-d', device, '-f'], 
                                                       capture_output=True, text=True)
                            if freq_result.returncode == 0:
                                device_info['frequency'] = freq_result.stdout.strip()
                                
                        except subprocess.CalledProcessError:
                            pass
                        
                        ptp_status['devices'].append(device_info)
        except subprocess.CalledProcessError:
            pass
        
        # Проверка запущенного PTP4L
        try:
            result = subprocess.run(['pgrep', '-f', 'ptp4l'], 
                                  capture_output=True, text=True)
            ptp_status['running'] = result.returncode == 0
            if ptp_status['running']:
                ptp_status['pid'] = result.stdout.strip()
        except subprocess.CalledProcessError:
            pass
        
        return ptp_status
    
    def collect_metrics(self) -> Dict[str, Any]:
        """Сбор всех метрик"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'interfaces': [],
            'quantum_pci': {},
            'ptp': {},
            'system': {}
        }
        
        # Обновление списка интерфейсов
        self.detect_ptp_interfaces()
        
        # Сбор информации об интерфейсах
        for interface in self.interfaces:
            interface_info = self.get_interface_info(interface)
            metrics['interfaces'].append(interface_info)
        
        # Статус Quantum-PCI
        metrics['quantum_pci'] = self.get_quantum_pci_status()
        
        # Статус PTP
        metrics['ptp'] = self.get_ptp_status()
        
        # Системная информация
        metrics['system'] = {
            'uptime': self.get_system_uptime(),
            'load': self.get_system_load(),
            'memory': self.get_memory_info()
        }
        
        self.metrics = metrics
        return metrics
    
    def get_system_uptime(self) -> str:
        """Получение времени работы системы"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
                hours = int(uptime_seconds // 3600)
                minutes = int((uptime_seconds % 3600) // 60)
                return f"{hours}h {minutes}m"
        except (IOError, ValueError):
            return "unknown"
    
    def get_system_load(self) -> List[float]:
        """Получение нагрузки системы"""
        try:
            with open('/proc/loadavg', 'r') as f:
                load_avg = f.read().split()[:3]
                return [float(x) for x in load_avg]
        except (IOError, ValueError):
            return [0.0, 0.0, 0.0]
    
    def get_memory_info(self) -> Dict[str, Any]:
        """Получение информации о памяти"""
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = {}
                for line in f:
                    if ':' in line:
                        key, value = line.split(':', 1)
                        meminfo[key.strip()] = value.strip()
                return meminfo
        except IOError:
            return {}
    
    def save_metrics(self, filename: str = None) -> str:
        """Сохранение метрик в файл"""
        if filename is None:
            filename = f"/tmp/intel-metrics-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
        
        try:
            with open(filename, 'w') as f:
                json.dump(self.metrics, f, indent=2)
            logger.info(f"Метрики сохранены в {filename}")
            return filename
        except IOError as e:
            logger.error(f"Ошибка сохранения метрик: {e}")
            return ""
    
    def generate_report(self) -> str:
        """Генерация текстового отчета"""
        if not self.metrics:
            self.collect_metrics()
        
        report = []
        report.append("=" * 60)
        report.append("ОТЧЕТ О МОНИТОРИНГЕ INTEL СЕТЕВЫХ КАРТ")
        report.append("=" * 60)
        report.append(f"Время: {self.metrics['timestamp']}")
        report.append("")
        
        # Информация об интерфейсах
        report.append("СЕТЕВЫЕ ИНТЕРФЕЙСЫ:")
        report.append("-" * 30)
        for interface in self.metrics['interfaces']:
            report.append(f"Интерфейс: {interface['interface']}")
            report.append(f"  Статус: {interface['status']}")
            report.append(f"  Скорость: {interface['speed']}")
            report.append(f"  PTP поддержка: {'Да' if interface['ptp_support'] else 'Нет'}")
            
            if interface['timestamping']:
                report.append("  Hardware timestamping:")
                for key, value in interface['timestamping'].items():
                    report.append(f"    {key}: {value}")
            
            # Основная статистика
            stats = interface['statistics']
            if 'rx_packets' in stats and 'tx_packets' in stats:
                report.append(f"  Пакеты: RX={stats['rx_packets']}, TX={stats['tx_packets']}")
            if 'rx_errors' in stats and 'tx_errors' in stats:
                report.append(f"  Ошибки: RX={stats['rx_errors']}, TX={stats['tx_errors']}")
            
            report.append("")
        
        # Статус Quantum-PCI
        qpci = self.metrics['quantum_pci']
        report.append("QUANTUM-PCI:")
        report.append("-" * 15)
        report.append(f"  Присутствует: {'Да' if qpci['present'] else 'Нет'}")
        if qpci['present']:
            report.append(f"  Серийный номер: {qpci['serial']}")
            report.append(f"  GNSS синхронизация: {'Да' if qpci['gnss_sync'] else 'Нет'}")
            report.append(f"  Источник времени: {qpci['clock_source']}")
        report.append("")
        
        # Статус PTP
        ptp = self.metrics['ptp']
        report.append("PTP:")
        report.append("-" * 5)
        report.append(f"  Запущен: {'Да' if ptp['running'] else 'Нет'}")
        if ptp['running'] and 'pid' in ptp:
            report.append(f"  PID: {ptp['pid']}")
        
        if ptp['devices']:
            report.append("  Устройства:")
            for device in ptp['devices']:
                report.append(f"    {device['device']}")
                if device['time']:
                    report.append(f"      Время: {device['time']}")
                if device['frequency']:
                    report.append(f"      Частота: {device['frequency']}")
        
        report.append("")
        
        # Системная информация
        system = self.metrics['system']
        report.append("СИСТЕМА:")
        report.append("-" * 10)
        report.append(f"  Время работы: {system['uptime']}")
        report.append(f"  Нагрузка: {system['load']}")
        
        report_text = "\n".join(report)
        return report_text

def main():
    """Основная функция"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Мониторинг Intel сетевых карт')
    parser.add_argument('--collect', action='store_true', 
                       help='Собрать метрики')
    parser.add_argument('--report', action='store_true', 
                       help='Сгенерировать отчет')
    parser.add_argument('--save', type=str, 
                       help='Сохранить метрики в файл')
    parser.add_argument('--daemon', action='store_true', 
                       help='Запуск в режиме демона')
    parser.add_argument('--interval', type=int, default=60, 
                       help='Интервал сбора метрик в секундах (по умолчанию: 60)')
    
    args = parser.parse_args()
    
    monitor = IntelNetworkMonitor()
    
    if args.daemon:
        logger.info(f"Запуск мониторинга в режиме демона (интервал: {args.interval}s)")
        while True:
            try:
                monitor.collect_metrics()
                if args.save:
                    monitor.save_metrics(args.save)
                time.sleep(args.interval)
            except KeyboardInterrupt:
                logger.info("Остановка мониторинга")
                break
            except Exception as e:
                logger.error(f"Ошибка в цикле мониторинга: {e}")
                time.sleep(args.interval)
    
    elif args.collect:
        metrics = monitor.collect_metrics()
        print(json.dumps(metrics, indent=2))
    
    elif args.report:
        report = monitor.generate_report()
        print(report)
    
    elif args.save:
        monitor.collect_metrics()
        filename = monitor.save_metrics(args.save)
        print(f"Метрики сохранены в {filename}")
    
    else:
        # По умолчанию - показать отчет
        report = monitor.generate_report()
        print(report)

# Глобальный экземпляр монитора
_monitor_instance = None

def get_monitor():
    """Получение глобального экземпляра монитора"""
    global _monitor_instance
    if _monitor_instance is None:
        _monitor_instance = PTPNetworkMonitor()
    return _monitor_instance

# Экспорт функций для API
def get_ptp_network_metrics():
    """API функция для получения метрик сетевых карт с PTP"""
    monitor = get_monitor()
    return monitor.collect_metrics()

def get_ptp_network_health():
    """API функция для получения статуса здоровья"""
    monitor = get_monitor()
    return monitor.get_health_status()

def get_ptp_network_ptp_metrics():
    """API функция для получения PTP метрик"""
    monitor = get_monitor()
    return monitor.get_ptp_metrics()

def get_ptp_interface_metrics(interface: str):
    """API функция для получения метрик конкретного интерфейса"""
    monitor = get_monitor()
    return monitor.get_interface_metrics(interface)

# Обратная совместимость
def get_intel_network_metrics():
    """API функция для получения метрик сетевых карт с PTP (обратная совместимость)"""
    return get_ptp_network_metrics()

def get_intel_network_health():
    """API функция для получения статуса здоровья (обратная совместимость)"""
    return get_ptp_network_health()

def get_intel_ptp_metrics():
    """API функция для получения PTP метрик (обратная совместимость)"""
    return get_ptp_network_ptp_metrics()

def get_intel_interface_metrics(interface: str):
    """API функция для получения метрик конкретного интерфейса (обратная совместимость)"""
    return get_ptp_interface_metrics(interface)

if __name__ == "__main__":
    main()
