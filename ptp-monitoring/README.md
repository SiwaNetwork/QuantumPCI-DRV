# 🕐 TimeCard PTP OCP Advanced Monitoring System v2.0

Полнофункциональная система мониторинга для TimeCard PTP OCP устройств с поддержкой всех аппаратных особенностей.

## ✨ Возможности

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

### 🎯 Стандартные возможности
- **Real-time dashboard**: Современный веб-интерфейс
- **Mobile PWA**: Адаптивное мобильное приложение
- **REST API**: Полный набор endpoints
- **WebSocket updates**: Live обновления данных
- **Export функции**: Логи и конфигурации
- **Service management**: Перезапуск сервисов

## 🚀 Быстрый старт

### Расширенный режим (рекомендуется)
```bash
# Клонируем репозиторий
git clone <repository>
cd ptp-monitoring

# Установка зависимостей
pip install -r requirements.txt

# Запуск расширенной системы
python3 demo-extended.py
```

### Альтернативные способы запуска

#### Через основное приложение
```bash
python3 api/app.py
```

#### Через расширенный API напрямую
```bash
python3 api/timecard-extended-api.py
```

#### Базовый режим (legacy)
```bash
python3 demo.py
```

## 🌐 Веб-интерфейсы

После запуска доступны следующие интерфейсы:

- **🏠 Главная страница**: http://localhost:8080/
- **📊 Extended Dashboard**: http://localhost:8080/dashboard  
- **📱 Mobile PWA**: http://localhost:8080/pwa
- **🔧 API Documentation**: http://localhost:8080/api/
- **ℹ️ System Info**: http://localhost:8080/info

## 📡 API Endpoints

### Расширенные endpoints

```http
GET  /api/devices                    # Список всех TimeCard устройств
GET  /api/device/{id}/status         # Полный статус устройства
GET  /api/metrics/extended           # Расширенные метрики всех устройств
GET  /api/metrics/history/{id}       # История метрик устройства
GET  /api/alerts                     # Активные алерты
GET  /api/alerts/history             # История алертов
GET  /api/config                     # Конфигурация системы
GET  /api/logs/export                # Экспорт логов
POST /api/restart/{service}          # Перезапуск сервисов
```

### Базовые endpoints (совместимость)

```http
GET  /api/metrics                    # Базовые PTP метрики
POST /api/restart/{service}          # Перезапуск сервисов
GET  /api/config                     # Конфигурация
GET  /api/logs/export                # Экспорт логов
```

## 🔧 Конфигурация

### Пороговые значения алертов

Система поддерживает настраиваемые пороги для всех типов метрик:

```python
alert_thresholds = {
    'thermal': {
        'fpga_temp': {'warning': 70, 'critical': 85},
        'osc_temp': {'warning': 60, 'critical': 75},
        # ...
    },
    'ptp': {
        'offset_ns': {'warning': 1000, 'critical': 10000},
        # ...
    },
    # ...
}
```

### Поддерживаемые созвездия

- **GPS**: Система позиционирования США
- **GLONASS**: Российская система ГЛОНАСС  
- **Galileo**: Европейская система навигации
- **BeiDou**: Китайская система навигации

## 🛠️ Требования

### Программные требования
- Python 3.7+
- Flask 2.0+
- Flask-SocketIO 5.0+
- Flask-CORS 4.0+

### Аппаратные требования  
- TimeCard PTP OCP устройство
- Linux система с поддержкой sysfs/debugfs
- Драйвер ptp_ocp

### Поддерживаемые TimeCard версии
- Hardware: Rev C и новее
- Firmware: v2.1.3 и новее
- FPGA: Xilinx версии

## 📊 Monitoring Features Matrix

| Feature | Basic Mode | Extended Mode |
|---------|------------|---------------|
| PTP Metrics | ✅ | ✅ |
| WebSocket Updates | ✅ | ✅ |
| Thermal Monitoring | ❌ | ✅ (6 sensors) |
| Power Monitoring | ❌ | ✅ (4 rails) |
| GNSS Tracking | ❌ | ✅ (4 constellations) |
| Oscillator Analysis | ❌ | ✅ (Allan deviation) |
| Hardware Status | ❌ | ✅ (LEDs, SMA, PHY) |
| Advanced Alerts | ❌ | ✅ |
| Health Scoring | ❌ | ✅ |
| Historical Data | ❌ | ✅ |

## 🔍 Диагностика

### Проверка статуса
```bash
# Проверка доступности API
curl http://localhost:8080/api/devices

# Получение информации о системе
curl http://localhost:8080/info

# Экспорт логов
curl http://localhost:8080/api/logs/export > timecard-logs.txt
```

### Системные требования
```bash
# Проверка наличия TimeCard
lspci -d 1d9b:

# Проверка драйвера
lsmod | grep ptp_ocp

# Проверка sysfs
ls /sys/class/timecard/
```

## 🐛 Устранение неполадок

### Частые проблемы

**1. "Extended API not found"**
```bash
# Убедитесь, что файл существует
ls -la api/timecard-extended-api.py

# Проверьте права доступа
chmod +x api/timecard-extended-api.py
```

**2. "Module import error"**
```bash
# Установите зависимости
pip install -r requirements.txt
```

**3. "Device not found"**
```bash
# Проверьте наличие TimeCard
lspci -d 1d9b:

# Проверьте загрузку драйвера
sudo modprobe ptp_ocp
```

### Debug режим
```bash
# Запуск с подробным логированием
python3 demo-extended.py --debug

# Проверка WebSocket соединения
# Откройте Developer Tools в браузере -> Network -> WS
```

## 📈 Performance

### Интервалы обновления
- **WebSocket updates**: 2 секунды (быстрые метрики)
- **Full refresh**: 5 секунд (все панели)
- **Background monitoring**: 60 секунд (история)
- **Log monitoring**: 10-30 секунд (события)

### Ресурсы системы
- **CPU usage**: ~1-2% на современных системах
- **Memory**: ~50-100 MB
- **Network**: Минимальный трафик
- **Storage**: ~1 MB/день логов

## 🤝 Разработка

### Структура проекта
```
ptp-monitoring/
├── api/
│   ├── timecard-extended-api.py  # Расширенный API
│   ├── app.py                    # Основное приложение
│   └── ptp-api.py               # Базовый API (legacy)
├── web/
│   ├── timecard-dashboard.html   # Расширенный dashboard
│   └── dashboard.html           # Базовый dashboard
├── pwa/                         # PWA приложение
├── config/                      # Конфигурации
├── scripts/                     # Скрипты установки
└── demo-extended.py            # Расширенная демо
```

### Добавление новых метрик
1. Обновите `TimeCardMonitor` класс в `timecard-extended-api.py`
2. Добавьте соответствующие элементы в `timecard-dashboard.html`
3. Обновите JavaScript для отображения новых данных

## 📄 Лицензия

MIT License - смотрите файл LICENSE для деталей.

## 🆘 Поддержка

- **Issues**: GitHub Issues  
- **Documentation**: Встроенная справка в `/api/`
- **API Reference**: http://localhost:8080/api/

---

**🕐 TimeCard PTP OCP Advanced Monitoring System v2.0**  
*Professional-grade monitoring for precision timing applications*