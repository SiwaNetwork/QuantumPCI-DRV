#!/usr/bin/env python3
"""
GNSS и SMA мониторинг с LED индикацией для TimeCard
Автор: AI Assistant

Цветовая схема:
- Зеленый: GNSS SYNC или SMA сигналы достоверны
- Красный: GNSS LOST или SMA сигналы недостоверны  
- Сиреневый: Режим holdover (автономное хранение)
- Желтый: Промежуточные состояния
"""

import os
import time
import json
import subprocess
from datetime import datetime
from typing import Dict, Any, Optional

class GNSSSMAMonitor:
    def __init__(self, bus=1, addr=0x37):
        self.bus = bus
        self.addr = addr
        self.timecard_sysfs = "/sys/class/timecard/ocp0"
        
        # LED индексы для разных статусов
        self.led_map = {
            'gnss_sync': 0,      # Power LED - зеленый/красный для GNSS
            'gnss_holdover': 1,   # Sync LED - сиреневый для holdover
            'sma3_status': 2,     # GNSS LED - статус SMA3
            'sma4_status': 3,     # Alarm LED - статус SMA4
            'clock_source': 4,    # Status1 LED - источник часов
            'system_status': 5    # Status2 LED - общий статус системы
        }
        
        # Цветовые коды для IS32FL3207
        self.colors = {
            'off': 0x00,
            'green': 0xFF,        # Полная яркость для зеленого
            'red': 0xFF,          # Полная яркость для красного  
            'purple': 0x80,       # Средняя яркость для сиреневого
            'yellow': 0xC0,       # Высокая яркость для желтого
            'dim_green': 0x40,    # Тусклый зеленый
            'dim_red': 0x40,      # Тусклый красный
            'blink': 0x60         # Мигающий режим
        }
        
        # Статусы для мониторинга
        self.status_cache = {}
        
    def check_i2c_device(self) -> bool:
        """Проверка наличия IS32FL3207"""
        try:
            result = subprocess.run(['sudo', 'i2cdetect', '-y', str(self.bus)], 
                                  capture_output=True, text=True, check=True)
            return "37" in result.stdout
        except subprocess.CalledProcessError:
            return False
    
    def init_led_controller(self) -> bool:
        """Инициализация LED контроллера"""
        try:
            # Включение контроллера
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), str(self.addr), '0x00', '0x01'], 
                         check=True)
            
            # Установка глобального тока
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), str(self.addr), '0x6E', '0xFF'], 
                         check=True)
            
            # Настройка scaling регистров
            for i in range(18):
                subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), str(self.addr), 
                              f'0x{0x4A + i:02x}', '0xFF'], check=True)
            
            # Обновление
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), str(self.addr), '0x49', '0x00'], 
                         check=True)
            
            return True
        except subprocess.CalledProcessError:
            return False
    
    def set_led_brightness(self, led_index: int, brightness: int) -> bool:
        """Установка яркости LED"""
        try:
            # PWM регистр (0x01-0x23 для LED 1-18)
            pwm_reg = 0x01 + led_index
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), str(self.addr), 
                          f'0x{pwm_reg:02x}', f'0x{brightness:02x}'], check=True)
            
            # Обновление
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), str(self.addr), '0x49', '0x00'], 
                         check=True)
            return True
        except subprocess.CalledProcessError:
            return False
    
    def read_sysfs_value(self, path: str) -> Optional[str]:
        """Чтение значения из sysfs"""
        try:
            if os.path.exists(path):
                with open(path, 'r') as f:
                    return f.read().strip()
        except Exception:
            pass
        return None
    
    def get_gnss_status(self) -> Dict[str, Any]:
        """Получение статуса GNSS"""
        status = {
            'sync': self.read_sysfs_value(f"{self.timecard_sysfs}/gnss_sync"),
            'clock_source': self.read_sysfs_value(f"{self.timecard_sysfs}/clock_source"),
            'available_sources': self.read_sysfs_value(f"{self.timecard_sysfs}/available_clock_sources"),
            'drift': self.read_sysfs_value(f"{self.timecard_sysfs}/clock_status_drift"),
            'offset': self.read_sysfs_value(f"{self.timecard_sysfs}/clock_status_offset")
        }
        
        # Определение режима работы
        if status['sync'] == 'SYNC':
            status['mode'] = 'sync'
            status['color'] = 'green'
        elif status['sync'] == 'LOST':
            status['mode'] = 'lost'
            status['color'] = 'red'
        elif status['clock_source'] in ['MAC', 'IRIG-B', 'external']:
            status['mode'] = 'holdover'
            status['color'] = 'purple'
        else:
            status['mode'] = 'unknown'
            status['color'] = 'yellow'
        
        return status
    
    def get_sma_status(self) -> Dict[str, Any]:
        """Получение статуса SMA выходов"""
        status = {}
        
        for i in range(1, 5):
            sma_path = f"{self.timecard_sysfs}/sma{i}"
            sma_value = self.read_sysfs_value(sma_path)
            
            if sma_value:
                # Определение достоверности сигнала
                if 'OUT:' in sma_value:
                    # Выходной сигнал - проверяем источник
                    if 'PHC' in sma_value or '10Mhz' in sma_value:
                        status[f'sma{i}'] = {
                            'type': 'output',
                            'signal': sma_value,
                            'reliable': True,
                            'color': 'green'
                        }
                    else:
                        status[f'sma{i}'] = {
                            'type': 'output', 
                            'signal': sma_value,
                            'reliable': False,
                            'color': 'red'
                        }
                else:
                    # Входной сигнал
                    status[f'sma{i}'] = {
                        'type': 'input',
                        'signal': sma_value,
                        'reliable': True,
                        'color': 'green'
                    }
            else:
                status[f'sma{i}'] = {
                    'type': 'unknown',
                    'signal': 'N/A',
                    'reliable': False,
                    'color': 'red'
                }
        
        return status
    
    def update_led_status(self, gnss_status: Dict, sma_status: Dict):
        """Обновление LED индикации"""
        
        # GNSS Sync LED (Power LED)
        if gnss_status['mode'] == 'sync':
            self.set_led_brightness(self.led_map['gnss_sync'], self.colors['green'])
        elif gnss_status['mode'] == 'lost':
            self.set_led_brightness(self.led_map['gnss_sync'], self.colors['red'])
        else:
            self.set_led_brightness(self.led_map['gnss_sync'], self.colors['yellow'])
        
        # Holdover LED (Sync LED)
        if gnss_status['mode'] == 'holdover':
            self.set_led_brightness(self.led_map['gnss_holdover'], self.colors['purple'])
        else:
            self.set_led_brightness(self.led_map['gnss_holdover'], self.colors['off'])
        
        # SMA3 Status LED (GNSS LED)
        if 'sma3' in sma_status:
            if sma_status['sma3']['reliable']:
                self.set_led_brightness(self.led_map['sma3_status'], self.colors['green'])
            else:
                self.set_led_brightness(self.led_map['sma3_status'], self.colors['red'])
        
        # SMA4 Status LED (Alarm LED)
        if 'sma4' in sma_status:
            if sma_status['sma4']['reliable']:
                self.set_led_brightness(self.led_map['sma4_status'], self.colors['green'])
            else:
                self.set_led_brightness(self.led_map['sma4_status'], self.colors['red'])
        
        # Clock Source LED (Status1 LED)
        if gnss_status['clock_source'] == 'GNSS':
            self.set_led_brightness(self.led_map['clock_source'], self.colors['green'])
        elif gnss_status['clock_source'] in ['MAC', 'IRIG-B']:
            self.set_led_brightness(self.led_map['clock_source'], self.colors['purple'])
        else:
            self.set_led_brightness(self.led_map['clock_source'], self.colors['yellow'])
        
        # System Status LED (Status2 LED)
        overall_status = 'green'
        if gnss_status['mode'] == 'lost':
            overall_status = 'red'
        elif gnss_status['mode'] == 'holdover':
            overall_status = 'purple'
        elif not all(sma.get('reliable', False) for sma in sma_status.values()):
            overall_status = 'yellow'
        
        self.set_led_brightness(self.led_map['system_status'], self.colors[overall_status])
    
    def turn_off_all_leds(self):
        """Выключение всех LED"""
        for i in range(18):
            self.set_led_brightness(i, self.colors['off'])
    
    def export_metrics(self, filename: str = None) -> Dict[str, Any]:
        """Экспорт метрик в JSON"""
        gnss_status = self.get_gnss_status()
        sma_status = self.get_sma_status()
        
        metrics = {
            "timestamp": datetime.now().isoformat(),
            "device": "TimeCard GNSS/SMA Monitor",
            "gnss": gnss_status,
            "sma": sma_status,
            "led_status": {
                "gnss_sync": gnss_status.get('color', 'unknown'),
                "holdover": 'purple' if gnss_status['mode'] == 'holdover' else 'off',
                "sma3": sma_status.get('sma3', {}).get('color', 'unknown'),
                "sma4": sma_status.get('sma4', {}).get('color', 'unknown'),
                "clock_source": gnss_status.get('color', 'unknown'),
                "system": 'green' if all(sma.get('reliable', False) for sma in sma_status.values()) else 'red'
            }
        }
        
        if filename:
            with open(filename, 'w') as f:
                json.dump(metrics, f, indent=2)
        
        return metrics
    
    def monitor_loop(self, interval: int = 5):
        """Основной цикл мониторинга"""
        print("=== GNSS/SMA Monitor для TimeCard ===")
        print(f"Интервал обновления: {interval} секунд")
        print("Нажмите Ctrl+C для остановки")
        print()
        
        try:
            while True:
                # Получение статусов
                gnss_status = self.get_gnss_status()
                sma_status = self.get_sma_status()
                
                # Обновление LED
                self.update_led_status(gnss_status, sma_status)
                
                # Вывод статуса
                self.print_status(gnss_status, sma_status)
                
                # Экспорт метрик
                self.export_metrics("gnss_sma_metrics.json")
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n🛑 Остановка мониторинга...")
            self.turn_off_all_leds()
            print("✅ Все LED выключены")
            print("🎉 Мониторинг завершен")
    
    def print_status(self, gnss_status: Dict, sma_status: Dict):
        """Вывод текущего статуса"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        print(f"[{timestamp}] === Статус GNSS/SMA ===")
        
        # GNSS статус
        print(f"GNSS Sync: {gnss_status['sync']} ({gnss_status['color']})")
        print(f"Clock Source: {gnss_status['clock_source']}")
        print(f"Mode: {gnss_status['mode']}")
        
        # SMA статус
        print("SMA Status:")
        for sma_name, sma_data in sma_status.items():
            status_icon = "🟢" if sma_data['reliable'] else "🔴"
            print(f"  {sma_name.upper()}: {status_icon} {sma_data['signal']}")
        
        print()

def main():
    monitor = GNSSSMAMonitor()
    
    # Проверка TimeCard
    if not os.path.exists(monitor.timecard_sysfs):
        print("❌ TimeCard не найден")
        return
    
    print(f"✅ TimeCard найден: {monitor.timecard_sysfs}")
    
    # Проверка I2C устройства
    if not monitor.check_i2c_device():
        print("❌ IS32FL3207 не найден")
        return
    
    print("✅ IS32FL3207 найден")
    
    # Инициализация LED контроллера
    if not monitor.init_led_controller():
        print("❌ Ошибка инициализации LED контроллера")
        return
    
    print("✅ LED контроллер инициализирован")
    
    # Запуск мониторинга
    monitor.monitor_loop()

if __name__ == "__main__":
    main() 