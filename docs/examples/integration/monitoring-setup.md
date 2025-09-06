# Настройка мониторинга PTP OCP

## Обзор

Комплексная система мониторинга для PTP OCP включающая Prometheus, Grafana, и пользовательские скрипты.

## Prometheus Node Exporter

### Установка textfile collector

```bash
# Создание директории для метрик
sudo mkdir -p /var/lib/prometheus/node-exporter

# Настройка прав доступа
sudo chown prometheus:prometheus /var/lib/prometheus/node-exporter
sudo chmod 755 /var/lib/prometheus/node-exporter

# Запуск node_exporter с textfile collector
sudo tee /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/prometheus/node-exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable node_exporter.service
sudo systemctl start node_exporter.service
```

## PTP Metrics Exporter

### Основной скрипт экспорта /usr/local/bin/ptp-metrics-exporter.sh

```bash
#!/bin/bash
# Экспорт метрик PTP для Prometheus

METRICS_FILE="/var/lib/prometheus/node-exporter/ptp.prom"
TEMP_FILE="/tmp/ptp_metrics.tmp"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >&2
}

# Функция безопасного обновления метрик
update_metrics() {
    cat > "$TEMP_FILE" << 'EOF'
# HELP ptp_offset_ns PTP offset from master in nanoseconds
# TYPE ptp_offset_ns gauge

# HELP ptp_frequency_adjustment PTP frequency adjustment in ppb
# TYPE ptp_frequency_adjustment gauge

# HELP ptp_master_clock_id PTP grandmaster clock ID
# TYPE ptp_master_clock_id gauge

# HELP ptp_port_state PTP port state (0=disabled, 1=listening, 2=pre_master, 3=master, 4=passive, 5=uncalibrated, 6=slave)
# TYPE ptp_port_state gauge

# HELP ptp_path_delay_ns PTP path delay in nanoseconds
# TYPE ptp_path_delay_ns gauge

# HELP ptp_steps_removed Number of steps removed from grandmaster
# TYPE ptp_steps_removed gauge

# HELP ptp_driver_status PTP driver status (1=ok, 0=error)
# TYPE ptp_driver_status gauge

# HELP ptp_device_info PTP device information
# TYPE ptp_device_info gauge
EOF

    # Проверка статуса драйвера
    if lsmod | grep -q ptp_ocp; then
        echo "ptp_driver_status 1" >> "$TEMP_FILE"
    else
        echo "ptp_driver_status 0" >> "$TEMP_FILE"
        mv "$TEMP_FILE" "$METRICS_FILE"
        return
    fi

    # Проверка TimeCard устройств
    for timecard in /sys/class/timecard/ocp*; do
        if [ -d "$timecard" ]; then
            ocp_name=$(basename "$timecard")
            
            # Основная информация о TimeCard
            if [ -f "$timecard/serialnum" ]; then
                serial=$(cat "$timecard/serialnum" 2>/dev/null || echo "unknown")
                echo "timecard_device_info{device=\"$ocp_name\",serial=\"$serial\"} 1" >> "$TEMP_FILE"
            fi
            
            # Статус GNSS синхронизации
            if [ -f "$timecard/gnss_sync" ]; then
                gnss_status=$(cat "$timecard/gnss_sync" 2>/dev/null || echo "unknown")
                gnss_locked=$( [ "$gnss_status" = "locked" ] && echo 1 || echo 0 )
                echo "timecard_gnss_locked{device=\"$ocp_name\"} $gnss_locked" >> "$TEMP_FILE"
            fi
            
            # Источник часов
            if [ -f "$timecard/clock_source" ]; then
                clock_source=$(cat "$timecard/clock_source" 2>/dev/null || echo "unknown")
                echo "timecard_clock_source_info{device=\"$ocp_name\",source=\"$clock_source\"} 1" >> "$TEMP_FILE"
            fi
            
            # Задержки кабелей
            for delay_type in external_pps_cable_delay internal_pps_cable_delay; do  # pci_delay НЕ ПОДДЕРЖИВАЕТСЯ
                if [ -f "$timecard/$delay_type" ]; then
                    delay_value=$(cat "$timecard/$delay_type" 2>/dev/null || echo "0")
                    echo "timecard_delay_ns{device=\"$ocp_name\",type=\"$delay_type\"} $delay_value" >> "$TEMP_FILE"
                fi
            done
            
            # UTC-TAI offset
            if [ -f "$timecard/utc_tai_offset" ]; then
                utc_tai=$(cat "$timecard/utc_tai_offset" 2>/dev/null || echo "0")
                echo "timecard_utc_tai_offset{device=\"$ocp_name\"} $utc_tai" >> "$TEMP_FILE"
            fi
        fi
    done

    # Проверка PTP устройств
    for dev in /dev/ptp*; do
        if [ -c "$dev" ]; then
            dev_num=$(basename "$dev" | sed 's/ptp//')
            
            # Получение информации об устройстве
            if [ -f "/sys/class/ptp/ptp${dev_num}/clock_name" ]; then
                clock_name=$(cat "/sys/class/ptp/ptp${dev_num}/clock_name")
                echo "ptp_device_info{device=\"$dev\",clock_name=\"$clock_name\"} 1" >> "$TEMP_FILE"
            fi
        fi
    done

    # Получение данных через pmc (если ptp4l запущен)
    if pgrep -f ptp4l >/dev/null; then
        
        # Current Data Set
        current_data=$(pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null)
        if [ -n "$current_data" ]; then
            offset=$(echo "$current_data" | grep offsetFromMaster | awk '{print $2}')
            freq_adj=$(echo "$current_data" | grep frequencyAdjustment | awk '{print $2}')
            
            [ -n "$offset" ] && echo "ptp_offset_ns $offset" >> "$TEMP_FILE"
            [ -n "$freq_adj" ] && echo "ptp_frequency_adjustment $freq_adj" >> "$TEMP_FILE"
        fi

        # Parent Data Set
        parent_data=$(pmc -u -b 0 'GET PARENT_DATA_SET' 2>/dev/null)
        if [ -n "$parent_data" ]; then
            grandmaster_id=$(echo "$parent_data" | grep grandmasterIdentity | awk '{print $2}')
            steps_removed=$(echo "$parent_data" | grep stepsRemoved | awk '{print $2}')
            
            [ -n "$grandmaster_id" ] && echo "ptp_master_clock_id{master_id=\"$grandmaster_id\"} 1" >> "$TEMP_FILE"
            [ -n "$steps_removed" ] && echo "ptp_steps_removed $steps_removed" >> "$TEMP_FILE"
        fi

        # Port Data Set
        port_data=$(pmc -u -b 0 'GET PORT_DATA_SET' 2>/dev/null)
        if [ -n "$port_data" ]; then
            port_state=$(echo "$port_data" | grep portState | awk '{print $2}')
            path_delay=$(echo "$port_data" | grep peerMeanPathDelay | awk '{print $2}')
            
            # Конвертация состояния порта в числовое значение
            case "$port_state" in
                "INITIALIZING") state_num=0 ;;
                "FAULTY") state_num=1 ;;
                "DISABLED") state_num=2 ;;
                "LISTENING") state_num=3 ;;
                "PRE_MASTER") state_num=4 ;;
                "MASTER") state_num=5 ;;
                "PASSIVE") state_num=6 ;;
                "UNCALIBRATED") state_num=7 ;;
                "SLAVE") state_num=8 ;;
                *) state_num=99 ;;
            esac
            
            echo "ptp_port_state{state=\"$port_state\"} $state_num" >> "$TEMP_FILE"
            [ -n "$path_delay" ] && echo "ptp_path_delay_ns $path_delay" >> "$TEMP_FILE"
        fi
    else
        log "ptp4l not running, limited metrics available"
    fi

    # Атомарное обновление файла метрик
    mv "$TEMP_FILE" "$METRICS_FILE"
    log "Metrics updated successfully"
}

# Основной цикл
while true; do
    update_metrics
    sleep 30
done
```

