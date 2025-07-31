# 🕐 TimeCard PTP OCP Real Monitoring

## 📋 Обзор

Система реального мониторинга TimeCard PTP OCP, которая читает **реальные данные** из драйвера устройства без генерации демо-данных.

## ✅ Реализованные функции

### 📡 **PTP Мониторинг**
- **Clock Offset**: Реальное значение из `/sys/class/timecard/ocp0/clock_status_offset`
- **Clock Drift**: Реальное значение из `/sys/class/timecard/ocp0/clock_status_drift`
- **Clock Source**: Реальный источник времени из `/sys/class/timecard/ocp0/clock_source`

### 🛰️ **GNSS Мониторинг**
- **Sync Status**: Реальный статус из `/sys/class/timecard/ocp0/gnss_sync`
- **Fix Type**: Определяется на основе статуса синхронизации
- **Alert Generation**: Автоматические алерты при потере сигнала

### 🔌 **SMA Мониторинг**
- **SMA1-SMA4**: Реальные данные из `/sys/class/timecard/ocp0/sma1-4`
- **Connection Status**: Автоматическое определение подключения
- **Signal Type**: Чтение типа сигнала (IN/OUT)

### 🚨 **Система Алертов**
- **PTP Alerts**: Критические алерты при большом offset
- **GNSS Alerts**: Критические алерты при потере сигнала
- **Real-time Monitoring**: Обновление каждые 5 секунд

## 🚀 Быстрый старт

### 1. Запуск мониторинга
```bash
cd ptp-monitoring
./start-real-monitoring.sh start
```

### 2. Проверка статуса
```bash
./start-real-monitoring.sh status
```

### 3. Просмотр логов
```bash
./start-real-monitoring.sh logs
```

### 4. Остановка
```bash
./start-real-monitoring.sh stop
```

## 🌐 Веб-интерфейсы

### Основные URL:
- **Dashboard**: http://localhost:8080/dashboard
- **API**: http://localhost:8080/api/
- **Main Page**: http://localhost:8080/

### API Endpoints:
- **Устройства**: `GET /api/devices`
- **Реальные метрики**: `GET /api/metrics/real`
- **Алерты**: `GET /api/alerts`
- **Статус устройства**: `GET /api/device/ocp0/status`

## 📊 Примеры данных

### Реальные PTP данные:
```json
{
  "ptp": {
    "offset_ns": 0,
    "drift_ppb": 0,
    "clock_source": "PPS",
    "status": "normal"
  }
}
```

### Реальные GNSS данные:
```json
{
  "gnss": {
    "sync_status": "LOST @ 2025-07-31T06:30:59",
    "fix_type": "NO_FIX",
    "status": "critical"
  }
}
```

### Реальные SMA данные:
```json
{
  "sma": {
    "sma1": {"value": "IN: 10Mhz", "status": "connected"},
    "sma2": {"value": "IN: PPS1", "status": "connected"},
    "sma3": {"value": "OUT: 10Mhz", "status": "disconnected"},
    "sma4": {"value": "OUT: PHC", "status": "disconnected"}
  }
}
```

## 🔧 Технические детали

### Источники данных:
- **Sysfs Interface**: `/sys/class/timecard/ocp0/`
- **Real-time Reading**: Прямое чтение из драйвера
- **No Demo Data**: Только реальные значения

### Архитектура:
- **Flask API**: Веб-сервер на порту 8080
- **WebSocket**: Real-time обновления
- **Background Monitoring**: Фоновый сбор данных
- **Alert System**: Автоматическая генерация алертов

### Зависимости:
- Python 3.x
- Flask
- Flask-SocketIO
- Flask-CORS

## 🚨 Система алертов

### PTP Алерты:
- **Warning**: Offset > 1000 ns
- **Critical**: Offset > 10000 ns

### GNSS Алерты:
- **Critical**: Статус содержит "LOST"

### Пример алерта:
```json
{
  "type": "gnss_lost",
  "message": "GNSS сигнал потерян: LOST @ 2025-07-31T06:30:59",
  "severity": "critical",
  "timestamp": 1753944389.3581305
}
```

## 📈 Мониторинг в реальном времени

### WebSocket события:
- `device_update`: Обновления данных устройства
- `status_update`: Статус подключения
- `error`: Ошибки мониторинга

### Обновление данных:
- **Интервал**: 5 секунд
- **История**: Последние 1000 записей
- **Алерты**: Последние 500 алертов

## 🔍 Отладка

### Проверка драйвера:
```bash
ls -la /sys/class/timecard/ocp0/
```

### Проверка данных:
```bash
cat /sys/class/timecard/ocp0/clock_status_offset
cat /sys/class/timecard/ocp0/gnss_sync
cat /sys/class/timecard/ocp0/sma1
```

### Логи API:
```bash
tail -f real-api.log
```

## ⚠️ Ограничения

### Доступные данные:
- ✅ PTP offset и drift
- ✅ GNSS sync status
- ✅ SMA connector status
- ✅ Device information

### Недоступные данные:
- ❌ Температурные сенсоры (нет в драйвере)
- ❌ Мониторинг питания (нет в драйвере)
- ❌ Детальные GNSS данные (нет в драйвере)
- ❌ Данные осциллятора (нет в драйвере)

## 🎯 Преимущества

1. **Реальные данные**: Только фактические значения из драйвера
2. **Надежность**: Нет зависимости от демо-данных
3. **Производительность**: Минимальная нагрузка на систему
4. **Точность**: Прямое чтение из sysfs интерфейса
5. **Алерты**: Автоматические уведомления о проблемах

## 📝 Команды управления

```bash
# Запуск
./start-real-monitoring.sh start

# Остановка
./start-real-monitoring.sh stop

# Перезапуск
./start-real-monitoring.sh restart

# Статус
./start-real-monitoring.sh status

# Логи
./start-real-monitoring.sh logs

# Справка
./start-real-monitoring.sh help
```

## 🔗 Ссылки

- **API Documentation**: http://localhost:8080/
- **Real Metrics**: http://localhost:8080/api/metrics/real
- **Device Status**: http://localhost:8080/api/device/ocp0/status
- **Alerts**: http://localhost:8080/api/alerts 