# Веб API для мониторинга Quantum-PCI

## Обзор

Веб API предоставляет полный доступ к данным мониторинга Quantum-PCI через REST интерфейс. API поддерживает как базовые, так и расширенные метрики с возможностью WebSocket обновлений в реальном времени.

## Базовый URL

```
http://localhost:8080/api/
```

## Аутентификация

В текущей версии API не требует аутентификации для локального доступа. Для production окружений рекомендуется настроить HTTPS и аутентификацию.

## Основные эндпоинты

### Информация о системе

#### GET `/`

Возвращает общую информацию о системе мониторинга.

**Пример запроса:**
```bash
curl http://localhost:8080/
```

**Пример ответа:**
```json
{
  "service": "TimeCard PTP Monitoring API v2.0",
  "version": "2.0.0",
  "timestamp": 1753689738.2285047,
  "devices_count": 1,
  "features": [
    "Basic PTP metrics and device status",
    "GNSS synchronization status",
    "SMA connector configuration",
    "Hardware status monitoring",
    "Real-time updates via WebSocket",
    "Device health assessment"
  ],
  "endpoints": {
    "devices": "/api/devices",
    "device_status": "/api/device/<id>/status",
    "extended_metrics": "/api/metrics/extended",
    "basic_metrics": "/api/metrics",
    "alerts": "/api/alerts",
    "alert_history": "/api/alerts/history",
    "metrics_history": "/api/metrics/history/<device_id>",
    "config": "/api/config",
    "logs": "/api/logs/export",
    "restart": "/api/restart/<service>"
  },
  "device_capabilities": {
    "clock_sources": ["GNSS", "MAC", "IRIG-B", "external", "RTC", "DCF"],
    "sma_signals": ["10MHz", "PPS", "GNSS", "IRIG", "DCF", "GEN1"],
    "interfaces": ["PTP", "UART", "I2C", "SPI"],
    "disciplining_sources": ["GNSS", "External", "Freerun"]
  }
}
```

### Устройства

#### GET `/api/devices`

Возвращает список всех обнаруженных TimeCard устройств.

**Пример запроса:**
```bash
curl http://localhost:8080/api/devices
```

**Пример ответа:**
```json
{
  "count": 1,
  "devices": [
    {
      "identification": {
        "device_id": "timecard0",
        "serial_number": "TC-2024-001",
        "firmware_version": "2.1.3",
        "hardware_revision": "Rev C",
        "manufacture_date": "2024-01-01",
                        "part_number": "Quantum-PCI-TimeCard-PCIE",
        "vendor": "Facebook Connectivity"
      },
      "capabilities": {
        "gnss_systems": ["GPS", "GLONASS", "Galileo", "BeiDou"],
        "disciplining_modes": ["GNSS", "External", "Freerun"],
        "output_signals": ["10MHz", "1PPS"],
        "reference_inputs": ["10MHz", "1PPS", "2MHz", "5MHz"],
        "ptp_versions": ["IEEE 1588-2019", "IEEE 1588-2008"],
        "frequency_accuracy": "±1e-12",
        "timestamp_accuracy": "±1ns",
        "holdover_time": "8 hours"
      },
      "pci": {
        "bus_address": "0000:01:00.0",
        "vendor_id": "1d9b",
        "device_id": "0400",
        "subsystem_vendor": "Facebook",
        "subsystem_device": "TimeCard",
        "bar0_address": "0xfe000000",
        "interrupt_line": "16"
      }
    }
  ],
  "timestamp": 1753689157.5418463
}
```

### Базовые метрики

#### GET `/api/metrics`

Возвращает базовые PTP метрики устройства.

**Пример запроса:**
```bash
curl http://localhost:8080/api/metrics
```

**Пример ответа:**
```json
{
  "driver_status": 1,
  "frequency": -10.781329410528244,
  "offset": 132,
  "path_delay": 2522,
  "port_state": 8,
  "timestamp": 1753689108.2276976
}
```

### Расширенные метрики

#### GET `/api/metrics/extended`

Возвращает полные расширенные метрики для всех подсистем.

**Пример запроса:**
```bash
curl http://localhost:8080/api/metrics/extended
```

**Пример ответа:**
```json
{
  "timecard0": {
    "driver_status": 1,
    "frequency": -6.298,
    "offset": 174,
    "path_delay": 2433,
    "port_state": 8,
    "timestamp": 1753689147.988943,
    "gnss": {
      "sync_status": "locked",
        "satellites_used": 14,
      "fix_type": "3D"
    },
    "clock_source": "GNSS",
    "sma1": "10MHz",
    "sma2": "PPS",
    "sma3": "disable",
    "sma4": "disable"

  }
}
```

### Статус устройства

#### GET `/api/device/{device_id}/status`

Возвращает полный статус конкретного устройства.

**Пример запроса:**
```bash
curl http://localhost:8080/api/device/timecard0/status
```

**Пример ответа:**
```json
{
  "device_id": "timecard0",
  "status": "operational",
  "gnss_sync": "locked",
  "clock_source": "GNSS",
  "ptp_offset": 174,
  "timestamp": 1753689147.988943
}
```

### Алерты

