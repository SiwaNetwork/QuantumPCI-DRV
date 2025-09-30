#!/usr/bin/env python3
"""
INA219 Filter - Фильтрация ложных значений для датчика INA219 #1 (3.3V)
"""

import json
import time
import statistics
from collections import deque

class INA219Filter:
    def __init__(self, window_size=5, valid_range=(2.5, 4.0)):
        """
        Инициализация фильтра
        
        Args:
            window_size: Размер окна для скользящего среднего
            valid_range: Валидный диапазон напряжений (min, max)
        """
        self.window_size = window_size
        self.valid_range = valid_range
        self.voltage_history = deque(maxlen=window_size)
        self.last_valid_voltage = 3.3  # Начальное значение
        
    def is_valid_voltage(self, voltage):
        """Проверка, находится ли напряжение в валидном диапазоне"""
        return self.valid_range[0] <= voltage <= self.valid_range[1]
    
    def filter_voltage(self, voltage, raw_value):
        """
        Фильтрация напряжения
        
        Args:
            voltage: Измеренное напряжение
            raw_value: Сырое значение с датчика
            
        Returns:
            tuple: (filtered_voltage, is_valid, reason)
        """
        # Проверка валидности
        if not self.is_valid_voltage(voltage):
            reason = f"Вне диапазона {self.valid_range[0]}-{self.valid_range[1]}V"
            return self.last_valid_voltage, False, reason
        
        # Добавляем в историю
        self.voltage_history.append(voltage)
        
        # Если недостаточно данных для фильтрации
        if len(self.voltage_history) < 3:
            self.last_valid_voltage = voltage
            return voltage, True, "Недостаточно данных для фильтрации"
        
        # Проверка на выбросы (отклонение от медианы)
        median_voltage = statistics.median(self.voltage_history)
        deviation = abs(voltage - median_voltage)
        
        # Если отклонение слишком большое (>0.5V)
        if deviation > 0.5:
            reason = f"Выброс: отклонение {deviation:.3f}V от медианы {median_voltage:.3f}V"
            return self.last_valid_voltage, False, reason
        
        # Вычисляем скользящее среднее
        filtered_voltage = statistics.mean(self.voltage_history)
        self.last_valid_voltage = filtered_voltage
        
        return filtered_voltage, True, "OK"

def test_ina219_filter():
    """Тест фильтра с реальными данными"""
    filter_3v3 = INA219Filter(window_size=5, valid_range=(2.5, 4.0))
    
    print("=== Тест фильтра INA219 #1 (3.3V) ===")
    print("Валидный диапазон: 2.5V - 4.0V")
    print("Размер окна: 5 измерений")
    print()
    
    # Тестовые данные (включая ложные значения)
    test_data = [
        (3.3, 2586, "Нормальное"),
        (3.3, 2586, "Нормальное"),
        (0.268, 538, "Ложное - слишком низкое"),
        (32.012, 64025, "Ложное - слишком высокое"),
        (3.3, 2586, "Нормальное"),
        (0.268, 538, "Ложное - слишком низкое"),
        (3.3, 2586, "Нормальное"),
        (3.2, 2500, "Нормальное"),
        (3.4, 2700, "Нормальное"),
        (0.268, 538, "Ложное - слишком низкое"),
    ]
    
    for i, (voltage, raw, description) in enumerate(test_data, 1):
        filtered_voltage, is_valid, reason = filter_3v3.filter_voltage(voltage, raw)
        
        status = "✅ ВАЛИДНО" if is_valid else "❌ ОТФИЛЬТРОВАНО"
        
        print(f"Измерение {i:2d}: {voltage:6.3f}V (raw: {raw:5d}) -> {filtered_voltage:6.3f}V | {status}")
        print(f"           {description} | {reason}")
        print()

if __name__ == "__main__":
    test_ina219_filter()
