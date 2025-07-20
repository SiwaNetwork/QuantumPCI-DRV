# PTP OCP Monitoring System

Комплексная система мониторинга для PTP OCP с веб-интерфейсами и API.

## 🚀 Быстрый старт

### Автоматическая установка

```bash
# Клонирование или копирование файлов
cd /workspace/ptp-monitoring

# Установка системы (требуются права root)
sudo bash scripts/install.sh
```

### Ручная установка

#### 1. Установка зависимостей

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv nginx

# Создание виртуального окружения
python3 -m venv venv
source venv/bin/activate

# Установка Python пакетов
pip install -r requirements.txt
```

#### 2. Запуск приложения

```bash
# Запуск API сервера
cd api
python app.py
```

## 📊 Доступные интерфейсы

После установки будут доступны следующие интерфейсы:

### 🖥️ Desktop Dashboard
- **URL**: `http://localhost:8080/dashboard`
- **Описание**: Полнофункциональный веб-интерфейс для мониторинга
- **Функции**:
  - Real-time метрики PTP
  - Управление сервисами (restart ptp4l, phc2sys)
  - Просмотр конфигурации
  - Экспорт логов
  - WebSocket для живых логов

### 📱 Mobile PWA
- **URL**: `http://localhost:8080/pwa`
- **Описание**: Мобильное прогрессивное веб-приложение
- **Функции**:
  - Адаптивный дизайн для мобильных устройств
  - Офлайн поддержка
  - Установка как нативное приложение
  - Push уведомления

### 🔧 API Endpoints
- **Base URL**: `http://localhost:8080/api/`
- **Endpoints**:
  - `GET /api/metrics` - Получение метрик PTP
  - `POST /api/restart/<service>` - Перезапуск сервиса
  - `GET /api/config` - Получение конфигурации
  - `GET /api/logs/export` - Экспорт логов

## 🔧 Конфигурация

### Структура проекта

```
ptp-monitoring/
├── api/
│   ├── app.py              # Основное приложение
│   └── ptp-api.py          # API модуль
├── web/
│   └── dashboard.html      # Desktop dashboard
├── pwa/
│   ├── index.html          # PWA приложение
│   ├── manifest.json       # PWA манифест
│   └── sw.js              # Service Worker
├── config/
│   └── grafana-dashboard.json
├── scripts/
│   └── install.sh          # Скрипт установки
├── requirements.txt        # Python зависимости
└── README.md
```

### Конфигурация nginx

Система автоматически настраивает nginx для проксирования запросов:

```nginx
server {
    listen 80;
    server_name localhost;
    
    location / {
        proxy_pass http://localhost:8080;
        # WebSocket поддержка
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 📈 Интеграция с Grafana

### Установка Grafana

```bash
# Ubuntu/Debian
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt-get update
sudo apt-get install grafana

# Запуск
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

### Импорт Dashboard

1. Откройте Grafana: `http://localhost:3000`
2. Войдите (admin/admin)
3. Импортируйте dashboard из `config/grafana-dashboard.json`

## 📊 Интеграция с Prometheus

### Установка Prometheus

```bash
# Скачивание Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
tar xzf prometheus-2.40.0.linux-amd64.tar.gz
sudo cp prometheus-2.40.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.40.0.linux-amd64/promtool /usr/local/bin/

# Создание конфигурации
sudo mkdir -p /etc/prometheus
sudo tee /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'ptp-custom'
    static_configs:
      - targets: ['localhost:8080']
EOF
```

### Node Exporter с Textfile Collector

```bash
# Установка Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
tar xzf node_exporter-1.6.0.linux-amd64.tar.gz
sudo cp node_exporter-1.6.0.linux-amd64/node_exporter /usr/local/bin/

# Systemd сервис
sudo tee /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/node_exporter \\
  --collector.textfile.directory=/var/lib/prometheus/node-exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

## 🔐 Безопасность

### Настройка HTTPS (опционально)

```bash
# Установка certbot
sudo apt-get install certbot python3-certbot-nginx

# Получение сертификата
sudo certbot --nginx -d your-domain.com

# Автообновление
sudo crontab -e
# Добавить: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Аутентификация

Для production среды рекомендуется добавить аутентификацию:

```nginx
# В конфигурацию nginx
auth_basic "PTP Monitor";
auth_basic_user_file /etc/nginx/.htpasswd;
```

## 🐛 Диагностика

### Проверка статуса

```bash
# Статус основного сервиса
sudo systemctl status ptp-monitoring

# Логи приложения
sudo journalctl -u ptp-monitoring -f

# Проверка портов
sudo netstat -tlnp | grep :8080
```

### Тестирование API

```bash
# Проверка метрик
curl http://localhost:8080/api/metrics

# Проверка конфигурации
curl http://localhost:8080/api/config

# Тест WebSocket (требует wscat)
wscat -c ws://localhost:8080/socket.io/?EIO=4&transport=websocket
```

### Общие проблемы

1. **Порт 8080 занят**
   ```bash
   sudo lsof -i :8080
   # Измените порт в app.py
   ```

2. **Ошибки прав доступа**
   ```bash
   sudo chown -R www-data:www-data /opt/ptp-monitoring
   ```

3. **Проблемы с WebSocket**
   ```bash
   # Проверьте nginx конфигурацию
   sudo nginx -t
   sudo systemctl reload nginx
   ```

## 🔄 Обновление

```bash
# Остановка сервиса
sudo systemctl stop ptp-monitoring

# Обновление файлов
cd /opt/ptp-monitoring
sudo cp -r /workspace/ptp-monitoring/* .

# Перезапуск
sudo systemctl start ptp-monitoring
```

## 📝 Лицензия

Этот проект создан для мониторинга PTP OCP систем и распространяется под MIT лицензией.

## 🤝 Поддержка

Для получения поддержки:
1. Проверьте логи: `sudo journalctl -u ptp-monitoring -f`
2. Убедитесь, что все зависимости установлены
3. Проверьте статус сервисов: `systemctl status ptp-monitoring`

---

**Версия**: 1.0.0  
**Последнее обновление**: $(date +%Y-%m-%d)