### Systemd сервис для экспорта метрик

```bash
sudo tee /etc/systemd/system/ptp-metrics-exporter.service << 'EOF'
[Unit]
Description=PTP Metrics Exporter for Prometheus
After=network.target ptp4l.service
Wants=ptp4l.service

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/ptp-metrics-exporter.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable ptp-metrics-exporter.service
sudo systemctl start ptp-metrics-exporter.service
```

## Grafana Dashboard

### JSON конфигурация dashboard

```json
{
  "dashboard": {
    "id": null,
    "title": "PTP OCP Monitoring",
    "tags": ["ptp", "timing", "synchronization"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "PTP Offset from Master",
        "type": "stat",
        "targets": [
          {
            "expr": "ptp_offset_ns",
            "legendFormat": "Offset (ns)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "ns",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 1000},
                {"color": "red", "value": 10000}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "PTP Frequency Adjustment",
        "type": "stat",
        "targets": [
          {
            "expr": "ptp_frequency_adjustment",
            "legendFormat": "Frequency (ppb)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 1000},
                {"color": "red", "value": 10000}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "PTP Offset History",
        "type": "graph",
        "targets": [
          {
            "expr": "ptp_offset_ns",
            "legendFormat": "Offset (ns)"
          }
        ],
        "yAxes": [
          {
            "label": "Nanoseconds",
            "show": true
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "PTP Port State",
        "type": "stat",
        "targets": [
          {
            "expr": "ptp_port_state",
            "legendFormat": "{{state}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {"type": "value", "value": "8", "text": "SLAVE"},
              {"type": "value", "value": "5", "text": "MASTER"},
              {"type": "value", "value": "7", "text": "UNCALIBRATED"},
              {"type": "value", "value": "3", "text": "LISTENING"}
            ]
          }
        },
        "gridPos": {"h": 4, "w": 8, "x": 0, "y": 16}
      },
      {
        "id": 5,
        "title": "Driver Status",
        "type": "stat",
        "targets": [
          {
            "expr": "ptp_driver_status",
            "legendFormat": "Driver Status"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {"type": "value", "value": "1", "text": "OK"},
              {"type": "value", "value": "0", "text": "ERROR"}
            ],
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        },
        "gridPos": {"h": 4, "w": 8, "x": 8, "y": 16}
      },
      {
        "id": 6,
        "title": "Steps Removed",
        "type": "stat",
        "targets": [
          {
            "expr": "ptp_steps_removed",
            "legendFormat": "Steps"
          }
        ],
        "gridPos": {"h": 4, "w": 8, "x": 16, "y": 16}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "5s"
  }
}
```

