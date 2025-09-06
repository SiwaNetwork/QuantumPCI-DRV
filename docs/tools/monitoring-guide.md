# Руководство по мониторингу Quantum-PCI

## Обзор

Данное руководство описывает систему мониторинга для устройств Quantum-PCI, основанную на реальных возможностях драйвера `ptp_ocp`.

## ⚠️ Важные ограничения

Система мониторинга **строго ограничена** возможностями драйвера `ptp_ocp`. Это означает:

### ✅ Доступные метрики:
- **PTP offset/drift** - из sysfs (`clock_status_offset`, `clock_status_drift`)
- **GNSS sync статус** - базовое состояние синхронизации
- **SMA конфигурация** - текущие настройки разъёмов
- **Информация об устройстве** - серийный номер, источник времени

### ❌ НЕ доступные метрики:
- **Детальный мониторинг температуры** - драйвер не предоставляет
- **Мониторинг питания и напряжений** - драйвер не предоставляет  
- **Детальный GNSS** (спутники, качество) - драйвер не предоставляет
- **Состояние LED/FPGA/аппаратуры** - драйвер не предоставляет

## Архитектура системы

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Browser   │◄──►│  Flask API       │◄──►│  ptp_ocp driver │
│   (Dashboard)   │    │  (Port 8080)     │    │  (sysfs)        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  phc_ctl tool    │
                       │  (PTP metrics)   │
                       └──────────────────┘
```

## Установка и запуск

### 1. Установка зависимостей

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3 python3-pip

# Установка Python пакетов
cd ptp-monitoring
pip3 install -r requirements.txt
```

### 2. Запуск мониторинга

```bash
# Запуск основного скрипта
python3 quantum-pci-monitor.py
```

### 3. Доступ к интерфейсам

После запуска доступны следующие endpoints:

- **📊 Realistic Dashboard**: http://localhost:8080/realistic-dashboard
- **🔧 API endpoints**: http://localhost:8080/api/
- **🗺️ Roadmap**: http://localhost:8080/api/roadmap
- **🏠 Main Page**: http://localhost:8080/

## API Endpoints

### Основные метрики

```bash
# Получить все метрики
curl http://localhost:8080/api/metrics

# Получить статус устройств
curl http://localhost:8080/api/devices

# Получить PTP метрики
curl http://localhost:8080/api/ptp

# Получить GNSS статус
curl http://localhost:8080/api/gnss
```

### Конфигурация

```bash
# Получить конфигурацию SMA
curl http://localhost:8080/api/sma

# Получить информацию о системе
curl http://localhost:8080/api/system

# Получить roadmap проекта
curl http://localhost:8080/api/roadmap
```

## Пример использования API

### Python

```python
import requests
import json

# Получение метрик
response = requests.get('http://localhost:8080/api/metrics')
if response.status_code == 200:
    metrics = response.json()
    print(f"PTP Offset: {metrics.get('ptp', {}).get('offset_ns', 'N/A')} ns")
    print(f"GNSS Sync: {metrics.get('gnss', {}).get('sync', 'N/A')}")
else:
    print(f"Error: {response.status_code}")
```

### Bash

```bash
#!/bin/bash

# Получение и парсинг метрик
METRICS=$(curl -s http://localhost:8080/api/metrics)
OFFSET=$(echo $METRICS | jq -r '.ptp.offset_ns // "N/A"')
SYNC=$(echo $METRICS | jq -r '.gnss.sync // "N/A"')

echo "PTP Offset: $OFFSET ns"
echo "GNSS Sync: $SYNC"
```

## Мониторинг в реальном времени

### WebSocket подключение

```javascript
const socket = io('http://localhost:8080');

socket.on('metrics_update', function(data) {
    console.log('New metrics:', data);
    updateDashboard(data);
});

socket.on('alert', function(alert) {
    console.log('Alert:', alert);
    showAlert(alert);
});
```

### Автоматические алерты

Система автоматически генерирует алерты при:

- **PTP Offset** > 1000ns (warning), > 10000ns (critical)
- **PTP Drift** > 100ppb (warning), > 1000ppb (critical)
- **GNSS потеря синхронизации**

## Логирование

Все события записываются в:
- **Консоль** - для отладки
- **WebSocket** - для real-time мониторинга
- **API logs** - доступны через `/api/logs`

## Устранение неполадок

### Проблема: "No devices found"

```bash
# Проверить наличие устройств
ls /sys/class/timecard/

# Проверить права доступа
sudo chmod 644 /sys/class/timecard/ocp*/

# Проверить драйвер
lsmod | grep ptp_ocp
```

### Проблема: "API не отвечает"

```bash
# Проверить порт
netstat -tulnp | grep 8080

# Проверить процесс
ps aux | grep quantum-pci-monitor

# Проверить логи
journalctl -f | grep quantum-pci
```

### Проблема: "Метрики не обновляются"

```bash
# Проверить sysfs
cat /sys/class/timecard/ocp0/clock_status_offset

# Проверить phc_ctl
phc_ctl /dev/ptp0 cmp

# Проверить права
ls -la /dev/ptp*
```

## Развитие проекта

Подробный план развития системы мониторинга доступен по адресу:
http://localhost:8080/api/roadmap

Основные направления:
- **Этап 1**: Расширение sysfs интерфейса драйвера
- **Этап 2**: Добавление температурного мониторинга
- **Этап 3**: Интеграция с GNSS модулем
- **Этап 4**: Полнофункциональная система мониторинга

## Поддержка

При возникновении проблем:

1. Проверьте системные требования
2. Убедитесь в корректности установки драйвера
3. Проверьте права доступа к устройствам
4. Обратитесь к разделу "Устранение неполадок"

Система мониторинга развивается в соответствии с возможностями драйвера и аппаратной платформы.
