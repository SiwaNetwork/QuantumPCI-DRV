#!/usr/bin/env python3
"""
Тест для проверки quantum-pci-monitor.py
"""

import sys
import os
import importlib.util
from pathlib import Path

def test_import():
    """Тест импорта основного модуля"""
    try:
        # Добавляем путь к API модулям
        api_path = Path(__file__).parent / 'api'
        sys.path.insert(0, str(api_path))
        
        # Проверяем импорт API модуля
        realistic_api_path = api_path / 'quantum-pci-realistic-api.py'
        
        if realistic_api_path.exists():
            print("✅ quantum-pci-realistic-api.py найден")
            
            # Пробуем импортировать
            spec = importlib.util.spec_from_file_location("quantum_pci_realistic_api", str(realistic_api_path))
            quantum_pci_api = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(quantum_pci_api)
            
            print("✅ API модуль успешно импортирован")
            
            # Проверяем наличие необходимых компонентов
            if hasattr(quantum_pci_api, 'app'):
                print("✅ Flask app найден")
            else:
                print("❌ Flask app не найден")
                return False
                
            if hasattr(quantum_pci_api, 'socketio'):
                print("✅ SocketIO найден")
            else:
                print("❌ SocketIO не найден")
                return False
                
            # Проверяем конфигурацию
            if hasattr(quantum_pci_api, 'CONFIG'):
                config = quantum_pci_api.CONFIG
                print(f"✅ Конфигурация загружена: версия {config.get('version', 'N/A')}")
            else:
                print("❌ Конфигурация не найдена")
                return False
                
            return True
            
        else:
            print("❌ quantum-pci-realistic-api.py не найден")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка импорта: {e}")
        return False

def test_dependencies():
    """Тест зависимостей"""
    required_modules = [
        'flask',
        'flask_socketio', 
        'flask_cors',
        'subprocess',
        'threading',
        'pathlib'
    ]
    
    missing_modules = []
    
    for module in required_modules:
        try:
            __import__(module)
            print(f"✅ {module} доступен")
        except ImportError:
            print(f"❌ {module} не найден")
            missing_modules.append(module)
    
    return len(missing_modules) == 0

def test_files():
    """Тест наличия необходимых файлов"""
    required_files = [
        'quantum-pci-monitor.py',
        'api/quantum-pci-realistic-api.py',
        'api/realistic-dashboard.html',
        'requirements.txt'
    ]
    
    missing_files = []
    
    for file_path in required_files:
        full_path = Path(__file__).parent / file_path
        if full_path.exists():
            print(f"✅ {file_path} найден")
        else:
            print(f"❌ {file_path} не найден")
            missing_files.append(file_path)
    
    return len(missing_files) == 0

def main():
    """Основная функция тестирования"""
    print("="*60)
    print("🧪 Тестирование Quantum-PCI Monitor")
    print("="*60)
    
    tests = [
        ("Проверка файлов", test_files),
        ("Проверка зависимостей", test_dependencies),
        ("Проверка импорта", test_import)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n📋 {test_name}:")
        print("-" * 40)
        
        try:
            result = test_func()
            if result:
                print(f"✅ {test_name}: ПРОЙДЕН")
                passed += 1
            else:
                print(f"❌ {test_name}: ПРОВАЛЕН")
        except Exception as e:
            print(f"❌ {test_name}: ОШИБКА - {e}")
    
    print("\n" + "="*60)
    print(f"📊 Результат: {passed}/{total} тестов пройдено")
    
    if passed == total:
        print("🎉 Все тесты пройдены! Система готова к запуску.")
        return True
    else:
        print("⚠️  Некоторые тесты провалены. Проверьте установку.")
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
