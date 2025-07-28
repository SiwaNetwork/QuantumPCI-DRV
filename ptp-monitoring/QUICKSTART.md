                                                                                                                                                                              # 🚀 TimeCard PTP OCP Advanced Monitoring - Quick Start

Быстрое руководство по запуску полнофункциональной системы мониторинга TimeCard PTP OCP v2.0.

## ⚡ Быстрый запуск (1 минута)

```bash
# 1. Переходим в директорию проекта
cd ptp-monitoring

# 2. Устанавливаем зависимости
pip install --break-system-packages -r requirements.txt

# 3. Запускаем расширенную систему
python3 demo-extended.py
```

После запуска система будет доступна по адресам:
- **📊 Extended Dashboard**: http://localhost:8080/dashboard
- **📱 Mobile PWA**: http://localhost:8080/pwa
- **🔧 API Documentation**: http://localhost:8080/api/
- **🏠 Main Page**: http://localhost:8080/

## 🎯 Что вы получите

### ✨ Расширенный мониторинг
- **🌡️ Thermal monitoring**: 6 температурных сенсоров (FPGA, oscillator, board, ambient, PLL, DDR)
- **⚡ Power analysis**: 4 voltage rails + current consumption по компонентам
- **🛰️ GNSS tracking**: GPS, GLONASS, Galileo, BeiDou созвездия
- **⚡ Oscillator disciplining**: Allan deviation анализ + PI controller
- **📡 Advanced PTP**: Path delay analysis, packet statistics, master tracking
- **🔧 Hardware status**: LEDs, SMA connectors, FPGA info, network PHY
- **🚨 Smart alerting**: Configurable thresholds + real-time notifications
- **📊 Health scoring**: Comprehensive system assessment
- **📈 Historical data**: Trending analysis + WebSocket live updates

## 🔍 Проверка работы

### Тест API
```bash
# Проверка основной информации
curl http://localhost:8080/info

# Получение расширенных метрик
curl http://localhost:8080/api/metrics/extended

# Список устройств
curl http://localhost:8080/api/devices

# Статус конкретного устройства
curl http://localhost:8080/api/device/timecard0/status

# Активные алерты
curl http://localhost:8080/api/alerts
```

### Ожидаемый результат
```json
{
  "system": "TimeCard PTP OCP Monitoring System",
  "version": "2.0.0",
  "extended_api_loaded": true,
  "features": {
    "thermal_monitoring": true,
    "gnss_tracking": true,
    "oscillator_disciplining": true,
    "hardware_monitoring": true,
    "power_monitoring": true,
    "advanced_alerting": true
  }
}
```

## 🛠️ Альтернативные режимы запуска

### Режим 1: Прямой запуск расширенного API
```bash
python3 api/timecard-extended-api.py
```

### Режим 2: Через основное приложение (auto-detection)
```bash
python3 api/app.py
```

### Режим 3: Базовый режим (legacy)
```bash
python3 demo.py
```

## 📊 Интерфейсы мониторинга

### 🖥️ Extended Dashboard
- **URL**: http://localhost:8080/dashboard
- **Возможности**:
  - Real-time мониторинг всех подсистем
  - Thermal status с цветовой индикацией
  - GNSS constellation tracking
  - Oscillator disciplining analysis  
  - Advanced PTP metrics
  - Hardware status monitoring
  - Power consumption analysis
  - Intelligent alerting system
  - System health scoring

### 📱 Mobile PWA
- **URL**: http://localhost:8080/pwa
- **Возможности**:
  - Адаптивный дизайн для мобильных устройств
  - Офлайн support
  - Push notifications
  - Все функции desktop версии

### 🔧 API Reference
- **URL**: http://localhost:8080/api/
- **Extended endpoints**:
  - `/api/devices` - Список TimeCard устройств
  - `/api/device/{id}/status` - Полный статус устройства
  - `/api/metrics/extended` - Расширенные метрики
  - `/api/alerts` - Система алертов
  - `/api/config` - Конфигурация

