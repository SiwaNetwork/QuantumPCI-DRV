#!/usr/bin/env python3
"""
Мониторинг GNSS и SMA статусов с LED индикацией
"""

import subprocess
import json
import time
import sys
import os

class GNSSSMAMonitorFixed:
    def __init__(self, bus=1, addr=0x37):
        self.bus = bus
        self.addr = addr
        self.quantum_pci_timecard_sysfs = "/sys/class/timecard/ocp0"
        
        # ИСПРАВЛЕННАЯ схема нумерации LED
        # LED 1,3,5 используют регистры 0x01,0x03,0x05
        # LED 2,4,6 используют регистры 0x07,0x09,0x0B
        self.led_map = {
            'gnss_sync': 0,      # Power LED - регистр 0x01
            'gnss_holdover': 1,   # Sync LED - регистр 0x07
            'sma3_status': 2,     # GNSS LED - регистр 0x03
            'sma4_status': 3,     # Alarm LED - регистр 0x09
            'clock_source': 4,    # Status1 LED - регистр 0x05
            'system_status': 5    # Status2 LED - регистр 0x0B
        }
        
        # Маппинг LED индексов на правильные регистры
        self.led_registers = {
            0: 0x01,  # LED 1 - Power
            1: 0x07,  # LED 2 - Sync (исправлено!)
            2: 0x03,  # LED 3 - GNSS
            3: 0x09,  # LED 4 - Alarm (исправлено!)
            4: 0x05,  # LED 5 - Status1
            5: 0x0B   # LED 6 - Status2 (исправлено!)
        }
        
        self.colors = {
            'off': 0x00,
            'green': 0xFF,
            'red': 0xFF,
            'purple': 0x80,
            'yellow': 0xC0
        }
        
        # Инициализация контроллера
        self.init_led_controller()
    
    def check_i2c_device(self):
        """Проверка наличия I2C устройства"""
        try:
            result = subprocess.run(['sudo', 'i2cdetect', '-y', str(self.bus)], 
                                  capture_output=True, text=True, check=True)
            # Ищем адрес в формате "37" (как отображается в i2cdetect)
            return f"{self.addr:02x}" in result.stdout
        except subprocess.CalledProcessError:
            return False
    
    def init_led_controller(self):
        """Инициализация LED контроллера"""
        try:
            # Включение контроллера
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', '0x00', '0x01'], check=True)
            
            # Установка глобального тока
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', '0x6E', '0xFF'], check=True)
            
            # Настройка scaling регистров
            for i in range(18):
                reg = 0x4A + i
                subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', f'0x{reg:02x}', '0xFF'], check=True)
            
            # Обновление контроллера
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', '0x49', '0x00'], check=True)
            
            print("✅ LED контроллер инициализирован")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Ошибка инициализации LED контроллера: {e}")
            return False
    
    def set_led_brightness(self, led_index, brightness):
        """Установка яркости LED с правильным регистром"""
        if led_index not in self.led_registers:
            print(f"❌ Неизвестный LED индекс: {led_index}")
            return False
        
        try:
            reg = self.led_registers[led_index]
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', f'0x{reg:02x}', f'0x{brightness:02x}'], check=True)
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', '0x49', '0x00'], check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Ошибка установки LED {led_index}: {e}")
            return False
    
    def read_sysfs_value(self, attribute):
        """Чтение значения из sysfs"""
        try:
                            with open(f"{self.quantum_pci_timecard_sysfs}/{attribute}", 'r') as f:
                return f.read().strip()
        except (FileNotFoundError, PermissionError):
            return None
    
    def get_gnss_status(self):
        """Получение статуса GNSS"""
        gnss_sync = self.read_sysfs_value('gnss_sync')
        clock_source = self.read_sysfs_value('clock_source')
        
        status = {
            'sync': gnss_sync == 'SYNC' if gnss_sync else False,
            'holdover': clock_source == 'holdover' if clock_source else False,
            'source': clock_source if clock_source else 'unknown'
        }
        
        return status
    
    def get_sma_status(self):
        """Получение статуса SMA выходов"""
        sma_status = {}
        
        for i in range(1, 5):
            sma_value = self.read_sysfs_value(f'sma{i}')
            if sma_value:
                sma_status[f'sma{i}'] = sma_value
            else:
                sma_status[f'sma{i}'] = 'unknown'
        
        return sma_status
    
    def update_led_status(self):
        """Обновление статуса LED на основе GNSS и SMA"""
        gnss_status = self.get_gnss_status()
        sma_status = self.get_sma_status()
        
        # LED 0: GNSS Sync Status (Power LED)
        if gnss_status['sync']:
            self.set_led_brightness(0, self.colors['green'])  # Зеленый - SYNC
        else:
            self.set_led_brightness(0, self.colors['red'])    # Красный - LOST
        
        # LED 1: GNSS Holdover Status (Sync LED)
        if gnss_status['holdover']:
            self.set_led_brightness(1, self.colors['purple']) # Сиреневый - holdover
        else:
            self.set_led_brightness(1, self.colors['off'])    # Выключен
        
        # LED 2: SMA3 Status (GNSS LED)
        # Проверяем что SMA3 работает как выход И GNSS синхронизирован
        sma3_working = sma_status.get('sma3', '').startswith('OUT:')
        if gnss_status['sync'] and sma3_working:
            self.set_led_brightness(2, self.colors['green'])  # Зеленый - надежный
        else:
            self.set_led_brightness(2, self.colors['red'])    # Красный - ненадежный
        
        # LED 3: SMA4 Status (Alarm LED)
        # Проверяем что SMA4 работает как выход И GNSS синхронизирован
        sma4_working = sma_status.get('sma4', '').startswith('OUT:')
        if gnss_status['sync'] and sma4_working:
            self.set_led_brightness(3, self.colors['green'])  # Зеленый - надежный
        else:
            self.set_led_brightness(3, self.colors['red'])    # Красный - ненадежный
        
        # LED 4: Clock Source Status (Status1 LED)
        if gnss_status['source'] == 'gnss':
            self.set_led_brightness(4, self.colors['green'])  # Зеленый - GNSS
        elif gnss_status['source'] == 'holdover':
            self.set_led_brightness(4, self.colors['purple']) # Сиреневый - holdover
        else:
            self.set_led_brightness(4, self.colors['yellow']) # Желтый - другой источник
        
        # LED 5: System Status (Status2 LED)
        if gnss_status['sync'] and not gnss_status['holdover']:
            self.set_led_brightness(5, self.colors['green'])  # Зеленый - нормальная работа
        else:
            self.set_led_brightness(5, self.colors['yellow']) # Желтый - предупреждение
        
        return {
            'gnss': gnss_status,
            'sma': sma_status,
            'leds': {
                'power': 'green' if gnss_status['sync'] else 'red',
                'sync': 'purple' if gnss_status['holdover'] else 'off',
                'gnss': 'green' if (gnss_status['sync'] and sma_status.get('sma3', '').startswith('OUT:')) else 'red',
                'alarm': 'green' if (gnss_status['sync'] and sma_status.get('sma4', '').startswith('OUT:')) else 'red',
                'status1': 'green' if gnss_status['source'] == 'gnss' else ('purple' if gnss_status['source'] == 'holdover' else 'yellow'),
                'status2': 'green' if (gnss_status['sync'] and not gnss_status['holdover']) else 'yellow'
            }
        }
    
    def turn_off_all_leds(self):
        """Выключение всех LED"""
        print("🔚 Выключение всех LED...")
        for led_index in range(6):
            self.set_led_brightness(led_index, 0)
        print("✅ Все LED выключены")
    
    def export_metrics(self, status):
        """Экспорт метрик в JSON файл"""
        metrics = {
            'timestamp': time.time(),
            'gnss_sync': status['gnss']['sync'],
            'gnss_holdover': status['gnss']['holdover'],
            'clock_source': status['gnss']['source'],
            'sma_status': status['sma'],
            'led_status': status['leds']
        }
        
        try:
            with open('gnss_sma_metrics_fixed.json', 'w') as f:
                json.dump(metrics, f, indent=2)
        except Exception as e:
            print(f"❌ Ошибка экспорта метрик: {e}")
    
    def print_status(self, status):
        """Вывод статуса в консоль"""
        print("\n" + "="*60)
        print("📊 СТАТУС GNSS И SMA МОНИТОРИНГА")
        print("="*60)
        
        # GNSS статус
        gnss = status['gnss']
        print(f"🛰️  GNSS Sync: {'✅ SYNC' if gnss['sync'] else '❌ LOST'}")
        print(f"🔄 Holdover: {'✅ АКТИВЕН' if gnss['holdover'] else '❌ НЕ АКТИВЕН'}")
        print(f"📡 Источник часов: {gnss['source']}")
        
        # SMA статус
        print("\n🔌 SMA Выходы:")
        for sma, value in status['sma'].items():
            # Определяем статус надежности для SMA3 и SMA4
            if sma in ['sma3', 'sma4']:
                is_output = value.startswith('OUT:')
                reliability = "✅ НАДЕЖНЫЙ" if (status['gnss']['sync'] and is_output) else "❌ НЕНАДЕЖНЫЙ"
                print(f"  {sma.upper()}: {value} ({reliability})")
            else:
                print(f"  {sma.upper()}: {value}")
        
        # LED статус
        print("\n💡 LED Индикация:")
        led_names = ['Power', 'Sync', 'GNSS', 'Alarm', 'Status1', 'Status2']
        for i, (name, color) in enumerate(zip(led_names, status['leds'].values())):
            print(f"  {name}: {color}")
        
        print("="*60)
    
    def monitor_loop(self, interval=5):
        """Основной цикл мониторинга"""
        print("🚀 Запуск мониторинга GNSS и SMA статусов...")
        print("💡 Используется ИСПРАВЛЕННАЯ схема нумерации LED")
        print("🎯 LED 2,4,6 используют регистры 0x07,0x09,0x0B")
        
        try:
            while True:
                status = self.update_led_status()
                self.export_metrics(status)
                self.print_status(status)
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n🛑 Остановка мониторинга...")
            self.turn_off_all_leds()
            print("✅ Мониторинг остановлен")

def main():
    """Главная функция"""
    monitor = GNSSSMAMonitorFixed()
    
    if not monitor.check_i2c_device():
        print("❌ IS32FL3207 не найден на I2C шине")
        sys.exit(1)
    
    print("✅ IS32FL3207 найден")
    
    # Демонстрация работы
    print("\n🎯 Демонстрация исправленной схемы LED:")
    
    # Тест каждого LED
    for i in range(6):
        print(f"Тест LED {i} (регистр 0x{monitor.led_registers[i]:02x})...")
        monitor.set_led_brightness(i, monitor.colors['green'])
        time.sleep(1)
        monitor.set_led_brightness(i, 0)
    
    print("\n✅ Демонстрация завершена")
    
    # Запуск мониторинга
    monitor.monitor_loop()

if __name__ == "__main__":
    main() 