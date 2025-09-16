# Интеграция с Chrony

## Обзор

Данный пример показывает, как интегрировать PTP с chronyd для обеспечения надежной временной синхронизации с несколькими источниками времени.

## Конфигурация Chrony

### Файл /etc/chrony/chrony.conf

```bash
# Основной источник времени - PTP часы (обновленная конфигурация)
refclock PHC /dev/ptp0 poll 3 dpoll -2 offset 0 stratum 1 precision 1e-9 prefer

# Резервные NTP источники
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst  
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

# Локальные серверы времени (если есть)
#server 192.168.1.100 iburst
#server 192.168.1.101 iburst

# Настройки синхронизации
makestep 1.0 3
rtcsync

# Файлы состояния
driftfile /var/lib/chrony/drift
logdir /var/log/chrony

# Разрешения для клиентов
allow 192.168.0.0/16
allow 10.0.0.0/8
allow 172.16.0.0/12

# Локальный сервер времени
local stratum 2
smoothtime 400 0.01 leaponly

# Мониторинг и логирование
log measurements statistics tracking refclocks
keyfile /etc/chrony/chrony.keys
commandkey 1
generatecommandkey

# Безопасность
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
cmdallow 127.0.0.1
cmdallow ::1

# Производительность
maxupdateskew 100.0
clientloglimit 1048576
```

## Systemd сервис для мониторинга

### Файл /etc/systemd/system/chrony-ptp-monitor.service

```ini
[Unit]
Description=Chrony PTP Monitor
After=chronyd.service ptp4l.service
Requires=chronyd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/chrony-ptp-monitor.sh
Restart=always
RestartSec=30
User=root
Group=root

[Install]
WantedBy=multi-user.target
```

### Скрипт мониторинга /usr/local/bin/chrony-ptp-monitor.sh

```bash
#!/bin/bash
# Мониторинг состояния PTP в Chrony

LOG_FILE="/var/log/chrony-ptp-monitor.log"
PTP_DEVICE="/dev/ptp0"
ALERT_THRESHOLD=1000000  # 1ms в наносекундах

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

check_ptp_status() {
    # Проверка доступности PTP устройства
    if [ ! -c "$PTP_DEVICE" ]; then
        log_message "ERROR: PTP device $PTP_DEVICE not available"
        return 1
    fi
    
    # Проверка состояния в chrony
    chronyc sources | grep "PHC" | while read line; do
        log_message "PTP Status: $line"
    done
    
    # Получение offset
    offset=$(chronyc sourcestats | grep "PHC" | awk '{print $7}')
    if [ -n "$offset" ]; then
        # Конвертация в наносекунды для сравнения
        offset_ns=$(echo "$offset * 1000000000" | bc -l | cut -d'.' -f1)
        offset_abs=${offset_ns#-}
        
        if [ "$offset_abs" -gt "$ALERT_THRESHOLD" ]; then
            log_message "WARNING: High PTP offset: ${offset}s (${offset_ns}ns)"
        else
            log_message "INFO: PTP offset within limits: ${offset}s"
        fi
    fi
}

# Основной цикл мониторинга
while true; do
    check_ptp_status
    sleep 60
done
```

## Настройка автоматического переключения

### Скрипт переключения источников /usr/local/bin/time-source-switcher.sh

```bash
#!/bin/bash
# Автоматическое переключение между PTP и NTP

PTP_DEVICE="/dev/ptp0"
MAX_PTP_OFFSET=5000000  # 5ms в наносекундах
CHRONY_CONF="/etc/chrony/chrony.conf"
CHRONY_CONF_BACKUP="/etc/chrony/chrony.conf.backup"

switch_to_ntp() {
    echo "Switching to NTP sources only..."
    cp "$CHRONY_CONF" "$CHRONY_CONF_BACKUP"
    sed 's/^refclock PHC/#refclock PHC/' "$CHRONY_CONF" > /tmp/chrony.conf.tmp
    mv /tmp/chrony.conf.tmp "$CHRONY_CONF"
    systemctl reload chronyd
}

switch_to_ptp() {
    echo "Switching back to PTP + NTP sources..."
    if [ -f "$CHRONY_CONF_BACKUP" ]; then
        cp "$CHRONY_CONF_BACKUP" "$CHRONY_CONF"
        systemctl reload chronyd
    fi
}

check_ptp_health() {
    # Проверка доступности устройства
    if [ ! -c "$PTP_DEVICE" ]; then
        return 1
    fi
    
    # Проверка состояния ptp4l
    if ! pgrep -f ptp4l >/dev/null; then
        return 1
    fi
    
    # Проверка offset
    offset=$(pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null | grep offsetFromMaster | awk '{print $2}')
    if [ -z "$offset" ]; then
        return 1
    fi
    
    offset_abs=${offset#-}
    if [ "$offset_abs" -gt "$MAX_PTP_OFFSET" ]; then
        return 1
    fi
    
    return 0
}

# Основная логика
if check_ptp_health; then
    echo "PTP is healthy, ensuring PTP+NTP configuration"
    switch_to_ptp
else
    echo "PTP is unhealthy, switching to NTP only"
    switch_to_ntp
fi
```

