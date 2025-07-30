# 🕐 TimeCard PTP OCP Advanced Monitoring System v2.0

Полнофункциональная система мониторинга для TimeCard PTP OCP устройств с поддержкой всех аппаратных особенностей.

> 📌 **Быстрый старт**: См. [QUICKSTART.md](QUICKSTART.md)  
> 📌 **Полная инструкция**: См. [TIMECARD_ИНСТРУКЦИЯ_ОПТИМИЗИРОВАННАЯ.md](../TIMECARD_ИНСТРУКЦИЯ_ОПТИМИЗИРОВАННАЯ.md)  
> 📌 **Monitoring Stack (Docker/Grafana)**: См. [MONITORING-STACK.md](MONITORING-STACK.md)

## ✨ Возможности системы мониторинга

### 🔥 Расширенный мониторинг TimeCard

#### 🌡️ Thermal Monitoring
- **6 температурных сенсоров**: FPGA, осциллятор, плата, ambient, PLL, DDR
- **Автоматическое управление охлаждением**: Контроль скорости вентилятора
- **Тепловое регулирование**: Предотвращение перегрева с автоматическим throttling
- **Настраиваемые пороги**: Предупреждения и критические значения

#### ⚡ Power Monitoring
- **4 voltage rails**: 3.3V, 1.8V, 1.2V, 12V мониторинг
- **Анализ потребления тока**: По компонентам (FPGA, OSC, DDR, PHY)
- **Эффективность питания**: Расчет КПД и тепловыделения
- **Контроль стабильности**: Отклонения напряжений от номинала

#### 🛰️ GNSS Advanced Tracking
- **4 созвездия**: GPS, GLONASS, Galileo, BeiDou
- **Детальная статистика**: Видимые/используемые спутники по системам
- **Качество сигнала**: PDOP, HDOP, VDOP, C/N0 анализ
- **Antenna monitoring**: Состояние антенны, питание, короткие замыкания
- **Survey-in процесс**: Контроль калибровки положения
- **Помехозащищенность**: Обнаружение jamming и spoofing

#### ⚡ Oscillator Disciplining
- **Allan deviation анализ**: Стабильность частоты на разных интервалах
- **PI controller мониторинг**: Пропорциональный и интегральный термы
- **Holdover performance**: Качество удержания при потере опорного сигнала
- **Frequency error tracking**: Отслеживание дрейфа частоты в ppb
- **Lock duration**: Время нахождения в синхронизме

#### 📡 Advanced PTP Metrics
- **Path delay анализ**: Вариации, минимум, максимум, асимметрия
- **Packet statistics**: Статистика по всем типам PTP пакетов
- **Master clock tracking**: История смены мастер-часов
- **Performance scoring**: Общая оценка качества PTP синхронизации
- **UTC/TAI информация**: Leap seconds и смещения времени

#### 🔧 Hardware Status Monitoring
- **LED индикаторы**: Power, Sync, GNSS, Alarm состояния
- **SMA connectors**: Статус PPS и REF входов/выходов
- **FPGA информация**: Версия, температура, утилизация ресурсов
- **Network PHY**: Состояние портов, скорость, дуплекс
- **Calibration data**: Задержки кабелей, смещения timestamp

#### 🚨 Intelligent Alerting System
- **Настраиваемые пороги**: Для всех типов метрик
- **Многоуровневые алерты**: Warning, Critical, Info
- **История алертов**: Сохранение и анализ событий
- **Real-time уведомления**: WebSocket live updates

#### 📊 Health Scoring & Analytics
- **Comprehensive scoring**: Общая оценка здоровья системы
- **Component-level анализ**: Отдельные оценки для каждой подсистемы
- **Trend analysis**: Анализ трендов и деградации
- **Historical data**: Сохранение метрик для долгосрочного анализа

## 📁 Структура проекта

```
ptp-monitoring/
├── api/
│   ├── app.py                    # Основное приложение (auto-detection)
│   ├── timecard-api.py           # Базовый API (v1.0)
│   └── timecard-extended-api.py  # Расширенный API (v2.0)
├── web/
│   ├── timecard-dashboard.html   # Расширенный dashboard
│   └── timecard-dashboard-v1.html # Базовый dashboard
├── pwa/
│   └── index.html               # Mobile PWA приложение
├── scripts/
│   ├── start-monitoring-stack.sh # Управление Docker stack
│   └── prometheus-exporter.py   # Prometheus экспортер
├── config/
│   ├── prometheus.yml           # Конфигурация Prometheus
│   ├── alertmanager.yml         # Конфигурация AlertManager
│   └── grafana-dashboard.json   # Dashboard для Grafana
├── demo.py                      # Базовая демонстрация
├── demo-extended.py             # Расширенная демонстрация
└── requirements.txt             # Python зависимости
```

## 🔧 Конфигурация

### Переменные окружения

```bash
# API порт (по умолчанию 8080)
export TIMECARD_API_PORT=8080

# Интервалы обновления (мс)
export UPDATE_INTERVAL=5000
export QUICK_UPDATE_INTERVAL=2000

# Уровень логирования
export LOG_LEVEL=INFO
```

### Настройка порогов алертов

Редактируйте `api/timecard-extended-api.py`:

```python
alert_thresholds = {
    'thermal': {
        'fpga_temp': {'warning': 70, 'critical': 85},
        'osc_temp': {'warning': 60, 'critical': 75}
    },
    'ptp': {
        'offset_ns': {'warning': 1000, 'critical': 10000}
    }
}
```

## 🐳 Docker Support

```bash
# Build образ
docker build -t timecard-monitoring .

# Запуск контейнера
docker run -d -p 8080:8080 --privileged \
  -v /sys:/sys:ro \
  --name timecard-monitor \
  timecard-monitoring
```

## 📚 API Documentation

Полная документация API доступна по адресу:
- http://localhost:8080/api/

Основные endpoints:
- `/api/metrics/extended` - Все расширенные метрики
- `/api/devices` - Список устройств
- `/api/alerts` - Активные алерты
- `/api/health` - Состояние системы

## 🛠️ Разработка

### Требования
- Python 3.7+
- Linux kernel 5.12+
- TimeCard драйвер загружен

### Тестирование
```bash
# Unit тесты
python -m pytest tests/

# Интеграционные тесты
python tests/integration_test.py
```

### Вклад в проект
1. Fork репозитория
2. Создайте feature branch
3. Commit изменения
4. Push в branch
5. Создайте Pull Request

## 📄 Лицензия

Этот проект лицензирован под MIT License.

---

**TimeCard PTP OCP Advanced Monitoring System v2.0**  
*Professional-grade monitoring for precision timing applications*