# Quantum-PCI Monitoring System

## 🎯 Обзор

Система веб-мониторинга для устройств Quantum-PCI с поддержкой ptp_ocp драйвера. Предоставляет мониторинг реальных метрик, доступных в драйвере.

## ✅ Возможности системы

### 📊 Мониторинг метрик
- **PTP метрики**: offset (нс), drift (ppb) из sysfs
- **GNSS статус**: базовая синхронизация (SYNC/LOST)
- **SMA коннекторы**: конфигурация разъемов 1-4
- **Устройство**: серийный номер, источники времени
- **Real-time обновления**: данные обновляются каждые 5 секунд

### 🌐 Веб-интерфейсы
- **📉 Красивый дашборд** - современный интерфейс с градиентами
- **🔧 REST API** - программный интерфейс для интеграции
- **🔌 WebSocket** - обновления в реальном времени
- **📱 Адаптивный дизайн** - работает на всех устройствах

### ⚠️ Система алертов
- Настраиваемые пороги для PTP offset/drift
- Уведомления в реальном времени
- Исторические данные и тренды

## 🚀 Быстрый старт

### Требования
- Python 3.8+
- PCI устройство Quantum-PCI
- Загруженный драйвер ptp_ocp
- Права доступа к /sys/class/timecard/

### Установка и запуск

```bash
# Переход в директорию мониторинга
cd /home/shiwa-time/QuantumPCI-DRV/ptp-monitoring

# Создание виртуального окружения
python3 -m venv monitoring-env

# Активация окружения
source monitoring-env/bin/activate

# Установка зависимостей
pip install -r requirements.txt

# Запуск системы мониторинга
python3 quantum-pci-monitor.py
```

### Доступ к интерфейсам

После запуска система будет доступна:

- **🏠 Главная страница**: http://localhost:8080/ (красивый дашборд)
- **📊 Обычный дашборд**: http://localhost:8080/dashboard
- **🎯 Реалистичный дашборд**: http://localhost:8080/realistic-dashboard
- **🔧 API документация**: http://localhost:8080/api/
- **🔌 WebSocket**: ws://localhost:8080/ws

## 📡 API Endpoints

### Основные endpoints
- `GET /api/devices` - список обнаруженных устройств
- `GET /api/device/<id>/status` - статус конкретного устройства
- `GET /api/metrics/real` - реальные метрики всех устройств
- `GET /api/alerts` - активные алерты
- `GET /api/limitations` - описание ограничений системы

### Примеры использования

```bash
# Получить список устройств
curl http://localhost:8080/api/devices

# Получить статус устройства ocp0
curl http://localhost:8080/api/device/ocp0/status

# Получить реальные метрики
curl http://localhost:8080/api/metrics/real

# Проверить активные алерты
curl http://localhost:8080/api/alerts
```

## ⚙️ Конфигурация

### Переменные окружения
```bash
export MONITORING_PORT=8080
export MONITORING_HOST=0.0.0.0
export LOG_LEVEL=INFO
```

### Настройка алертов
Пороги алертов настраиваются в файле `api/quantum-pci-realistic-api.py`:

```python
'alerts': {
    'ptp': {
        'offset_ns': {'warning': 1000, 'critical': 10000},
        'drift_ppb': {'warning': 100, 'critical': 1000},
    }
}
```

## 🔧 Управление сервисом

### Запуск
```bash
cd /home/shiwa-time/QuantumPCI-DRV/ptp-monitoring
source monitoring-env/bin/activate
python3 quantum-pci-monitor.py &
```

### Остановка
```bash
pkill -f quantum-pci-monitor
```

### Перезапуск
```bash
pkill -f quantum-pci-monitor
cd /home/shiwa-time/QuantumPCI-DRV/ptp-monitoring
source monitoring-env/bin/activate
python3 quantum-pci-monitor.py &
```

## 🏗️ Структура проекта

```
ptp-monitoring/
├── api/                           # API и веб-интерфейсы
│   ├── quantum-pci-realistic-api.py  # Основной API модуль
│   ├── realistic-dashboard.html      # Красивый дашборд
│   ├── dashboard.html               # Обычный дашборд
│   └── prometheus-exporter.py       # Prometheus экспортер
├── web/                           # Дополнительные веб-ресурсы
│   └── dashboard.html             # Альтернативный интерфейс
├── monitoring-env/                # Виртуальное окружение Python
├── quantum-pci-monitor.py         # Главный скрипт запуска
├── test_monitor.py               # Тесты системы
├── requirements.txt              # Зависимости Python
└── README.md                     # Документация
```

## 🐛 Устранение неполадок

### Распространенные проблемы

1. **Сервер не запускается**
   ```bash
   # Проверить зависимости
   source monitoring-env/bin/activate
   pip install -r requirements.txt
   ```

2. **Quantum-PCI не обнаруживается**
   ```bash
   # Проверить драйвер
   lsmod | grep ptp_ocp
   ls /sys/class/timecard/
   ```

3. **API не отвечает**
   ```bash
   # Проверить процесс
   ps aux | grep quantum-pci-monitor
   # Проверить порт
   netstat -tlnp | grep 8080
   ```

4. **Дашборд не загружается**
   ```bash
   # Проверить доступность
   curl http://localhost:8080/
   # Открыть в браузере
   firefox http://localhost:8080/
   ```

### Проверка статуса системы

```bash
# Проверить процесс мониторинга
ps aux | grep quantum-pci-monitor

# Проверить доступность API
curl -s http://localhost:8080/api/devices | python3 -m json.tool

# Проверить метрики
curl -s http://localhost:8080/api/metrics/real | python3 -m json.tool
```

## 📊 Мониторинг метрик

### PTP метрики
- **offset_ns**: Смещение времени в наносекундах
- **drift_ppb**: Дрейф частоты в частях на миллиард
- **clock_source**: Источник времени (PPS, PTP, IRIG, etc.)

### GNSS статус
- **sync_status**: Статус синхронизации (SYNC/LOST)
- **available**: Доступность GNSS модуля

### SMA конфигурация
- **sma1-4**: Конфигурация разъемов (IN/OUT, тип сигнала)
- **available_inputs**: Доступные типы входных сигналов
- **available_outputs**: Доступные типы выходных сигналов

## 🔒 Безопасность

- Система работает только в локальной сети
- Нет аутентификации (предназначена для внутреннего использования)
- Доступ только к чтению sysfs интерфейсов
- Не требует root прав для веб-интерфейса

## 📝 Лицензия

Система мониторинга распространяется под лицензией проекта Quantum-PCI.