## Alerting Rules

### Prometheus rules для PTP

```yaml
# /etc/prometheus/rules/ptp.yml
groups:
  - name: ptp_alerts
    rules:
      - alert: PTPHighOffset
        expr: abs(ptp_offset_ns) > 1000000
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "PTP offset is high"
          description: "PTP offset is {{ $value }}ns, which exceeds 1ms threshold"

      - alert: PTPCriticalOffset
        expr: abs(ptp_offset_ns) > 10000000
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "PTP offset is critical"
          description: "PTP offset is {{ $value }}ns, which exceeds 10ms threshold"

      - alert: PTPDriverDown
        expr: ptp_driver_status != 1
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "PTP driver is not loaded"
          description: "PTP OCP driver is not loaded or functioning"

      - alert: PTPNotSynchronized
        expr: ptp_port_state{state!="SLAVE",state!="MASTER"} == 1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "PTP is not synchronized"
          description: "PTP port state is {{ $labels.state }}, not synchronized"

      - alert: PTPHighFrequencyAdjustment
        expr: abs(ptp_frequency_adjustment) > 50000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PTP frequency adjustment is high"
          description: "PTP frequency adjustment is {{ $value }}ppb"
```

## Логирование и ротация

### Rsyslog конфигурация

```bash
# /etc/rsyslog.d/50-ptp.conf
# PTP логи
:programname, isequal, "ptp4l" /var/log/ptp/ptp4l.log
:programname, isequal, "phc2sys" /var/log/ptp/phc2sys.log
:programname, isequal, "ptp-metrics-exporter" /var/log/ptp/metrics.log

# Kernel сообщения PTP
:msg, contains, "ptp_ocp" /var/log/ptp/driver.log

# Остановить дальнейшую обработку
& stop
```

### Logrotate конфигурация

```bash
# /etc/logrotate.d/ptp
/var/log/ptp/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        /bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
```

## Установка и настройка

```bash
# Создание пользователя prometheus
sudo useradd --system --shell /bin/false prometheus

# Создание директорий
sudo mkdir -p /var/log/ptp
sudo mkdir -p /var/lib/prometheus/node-exporter
sudo chown prometheus:prometheus /var/lib/prometheus/node-exporter

# Установка скриптов
sudo chmod +x /usr/local/bin/ptp-metrics-exporter.sh
sudo chown prometheus:prometheus /usr/local/bin/ptp-metrics-exporter.sh

# Активация сервисов
sudo systemctl daemon-reload
sudo systemctl enable ptp-metrics-exporter.service
sudo systemctl start ptp-metrics-exporter.service

# Перезапуск rsyslog для применения новых правил
sudo systemctl restart rsyslog

# Проверка статуса
sudo systemctl status ptp-metrics-exporter.service
cat /var/lib/prometheus/node-exporter/ptp.prom
```

## Проверка мониторинга

```bash
# Проверка метрик
curl -s http://localhost:9100/metrics | grep ptp_

# Проверка логов
tail -f /var/log/ptp/ptp4l.log
tail -f /var/log/ptp/metrics.log

# Проверка алертов в Prometheus
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname | startswith("PTP"))'
```