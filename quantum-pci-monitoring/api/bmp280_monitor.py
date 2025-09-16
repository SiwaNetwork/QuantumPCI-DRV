#!/usr/bin/env python3
"""
BMP280 Sensor Monitor Module
Модуль для мониторинга датчика BMP280 (температура и давление)
"""

import os
import subprocess
import time
import json
from pathlib import Path
from typing import Dict, Optional, Tuple

class BMP280Monitor:
    """
    Мониторинг датчика BMP280 через I2C
    """
    
    def __init__(self):
        self.driver_script = "/home/shiwa-time/QuantumPCI-DRV/bmp280-sensor/bmp280_driver.sh"
        self.last_reading = None
        self.last_update = None
        self.error_count = 0
        self.max_errors = 5
        
    def is_available(self) -> bool:
        """Проверка доступности датчика BMP280"""
        try:
            # Проверяем наличие драйвера
            if not os.path.exists(self.driver_script):
                return False
                
            # Проверяем права на выполнение
            if not os.access(self.driver_script, os.X_OK):
                return False
                
            # Проверяем наличие i2c-tools
            result = subprocess.run(['which', 'i2cget'], 
                                  capture_output=True, text=True)
            if result.returncode != 0:
                return False
                
            return True
            
        except Exception as e:
            print(f"❌ Ошибка проверки доступности BMP280: {e}")
            return False
    
    def get_sensor_data(self) -> Dict:
        """
        Получение данных с датчика BMP280
        
        Returns:
            Dict с данными датчика или None при ошибке
        """
        try:
            # Выполняем команду получения всех данных
            result = subprocess.run(
                [self.driver_script, 'all'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                self.error_count += 1
                return {
                    'error': f'Ошибка выполнения драйвера: {result.stderr}',
                    'available': False
                }
            
            # Парсим вывод
            output = result.stdout
            temperature = None
            pressure = None
            
            for line in output.split('\n'):
                if 'Температура' in line and '°C' in line:
                    try:
                        temp_str = line.split('=')[1].strip().replace('°C', '').replace(' ', '')
                        temperature = float(temp_str)
                    except (IndexError, ValueError):
                        pass
                        
                elif 'Давление' in line and 'Па' in line:
                    try:
                        press_str = line.split('=')[1].strip().replace('Па', '').replace(' ', '')
                        pressure = float(press_str)
                    except (IndexError, ValueError):
                        pass
            
            if temperature is not None and pressure is not None:
                self.last_reading = {
                    'temperature_c': temperature,
                    'pressure_pa': pressure,
                    'pressure_hpa': pressure / 100,
                    'pressure_mbar': pressure / 100,
                    'timestamp': time.time(),
                    'available': True,
                    'error_count': self.error_count
                }
                self.last_update = time.time()
                self.error_count = 0
                return self.last_reading
            else:
                self.error_count += 1
                return {
                    'error': 'Не удалось распарсить данные датчика',
                    'available': False,
                    'error_count': self.error_count
                }
                
        except subprocess.TimeoutExpired:
            self.error_count += 1
            return {
                'error': 'Таймаут выполнения команды',
                'available': False,
                'error_count': self.error_count
            }
        except Exception as e:
            self.error_count += 1
            return {
                'error': f'Ошибка получения данных: {str(e)}',
                'available': False,
                'error_count': self.error_count
            }
    
    def get_sensor_info(self) -> Dict:
        """Получение информации о датчике"""
        return {
            'name': 'BMP280',
            'type': 'Barometric Pressure & Temperature Sensor',
            'i2c_address': '0x76',
            'i2c_bus': '1',
            'driver_script': self.driver_script,
            'available': self.is_available(),
            'last_update': self.last_update,
            'error_count': self.error_count
        }
    
    def get_temperature_only(self) -> Optional[float]:
        """Получение только температуры"""
        try:
            result = subprocess.run(
                [self.driver_script, 'temp'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'Температура' in line and '°C' in line:
                        try:
                            temp_str = line.split('=')[1].strip().replace('°C', '').replace(' ', '')
                            return float(temp_str)
                        except (IndexError, ValueError):
                            pass
        except Exception:
            pass
        return None
    
    def get_pressure_only(self) -> Optional[float]:
        """Получение только давления"""
        try:
            result = subprocess.run(
                [self.driver_script, 'press'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'Давление' in line and 'Па' in line:
                        try:
                            press_str = line.split('=')[1].strip().replace('Па', '').replace(' ', '')
                            return float(press_str)
                        except (IndexError, ValueError):
                            pass
        except Exception:
            pass
        return None

# Глобальный экземпляр монитора
bmp280_monitor = BMP280Monitor()

def get_bmp280_data() -> Dict:
    """Получение данных BMP280 для API"""
    return bmp280_monitor.get_sensor_data()

def get_bmp280_info() -> Dict:
    """Получение информации о BMP280 для API"""
    return bmp280_monitor.get_sensor_info()

def is_bmp280_available() -> bool:
    """Проверка доступности BMP280"""
    return bmp280_monitor.is_available()
