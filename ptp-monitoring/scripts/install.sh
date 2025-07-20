#!/bin/bash
# install.sh - Установка PTP Monitoring System

set -e

echo "=================================================="
echo "🚀 PTP Monitoring System Installation"
echo "=================================================="

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Этот скрипт должен запускаться с правами root (sudo)"
   exit 1
fi

# Получаем домашнюю директорию пользователя
USER_HOME=$(eval echo ~${SUDO_USER})
INSTALL_DIR="/opt/ptp-monitoring"

echo "📦 Установка системных зависимостей..."

# Обновление пакетов
apt-get update

# Установка Python и pip
apt-get install -y python3 python3-pip python3-venv

# Установка Node.js для дополнительных инструментов (опционально)
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

echo "🐍 Создание Python виртуального окружения..."

# Создание директории установки
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Копирование файлов приложения
cp -r /workspace/ptp-monitoring/* .

# Создание виртуального окружения
python3 -m venv venv
source venv/bin/activate

# Установка Python зависимостей
pip install -r requirements.txt

echo "🔧 Настройка системных сервисов..."

# Создание systemd сервиса для PTP API
cat > /etc/systemd/system/ptp-monitoring.service << EOF
[Unit]
Description=PTP Monitoring API Server
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python api/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Создание пользователя prometheus если не существует
if ! id "prometheus" &>/dev/null; then
    useradd --system --shell /bin/false prometheus
fi

# Создание директории для метрик
mkdir -p /var/lib/prometheus/node-exporter
chown prometheus:prometheus /var/lib/prometheus/node-exporter
chmod 755 /var/lib/prometheus/node-exporter

# Создание тестового файла метрик
cat > /var/lib/prometheus/node-exporter/ptp.prom << EOF
# HELP ptp_offset_ns PTP offset in nanoseconds
ptp_offset_ns 150
# HELP ptp_frequency_adjustment PTP frequency adjustment in ppb
ptp_frequency_adjustment -45
# HELP ptp_driver_status PTP driver status (1=OK, 0=ERROR)
ptp_driver_status 1
# HELP ptp_port_state PTP port state
ptp_port_state 8
# HELP ptp_path_delay_ns PTP path delay in nanoseconds
ptp_path_delay_ns 2500
EOF

chown prometheus:prometheus /var/lib/prometheus/node-exporter/ptp.prom

echo "🌐 Настройка nginx (опционально)..."

# Установка nginx если не установлен
if ! command -v nginx &> /dev/null; then
    apt-get install -y nginx
fi

# Создание конфигурации nginx для PWA
cat > /etc/nginx/sites-available/ptp-monitor << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    # Главная страница и API на порту 8080
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # WebSocket соединения
    location /socket.io/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# Активация конфигурации nginx
if [ ! -L /etc/nginx/sites-enabled/ptp-monitor ]; then
    ln -s /etc/nginx/sites-available/ptp-monitor /etc/nginx/sites-enabled/
fi

# Перезагрузка nginx
systemctl reload nginx

echo "🔄 Запуск сервисов..."

# Активация и запуск PTP Monitoring сервиса
systemctl daemon-reload
systemctl enable ptp-monitoring.service
systemctl start ptp-monitoring.service

echo "✅ Установка завершена!"
echo "=================================================="
echo "🎉 PTP Monitoring System готов к использованию!"
echo "=================================================="
echo "📊 Desktop Dashboard: http://localhost/dashboard"
echo "📱 Mobile PWA:        http://localhost/pwa"
echo "🔧 API Endpoints:     http://localhost/api/"
echo "🏠 Main Page:         http://localhost/"
echo ""
echo "Прямой доступ (без nginx):"
echo "📊 Desktop Dashboard: http://localhost:8080/dashboard"
echo "📱 Mobile PWA:        http://localhost:8080/pwa"
echo "=================================================="
echo ""
echo "🔍 Проверка статуса:"
echo "systemctl status ptp-monitoring"
echo ""
echo "📋 Просмотр логов:"
echo "journalctl -u ptp-monitoring -f"
echo "=================================================="