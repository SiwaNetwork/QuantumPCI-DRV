#!/usr/bin/env python3
"""
LED Monitor для TimeCard
Интеграция управления светодиодами IS32FL3207 с системой мониторинга
"""

import subprocess
import time
import json
import os
from datetime import datetime

class LEDMonitor:
    def __init__(self, bus=1, addr=0x37):
        self.bus = bus
        self.addr = addr
        self.pwm_regs = [0x01, 0x03, 0x05, 0x07, 0x09, 0x0B, 0x0D, 0x0F, 
                         0x11, 0x13, 0x15, 0x17, 0x19, 0x1B, 0x1D, 0x1F, 
                         0x21, 0x23]
        self.led_names = {
            0: "Power", 1: "Sync", 2: "GNSS", 3: "Alarm",
            4: "Status1", 5: "Status2", 6: "Status3", 7: "Status4",
            8: "Debug1", 9: "Debug2", 10: "Debug3", 11: "Debug4",
            12: "Info1", 13: "Info2", 14: "Info3", 15: "Info4",
            16: "Test1", 17: "Test2"
        }
        
    def check_i2c_device(self):
        """Проверка наличия IS32FL3207"""
        try:
            result = subprocess.run(['sudo', 'i2cdetect', '-y', str(self.bus)], 
                                  capture_output=True, text=True)
            # Ищем адрес 37 в выводе i2cdetect
            return "37" in result.stdout
        except Exception as e:
            print(f"❌ Ошибка проверки I2C: {e}")
            return False
    
    def init_led_controller(self):
        """Инициализация LED контроллера"""
        try:
            # Включение чипа
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', '0x00', '0x01'])
            
            # Global Current Control
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', '0x6E', '0xFF'])
            
            # Scaling регистры для всех каналов
            for reg in range(74, 92):
                subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', f'0x{reg:02x}', '0xFF'])
            
            print("✅ LED контроллер инициализирован")
            return True
        except Exception as e:
            print(f"❌ Ошибка инициализации: {e}")
            return False
    
    def read_led_status(self, led_index):
        """Чтение статуса конкретного LED"""
        try:
            reg = self.pwm_regs[led_index]
            result = subprocess.run(['sudo', 'i2cget', '-y', str(self.bus), f'0x{self.addr:02x}', f'0x{reg:02x}'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                return int(result.stdout.strip(), 16)
            return 0
        except Exception as e:
            print(f"❌ Ошибка чтения LED {led_index}: {e}")
            return 0
    
    def set_led_brightness(self, led_index, brightness):
        """Установка яркости LED"""
        try:
            reg = self.pwm_regs[led_index]
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', f'0x{reg:02x}', f'0x{brightness:02x}'])
            subprocess.run(['sudo', 'i2cset', '-y', str(self.bus), f'0x{self.addr:02x}', '0x49', '0x00'])
            return True
        except Exception as e:
            print(f"❌ Ошибка установки LED {led_index}: {e}")
            return False
    
    def turn_off_all_leds(self):
        """Выключение всех LED"""
        for i in range(18):
            self.set_led_brightness(i, 0)
    
    def get_all_led_status(self):
        """Получение статуса всех LED"""
        status = {}
        for i in range(18):
            brightness = self.read_led_status(i)
            led_name = self.led_names.get(i, f"LED{i+1}")
            
            # Определение состояния
            if brightness == 0:
                state = "off"
            elif brightness >= 0xE0:
                state = "bright"
            elif brightness >= 0x80:
                state = "medium"
            elif brightness >= 0x40:
                state = "dim"
            else:
                state = "very_dim"
            
            status[led_name] = {
                "brightness": brightness,
                "state": state,
                "percentage": int((brightness / 255) * 100)
            }
        
        return status
    
    def set_led_pattern(self, pattern_name):
        """Установка предопределенных паттернов LED"""
        patterns = {
            "all_off": lambda: [self.set_led_brightness(i, 0) for i in range(18)],
            "all_on": lambda: [self.set_led_brightness(i, 0xFF) for i in range(18)],
            "power_on": lambda: [
                self.set_led_brightness(0, 0xFF),  # Power LED
                self.set_led_brightness(1, 0x80),  # Sync LED
                self.set_led_brightness(2, 0x80),  # GNSS LED
                self.set_led_brightness(3, 0x00)   # Alarm LED
            ],
            "error": lambda: [
                self.set_led_brightness(0, 0xFF),  # Power LED
                self.set_led_brightness(1, 0x00),  # Sync LED
                self.set_led_brightness(2, 0x00),  # GNSS LED
                self.set_led_brightness(3, 0xFF)   # Alarm LED
            ],
            "warning": lambda: [
                self.set_led_brightness(0, 0xFF),  # Power LED
                self.set_led_brightness(1, 0x80),  # Sync LED
                self.set_led_brightness(2, 0x40),  # GNSS LED
                self.set_led_brightness(3, 0x80)   # Alarm LED
            ],
            "test": lambda: [
                self.set_led_brightness(i, 0x80 if i % 2 == 0 else 0x00) for i in range(18)
            ]
        }
        
        if pattern_name in patterns:
            patterns[pattern_name]()
            print(f"✅ Установлен паттерн: {pattern_name}")
            return True
        else:
            print(f"❌ Неизвестный паттерн: {pattern_name}")
            return False
    
    def export_metrics(self, filename=None):
        """Экспорт метрик LED в JSON"""
        status = self.get_all_led_status()
        metrics = {
            "timestamp": datetime.now().isoformat(),
            "device": "TimeCard LED Controller",
            "i2c_bus": self.bus,
            "i2c_addr": f"0x{self.addr:02x}",
            "leds": status,
            "summary": {
                "total_leds": 18,
                "active_leds": sum(1 for led in status.values() if led["brightness"] > 0),
                "average_brightness": sum(led["brightness"] for led in status.values()) // 18
            }
        }
        
        if filename:
            with open(filename, 'w') as f:
                json.dump(metrics, f, indent=2)
            print(f"✅ Метрики сохранены в {filename}")
        
        return metrics

def main():
    print("=== LED Monitor для TimeCard ===")
    
    # Проверка TimeCard
    timecard_sysfs = "/sys/class/timecard/ocp0"
    if os.path.exists(timecard_sysfs):
        serial = open(f"{timecard_sysfs}/serialnum").read().strip()
        print(f"✅ TimeCard найден: {serial}")
    else:
        print("❌ TimeCard не найден")
        return
    
    # Создание монитора
    monitor = LEDMonitor()
    
    # Проверка I2C устройства
    if not monitor.check_i2c_device():
        print("❌ IS32FL3207 не найден")
        return
    
    print("✅ IS32FL3207 найден")
    
    # Инициализация
    if not monitor.init_led_controller():
        print("❌ Ошибка инициализации")
        return
    
    # Демонстрация функций
    print("\n🎯 Демонстрация функций:")
    
    # 1. Показать текущий статус
    print("\n1. Текущий статус всех LED:")
    status = monitor.get_all_led_status()
    for name, info in status.items():
        print(f"   {name}: {info['state']} ({info['percentage']}%)")
    
    # 2. Тест паттернов
    print("\n2. Тест паттернов LED:")
    patterns = ["all_off", "power_on", "warning", "error", "test", "all_off"]
    
    for pattern in patterns:
        print(f"   Установка паттерна: {pattern}")
        monitor.set_led_pattern(pattern)
        time.sleep(1)
    
    # 3. Экспорт метрик
    print("\n3. Экспорт метрик:")
    metrics = monitor.export_metrics("led_metrics.json")
    print(f"   Активных LED: {metrics['summary']['active_leds']}")
    print(f"   Средняя яркость: {metrics['summary']['average_brightness']}")
    
    print("\n✅ Демонстрация завершена")
    
    # Выключение всех LED
    print("\n🔚 Выключение всех LED...")
    for i in range(18):
        monitor.set_led_brightness(i, 0)
    
    print("✅ Все LED выключены")
    print("🎉 Демонстрация завершена!")

if __name__ == "__main__":
    main() 