# Руководство по GUI

## Обзор

Данный документ описывает графические интерфейсы и веб-интерфейсы для управления и мониторинга PTP OCP системы.

## Web-based мониторинг

### Grafana Dashboard

#### Установка и настройка

```bash
# Установка Grafana
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt-get update
sudo apt-get install grafana

# Запуск Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

#### Настройка Data Source

1. Откройте веб-интерфейс: http://localhost:3000
2. Войдите с данными admin/admin
3. Перейдите в Configuration → Data Sources
4. Добавьте Prometheus data source:
   - URL: http://localhost:9090
   - Access: Server (Default)

#### Импорт PTP Dashboard

```json
{
  "dashboard": {
    "title": "PTP OCP Monitoring",
    "panels": [
      {
        "title": "PTP Offset",
        "type": "graph",
        "targets": [{"expr": "ptp_offset_ns"}],
        "yAxes": [{"unit": "ns"}]
      },
      {
        "title": "Frequency Adjustment", 
        "type": "graph",
        "targets": [{"expr": "ptp_frequency_adjustment"}],
        "yAxes": [{"unit": "ppb"}]
      }
    ]
  }
}
```

#### Основные панели мониторинга

**Панель 1: PTP Offset**
- Метрика: `ptp_offset_ns`
- Тип: Time series
- Единица: наносекунды
- Пороги: Зеленый < 1000ns, Желтый < 10000ns, Красный > 10000ns

**Панель 2: Port State**
- Метрика: `ptp_port_state`
- Тип: Stat
- Маппинг: 8=SLAVE, 5=MASTER, 7=UNCALIBRATED

**Панель 3: Driver Status**
- Метрика: `ptp_driver_status`
- Тип: Stat
- Маппинг: 1=OK, 0=ERROR

### Prometheus Web UI

#### Доступ к интерфейсу

URL: http://localhost:9090

#### Основные запросы

```promql
# Текущий offset
ptp_offset_ns

# История offset за последний час
ptp_offset_ns[1h]

# Средний offset за 5 минут
avg_over_time(ptp_offset_ns[5m])

# Частота превышения порога 1ms
rate(ptp_offset_ns > 1000000)[5m]

# Состояние драйвера
ptp_driver_status

# Информация об устройствах
ptp_device_info
```

#### Создание алертов

```yaml
groups:
  - name: ptp_alerts
    rules:
      - alert: PTPHighOffset
        expr: abs(ptp_offset_ns) > 1000000
        for: 1m
        annotations:
          summary: "PTP offset превышает 1ms"
```

## Chrony Web Interface

### Установка Chrony Exporter

```bash
# Установка chrony_exporter
wget https://github.com/SuperQ/chrony_exporter/releases/download/v0.4.0/chrony_exporter-0.4.0.linux-amd64.tar.gz
tar xzf chrony_exporter-0.4.0.linux-amd64.tar.gz
sudo cp chrony_exporter-0.4.0.linux-amd64/chrony_exporter /usr/local/bin/

# Создание systemd сервиса
sudo tee /etc/systemd/system/chrony-exporter.service << 'EOF'
[Unit]
Description=Chrony Exporter
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/chrony_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable chrony-exporter.service
sudo systemctl start chrony-exporter.service
```

### Метрики Chrony

```promql
# Offset источников времени
chrony_sources_offset_seconds

# Stratum источников
chrony_sources_stratum

# Reachability
chrony_sources_reachability_ratio

