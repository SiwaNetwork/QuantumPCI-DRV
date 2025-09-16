#!/usr/bin/env python3
"""
PCT2075TP Temperature Monitor
Мониторинг датчика температуры PCT2075TP через I2C
"""

import subprocess
import time
import json
from typing import Dict, Optional, Any

class PCT2075Monitor:
    """
    Мониторинг датчика температуры PCT2075TP
    """
    
    def __init__(self):
        self.i2c_bus = 1
        self.device_address = '48'  # PCT2075TP на адресе 0x48
        self.last_reading = None
        self.last_update = None
        self.error_count = 0
        self.max_errors = 5
        
    def is_available(self) -> bool:
        """Проверка доступности PCT2075TP"""
        try:
            result = subprocess.run(
                ['i2cget', '-y', str(self.i2c_bus), f'0x{self.device_address}', '0x00', 'w'],
                capture_output=True, text=True, timeout=5
            )
            return result.returncode == 0
        except Exception:
            return False
    
    def _read_i2c_register(self, register: str) -> Optional[int]:
        """Чтение регистра I2C"""
        try:
            result = subprocess.run(
                ['i2cget', '-y', str(self.i2c_bus), f'0x{self.device_address}', register, 'w'],
                capture_output=True, text=True, timeout=5
            )
            
            if result.returncode == 0:
                # Убираем 0x и преобразуем в int
                hex_value = result.stdout.strip()
                return int(hex_value, 16)
            else:
                print(f"❌ Ошибка чтения I2C {self.device_address}:{register} - {result.stderr}")
                return None
                
        except Exception as e:
            print(f"❌ Ошибка чтения I2C {self.device_address}:{register} - {e}")
            return None
    
    def _calculate_temperature(self, raw_value: int) -> float:
        """Расчет температуры по raw значению согласно техническому описанию PCT2075TP"""
        # PCT2075TP использует 11-битное значение с разрешением 0.125°C
        # Биты 15-3: температура (11 бит)
        # Биты 2-0: не используются
        
        # Извлекаем 11-битное значение температуры
        temp_bits = (raw_value >> 3) & 0x7FF
        
        # Проверяем знаковый бит (бит 10)
        sign_bit = (temp_bits >> 10) & 1
        
        if sign_bit == 0:
            # Положительная температура
            temperature = temp_bits * 0.125
        else:
            # Отрицательная температура (дополнительный код)
            temperature = -((~temp_bits & 0x7FF) + 1) * 0.125
        
        # Проверяем, что температура в разумных пределах для комнатной температуры
        # PCT2075TP должен показывать температуру в диапазоне 15-35°C в нормальных условиях
        if 15 <= temperature <= 35:
            return temperature
        elif -10 <= temperature <= 50:
            # Расширенный диапазон для экстремальных условий
            return temperature
        else:
            # Если температура нереальная, возвращаем ошибку
            return float('nan')
    
    def _is_temperature_realistic(self, temperature: float) -> bool:
        """Проверка, что температура в разумных пределах"""
        return -50 <= temperature <= 100
    
    def get_temperature_data(self) -> Dict[str, Any]:
        """Получение данных температуры с PCT2075TP"""
        if not self.is_available():
            return {
                'available': False,
                'error': 'PCT2075TP недоступен'
            }
        
        try:
            # Читаем регистр температуры (0x00)
            raw_temp = self._read_i2c_register('0x00')
            if raw_temp is None:
                self.error_count += 1
                return {
                    'available': False,
                    'error': f'Ошибка чтения температуры (попытка {self.error_count})'
                }
            
            # Читаем регистр конфигурации (0x01)
            raw_config = self._read_i2c_register('0x01')
            
            # Читаем регистр Thyst (0x02)
            raw_thyst = self._read_i2c_register('0x02')
            
            # Читаем регистр Tos (0x03)
            raw_tos = self._read_i2c_register('0x03')
            
            # Рассчитываем температуру
            temperature = self._calculate_temperature(raw_temp)
            
            # Проверяем, что температура в разумных пределах
            if not self._is_temperature_realistic(temperature):
                self.error_count += 1
                return {
                    'available': False,
                    'error': f'Нереальная температура: {temperature:.1f}°C (raw: {raw_temp})',
                    'error_count': self.error_count,
                    'raw_analysis': {
                        'raw_value': raw_temp,
                        'hex_value': f'0x{raw_temp:04x}',
                        'temp_bits': (raw_temp >> 3) & 0x7FF,
                        'sign_bit': ((raw_temp >> 3) & 0x7FF) >> 10 & 1,
                        'calculated_temp': temperature
                    },
                    'diagnosis': {
                        'status': 'SENSOR_FAULT',
                        'possible_causes': [
                            'Неисправность датчика PCT2075TP',
                            'Проблема с подключением I2C',
                            'Проблемы с питанием датчика (3.3V)',
                            'Электромагнитные помехи',
                            'Неправильный адрес I2C'
                        ],
                        'suggestions': [
                            'Заменить датчик PCT2075TP',
                            'Проверить подключение I2C шины (SDA/SCL)',
                            'Проверить питание датчика',
                            'Проверить отсутствие коротких замыканий',
                            'Попробовать другой адрес I2C (0x49)'
                        ],
                        'note': 'PCT2075TP показывает нестабильные нереальные значения. Датчик требует замены.'
                    }
                }
            
            # Сбрасываем счетчик ошибок при успешном чтении
            self.error_count = 0
            
            # Сохраняем последнее чтение
            self.last_reading = {
                'temperature': temperature,
                'raw_temp': raw_temp,
                'raw_config': raw_config,
                'raw_thyst': raw_thyst,
                'raw_tos': raw_tos,
                'timestamp': time.time()
            }
            self.last_update = time.time()
            
            return {
                'available': True,
                'device': {
                    'name': 'PCT2075TP',
                    'address': f'0x{self.device_address}',
                    'description': 'Датчик температуры с разрешением 0.125°C (11-bit)'
                },
                'temperature': {
                    'value': round(temperature, 3),
                    'unit': '°C',
                    'raw': raw_temp,
                    'formula': 'raw * 0.125°C (11-bit, two\'s complement)'
                },
                'configuration': {
                    'raw': raw_config,
                    'description': 'Регистр конфигурации'
                },
                'thresholds': {
                    'thyst': {
                        'raw': raw_thyst,
                        'description': 'Порог гистерезиса'
                    },
                    'tos': {
                        'raw': raw_tos,
                        'description': 'Порог перегрева'
                    }
                },
                'status': {
                    'stable': self._is_temperature_realistic(temperature),
                    'error_count': self.error_count,
                    'last_update': self.last_update
                },
                'timestamp': time.time()
            }
            
        except Exception as e:
            self.error_count += 1
            return {
                'available': False,
                'error': f'Ошибка чтения PCT2075TP: {e}',
                'error_count': self.error_count
            }
    
    def get_device_info(self) -> Dict[str, Any]:
        """Получение информации об устройстве"""
        return {
            'name': 'PCT2075TP Temperature Monitor',
            'version': '1.0.0',
            'description': 'Мониторинг температуры через PCT2075TP датчик',
            'i2c_bus': self.i2c_bus,
            'device_address': f'0x{self.device_address}',
            'specifications': {
                'temperature_range': '-55°C to +125°C',
                'accuracy': '±1°C (-25°C to +100°C)',
                'resolution': '0.125°C',
                'format': '11-bit two\'s complement'
            },
            'registers': {
                '0x00': 'Temperature register (read-only)',
                '0x01': 'Configuration register',
                '0x02': 'Thyst register (hysteresis)',
                '0x03': 'Tos register (overtemperature)',
                '0x04': 'Tidle register (conversion time)'
            },
            'formula': {
                'positive': 'Temp = +(raw) × 0.125°C (if D10=0)',
                'negative': 'Temp = -(two\'s complement of raw) × 0.125°C (if D10=1)'
            }
        }

def main():
    """Тестирование модуля PCT2075TP"""
    print("=== Тестирование PCT2075TP Monitor ===")
    
    monitor = PCT2075Monitor()
    
    print(f"Доступность: {monitor.is_available()}")
    print()
    
    print("=== Информация об устройстве ===")
    info = monitor.get_device_info()
    print(json.dumps(info, indent=2, ensure_ascii=False))
    print()
    
    print("=== Данные температуры ===")
    data = monitor.get_temperature_data()
    print(json.dumps(data, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
