# TimeCard PTP OCP Extended Monitoring Stack

Полная система мониторинга TimeCard PTP OCP с интеграцией Grafana, Prometheus и AlertManager.

## 🏗️ Архитектура системы

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   TimeCard      │    │   Prometheus     │    │    Grafana      │
│   Extended API  │◄──►│   Exporter       │◄──►│   Dashboard     │
│   (Port 8080)   │    │   (Port 9090)    │    │   (Port 3000)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │   Prometheus    │              │
         │              │   (Port 9091)   │              │
         │              └─────────────────┘              │
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │  AlertManager   │              │
         │              │   (Port 9093)   │              │
         │              └─────────────────┘              │
         │                                                │
         │              ┌─────────────────┐              │
         └─────────────►│ VictoriaMetrics │◄─────────────┘
                        │   (Port 9009)   │
                        └─────────────────┘
```

## 📊 Компоненты системы

### 1. TimeCard Extended API (Порт 8080)
- **Описание**: Расширенный API для мониторинга всех аспектов TimeCard
- **Функции**:
  - Веб-дашборд с real-time updates
  - REST API для всех метрик
  - WebSocket для live данных
  - Системы алертов и health scoring
  - Исторические данные

### 2. Prometheus Exporter (Порт 9090)
- **Описание**: Экспортер метрик TimeCard в формате Prometheus
- **Метрики**:
  - 📡 **PTP**: offset, path delay, packet stats, performance score
  - 🌡️ **Thermal**: 6 температурных сенсоров + охлаждение
  - ⚡ **Power**: 4 voltage rails + current consumption
  - 🛰️ **GNSS**: 4 constellation + accuracy + antenna status
  - ⚡ **Oscillator**: Allan deviation + stability + lock status
  - 🔧 **Hardware**: LEDs, FPGA, network ports, SMA connectors
  - 🚨 **Alerts**: активные + исторические по severity
  - 📊 **Health**: system + component scores

### 3. Prometheus (Порт 9091)
- **Описание**: Система сбора и хранения метрик
- **Функции**:
  - Сбор метрик каждые 30 секунд
  - Recording rules для агрегированных метрик
  - Alert rules для всех компонентов
  - Retention: 30 дней

### 4. Grafana (Порт 3000)
- **Описание**: Система визуализации и dashboards
- **Логин**: admin / timecard123
- **Функции**:
  - Comprehensive TimeCard dashboard
  - 18 panels для всех аспектов
  - Device selector
  - Алерты и аннотации
  - Автоматический import dashboard

### 5. AlertManager (Порт 9093)
- **Описание**: Система обработки и маршрутизации алертов
- **Функции**:
  - Email уведомления по компонентам
  - Slack интеграция
  - Группировка и подавление алертов
  - Эскалация по severity

### 6. VictoriaMetrics (Порт 9009)
- **Описание**: Long-term storage для метрик
- **Функции**:
  - Хранение данных до 1 года
  - Сжатие и оптимизация
  - Remote read/write для Prometheus

## 🚀 Быстрый запуск

### Режим Docker (Рекомендуется)

```bash
# Запуск полной системы
./start-monitoring-stack.sh start docker

# Проверка статуса
./start-monitoring-stack.sh status

# Просмотр логов
./start-monitoring-stack.sh logs docker

# Остановка
./start-monitoring-stack.sh stop docker
```

### Режим Development

```bash
# Запуск в dev режиме
./start-monitoring-stack.sh start dev

