#!/usr/bin/env python3
"""
Мониторинг INA219 с фильтрацией ложных значений
"""

import requests
import time
import json
from ina219_filter import INA219Filter

def monitor_ina219_filtered():
    """Мониторинг INA219 с фильтрацией"""
    
    # Создаем фильтры для каждого датчика
    filter_3v3 = INA219Filter(window_size=5, valid_range=(2.5, 4.0))
    filter_5v = INA219Filter(window_size=5, valid_range=(4.0, 6.0))
    filter_12v = INA219Filter(window_size=5, valid_range=(10.0, 15.0))
    
    print("=== Мониторинг INA219 с фильтрацией ложных значений ===")
    print("Нажмите Ctrl+C для остановки")
    print()
    
    try:
        while True:
            try:
                # Получаем данные с API
                response = requests.get('http://localhost:8080/api/ina219', timeout=5)
                data = response.json()
                
                devices = data['data']['devices']
                
                print(f"\n{'='*60}")
                print(f"Время: {time.strftime('%H:%M:%S')}")
                print(f"{'='*60}")
                
                # Обрабатываем каждый датчик
                for addr, device in devices.items():
                    if addr == '44':  # 3.3V
                        voltage = device['bus_voltage']['value']
                        raw = device['bus_voltage']['raw']
                        filtered_voltage, is_valid, reason = filter_3v3.filter_voltage(voltage, raw)
                        name = "INA219 #1 (3.3V)"
                        
                    elif addr == '41':  # 5V
                        voltage = device['bus_voltage']['value']
                        raw = device['bus_voltage']['raw']
                        filtered_voltage, is_valid, reason = filter_5v.filter_voltage(voltage, raw)
                        name = "INA219 #2 (5V)"
                        
                    elif addr == '40':  # 12V
                        voltage = device['bus_voltage']['value']
                        raw = device['bus_voltage']['raw']
                        filtered_voltage, is_valid, reason = filter_12v.filter_voltage(voltage, raw)
                        name = "INA219 #3 (12V)"
                    else:
                        continue
                    
                    # Выводим результат
                    status = "✅" if is_valid else "❌"
                    print(f"{name}:")
                    print(f"  Исходное: {voltage:6.3f}V (raw: {raw:5d})")
                    print(f"  Фильтр:   {filtered_voltage:6.3f}V {status}")
                    print(f"  Статус:   {reason}")
                    print()
                
                time.sleep(2)
                
            except requests.exceptions.RequestException as e:
                print(f"Ошибка API: {e}")
                time.sleep(5)
            except Exception as e:
                print(f"Ошибка: {e}")
                time.sleep(5)
                
    except KeyboardInterrupt:
        print("\n\nМониторинг остановлен пользователем")

if __name__ == "__main__":
    monitor_ina219_filtered()
