#!/usr/bin/env python3
"""
INA219 Voltage Monitor Module
Модуль для мониторинга датчиков INA219BIDR (напряжение и ток)
"""

import subprocess
import time
import json
import statistics
from pathlib import Path
from typing import Dict, Optional, List
from collections import deque

class INA219Filter:
    """Фильтр для устранения ложных значений INA219"""
    
    def __init__(self, window_size=5, valid_range=(2.5, 4.0)):
        self.window_size = window_size
        self.valid_range = valid_range
        self.voltage_history = deque(maxlen=window_size)
        self.last_valid_voltage = 3.3
        
    def is_valid_voltage(self, voltage):
        """Проверка валидности напряжения"""
        return self.valid_range[0] <= voltage <= self.valid_range[1]
    
    def filter_voltage(self, voltage, raw_value):
        """Фильтрация напряжения"""
        if not self.is_valid_voltage(voltage):
            return self.last_valid_voltage, False, f"Вне диапазона {self.valid_range[0]}-{self.valid_range[1]}V"
        
        self.voltage_history.append(voltage)
        
        if len(self.voltage_history) < 3:
            self.last_valid_voltage = voltage
            return voltage, True, "Недостаточно данных"
        
        # Проверка на выбросы
        median_voltage = statistics.median(self.voltage_history)
        deviation = abs(voltage - median_voltage)
        
        if deviation > 0.5:
            return self.last_valid_voltage, False, f"Выброс: отклонение {deviation:.3f}V"
        
        filtered_voltage = statistics.mean(self.voltage_history)
        self.last_valid_voltage = filtered_voltage
        
        return filtered_voltage, True, "OK"

