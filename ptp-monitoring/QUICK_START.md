# 🚀 Быстрый старт - TimeCard Real Monitoring

## ⚡ Запуск за 30 секунд

### 1. Запуск мониторинга
```bash
cd ptp-monitoring
./start-real-monitoring.sh start
```

### 2. Открыть веб-интерфейс
Откройте браузер и перейдите по адресу:
**http://localhost:8080/dashboard**

## 📊 Что вы увидите

### 📡 PTP Status
- **Offset**: Реальное значение из драйвера (ns)
- **Drift**: Реальное значение из драйвера (ppb)
- **Clock Source**: Реальный источник времени (PPS/PTP/GNSS)
- **Status**: normal/warning/critical

### 🛰️ GNSS Status
- **Sync Status**: Реальный статус синхронизации
- **Fix Type**: 3D/NO_FIX/UNKNOWN

### 🔌 SMA Connectors
- **SMA1-SMA4**: Статус подключения разъемов
- **Connection**: connected/disconnected

### 🚨 Active Alerts
- **Критические алерты**: GNSS потеря сигнала
- **Предупреждения**: PTP offset превышен

## 🔧 Управление

### Команды скрипта:
```bash
./start-real-monitoring.sh start    # Запуск
./start-real-monitoring.sh stop     # Остановка
./start-real-monitoring.sh restart  # Перезапуск
./start-real-monitoring.sh status   # Статус
./start-real-monitoring.sh logs     # Логи
```

### API Endpoints:
- **Dashboard**: http://localhost:8080/dashboard
- **Real Metrics**: http://localhost:8080/api/metrics/real
- **Alerts**: http://localhost:8080/api/alerts
- **Device Info**: http://localhost:8080/api/devices

## ✅ Проверка работы

### 1. Проверка API
```bash
curl http://localhost:8080/api/metrics/real
```

### 2. Проверка алертов
```bash
curl http://localhost:8080/api/alerts
```

### 3. Проверка статуса
```bash
./start-real-monitoring.sh status
```

## 🎯 Реальные данные

Система читает **ТОЛЬКО реальные данные** из драйвера:

- ✅ `/sys/class/timecard/ocp0/clock_status_offset`
- ✅ `/sys/class/timecard/ocp0/clock_status_drift`
- ✅ `/sys/class/timecard/ocp0/gnss_sync`
- ✅ `/sys/class/timecard/ocp0/sma1-4`

**Никаких демо-данных!**

## 🚨 Устранение проблем

### Проблема: Dashboard не загружается
```bash
# Проверьте, что API запущен
./start-real-monitoring.sh status

# Проверьте логи
./start-real-monitoring.sh logs
```

### Проблема: Нет данных
```bash
# Проверьте драйвер
ls -la /sys/class/timecard/

# Проверьте устройство
cat /sys/class/timecard/ocp0/clock_status_offset
```

### Проблема: Порт занят
```bash
# Остановите старые процессы
pkill -f "python.*timecard"

# Перезапустите
./start-real-monitoring.sh restart
```

## 📈 Real-time обновления

- **Автообновление**: каждые 5 секунд
- **WebSocket**: real-time уведомления
- **Логи**: live обновления в консоли

## 🎉 Готово!

Теперь у вас есть полноценный мониторинг реальных данных TimeCard!

**Откройте http://localhost:8080/dashboard и наслаждайтесь!** 🚀 