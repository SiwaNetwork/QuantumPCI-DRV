#!/bin/bash
# install-deps.sh - Установка зависимостей для веб-мониторинга

echo "============================================================================"
echo "📦 Установка зависимостей для Quantum-PCI Web Monitoring"
echo "============================================================================"

# Установка системных пакетов Python (требует sudo)
echo "🔧 Установка системных пакетов Python..."
sudo apt update
sudo apt install -y \
    python3-pip \
    python3-flask \
    python3-eventlet \
    python3-requests \
    python3-yaml \
    python3-psutil

# Установка дополнительных пакетов через pip
echo ""
echo "📦 Установка дополнительных пакетов через pip..."
pip3 install --user \
    flask-socketio \
    python-socketio \
    flask-cors \
    prometheus-client

echo ""
echo "============================================================================"
echo "✅ Установка завершена!"
echo "============================================================================"
echo ""
echo "Для запуска мониторинга выполните:"
echo "  cd /home/shiwa-time/QuantumPCI-DRV/quantum-pci-monitoring"
echo "  ./setup-and-run.sh"
echo ""