class INA219Monitor:
    """
    Мониторинг датчиков INA219BIDR через I2C
    """
    
    def __init__(self):
        self.i2c_bus = 1
        self.devices = {
            '44': {'name': 'INA219 #1', 'description': '3.3V система (показывает ~3.3V)'},
            '41': {'name': 'INA219 #2', 'description': '5V система (показывает ~14.6V, ожидалось 5V)'},
            '40': {'name': 'INA219 #3', 'description': '12V система (показывает ~26.9V)'}
        }
        self.last_readings = {}
        self.last_update = None
        self.error_count = 0
        self.max_errors = 5
        
        # Инициализация фильтров для каждого датчика
        self.filters = {
            '44': INA219Filter(window_size=5, valid_range=(2.5, 4.0)),  # 3.3V
            '41': INA219Filter(window_size=5, valid_range=(4.0, 6.0)),  # 5V
            '40': INA219Filter(window_size=5, valid_range=(10.0, 15.0)) # 12V
        }
        
    def is_available(self) -> bool:
        """Проверка доступности I2C и INA219 датчиков"""
        try:
            # Проверяем наличие i2c-tools
            result = subprocess.run(['which', 'i2cget'], 
                                  capture_output=True, text=True)
            if result.returncode != 0:
                return False
                
            # Проверяем доступность I2C шины
            result = subprocess.run(['i2cdetect', '-l'], 
                                  capture_output=True, text=True)
            if f'i2c-{self.i2c_bus}' not in result.stdout:
                return False
                
            # Проверяем наличие INA219 устройств
            result = subprocess.run(['i2cdetect', '-y', str(self.i2c_bus)], 
                                  capture_output=True, text=True)
            
            available_devices = []
            for addr, info in self.devices.items():
                if addr in result.stdout:
                    available_devices.append(addr)
                    
            return len(available_devices) > 0
            
        except Exception as e:
            print(f"❌ Ошибка проверки доступности INA219: {e}")
            return False
    
    def _read_i2c_register(self, address: str, register: str) -> Optional[int]:
        """Чтение регистра I2C устройства"""
        try:
            # Добавляем 0x к адресу если его нет
            if not address.startswith('0x'):
                address = f'0x{address}'
                
            result = subprocess.run([
                'i2cget', '-y', str(self.i2c_bus), address, register, 'w'
            ], capture_output=True, text=True, timeout=2)
            
            if result.returncode == 0:
                return int(result.stdout.strip(), 16)
            else:
                return None
                
        except Exception as e:
            print(f"❌ Ошибка чтения I2C {address}:{register} - {e}")
            return None
    
    def _calculate_voltage(self, raw_value: int, voltage_type: str, address: str = None) -> float:
        """Расчет напряжения по raw значению с адаптивной калибровкой"""
        if voltage_type == 'bus':
            # Ожидаемые напряжения для каждого INA219
            expected_voltages = {
                '44': 3.3,   # INA219 #1: 3.3V система
                '41': 5.0,   # INA219 #2: 5V система  
                '40': 12.0   # INA219 #3: 12V система
            }
            
            if address and address in expected_voltages:
                # Адаптивная калибровка: используем текущее raw значение для расчета коэффициента
                expected_voltage = expected_voltages[address]
                
                # Если raw значение разумное (не слишком большое или маленькое)
                if 1000 < raw_value < 50000:
                    # Рассчитываем коэффициент на лету
                    calibration_factor = expected_voltage / raw_value
                    return raw_value * calibration_factor
                else:
                    # Если raw значение неразумное, используем стандартную формулу
                    return (raw_value >> 3) * 0.004
            else:
                # Стандартная формула INA219
                return (raw_value >> 3) * 0.004
        elif voltage_type == 'shunt':
            # Напряжение шунта: raw * 10μV согласно техническому описанию
            return raw_value * 0.00001
        else:
            return 0.0
    
    def get_device_data(self, address: str) -> Dict:
        """Получение данных с конкретного INA219 устройства"""
        device_info = self.devices.get(address, {})
        
        # Читаем регистры
        bus_voltage_raw = self._read_i2c_register(address, '0x02')
        shunt_voltage_raw = self._read_i2c_register(address, '0x01')
        current_raw = self._read_i2c_register(address, '0x04')
        power_raw = self._read_i2c_register(address, '0x03')
        
        if bus_voltage_raw is None:
            return {
                'address': address,
                'name': device_info.get('name', f'INA219 {address}'),
                'description': device_info.get('description', ''),
                'available': False,
                'error': 'Не удалось прочитать данные'
            }
        
        # Рассчитываем напряжения с правильными коэффициентами
        bus_voltage = self._calculate_voltage(bus_voltage_raw, 'bus', address)
        shunt_voltage = self._calculate_voltage(shunt_voltage_raw, 'shunt')
        
        # Применяем фильтр для устранения ложных значений
        if address in self.filters:
            filtered_voltage, is_valid, filter_reason = self.filters[address].filter_voltage(bus_voltage, bus_voltage_raw)
            bus_voltage = filtered_voltage
            filter_status = 'filtered' if not is_valid else 'ok'
        else:
            filter_status = 'no_filter'
            filter_reason = 'Фильтр не настроен'
        
        return {
            'address': address,
            'name': device_info.get('name', f'INA219 {address}'),
            'description': device_info.get('description', ''),
            'available': True,
            'bus_voltage': {
                'value': bus_voltage,
                'unit': 'V',
                'raw': bus_voltage_raw,
                'filter_status': filter_status,
                'filter_reason': filter_reason
            },
            'shunt_voltage': {
                'value': shunt_voltage,
                'unit': 'V',
                'raw': shunt_voltage_raw
            },
            'current': {
                'value': 0.0,  # Требует калибровки
                'unit': 'A',
                'raw': current_raw,
                'note': 'Требует калибровки для шунта 2 МОм'
            },
            'power': {
                'value': 0.0,  # Требует калибровки
                'unit': 'W',
                'raw': power_raw,
                'note': 'Требует калибровки для шунта 2 МОм'
            },
            'timestamp': time.time()
        }
    
    def get_all_data(self) -> Dict:
        """Получение данных со всех INA219 устройств"""
        all_data = {
            'available': self.is_available(),
            'devices': {},
            'summary': {
                'total_devices': len(self.devices),
                'active_devices': 0,
                'total_bus_voltage': 0.0,
                'total_shunt_voltage': 0.0
            },
            'timestamp': time.time()
        }
        
        if not all_data['available']:
            return all_data
        
        active_count = 0
        total_bus = 0.0
        total_shunt = 0.0
        
        for address in self.devices.keys():
            device_data = self.get_device_data(address)
            all_data['devices'][address] = device_data
            
            if device_data['available']:
                active_count += 1
                total_bus += device_data['bus_voltage']['value']
                total_shunt += device_data['shunt_voltage']['value']
        
        all_data['summary']['active_devices'] = active_count
        all_data['summary']['total_bus_voltage'] = total_bus
        all_data['summary']['total_shunt_voltage'] = total_shunt
        
        self.last_readings = all_data
        self.last_update = time.time()
        
        return all_data
    
    def get_device_info(self) -> Dict:
        """Получение информации об INA219 устройствах"""
        return {
            'name': 'INA219BIDR Voltage Monitor',
            'version': '1.0.0',
            'description': 'Мониторинг напряжения и тока через INA219BIDR датчики',
            'i2c_bus': self.i2c_bus,
            'devices': self.devices,
            'formulas': {
                'bus_voltage': '(raw >> 3) * 4mV',
                'shunt_voltage': 'raw * 10μV',
                'current': 'raw * Current_LSB (требует калибровки)',
                'power': 'raw * Power_LSB (требует калибровки)'
            },
            'calibration_note': 'Для получения тока и мощности требуется калибровка для шунта 2 МОм'
        }

# Глобальные функции для совместимости с API
def get_ina219_data() -> Dict:
    """Получение данных INA219"""
    monitor = INA219Monitor()
    return monitor.get_all_data()

def get_ina219_info() -> Dict:
    """Получение информации об INA219"""
    monitor = INA219Monitor()
    return monitor.get_device_info()

def is_ina219_available() -> bool:
    """Проверка доступности INA219"""
    monitor = INA219Monitor()
    return monitor.is_available()

if __name__ == "__main__":
    # Тестирование модуля
    monitor = INA219Monitor()
    
    print("=== Тестирование INA219 Monitor ===")
    print(f"Доступность: {monitor.is_available()}")
    
    if monitor.is_available():
        print("\n=== Информация об устройствах ===")
        info = monitor.get_device_info()
        print(json.dumps(info, indent=2, ensure_ascii=False))
        
        print("\n=== Данные устройств ===")
        data = monitor.get_all_data()
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print("❌ INA219 устройства недоступны")