## 🔧 Конфигурация

### Настройка threshold алертов
Отредактируйте файл `api/timecard-extended-api.py`:

```python
alert_thresholds = {
    'thermal': {
        'fpga_temp': {'warning': 70, 'critical': 85},
        'osc_temp': {'warning': 60, 'critical': 75},
        # Ваши пороги...
    },
    'ptp': {
        'offset_ns': {'warning': 1000, 'critical': 10000},
        # Ваши пороги...
    }
}
```

### Интервалы обновления
```python
# В TimeCardDashboard класс (timecard-dashboard.html)
updateInterval = 5000;      # Полное обновление (5 сек)
quickUpdateInterval = 2000; # WebSocket updates (2 сек)
backgroundInterval = 60000; # История метрик (1 мин)
```

## 🐛 Устранение неполадок

### Проблема: "Module not found"
```bash
# Установите зависимости
pip install --break-system-packages -r requirements.txt

# Или с виртуальным окружением
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Проблема: "Port 8080 already in use"
```bash
# Найдите процесс
sudo lsof -i :8080

# Или измените порт в коде
# В файле api/timecard-extended-api.py замените:
socketio.run(app, host='0.0.0.0', port=8081, ...)
```

### Проблема: "Extended API not found"
```bash
# Проверьте файлы
ls -la api/
chmod +x api/timecard-extended-api.py

# Или запустите в базовом режиме
python3 demo.py
```

### Проблема: WebSocket не работает
- Откройте Developer Tools в браузере
- Проверьте вкладку Network -> WS
- Убедитесь, что нет блокировки firewall

## 📈 Performance мониторинг

### Системные требования
- **CPU**: ~1-2% на современных системах
- **Memory**: ~50-100 MB
- **Network**: Минимальный трафик
- **Storage**: ~1 MB/день логов

### Оптимизация
```python
# Уменьшить интервалы для production
updateInterval = 10000;     # 10 секунд вместо 5
backgroundInterval = 300000; # 5 минут вместо 1

# Отключить отладочные сообщения
socketio.run(app, debug=False, ...)
```

## 🎓 Дополнительные возможности

### Export логов
```bash
curl http://localhost:8080/api/logs/export > timecard-logs.txt
```

### Restart сервисов
```bash
curl -X POST http://localhost:8080/api/restart/ptp4l
curl -X POST http://localhost:8080/api/restart/chronyd
```

### Получение истории метрик
```bash
curl http://localhost:8080/api/metrics/history/timecard0
```

### WebSocket подключение (JavaScript)
```javascript
const socket = io();
socket.on('metrics_update', (data) => {
    console.log('New metrics:', data);
});
```

## 🌟 Отличия от базовой версии

| Feature | Basic v1.0 | Extended v2.0 |
|---------|------------|---------------|
| PTP Metrics | ✅ Basic | ✅ Advanced |
| Thermal Monitoring | ❌ | ✅ 6 sensors |
| Power Monitoring | ❌ | ✅ 4 rails |
| GNSS Tracking | ❌ | ✅ 4 constellations |
| Oscillator Analysis | ❌ | ✅ Allan deviation |
| Hardware Status | ❌ | ✅ Complete |
| Alerting System | ❌ | ✅ Intelligent |
| Health Scoring | ❌ | ✅ Comprehensive |
| Historical Data | ❌ | ✅ Full tracking |
| WebSocket Updates | ✅ Basic | ✅ Advanced |

## 🏆 Готово!

Теперь у вас запущена полнофункциональная система мониторинга TimeCard PTP OCP с профессиональными возможностями для precision timing приложений.

**Next Steps**:
1. Откройте http://localhost:8080/dashboard
2. Изучите все доступные метрики
3. Настройте пороги алертов под ваши нужды
4. Интегрируйте с вашими monitoring системами

---
**TimeCard PTP OCP Advanced Monitoring System v2.0**  
*Professional-grade monitoring for precision timing applications*