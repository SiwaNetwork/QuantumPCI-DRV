#!/usr/bin/env python3
# demo-real.py - Реальный мониторинг TimeCard с данными с устройства

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
    print("🚀 TimeCard PTP OCP Real Monitoring v2.0")
    print("="*80)
    
    # Проверяем наличие реального API
    real_api_path = api_path / 'timecard-real-api.py'
    
    if real_api_path.exists():
        print("✅ Real TimeCard API found - starting real hardware monitoring")
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
            spec = importlib.util.spec_from_file_location("timecard_real_api", str(real_api_path))
            timecard_real_api = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(timecard_real_api)
            
            print("📊 Real Dashboard: http://localhost:8080/dashboard")
            print("📱 Real PWA:      http://localhost:8080/pwa")
            print("🔧 Real API:      http://localhost:8080/api/")
            print("🏠 Main Page:     http://localhost:8080/")
            print("="*80)
            print("🎯 Starting real hardware monitoring...")
            
            # Запускаем сервер
            timecard_real_api.socketio.run(
                timecard_real_api.app, 
                host='0.0.0.0', 
                port=8080, 
                debug=False,
                allow_unsafe_werkzeug=True
            )
            
        except ImportError as e:
            print(f"❌ Error importing real API: {e}")
            fallback_to_demo()
        except Exception as e:
            print(f"❌ Error running real API: {e}")
            fallback_to_demo()
            
    else:
        print("❌ Real API not found!")
        fallback_to_demo()

def fallback_to_demo():
    """Fallback к демо версии"""
    print("="*80)
    print("🔄 Falling back to DEMO mode (simulated data)")
    print("="*80)
    print("📋 Demo Features Available:")
    print("   📊  Simulated PTP metrics")
    print("   🌡️  Simulated thermal data")
    print("   ⚡  Simulated power data")
    print("   🛰️  Simulated GNSS data")
    print("   🔌  WebSocket updates")
    print("   📱  Web interface")
    print("="*80)
    
    try:
        # Импортируем и запускаем демо приложение
        import importlib.util
        demo_api_path = api_path / 'timecard-extended-api.py'
        spec = importlib.util.spec_from_file_location("demo_api", str(demo_api_path))
        demo_api = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(demo_api)
        
        print("📊 Demo Dashboard:    http://localhost:8080/dashboard")
        print("🔧 Demo API:          http://localhost:8080/api/")
        print("🏠 Main Page:         http://localhost:8080/")
        print("="*80)
        print("🎯 Starting demo server...")
        
        # Запускаем демо сервер
        demo_api.socketio.run(
            demo_api.app, 
            host='0.0.0.0', 
            port=8080, 
            debug=False,
            allow_unsafe_werkzeug=True
        )
        
    except Exception as e:
        print(f"❌ Error running demo API: {e}")
        sys.exit(1)

def check_hardware():
    """Проверка наличия реального оборудования"""
    print("🔍 Checking for real TimeCard hardware...")
    
    # Проверка sysfs
    timecard_sysfs = "/sys/class/timecard"
    if os.path.exists(timecard_sysfs):
        devices = os.listdir(timecard_sysfs)
        if devices:
            print(f"✅ Found TimeCard devices in sysfs: {devices}")
            return True
        else:
            print("⚠️  TimeCard sysfs exists but no devices found")
    else:
        print("❌ TimeCard sysfs not found")
    
    # Проверка PTP устройств
    ptp_devices = []
    try:
        import glob
        ptp_devices = glob.glob("/dev/ptp*")
        if ptp_devices:
            print(f"✅ Found PTP devices: {ptp_devices}")
        else:
            print("❌ No PTP devices found")
    except Exception as e:
        print(f"❌ Error checking PTP devices: {e}")
    
    # Проверка драйвера
    try:
        result = os.system("lsmod | grep ptp_ocp > /dev/null 2>&1")
        if result == 0:
            print("✅ PTP OCP driver loaded")
        else:
            print("❌ PTP OCP driver not loaded")
    except Exception as e:
        print(f"❌ Error checking driver: {e}")
    
    return len(ptp_devices) > 0

if __name__ == '__main__':
    # Проверяем оборудование
    has_hardware = check_hardware()
    
    if has_hardware:
        print("🎉 Real TimeCard hardware detected!")
        main()
    else:
        print("⚠️  No real TimeCard hardware detected, using demo mode")
        fallback_to_demo() 