## Cron задача для автоматического мониторинга

### Файл /etc/cron.d/chrony-ptp-health

```bash
# Проверка здоровья PTP каждые 5 минут
*/5 * * * * root /usr/local/bin/time-source-switcher.sh >> /var/log/time-source-switcher.log 2>&1

# Ротация логов раз в день
0 0 * * * root find /var/log -name "*chrony*ptp*" -mtime +7 -delete
```

## Мониторинг через Prometheus

### Экспортер метрик /usr/local/bin/chrony-ptp-exporter.sh

```bash
#!/bin/bash
# Экспорт метрик Chrony-PTP для Prometheus

METRICS_FILE="/var/lib/prometheus/node-exporter/chrony_ptp.prom"

# Получение статистики Chrony
sources_output=$(chronyc sources -v 2>/dev/null)
sourcestats_output=$(chronyc sourcestats 2>/dev/null)

# Инициализация файла метрик
cat > "$METRICS_FILE" << 'EOF'
# HELP chrony_ptp_source_reachability Source reachability
# TYPE chrony_ptp_source_reachability gauge

# HELP chrony_ptp_source_stratum Source stratum
# TYPE chrony_ptp_source_stratum gauge

# HELP chrony_ptp_source_offset Source offset in seconds
# TYPE chrony_ptp_source_offset gauge

# HELP chrony_ptp_source_jitter Source jitter in seconds
# TYPE chrony_ptp_source_jitter gauge
EOF

# Парсинг и экспорт метрик
echo "$sources_output" | grep "PHC" | while read line; do
    # Извлечение данных из строки
    source=$(echo "$line" | awk '{print $3}')
    stratum=$(echo "$line" | awk '{print $4}')
    reach=$(echo "$line" | awk '{print $6}')
    offset=$(echo "$line" | awk '{print $9}')
    
    # Запись метрик
    echo "chrony_ptp_source_reachability{source=\"$source\"} $reach" >> "$METRICS_FILE"
    echo "chrony_ptp_source_stratum{source=\"$source\"} $stratum" >> "$METRICS_FILE"
    echo "chrony_ptp_source_offset{source=\"$source\"} $offset" >> "$METRICS_FILE"
done

# Экспорт статистики
echo "$sourcestats_output" | grep "PHC" | while read line; do
    source=$(echo "$line" | awk '{print $2}')
    jitter=$(echo "$line" | awk '{print $8}')
    
    echo "chrony_ptp_source_jitter{source=\"$source\"} $jitter" >> "$METRICS_FILE"
done
```

## Установка и активация

```bash
# Установка скриптов
sudo chmod +x /usr/local/bin/chrony-ptp-monitor.sh
sudo chmod +x /usr/local/bin/time-source-switcher.sh
sudo chmod +x /usr/local/bin/chrony-ptp-exporter.sh

# Активация сервисов
sudo systemctl enable chrony-ptp-monitor.service
sudo systemctl start chrony-ptp-monitor.service

# Установка cron задач
sudo systemctl reload crond

# Проверка статуса
sudo systemctl status chrony-ptp-monitor.service
chronyc sources
chronyc sourcestats
```

## Тестирование

```bash
# Проверка источников времени
chronyc sources -v

# Проверка статистики
chronyc sourcestats

# Мониторинг изменений времени
chronyc tracking

# Ручной тест переключения
sudo /usr/local/bin/time-source-switcher.sh
```