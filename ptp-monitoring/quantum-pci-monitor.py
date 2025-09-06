#!/usr/bin/env python3
# quantum-pci-monitor.py - Мониторинг Quantum-PCI с реальными данными с устройства

import os
import sys
import time
import threading
from pathlib import Path

# Добавляем путь к API модулям
api_path = Path(__file__).parent / 'api'
sys.path.insert(0, str(api_path))

def main():
    print("="*80)
    print("🚀 Quantum-PCI Real Monitoring v2.0")
    print("="*80)
    
    # Проверяем наличие реалистичного API
    realistic_api_path = api_path / 'quantum-pci-realistic-api.py'
    
    if realistic_api_path.exists():
        print("✅ Realistic Quantum-PCI API found - starting realistic hardware monitoring")
        print("="*80)
        print("⚠️  ВНИМАНИЕ: Мониторинг ограничен возможностями ptp_ocp драйвера")
        print("")
        print("✅ ДОСТУПНЫЕ функции:")
        print("   📊  PTP offset/drift из sysfs")
        print("   🛰️  Базовый GNSS статус")
        print("   🔌  SMA конфигурация")
        print("   📋  Информация об устройстве")
        print("")
        print("❌ НЕ ДОСТУПНЫЕ функции:")
        print("   🌡️  Детальный мониторинг температуры")
        print("   ⚡  Мониторинг питания")
        print("   🛰️  Детальный GNSS (спутники)")
        print("   🔧  Состояние LED/FPGA")
        print("="*80)
        
        # Запускаем реалистичный API
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("quantum_pci_realistic_api", str(realistic_api_path))
            quantum_pci_api = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(quantum_pci_api)
            
            print("📊 Realistic Dashboard: http://localhost:8080/dashboard")
            print("🔧 Realistic API:       http://localhost:8080/api/")
            print("🗺️  Roadmap:            http://localhost:8080/api/roadmap")
            print("🏠 Main Page:           http://localhost:8080/")
            print("="*80)
            print("🎯 Starting realistic hardware monitoring...")
            
            # Запускаем сервер
            quantum_pci_api.socketio.run(
                quantum_pci_api.app, 
                host='0.0.0.0', 
                port=8080, 
                debug=False,
                allow_unsafe_werkzeug=True
            )
            
        except ImportError as e:
            print(f"❌ Error importing Quantum-PCI API: {e}")
            print("❌ Please install required dependencies: pip install -r requirements.txt")
            sys.exit(1)
        except Exception as e:
            print(f"❌ Error running Quantum-PCI API: {e}")
            sys.exit(1)
            
    else:
        print("❌ Realistic Quantum-PCI API not found!")
        print("❌ Please ensure the API file exists at: api/quantum-pci-realistic-api.py")
        print("💡 Run this to create it: check the repository for the realistic API file")
        sys.exit(1)


if __name__ == '__main__':
    main() 