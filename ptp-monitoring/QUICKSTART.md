# 🚀 Quantum-PCI TimeCard PTP OCP Advanced Monitoring - Quick Start

Быстрое руководство по запуску полнофункциональной системы мониторинга Quantum-PCI TimeCard PTP OCP v2.0.

> 📌 **Примечание**: Для полной инструкции по установке драйвера и базовой настройке см. [TIMECARD_ИНСТРУКЦИЯ_ОПТИМИЗИРОВАННАЯ.md](../TIMECARD_ИНСТРУКЦИЯ_ОПТИМИЗИРОВАННАЯ.md)

## ⚡ Быстрый запуск мониторинга

```bash
# Предполагается, что драйвер уже установлен
cd ptp-monitoring
pip install -r requirements.txt
python3 demo-extended.py
```

## 🎯 Что включает расширенный мониторинг

### ✨ Дополнительные возможности v2.0
- **🌡️ Thermal monitoring**: 6 температурных сенсоров (FPGA, oscillator, board, ambient, PLL, DDR)
- **⚡ Power analysis**: 4 voltage rails + current consumption по компонентам
- **🛰️ GNSS tracking**: GPS, GLONASS, Galileo, BeiDou созвездия
- **⚡ Oscillator disciplining**: Allan deviation анализ + PI controller
- **📡 Advanced PTP**: Path delay analysis, packet statistics, master tracking
- **🔧 Hardware status**: LEDs, SMA connectors, FPGA info, network PHY
- **🚨 Smart alerting**: Configurable thresholds + real-time notifications
- **📊 Health scoring**: Comprehensive system assessment
- **📈 Historical data**: Trending analysis + WebSocket live updates

## 🔧 Специфичная конфигурация мониторинга

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

## 🎓 Расширенные API endpoints

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

## 📈 Performance мониторинг

### Системные требования
- **CPU**: ~1-2% на современных системах
- **Memory**: ~50-100 MB
- **Network**: Минимальный трафик
- **Storage**: ~1 MB/день логов

### Оптимизация для production
```python
# Уменьшить интервалы для production
updateInterval = 10000;     # 10 секунд вместо 5
backgroundInterval = 300000; # 5 минут вместо 1

# Отключить отладочные сообщения
socketio.run(app, debug=False, ...)
```

---
**Quantum-PCI TimeCard PTP OCP Advanced Monitoring System v2.0**  
*Professional-grade monitoring for precision timing applications*