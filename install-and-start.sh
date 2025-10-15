#!/bin/bash
# Простая установка и запуск веб-мониторинга (одна команда)

set -e

echo "🚀 Установка и запуск веб-мониторинга Quantum-PCI..."
echo ""

# Установка всех необходимых пакетов
echo "📦 Установка пакетов..."
sudo apt install -y python3-pip python3-flask python3-eventlet python3-requests python3-yaml python3-psutil 2>&1

# Установка дополнительных модулей через pip3
echo ""
echo "📦 Установка Python модулей..."
pip3 install --user flask-socketio python-socketio flask-cors prometheus-client 2>&1

echo ""
echo "✅ Установка завершена!"
echo ""
echo "🌐 Запуск веб-сервера..."
echo ""

# Переход в директорию мониторинга
cd /home/shiwa-time/QuantumPCI-DRV/quantum-pci-monitoring

# Запуск мониторинга
python3 quantum-pci-monitor.py










