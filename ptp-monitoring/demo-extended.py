#!/usr/bin/env python3
"""
Quantum-PCI TimeCard PTP OCP Extended Demo v2.0
"""

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
    print("🚀 Starting Quantum-PCI TimeCard PTP OCP Extended Demo v2.0")
    print("="*80)
    
    # Проверяем наличие расширенного API
    extended_api_path = api_path / 'timecard-extended-api.py'
    basic_api_path = api_path / 'app.py'
    
    if extended_api_path.exists():
        print("✅ Extended TimeCard API found - starting full monitoring system")
        print("="*80)
        print("🔧 Available Features:")
        print("   🌡️  Complete thermal monitoring (FPGA, oscillator, board, DDR, PLL)")
        print("   ⚡  Power consumption analysis (4 voltage rails + currents)")
        print("   🛰️  GNSS constellation tracking (GPS+GLONASS+Galileo+BeiDou)")
        print("   ⚡  Oscillator disciplining with Allan deviation analysis")
        print("   📡  Advanced PTP metrics with packet statistics")
        print("   🔧  Hardware monitoring (LEDs, SMA connectors, FPGA, PHY)")
        print("   🚨  Intelligent alerting system with configurable thresholds")
        print("   📊  Health scoring with comprehensive system assessment")
        print("   📈  Historical data storage & trending analysis")
        print("   🔌  WebSocket real-time updates")
        print("="*80)
        
        # Запускаем расширенный API напрямую
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("timecard_api", extended_api_path)
            timecard_api = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(timecard_api)
            
            print("📊 Extended Dashboard: http://localhost:8080/dashboard")
            print("📱 Mobile PWA:         http://localhost:8080/pwa")
            print("🔧 Extended API:       http://localhost:8080/api/")
            print("🏠 Main Page:          http://localhost:8080/")
            print("="*80)
            print("🎯 Starting server...")
            
            # Запускаем сервер
            timecard_api.socketio.run(
                timecard_api.app, 
                host='0.0.0.0', 
                port=8080, 
                debug=False,
                allow_unsafe_werkzeug=True
            )
            
        except ImportError as e:
            print(f"❌ Error importing extended API: {e}")
            fallback_to_basic()
        except Exception as e:
            print(f"❌ Error running extended API: {e}")
            fallback_to_basic()
            
    elif basic_api_path.exists():
        print("⚠️  Extended API not found - falling back to basic mode")
        fallback_to_basic()
    else:
        print("❌ No API files found!")
        sys.exit(1)

def fallback_to_basic():
    """Fallback к базовому API"""
    print("="*80)
    print("🔄 Starting in BASIC mode")
    print("="*80)
    print("📋 Basic Features Available:")
    print("   📊  Basic PTP metrics")
    print("   🔌  WebSocket updates")
    print("   📱  Web interface")
    print("="*80)
    
    try:
        # Импортируем и запускаем основное приложение
        import importlib.util
        api_path = Path(__file__).parent / 'api' / 'app.py'
        spec = importlib.util.spec_from_file_location("main_app", api_path)
        main_app = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(main_app)
        
        print("📊 Basic Dashboard:    http://localhost:8080/dashboard")
        print("🔧 Basic API:          http://localhost:8080/api/")
        print("🏠 Main Page:          http://localhost:8080/")
        print("="*80)
        print("🎯 Starting basic server...")
        
        # Запускаем сервер
        main_app.socketio.run(
            main_app.app, 
            host='0.0.0.0', 
            port=8080, 
            debug=False,
            allow_unsafe_werkzeug=True
        )
        
    except Exception as e:
        print(f"❌ Error running basic API: {e}")
        sys.exit(1)

def install_dependencies():
    """Установка зависимостей"""
    print("🔧 Installing dependencies...")
    try:
        import subprocess
        result = subprocess.run([
            sys.executable, '-m', 'pip', 'install', '-r', 'requirements.txt'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Dependencies installed successfully")
        else:
            print(f"⚠️ Warning installing dependencies: {result.stderr}")
            
    except Exception as e:
        print(f"⚠️ Could not install dependencies: {e}")

def check_dependencies():
    """Проверка зависимостей"""
    required_packages = [
        'flask',
        'flask_socketio', 
        'flask_cors'
    ]
    
    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        print(f"⚠️ Missing packages: {', '.join(missing_packages)}")
        print("🔧 Attempting to install...")
        install_dependencies()
        return False
    
    return True

if __name__ == '__main__':
    try:
        # Проверяем зависимости
        if not check_dependencies():
            print("🔄 Restarting after dependency installation...")
            time.sleep(2)
        
        # Запускаем main
        main()
        
    except KeyboardInterrupt:
        print("\n👋 Shutting down TimeCard monitoring system...")
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        print("🛠️ Try running: pip install -r requirements.txt")
        sys.exit(1)