# Системное время tracking
chrony_tracking_last_offset_seconds
chrony_tracking_frequency_ppm
```

## Простой HTML Dashboard

### Создание статического дашборда

```html
<!DOCTYPE html>
<html>
<head>
    <title>PTP OCP Monitor</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric {
            display: inline-block;
            margin: 10px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 5px;
            min-width: 150px;
            text-align: center;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
            color: #333;
        }
        .metric-label {
            font-size: 12px;
            color: #666;
            text-transform: uppercase;
        }
        .status-ok { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-error { color: #dc3545; }
        #log {
            height: 300px;
            overflow-y: scroll;
            background: #000;
            color: #0f0;
            padding: 10px;
            font-family: monospace;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>PTP OCP Monitoring Dashboard</h1>
        
        <div class="card">
            <h2>System Status</h2>
            <div class="metric">
                <div class="metric-value" id="driver-status">Loading...</div>
                <div class="metric-label">Driver Status</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="port-state">Loading...</div>
                <div class="metric-label">Port State</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="sync-status">Loading...</div>
                <div class="metric-label">Sync Status</div>
            </div>
        </div>

        <div class="card">
            <h2>PTP Metrics</h2>
            <div class="metric">
                <div class="metric-value" id="offset">Loading...</div>
                <div class="metric-label">Offset (ns)</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="frequency">Loading...</div>
                <div class="metric-label">Frequency (ppb)</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="path-delay">Loading...</div>
                <div class="metric-label">Path Delay (ns)</div>
            </div>
        </div>

        <div class="card">
            <h2>Configuration</h2>
            <button onclick="restartPTP()">Restart PTP4L</button>
            <button onclick="restartPHC2SYS()">Restart PHC2SYS</button>
            <button onclick="showConfig()">Show Config</button>
            <button onclick="exportLogs()">Export Logs</button>
        </div>

        <div class="card">
            <h2>Real-time Log</h2>
            <div id="log"></div>
        </div>
    </div>

    <script>
        // Функции для обновления данных
        async function updateMetrics() {
            try {
                // Получение метрик из API
                const response = await fetch('/api/metrics');
                const data = await response.json();
                
                // Обновление элементов
                document.getElementById('driver-status').textContent = 
                    data.driver_status === 1 ? 'OK' : 'ERROR';
                document.getElementById('driver-status').className = 
                    'metric-value ' + (data.driver_status === 1 ? 'status-ok' : 'status-error');
                
                document.getElementById('offset').textContent = data.offset || 'N/A';
                document.getElementById('frequency').textContent = data.frequency || 'N/A';
                document.getElementById('path-delay').textContent = data.path_delay || 'N/A';
                
                // Обновление статуса порта
                const portStates = {
                    3: 'LISTENING',
                    5: 'MASTER', 
                    6: 'PASSIVE',
                    7: 'UNCALIBRATED',
                    8: 'SLAVE'
                };
                document.getElementById('port-state').textContent = 
                    portStates[data.port_state] || 'UNKNOWN';
                
            } catch (error) {
                console.error('Error updating metrics:', error);
            }
        }

        // Функции управления
        async function restartPTP() {
            if (confirm('Restart PTP4L service?')) {
                try {
                    await fetch('/api/restart/ptp4l', {method: 'POST'});
                    addLog('PTP4L restart initiated');
                } catch (error) {
                    addLog('Error restarting PTP4L: ' + error.message);
                }
            }
        }

        async function restartPHC2SYS() {
            if (confirm('Restart PHC2SYS service?')) {
                try {
                    await fetch('/api/restart/phc2sys', {method: 'POST'});
                    addLog('PHC2SYS restart initiated');
                } catch (error) {
                    addLog('Error restarting PHC2SYS: ' + error.message);
                }
            }
        }

        function showConfig() {
            window.open('/api/config', '_blank');
        }

        function exportLogs() {
            window.open('/api/logs/export', '_blank');
        }

        // Функция добавления сообщений в лог
        function addLog(message) {
            const logElement = document.getElementById('log');
            const timestamp = new Date().toISOString();
            logElement.innerHTML += `${timestamp}: ${message}\n`;
            logElement.scrollTop = logElement.scrollHeight;
        }

        // WebSocket для real-time логов
        function connectWebSocket() {
            const ws = new WebSocket('ws://localhost:8080/ws/logs');
            
            ws.onmessage = function(event) {
                addLog(event.data);
            };
            
            ws.onclose = function() {
                addLog('WebSocket connection closed, reconnecting...');
                setTimeout(connectWebSocket, 5000);
            };
        }

        // Инициализация
        document.addEventListener('DOMContentLoaded', function() {
            updateMetrics();
            setInterval(updateMetrics, 5000);
            connectWebSocket();
        });
    </script>
</body>
</html>
```

### Backend API сервер

```python
#!/usr/bin/env python3
# simple-ptp-api.py - Простой API сервер для PTP мониторинга

from flask import Flask, jsonify, request
from flask_socketio import SocketIO
import subprocess
import json
import threading
import time

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

# API endpoints
@app.route('/api/metrics')
def get_metrics():
    """Получение текущих метрик PTP"""
    try:
        # Чтение метрик из Prometheus textfile
        metrics = {}
        with open('/var/lib/prometheus/node-exporter/ptp.prom', 'r') as f:
            for line in f:
                if line.startswith('ptp_'):
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        metric_name = parts[0]
                        metric_value = parts[1]
                        if metric_name == 'ptp_offset_ns':
                            metrics['offset'] = int(float(metric_value))
                        elif metric_name == 'ptp_frequency_adjustment':
                            metrics['frequency'] = int(float(metric_value))
                        elif metric_name == 'ptp_driver_status':
                            metrics['driver_status'] = int(float(metric_value))
                        elif 'ptp_port_state' in metric_name:
                            metrics['port_state'] = int(float(metric_value))
        
        return jsonify(metrics)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/restart/<service>', methods=['POST'])
def restart_service(service):
    """Перезапуск сервиса"""
    if service not in ['ptp4l', 'phc2sys']:
        return jsonify({'error': 'Invalid service'}), 400
    
    try:
        subprocess.run(['systemctl', 'restart', f'{service}.service'], 
                      check=True, capture_output=True)
        return jsonify({'status': 'success'})
    except subprocess.CalledProcessError as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/config')
def get_config():
    """Получение конфигурации"""
    try:
        with open('/etc/ptp4l.conf', 'r') as f:
            config = f.read()
        return config, 200, {'Content-Type': 'text/plain'}
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs/export')
def export_logs():
    """Экспорт логов"""
    try:
        result = subprocess.run(['journalctl', '-u', 'ptp4l', '--no-pager'], 
                               capture_output=True, text=True)
        return result.stdout, 200, {
            'Content-Type': 'text/plain',
            'Content-Disposition': 'attachment; filename=ptp4l.log'
        }
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def log_monitor():
    """Мониторинг логов в реальном времени"""
    process = subprocess.Popen(['journalctl', '-u', 'ptp4l', '-f', '--no-pager'],
                              stdout=subprocess.PIPE, text=True)
    
    for line in iter(process.stdout.readline, ''):
        if line:
            socketio.emit('log', line.strip())

if __name__ == '__main__':
    # Запуск мониторинга логов в отдельном потоке
    log_thread = threading.Thread(target=log_monitor, daemon=True)
    log_thread.start()
    
    # Запуск веб-сервера
    socketio.run(app, host='0.0.0.0', port=8080, debug=True)
```

## Мобильное приложение (веб-приложение)

### Progressive Web App (PWA)

```html
<!DOCTYPE html>
<html>
<head>
    <title>PTP Monitor Mobile</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#2196F3">
    <link rel="manifest" href="manifest.json">
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            margin: 15px 0;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .metric {
            text-align: center;
            margin: 20px 0;
        }
        .metric-value {
            font-size: 36px;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-label {
            font-size: 14px;
            opacity: 0.8;
        }
        .status-indicator {
            width: 20px;
            height: 20px;
            border-radius: 50%;
            display: inline-block;
            margin-right: 10px;
        }
        .status-ok { background-color: #4CAF50; }
        .status-warning { background-color: #FF9800; }
        .status-error { background-color: #F44336; }
        button {
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            padding: 15px 25px;
            border-radius: 25px;
            font-size: 16px;
            margin: 10px 5px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.3);
        }
        button:active {
            background: rgba(255,255,255,0.3);
        }
    </style>
</head>
<body>
    <div id="app">
        <h1>🕐 PTP Monitor</h1>
        
        <div class="card">
            <h2>Status</h2>
            <div id="status-section">
                <span class="status-indicator" id="status-indicator"></span>
                <span id="status-text">Checking...</span>
            </div>
        </div>

        <div class="card">
            <div class="metric">
                <div class="metric-value" id="offset-value">--</div>
                <div class="metric-label">Offset (ns)</div>
            </div>
        </div>

        <div class="card">
            <div class="metric">
                <div class="metric-value" id="freq-value">--</div>
                <div class="metric-label">Frequency (ppb)</div>
            </div>
        </div>

        <div class="card">
            <button onclick="refreshData()">🔄 Refresh</button>
            <button onclick="showLogs()">📋 Logs</button>
            <button onclick="showConfig()">⚙️ Config</button>
        </div>
    </div>

    <script>
        // Service Worker регистрация
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('sw.js');
        }

        // Функции приложения
        async function refreshData() {
            try {
                const response = await fetch('/api/metrics');
                const data = await response.json();
                
                updateUI(data);
            } catch (error) {
                console.error('Error:', error);
                showError();
            }
        }

        function updateUI(data) {
            // Обновление offset
            document.getElementById('offset-value').textContent = 
                data.offset ? data.offset.toLocaleString() : '--';
            
            // Обновление частоты
            document.getElementById('freq-value').textContent = 
                data.frequency ? data.frequency.toLocaleString() : '--';
            
            // Обновление статуса
            const statusIndicator = document.getElementById('status-indicator');
            const statusText = document.getElementById('status-text');
            
            if (data.driver_status === 1) {
                statusIndicator.className = 'status-indicator status-ok';
                statusText.textContent = 'System OK';
            } else {
                statusIndicator.className = 'status-indicator status-error';
                statusText.textContent = 'System Error';
            }
        }

        function showError() {
            document.getElementById('status-indicator').className = 'status-indicator status-error';
            document.getElementById('status-text').textContent = 'Connection Error';
        }

        function showLogs() {
            window.open('/api/logs/export', '_blank');
        }

        function showConfig() {
            window.open('/api/config', '_blank');
        }

        // Автообновление каждые 10 секунд
        setInterval(refreshData, 10000);
        
        // Первоначальная загрузка
        refreshData();
    </script>
</body>
</html>
```

### Manifest для PWA

```json
{
  "name": "PTP Monitor",
  "short_name": "PTP Monitor",
  "description": "PTP OCP Monitoring Application",
  "start_url": "/",
  "display": "standalone",
  "theme_color": "#2196F3",
  "background_color": "#ffffff",
  "icons": [
    {
      "src": "icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icon-512.png", 
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

## Установка GUI компонентов

```bash
# Создание директории для веб-интерфейса
sudo mkdir -p /var/www/ptp-monitor

# Копирование файлов
sudo cp dashboard.html /var/www/ptp-monitor/index.html
sudo cp manifest.json /var/www/ptp-monitor/
sudo cp simple-ptp-api.py /usr/local/bin/

# Установка зависимостей Python
pip3 install flask flask-socketio

# Создание systemd сервиса для API
sudo tee /etc/systemd/system/ptp-api.service << 'EOF'
[Unit]
Description=PTP API Server
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/ptp-monitor
ExecStart=/usr/bin/python3 /usr/local/bin/simple-ptp-api.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Запуск сервисов
sudo systemctl enable ptp-api.service
sudo systemctl start ptp-api.service

# Настройка nginx (опционально)
sudo tee /etc/nginx/sites-available/ptp-monitor << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /var/www/ptp-monitor;
        index index.html;
    }
    
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /ws/ {
        proxy_pass http://localhost:8080/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/ptp-monitor /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

## Доступ к интерфейсам

- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090  
- **Custom Dashboard**: http://localhost:8080
- **Mobile PWA**: http://localhost/

Все интерфейсы предоставляют различные уровни детализации для мониторинга и управления PTP OCP системой.