#### GET `/api/alerts`

Возвращает активные алерты системы.

**Пример запроса:**
```bash
curl http://localhost:8080/api/alerts
```

**Пример ответа:**
```json
{
  "active_alerts": [
    {
      "id": "alert_001",
      "severity": "warning",
      "category": "sync",
      "message": "GNSS synchronization lost",
      "device_id": "timecard0",
      "timestamp": 1753689147.988943,
      "acknowledged": false
    }
  ],
  "total_active": 1,
  "timestamp": 1753689147.988943
}
```

#### GET `/api/alerts/history`

Возвращает историю алертов.

**Пример запроса:**
```bash
curl http://localhost:8080/api/alerts/history
```

### История метрик

#### GET `/api/metrics/history/{device_id}`

Возвращает историю метрик для конкретного устройства.

**Пример запроса:**
```bash
curl http://localhost:8080/api/metrics/history/timecard0
```

### Конфигурация

#### GET `/api/config`

Возвращает текущую конфигурацию системы.

**Пример запроса:**
```bash
curl http://localhost:8080/api/config
```

### Экспорт логов

#### GET `/api/logs/export`

Экспортирует логи системы.

**Пример запроса:**
```bash
curl http://localhost:8080/api/logs/export
```

### Перезапуск сервисов

#### POST `/api/restart/{service}`

Перезапускает указанный сервис.

**Пример запроса:**
```bash
curl -X POST http://localhost:8080/api/restart/ptp4l
curl -X POST http://localhost:8080/api/restart/chronyd
```

## WebSocket API

### Подключение

```javascript
const socket = io('http://localhost:8080');

socket.on('connect', () => {
  console.log('Connected to TimeCard monitoring');
});

socket.on('disconnect', () => {
  console.log('Disconnected from TimeCard monitoring');
});
```

### События

#### `status_update`
Получается при подключении клиента.

```javascript
socket.on('status_update', (data) => {
  console.log('Status update:', data);
  // {
  //   connected: true,
  //   devices_count: 1,
  //   current_offset: 174,
  //   api_version: '2.0.0',
  //   features_enabled: [...],
  //   timestamp: 1753689147.988943
  // }
});
```

#### `device_update`
Получается при обновлении данных устройства.

```javascript
socket.on('device_update', (data) => {
  console.log('Device update:', data);
  // {
  //   device_id: 'timecard0',
  //   ptp_offset: 174,
  //   fpga_temp: 45.3,
  //   satellites_used: 14,
  //   timestamp: 1753689147.988943
  // }
});
```

#### `log_update`
Получается при появлении новых логов.

```javascript
socket.on('log_update', (data) => {
  console.log('Log update:', data);
  // {
  //   source: 'timecard',
  //   level: 'info',
  //   message: '[10:30:15] TimeCard FPGA temperature: 45.3°C (normal)',
  //   timestamp: 1753689147.988943
  // }
});
```

#### `metrics_update`
Получается при обновлении метрик.

```javascript
socket.on('metrics_update', (data) => {
  console.log('Metrics update:', data);
  // Полные расширенные метрики
});
```

### Запросы от клиента

#### `request_device_update`
Запрашивает обновление данных устройства.

```javascript
socket.emit('request_device_update', {
  device_id: 'timecard0'
});
```

## Коды ошибок

| Код | Описание |
|-----|----------|
| 200 | Успешный запрос |
| 400 | Неверный запрос |
| 404 | Ресурс не найден |
| 500 | Внутренняя ошибка сервера |

## Ограничения

- **Частота запросов**: Рекомендуется не более 10 запросов в секунду
- **Размер ответа**: Максимальный размер JSON ответа - 1MB
- **WebSocket соединения**: Максимум 100 одновременных соединений
- **История метрик**: Хранится последние 1000 записей

## Примеры использования

### Python

```python
import requests
import json

# Получение расширенных метрик
response = requests.get('http://localhost:8080/api/metrics/extended')
metrics = response.json()

# Получение списка устройств
response = requests.get('http://localhost:8080/api/devices')
devices = response.json()

# Проверка алертов
response = requests.get('http://localhost:8080/api/alerts')
alerts = response.json()
```

### JavaScript

```javascript
// Получение метрик
fetch('http://localhost:8080/api/metrics/extended')
  .then(response => response.json())
  .then(data => {
    console.log('Metrics:', data);
  });

// WebSocket подключение
const socket = io('http://localhost:8080');
socket.on('device_update', (data) => {
  updateDashboard(data);
});
```

### cURL

```bash
# Получение информации о системе
curl http://localhost:8080/

# Получение метрик
curl http://localhost:8080/api/metrics/extended

# Проверка алертов
curl http://localhost:8080/api/alerts

# Экспорт логов
curl http://localhost:8080/api/logs/export > timecard-logs.txt
```

## Версионирование

API использует семантическое версионирование. Текущая версия: `2.0.0`

- **Major**: Несовместимые изменения
- **Minor**: Новые функции с обратной совместимостью
- **Patch**: Исправления ошибок

## Поддержка

Для вопросов по API обращайтесь к разработчикам проекта или создавайте issues в репозитории. 