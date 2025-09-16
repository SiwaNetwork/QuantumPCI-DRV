#!/usr/bin/env python3
"""
BNO055 Sensor Monitor Module
Модуль для мониторинга датчика BNO055 (9-DOF IMU с fusion алгоритмом)
"""

import os
import subprocess
import time
import json
from pathlib import Path
from typing import Dict, Optional, Tuple

class BNO055Monitor:
    """
    Мониторинг датчика BNO055 через I2C
    Поддерживает чтение ориентации, ускорения, гироскопа и магнетометра
    """
    
    def __init__(self):
        self.driver_script = "/home/shiwa-time/QuantumPCI-DRV/bno055-sensor/bno055_driver.sh"
        self.last_reading = None
        self.last_update = None
        self.error_count = 0
        self.max_errors = 5
        
    def is_available(self) -> bool:
        """Проверка доступности датчика BNO055"""
        try:
            # Проверяем наличие драйвера
            if not os.path.exists(self.driver_script):
                return False
                
            # Проверяем права на выполнение
            if not os.access(self.driver_script, os.X_OK):
                return False
                
            # Пробуем запустить драйвер для проверки
            result = subprocess.run(
                [self.driver_script, "status"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            return result.returncode == 0
            
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError):
            return False
        except Exception as e:
            print(f"BNO055 availability check error: {e}")
            return False
    
    def _read_sensor_data(self) -> Optional[Dict]:
        """Чтение данных с датчика BNO055"""
        try:
            # Запускаем драйвер для получения данных
            result = subprocess.run(
                [self.driver_script, "read"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                self.error_count += 1
                return None
                
            # Парсим вывод драйвера
            output = result.stdout.strip()
            if not output:
                self.error_count += 1
                return None
                
            # Парсим JSON данные (если драйвер возвращает JSON)
            try:
                data = json.loads(output)
                return data
            except json.JSONDecodeError:
                # Если не JSON, парсим текстовый вывод
                return self._parse_text_output(output)
                
        except subprocess.TimeoutExpired:
            self.error_count += 1
            return None
        except Exception as e:
            print(f"BNO055 read error: {e}")
            self.error_count += 1
            return None
    
    def _parse_text_output(self, output: str) -> Dict:
        """Парсинг текстового вывода драйвера"""
        data = {
            "timestamp": time.time(),
            "euler_angles": {"heading": 0, "roll": 0, "pitch": 0},
            "quaternions": {"w": 0, "x": 0, "y": 0, "z": 0},
            "linear_acceleration": {"x": 0, "y": 0, "z": 0},
            "gravity_vector": {"x": 0, "y": 0, "z": 0},
            "accelerometer": {"x": 0, "y": 0, "z": 0},
            "gyroscope": {"x": 0, "y": 0, "z": 0},
            "magnetometer": {"x": 0, "y": 0, "z": 0},
            "temperature": 0,
            "calibration_status": {"system": 0, "gyro": 0, "accel": 0, "mag": 0},
            "operation_mode": "unknown",
            "power_mode": "unknown"
        }
        
        lines = output.split('\n')
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            # Парсим различные типы данных
            if "Heading:" in line:
                try:
                    data["euler_angles"]["heading"] = float(line.split(":")[1].strip())
                except (ValueError, IndexError):
                    pass
            elif "Roll:" in line:
                try:
                    data["euler_angles"]["roll"] = float(line.split(":")[1].strip())
                except (ValueError, IndexError):
                    pass
            elif "Pitch:" in line:
                try:
                    data["euler_angles"]["pitch"] = float(line.split(":")[1].strip())
                except (ValueError, IndexError):
                    pass
            elif "Temperature:" in line:
                try:
                    data["temperature"] = float(line.split(":")[1].strip())
                except (ValueError, IndexError):
                    pass
            elif "Operation Mode:" in line:
                data["operation_mode"] = line.split(":")[1].strip()
            elif "Power Mode:" in line:
                data["power_mode"] = line.split(":")[1].strip()
                
        return data
    
    def get_sensor_data(self) -> Dict:
        """Получение данных с датчика BNO055"""
        if not self.is_available():
            return {
                "available": False,
                "error": "BNO055 sensor not available",
                "timestamp": time.time()
            }
        
        # Читаем данные с датчика
        sensor_data = self._read_sensor_data()
        
        if sensor_data is None:
            return {
                "available": False,
                "error": f"Failed to read BNO055 data (error count: {self.error_count})",
                "timestamp": time.time()
            }
        
        # Сбрасываем счетчик ошибок при успешном чтении
        if self.error_count > 0:
            self.error_count = 0
            
        self.last_reading = sensor_data
        self.last_update = time.time()
        
        return {
            "available": True,
            "data": sensor_data,
            "timestamp": time.time(),
            "error_count": self.error_count
        }
    
    def get_device_info(self) -> Dict:
        """Получение информации об устройстве BNO055"""
        return {
            "name": "BNO055",
            "type": "9-DOF IMU Sensor",
            "description": "Bosch BNO055 9-DOF IMU с fusion алгоритмом",
            "i2c_bus": 1,
            "i2c_address": "0x29",
            "driver_script": self.driver_script,
            "features": [
                "Euler angles (Heading, Roll, Pitch)",
                "Quaternions (W, X, Y, Z)",
                "Linear acceleration",
                "Gravity vector",
                "Accelerometer (X, Y, Z)",
                "Gyroscope (X, Y, Z)",
                "Magnetometer (X, Y, Z)",
                "Temperature",
                "Calibration status",
                "Fusion algorithm"
            ],
            "available": self.is_available(),
            "last_update": self.last_update,
            "error_count": self.error_count
        }
    
    def get_calibration_status(self) -> Dict:
        """Получение статуса калибровки"""
        if not self.is_available():
            return {
                "available": False,
                "error": "BNO055 sensor not available",
                "timestamp": time.time()
            }
        
        try:
            # Запускаем драйвер для получения статуса калибровки
            result = subprocess.run(
                [self.driver_script, "calibration"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                return {
                    "available": False,
                    "error": "Failed to get calibration status",
                    "timestamp": time.time()
                }
            
            # Парсим статус калибровки
            output = result.stdout.strip()
            calibration_data = {
                "system": 0,
                "gyro": 0,
                "accel": 0,
                "mag": 0,
                "timestamp": time.time()
            }
            
            lines = output.split('\n')
            for line in lines:
                line = line.strip()
                if "System:" in line:
                    try:
                        calibration_data["system"] = int(line.split(":")[1].strip())
                    except (ValueError, IndexError):
                        pass
                elif "Gyro:" in line:
                    try:
                        calibration_data["gyro"] = int(line.split(":")[1].strip())
                    except (ValueError, IndexError):
                        pass
                elif "Accel:" in line:
                    try:
                        calibration_data["accel"] = int(line.split(":")[1].strip())
                    except (ValueError, IndexError):
                        pass
                elif "Mag:" in line:
                    try:
                        calibration_data["mag"] = int(line.split(":")[1].strip())
                    except (ValueError, IndexError):
                        pass
            
            return {
                "available": True,
                "calibration": calibration_data,
                "timestamp": time.time()
            }
            
        except Exception as e:
            return {
                "available": False,
                "error": f"Calibration status error: {e}",
                "timestamp": time.time()
            }
    
    def get_operation_mode(self) -> Dict:
        """Получение режима работы"""
        if not self.is_available():
            return {
                "available": False,
                "error": "BNO055 sensor not available",
                "timestamp": time.time()
            }
        
        try:
            # Запускаем драйвер для получения режима работы
            result = subprocess.run(
                [self.driver_script, "mode"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                return {
                    "available": False,
                    "error": "Failed to get operation mode",
                    "timestamp": time.time()
                }
            
            # Парсим режим работы
            output = result.stdout.strip()
            mode_data = {
                "operation_mode": "unknown",
                "power_mode": "unknown",
                "timestamp": time.time()
            }
            
            lines = output.split('\n')
            for line in lines:
                line = line.strip()
                if "Operation Mode:" in line:
                    mode_data["operation_mode"] = line.split(":")[1].strip()
                elif "Power Mode:" in line:
                    mode_data["power_mode"] = line.split(":")[1].strip()
            
            return {
                "available": True,
                "mode": mode_data,
                "timestamp": time.time()
            }
            
        except Exception as e:
            return {
                "available": False,
                "error": f"Operation mode error: {e}",
                "timestamp": time.time()
            }

# Функция для тестирования
def test_bno055_monitor():
    """Тестирование монитора BNO055"""
    monitor = BNO055Monitor()
    
    print("=== BNO055 Monitor Test ===")
    print(f"Available: {monitor.is_available()}")
    print(f"Device Info: {monitor.get_device_info()}")
    
    if monitor.is_available():
        print(f"Sensor Data: {monitor.get_sensor_data()}")
        print(f"Calibration Status: {monitor.get_calibration_status()}")
        print(f"Operation Mode: {monitor.get_operation_mode()}")

if __name__ == "__main__":
    test_bno055_monitor()
