#!/usr/bin/env python3

import subprocess

def debug_i2c():
    print("=== Отладка I2C ===")
    
    # Запуск i2cdetect с sudo
    result = subprocess.run(['sudo', 'i2cdetect', '-y', '1'], capture_output=True, text=True)
    print("Вывод i2cdetect:")
    print(result.stdout)
    
    # Проверка поиска адреса
    print(f"Поиск '37' в выводе: {'37' in result.stdout}")
    print(f"Поиск '0x37' в выводе: {'0x37' in result.stdout}")
    
    # Проверка каждой строки
    for i, line in enumerate(result.stdout.split('\n')):
        if '37' in line:
            print(f"Строка {i}: '{line}'")

if __name__ == "__main__":
    debug_i2c() 