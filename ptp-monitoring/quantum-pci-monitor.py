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
    
    # Проверяем наличие реального API
    real_api_path = api_path / 'quantum-pci-api.py'
    
    if real_api_path.exists():
        print("✅ Real Quantum-PCI API found - starting real hardware monitoring")
        print("="*80)
        print("🔧 Real Hardware Features:")
        print("   🌡️  Real thermal sensors from sysfs/hwmon")
        print("   ⚡  Real power monitoring from device registers")
        print("   🛰️  Real GNSS status from device interface")
        print("   ⚡  Real PTP metrics from ptp4l")
        print("   📡  Real hardware status from sysfs")
        print("   🔧  Direct device communication")
        print("   📊  Real-time data from actual TimeCard")
        print("   🚨  Real alerting based on actual thresholds")
        print("   📈  Real historical data from device")
        print("   🔌  Real WebSocket updates from hardware")
        print("="*80)
        
        # Запускаем реальный API
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("quantum_pci_api", str(real_api_path))
            quantum_pci_api = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(quantum_pci_api)
            
            print("📊 Real Dashboard: http://localhost:8080/dashboard")
            print("📱 Real PWA:      http://localhost:8080/pwa")
            print("🔧 Real API:      http://localhost:8080/api/")
            print("🏠 Main Page:     http://localhost:8080/")
            print("="*80)
            print("🎯 Starting real hardware monitoring...")
            
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
        print("❌ Quantum-PCI API not found!")
        print("❌ Please ensure the API file exists at: api/quantum-pci-api.py")
        sys.exit(1)


if __name__ == '__main__':
    main() 