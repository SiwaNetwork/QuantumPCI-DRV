# 🎯 Quantum-PCI TimeCard - Быстрая справка

## ⚡ Самые частые команды

### 🚀 Запуск системы
```bash
# 1. Загрузка драйвера
sudo modprobe ptp_ocp

# 2. Запуск мониторинга
cd ptp-monitoring && python3 demo-extended.py

# 3. Открыть dashboard
xdg-open http://localhost:8080/dashboard
```

### 🔍 Проверка статуса
```bash
# Quantum-PCI TimeCard обнаружен?
ls /sys/class/timecard/ocp0/

# PTP синхронизация
cat /sys/class/timecard/ocp0/clock_source

# GNSS статус
cat /sys/class/timecard/ocp0/gnss_sync

# Температура
grep . /sys/class/timecard/ocp0/*temp* 2>/dev/null
```

### 🛠️ Быстрая настройка
```bash
# Источник времени на GNSS
echo "GNSS" > /sys/class/timecard/ocp0/clock_source

# PPS на выход SMA3
echo "PPS" > /sys/class/timecard/ocp0/sma3_out

# 10MHz на выход SMA4
echo "10MHz" > /sys/class/timecard/ocp0/sma4_out
```

### 📊 API запросы
```bash
# Все метрики
curl -s http://localhost:8080/api/metrics/extended | jq .

# Только PTP offset
curl -s http://localhost:8080/api/metrics/ptp/advanced | jq '.offset_ns'

# Температуры
curl -s http://localhost:8080/api/metrics/thermal | jq '.sensors'

# Алерты
curl -s http://localhost:8080/api/alerts | jq '.active'
```

### 🐛 Быстрая диагностика
```bash
# Драйвер загружен?
lsmod | grep ptp_ocp

# PCI устройство видно?
lspci -d 1d9b:

# Логи драйвера
dmesg | grep ptp_ocp | tail -20

# Проверка API
curl -I http://localhost:8080/api/health
```

### 🔄 Перезапуск компонентов
```bash
# Перезагрузка драйвера
sudo rmmod ptp_ocp && sudo modprobe ptp_ocp

# Перезапуск мониторинга
pkill -f demo-extended.py
cd ptp-monitoring && python3 demo-extended.py

# Перезапуск PTP сервисов
sudo systemctl restart ptp4l phc2sys
```

## 📌 Полезные пути

| Что | Путь |
|-----|------|
| Sysfs Quantum-PCI TimeCard | `/sys/class/timecard/ocp0/` |
| PTP устройство | `/dev/ptp4` |
| GNSS порт | `/dev/ttyS5` |
| Dashboard | `http://localhost:8080/dashboard` |
| API docs | `http://localhost:8080/api/` |

## 🎨 Цветовые индикаторы в Dashboard

| Цвет | Значение |
|------|----------|
| 🟢 Зеленый | Норма |
| 🟡 Желтый | Предупреждение |
| 🔴 Красный | Критично |
| ⚫ Серый | Нет данных |

## ⌨️ Горячие клавиши Dashboard

| Клавиша | Действие |
|---------|----------|
| `R` | Обновить данные |
| `F` | Полноэкранный режим |
| `A` | Показать/скрыть алерты |
| `H` | Справка |

---
*Сохраните эту справку для быстрого доступа!*