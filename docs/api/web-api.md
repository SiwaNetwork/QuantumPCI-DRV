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

#### GET `/api/`

Возвращает общую информацию о системе мониторинга.

**Пример запроса:**
```bash
curl http://localhost:8080/api/
```

**Пример ответа:**
```json
{
  "api_name": "Quantum-PCI Realistic Monitoring API",
  "version": "2.0.0-realistic",
  "description": "Мониторинг ТОЛЬКО реальных метрик из ptp_ocp драйвера",
  "detected_devices": 1,
  "disclaimer": {
    "available_metrics": [
      "PTP offset/drift из clock_status_*",
      "GNSS sync статус из gnss_sync",
      "SMA конфигурация из sma1-4",
      "Источники времени из clock_source",
      "Серийный номер из serialnum"
    ],
    "limitations": [
      "Нет детального мониторинга температуры",
      "Нет мониторинга питания и напряжений",
      "Нет детального GNSS мониторинга",
      "Нет мониторинга LED индикаторов и FPGA состояния"
    ]
  },
  "endpoints": {
    "devices": "/api/devices",
    "device_status": "/api/device/<device_id>/status",
    "real_metrics": "/api/metrics/real",
    "alerts": "/api/alerts",
    "roadmap": "/api/roadmap"
  },
  "timestamp": 1759817253.8174174
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

### Реальные метрики

#### GET `/api/metrics/real`

Возвращает реальные метрики всех устройств из ptp_ocp драйвера.

**Пример запроса:**
```bash
curl http://localhost:8080/api/metrics/real
```

**Пример ответа:**
```json
{
  "metrics": {
    "ocp0": {
      "ptp": {
        "offset_ns": 0,
        "drift_ppb": 0,
        "clock_source": "PPS",
        "status": "ok"
      },
      "gnss": {
        "sync_status": "LOST @ 2025-10-06T05:45:11",
        "available": true,
        "status": "critical"
      },
      "sma": {
        "sma1": {"config": "10Mhz", "available": true},
        "sma2": {"config": "PPS", "available": true}
      },
      "timestamp": 1759817295.224438
    },
    "bmp280": {
      "temperature_c": 24.5,
      "pressure_hpa": 1013.25,
      "available": true
    },
    "ina219": {
      "voltage_v": 12.01,
      "current_ma": 245.3,
      "power_mw": 2945.0,
      "available": true
    }
  },
  "note": "Реальные метрики из ptp_ocp драйвера + датчики",
  "timestamp": 1759817295.224438
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

### Дорожная карта

#### GET `/api/roadmap`

Возвращает дорожную карту развития проекта.

**Пример запроса:**
```bash
curl http://localhost:8080/api/roadmap
```

### Дополнительные датчики

#### GET `/api/bno055`

Возвращает данные акселерометра и гироскопа BNO055.

**Пример запроса:**
```bash
curl http://localhost:8080/api/bno055
```

#### GET `/api/ina219`

Возвращает данные мониторинга питания INA219.

**Пример запроса:**
```bash
curl http://localhost:8080/api/ina219
```

#### GET `/api/bmp280`

Возвращает данные температуры и давления BMP280.

**Пример запроса:**
```bash
curl http://localhost:8080/api/bmp280
```

### PTP Network мониторинг

#### GET `/api/ptp-network`

Возвращает метрики сетевых карт с PTP.

**Пример запроса:**
```bash
curl http://localhost:8080/api/ptp-network
```

#### GET `/api/ptp-network/health`

Возвращает статус здоровья PTP сетевых карт.

**Пример запроса:**
```bash
curl http://localhost:8080/api/ptp-network/health
```

### Логи

#### GET `/api/logs`

Возвращает последние 100 строк логов системы.

**Пример запроса:**
```bash
curl http://localhost:8080/api/logs
```

### Экспорт данных

#### GET `/api/export`

Экспортирует все данные системы.

**Пример запроса:**
```bash
curl http://localhost:8080/api/export
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

# Получение реальных метрик
response = requests.get('http://localhost:8080/api/metrics/real')
metrics = response.json()

# Получение списка устройств
response = requests.get('http://localhost:8080/api/devices')
devices = response.json()

# Проверка алертов
response = requests.get('http://localhost:8080/api/alerts')
alerts = response.json()

# Получение данных датчиков
response = requests.get('http://localhost:8080/api/bno055')
bno055_data = response.json()

# Мониторинг питания
response = requests.get('http://localhost:8080/api/ina219')
ina219_data = response.json()
```

### JavaScript

```javascript
// Получение метрик
fetch('http://localhost:8080/api/metrics/real')
  .then(response => response.json())
  .then(data => {
    console.log('Metrics:', data);
  });

// Получение данных датчиков
fetch('http://localhost:8080/api/bno055')
  .then(response => response.json())
  .then(data => {
    console.log('BNO055:', data);
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
curl http://localhost:8080/api/

# Получение реальных метрик
curl http://localhost:8080/api/metrics/real

# Проверка алертов
curl http://localhost:8080/api/alerts

# Получение дорожной карты
curl http://localhost:8080/api/roadmap

# Данные датчиков
curl http://localhost:8080/api/bno055
curl http://localhost:8080/api/ina219
curl http://localhost:8080/api/bmp280

# Экспорт данных
curl http://localhost:8080/api/export > quantum-export.json
```

## Версионирование

API использует семантическое версионирование. Текущая версия: `2.0.0`

- **Major**: Несовместимые изменения
- **Minor**: Новые функции с обратной совместимостью
- **Patch**: Исправления ошибок

## Поддержка

Для вопросов по API обращайтесь к разработчикам проекта или создавайте issues в репозитории. 