# Остановка
./start-monitoring-stack.sh stop dev
```

## 🌐 Веб-интерфейсы

| Сервис | URL | Логин | Описание |
|--------|-----|-------|----------|
| **TimeCard Dashboard** | http://localhost:8080 | - | Основной дашборд TimeCard |
| **Grafana** | http://localhost:3000 | admin:timecard123 | Система мониторинга |
| **Prometheus** | http://localhost:9091 | - | Сбор метрик |
| **AlertManager** | http://localhost:9093 | - | Управление алертами |

## 📊 API Endpoints

### TimeCard API
- `GET /api/health` - Health check
- `GET /api/metrics/extended` - Все расширенные метрики
- `GET /api/metrics/ptp/advanced` - Продвинутые PTP метрики
- `GET /api/metrics/thermal` - Тепловые метрики
- `GET /api/metrics/power` - Метрики питания
- `GET /api/metrics/gnss` - GNSS метрики
- `GET /api/metrics/oscillator` - Метрики осциллятора
- `GET /api/metrics/hardware` - Аппаратные метрики
- `GET /api/alerts` - Текущие алерты
- `GET /api/devices` - Список устройств

### Prometheus Exporter
- `GET /metrics` - Все метрики в формате Prometheus

## 🚨 Система алертов

### Критические алерты (Critical)
- **PTP Offset > 1ms** - Критическое отклонение PTP
- **Temperature > 85°C** - Критическая температура
- **Voltage deviation > 10%** - Критическое отклонение напряжения
- **GNSS Fix Lost** - Потеря GNSS фиксации
- **Oscillator Unlocked** - Разблокировка осциллятора

### Предупреждения (Warning)
- **PTP Path Delay > 10ms** - Высокая задержка PTP
- **Temperature > 75°C** - Высокая температура
- **Voltage deviation > 5%** - Отклонение напряжения
- **Low GNSS accuracy** - Низкая точность GNSS
- **High oscillator frequency error** - Ошибка частоты

## 📈 Grafana Dashboard

### Панели мониторинга:
1. **System Overview** - Общий health score всех компонентов
2. **PTP Offset** - График PTP offset в реальном времени
3. **Path Delay & Variance** - Задержка и вариация PTP
4. **Temperature Monitoring** - 6 температурных сенсоров
5. **Power Rails** - 4 voltage rails
6. **GNSS Satellites** - Количество спутников
7. **GNSS Constellations** - Pie chart созвездий
8. **GNSS Accuracy** - Точность позиционирования
9. **Oscillator Status** - Статус блокировки
10. **Frequency Error** - Ошибка частоты осциллятора
11. **Allan Deviation** - Стабильность осциллятора
12. **Power Consumption** - Потребление мощности
13. **Current Consumption** - Потребление тока
14. **Hardware Status** - LED, FPGA, network ports
15. **Network Ports** - Статус сетевых портов
16. **Active Alerts** - Таблица активных алертов
17. **PTP Packet Statistics** - Статистика PTP пакетов
18. **System Health Trends** - Тренды здоровья системы

### Автоматические функции:
- **Device Selector** - Выбор устройства
- **Auto-refresh** каждые 30 секунд
- **Threshold coloring** - Цветовая индикация
- **Alert annotations** - Аннотации алертов
- **Drill-down links** - Ссылки на детали

## 🔧 Конфигурация

### Prometheus (config/prometheus.yml)
- Интервал сбора: 30 секунд
- Retention: 30 дней
- Recording rules для агрегации
- Alert rules для всех компонентов

### AlertManager (config/alertmanager.yml)
- Email уведомления по командам
- Slack интеграция
- Группировка по severity
- Подавление дублированных алертов

### Grafana
- Автоматический import dashboards
- Datasource provisioning
- Persistent storage

## 📊 Метрики Prometheus

### PTP Метрики
```promql
# PTP offset
timecard_ptp_offset_nanoseconds{device_id="timecard0"}

# Path delay
timecard_ptp_path_delay_nanoseconds{device_id="timecard0"}

# Packet loss
timecard_ptp_packet_loss_percent{device_id="timecard0"}

# Performance score
timecard_ptp_performance_score{device_id="timecard0"}
```

### Тепловые метрики
```promql
# Температуры
timecard_temperature_celsius{device_id="timecard0",sensor="fpga_temp"}
timecard_temperature_celsius{device_id="timecard0",sensor="osc_temp"}

# Скорость вентилятора
timecard_fan_speed_rpm{device_id="timecard0"}

# Thermal throttling
timecard_thermal_throttling{device_id="timecard0"}
```

### GNSS метрики
```promql
# Спутники
timecard_gnss_satellites{device_id="timecard0",constellation="gps",type="used"}

# Точность
timecard_gnss_accuracy{device_id="timecard0",type="time",unit="nanoseconds"}

# Статус антенны
timecard_gnss_antenna_status{device_id="timecard0"}
```

### Метрики питания
```promql
# Напряжения
timecard_voltage_volts{device_id="timecard0",rail="3v3"}

# Отклонения напряжения
timecard_voltage_deviation_percent{device_id="timecard0",rail="3v3"}

# Потребление мощности
timecard_power_consumption_watts{device_id="timecard0",type="total"}
```

## 🐛 Troubleshooting

### 1. Сервисы не запускаются
```bash
# Проверка портов
sudo lsof -i :8080,9090,9091,3000,9093

# Проверка Docker
docker-compose ps
docker-compose logs

# Проверка зависимостей
./start-monitoring-stack.sh help
```

### 2. Нет метрик в Grafana
```bash
# Проверка Prometheus targets
curl http://localhost:9091/api/v1/targets

# Проверка exporter
curl http://localhost:9090/metrics

# Проверка API
curl http://localhost:8080/api/health
```

### 3. Не приходят алерты
```bash
# Проверка AlertManager
curl http://localhost:9093/api/v1/alerts

# Проверка rules
curl http://localhost:9091/api/v1/rules

# Проверка конфигурации
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### 4. Проблемы с производительностью
```bash
# Мониторинг ресурсов
docker stats

# Проверка метрик системы
curl http://localhost:9100/metrics

# Логи сервисов
./start-monitoring-stack.sh logs docker
```

## 📝 Логирование

### Уровни логирования:
- **DEBUG** - Детальная отладочная информация
- **INFO** - Общая информация о работе
- **WARNING** - Предупреждения
- **ERROR** - Ошибки

### Просмотр логов:
```bash
# Все сервисы
./start-monitoring-stack.sh logs docker

# Конкретный сервис
docker-compose logs -f timecard-api
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## 🔐 Безопасность

### Рекомендации:
1. **Grafana**: Смените пароль по умолчанию
2. **Prometheus**: Настройте authentication
3. **AlertManager**: Настройте SMTP credentials
4. **Network**: Используйте internal networks
5. **SSL/TLS**: Настройте HTTPS для production

### Бэкапы:
```bash
# Prometheus data
docker-compose exec prometheus tar -czf /prometheus-backup.tar.gz /prometheus

# Grafana data
docker-compose exec grafana tar -czf /grafana-backup.tar.gz /var/lib/grafana
```

## 📚 Дополнительные ресурсы

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [TimeCard PTP OCP Specification](https://www.opencompute.org/documents/ocp-timecard-specification-1-0-pdf)