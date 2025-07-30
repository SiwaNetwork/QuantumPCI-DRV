# Веб API для мониторинга TimeCard PTP OCP

## Обзор

Веб API предоставляет полный доступ к данным мониторинга TimeCard через REST интерфейс. API поддерживает как базовые, так и расширенные метрики с возможностью WebSocket обновлений в реальном времени.

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
  "service": "TimeCard PTP OCP Monitoring API v2.0",
  "version": "2.0.0",
  "timestamp": 1753689738.2285047,
  "devices_count": 1,
  "features": [
    "Complete thermal monitoring (FPGA, oscillator, board, DDR, PLL)",
    "Advanced GNSS receiver status & satellite constellation tracking",
    "Oscillator disciplining analysis with Allan deviation",
    "Extended PTP metrics with packet statistics & path analysis",
    "Hardware monitoring (LEDs, SMA connectors, PHY, calibration)",
    "Power consumption tracking with voltage/current monitoring",
    "Intelligent alerting system with configurable thresholds",
    "Historical data storage & trending analysis",
    "WebSocket real-time updates",
    "Health scoring with comprehensive system assessment"
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
    "thermal_sensors": ["fpga", "oscillator", "board", "ambient", "pll", "ddr"],
    "gnss_constellations": ["GPS", "GLONASS", "Galileo", "BeiDou"],
    "power_rails": ["3.3V", "1.8V", "1.2V", "12V"],
    "sma_connectors": ["PPS_IN", "PPS_OUT", "REF_IN", "REF_OUT"],
    "led_indicators": ["power", "sync", "gnss", "alarm"],
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
    "frequency": -6.298276978383928,
    "offset": 174,
    "path_delay": 2433,
    "port_state": 8,
    "timestamp": 1753689147.988943,
    "gnss": {
      "accuracy": {
        "hdop": 1.2264472796260772,
        "horizontal_accuracy": 2.5120287484198225,
        "pdop": 1.6646297157051344,
        "time_accuracy": 14.553207739085206,
        "vdop": 1.9533574282471065,
        "vertical_accuracy": 3.7646968814843307
      },
      "antenna": {
        "open_circuit": false,
        "power": "ON",
        "short_circuit": false,
        "signal_strength_db": 45,
        "status": "OK"
      },
      "constellations": {
        "beidou": 0,
        "galileo": 2,
        "glonass": 4,
        "gps": 8
      },
      "fix": {
        "fix_quality": "GPS+GLONASS",
        "fix_type": "3D",
        "satellites_tracked": 15,
        "satellites_used": 14,
        "satellites_visible": 17
      },
      "interference": {
        "cno_mean": 42.325033762688356,
        "jamming_level": 2,
        "jamming_state": "OK",
        "multipath_indicator": 0.47440339679988025,
        "spoofing_state": "OK"
      },
      "overall_health": 100,
      "survey": {
        "accuracy_requirement_met": true,
        "active": false,
        "duration_seconds": 3600,
        "position_valid": true,
        "progress_percent": 100
      }
    },
    "thermal": {
      "ambient_temp": {
        "status": "normal",
        "threshold_critical": 50,
        "threshold_warning": 40,
        "unit": "°C",
        "value": 25.5
      },
      "board_temp": {
        "status": "normal",
        "threshold_critical": 80,
        "threshold_warning": 65,
        "unit": "°C",
        "value": 41.6
      },
      "ddr_temp": {
        "status": "normal",
        "threshold_critical": 999,
        "threshold_warning": 999,
        "unit": "°C",
        "value": 35.6
      },
      "fpga_temp": {
        "status": "normal",
        "threshold_critical": 85,
        "threshold_warning": 70,
        "unit": "°C",
        "value": 45.3
      },
      "osc_temp": {
        "status": "normal",
        "threshold_critical": 75,
        "threshold_warning": 60,
        "unit": "°C",
        "value": 38.0
      },
      "pll_temp": {
        "status": "normal",
        "threshold_critical": 999,
        "threshold_warning": 999,
        "unit": "°C",
        "value": 39.3
      },
      "cooling": {
        "auto_fan_control": true,
        "fan_speed": 1556,
        "thermal_throttling": false
      }
    },
    "power": {
      "voltage_3v3": {
        "deviation_percent": 4.32,
        "nominal": 3.3,
        "status": "normal",
        "unit": "V",
        "value": 3.443
      },
      "voltage_1v8": {
        "deviation_percent": 1.33,
        "nominal": 1.8,
        "status": "normal",
        "unit": "V",
        "value": 1.824
      },
      "voltage_1v2": {
        "deviation_percent": -1.7,
        "nominal": 1.2,
        "status": "normal",
        "unit": "V",
        "value": 1.18
      },
      "voltage_12v": {
        "deviation_percent": 0.12,
        "nominal": 12.0,
        "status": "normal",
        "unit": "V",
        "value": 12.014
      },
      "current_total": {
        "status": "normal",
        "unit": "mA",
        "value": 1768
      },
      "current_fpga": {
        "status": "normal",
        "unit": "mA",
        "value": 805
      },
      "current_osc": {
        "status": "normal",
        "unit": "mA",
        "value": 411
      },
      "current_ddr": {
        "status": "normal",
        "unit": "mA",
        "value": 308
      },
      "current_phy": {
        "status": "normal",
        "unit": "mA",
        "value": 244
      },
      "power_consumption": {
        "efficiency_percent": 86,
        "heat_dissipation": 3.19,
        "idle_power_watts": 8.5,
        "peak_power_watts": 25.0,
        "total_watts": 21.24
      }
    },
    "oscillator": {
      "basic": {
        "disciplining_state": "locked",
        "holdover": false,
        "lock_duration_seconds": 3658,
        "locked": true,
        "reference_source": "GNSS"
      },
      "frequency": {
        "frequency_drift_ppb_s": 0.06026776817750834,
        "frequency_error_ppb": -15.215288588261144,
        "frequency_stability_100s": 3.052512627587126e-12,
        "frequency_stability_10s": 8.572052367656592e-12,
        "frequency_stability_1s": 1.7338575501746188e-11
      },
      "allan_deviation": {
        "tau_1s": 2.207109261301891e-11,
        "tau_10s": 8.668081268690784e-12,
        "tau_100s": 3.326881396957649e-12,
        "tau_1000s": 1.8138403936926092e-12
      },
      "holdover": {
        "holdover_accuracy_ns": 500,
        "holdover_performance_grade": "good",
        "last_holdover_duration": 0,
        "max_holdover_time": 3600
      },
      "servo": {
        "integral_term": -22.527075037617028,
        "pi_controller_state": "locked",
        "proportional_term": 5.925923420753529,
        "servo_offset_ns": -70.77348726387206,
        "time_constant_seconds": 300
      },
      "overall_stability": "good"
    },
    "ptp_advanced": {
      "basic": {
        "clock_accuracy": "within_25ns",
        "frequency_adjustment_ppb": -6.298276978383928,
        "offset_ns": 174,
        "path_delay_ns": 2433
      },
      "delay_stats": {
        "asymmetry_ns": 20.303557547141963,
        "delay_mechanism": "E2E",
        "path_delay_max": 2656.463792433019,
        "path_delay_min": 2314.1482574420234,
        "path_delay_variance": 81.44025551641855
      },
      "master": {
        "domain_number": 0,
        "grandmaster_id": "001122.fffe.334455",
        "master_changes_count": 0,
        "master_clock_id": "001122.fffe.334455",
        "steps_removed": 1,
        "time_source": "GNSS",
        "utc_offset": 37
      },
      "packet_stats": {
        "announce_rx": 1354,
        "announce_tx": 939,
        "delay_req_tx": 1946,
        "delay_resp_rx": 1269,
        "out_of_order_packets": 3,
        "packet_loss_percent": 0.441,
        "sync_rx": 12959,
        "sync_tx": 7707
      },
      "performance_score": 90
    },
    "hardware": {
      "leds": {
        "alarm_led": "off",
        "gnss_led": "green",
        "power_led": "green",
        "sync_led": "green"
      },
      "fpga": {
        "build_date": "2024-01-15",
        "dna": "0x123456789ABCDEF0",
        "logic_utilization": 62,
        "memory_utilization": 41,
        "temperature": 46.74251200085072,
        "utilization_percent": 62,
        "version": "2.1.3"
      },
      "phy": {
        "port1": {
          "auto_negotiation": true,
          "duplex": "full",
          "link_up": true,
          "speed_mbps": 1000
        },
        "port2": {
          "auto_negotiation": true,
          "duplex": "full",
          "link_up": true,
          "speed_mbps": 1000
        }
      },
      "sma_connectors": {
        "pps_in": {
          "connected": false,
          "frequency": 1.0,
          "signal_present": false
        },
        "pps_out": {
          "enabled": true,
          "signal_strength": 3.384154229565501
        },
        "ref_in": {
          "connected": false,
          "frequency": 10000000
        },
        "ref_out": {
          "enabled": true,
          "frequency": 10000000,
          "signal_strength": 3.3229796695623426
        }
      },
      "calibration": {
        "cable_delay_ns": 125.5,
        "calibrated": true,
        "calibration_date": "2024-01-01",
        "factory_defaults": false,
        "last_calibration_method": "factory",
        "timestamp_offset_ns": 0
      },
      "overall_health": 100
    }
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
  "uptime_seconds": 86400,
  "last_sync": "2024-01-15T10:30:00Z",
  "gnss_locked": true,
  "oscillator_locked": true,
  "ptp_synchronized": true,
  "temperature_normal": true,
  "power_normal": true,
  "overall_health": 95,
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
      "category": "thermal",
      "message": "FPGA temperature approaching threshold: 68°C",
      "device_id": "timecard0",
      "timestamp": 1753689147.988943,
      "acknowledged": false
    }
  ],
  "total_active": 1,
  "total_critical": 0,
  "total_warning": 1,
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