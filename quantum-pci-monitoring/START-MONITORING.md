# 🚀 Запуск веб-мониторинга Quantum-PCI

## Быстрый старт (3 шага)

### Шаг 1: Установка зависимостей

Выполните эту команду в терминале (потребуется пароль sudo):

```bash
./install-deps.sh
```

Или вручную:

```bash
# Установка системных пакетов
sudo apt update
sudo apt install -y python3-pip python3-flask python3-eventlet python3-requests python3-yaml python3-psutil

# Установка дополнительных пакетов
pip3 install --user flask-socketio python-socketio flask-cors prometheus-client
```

### Шаг 2: Запуск мониторинга

После установки зависимостей запустите:

```bash
cd /home/shiwa-time/QuantumPCI-DRV/quantum-pci-monitoring
./setup-and-run.sh
```

Или напрямую:

```bash
cd /home/shiwa-time/QuantumPCI-DRV/quantum-pci-monitoring
python3 quantum-pci-monitor.py
```

**Автоматическая инициализация мультиплексора I2C:**
- При запуске мониторинг автоматически настраивает мультиплексор I2C (адрес 0x70)
- Это обеспечивает доступ ко всем датчикам (BMP280, INA219, BNO055, LED контроллер)
- Если мультиплексор недоступен, мониторинг продолжит работу с доступными датчиками

### Шаг 3: Открыть в браузере

После запуска откройте в браузере:

- **Главная страница**: http://localhost:8080/
- **Dashboard**: http://localhost:8080/realistic-dashboard
- **API**: http://localhost:8080/api/
- **Roadmap**: http://localhost:8080/api/roadmap

---

## 📋 Подробная инструкция

### Проверка системы

```bash
# Проверка драйвера
lsmod | grep ptp_ocp

# Проверка устройств
ls -la /sys/class/timecard/

# Проверка Python
python3 --version
```

### Управление сервисом

#### Запуск в фоновом режиме

```bash
cd /home/shiwa-time/QuantumPCI-DRV/quantum-pci-monitoring
nohup python3 quantum-pci-monitor.py > monitoring.log 2>&1 &
echo $! > monitoring.pid
```

#### Проверка статуса

```bash
# Проверка процесса
ps aux | grep quantum-pci-monitor

# Проверка порта
netstat -tlnp | grep 8080

# Проверка логов
tail -f monitoring.log
```

#### Остановка

```bash
# Если запущено в фоне с PID
kill $(cat monitoring.pid)

# Или найти и остановить процесс
pkill -f quantum-pci-monitor
```

### Тестирование API

```bash
# Список устройств
curl http://localhost:8080/api/devices

# Статус устройства
curl http://localhost:8080/api/device/ocp0/status

# Реальные метрики
curl http://localhost:8080/api/metrics/real

# Алерты
curl http://localhost:8080/api/alerts

# Дорожная карта
curl http://localhost:8080/api/roadmap
```

---

## 🐛 Устранение проблем

### Проблема: pip3 не найден

```bash
sudo apt install -y python3-pip
```

### Проблема: Порт 8080 занят

```bash
# Найти процесс
lsof -i :8080

# Остановить процесс
kill <PID>

# Или изменить порт в quantum-pci-monitor.py (строка 58)
```

### Проблема: Драйвер не загружен

```bash
cd /home/shiwa-time/QuantumPCI-DRV/ДРАЙВЕРА
sudo make install
sudo modprobe ptp_ocp
```

### Проблема: Устройства не найдены

Мониторинг будет работать в демо-режиме с симулированными данными.

---

## 📊 Доступные метрики

### ✅ Реальные метрики (из sysfs)

- **PTP offset** - смещение времени в наносекундах
- **PTP drift** - дрейф частоты в ppb
- **GNSS sync** - статус синхронизации
- **SMA конфигурация** - настройки разъемов
- **Device info** - информация об устройстве

### ⚠️ Ограничения

Текущий драйвер ptp_ocp предоставляет ограниченный набор метрик.
Не доступны:
- Детальная температура
- Детальное питание
- Детальные данные GNSS (спутники)
- Состояние LED/FPGA

---

## 🎯 Автоматический запуск при загрузке

Создайте systemd сервис:

```bash
sudo tee /etc/systemd/system/quantum-pci-monitor.service << 'EOF'
[Unit]
Description=Quantum-PCI Web Monitoring
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/shiwa-time/QuantumPCI-DRV/quantum-pci-monitoring
ExecStart=/usr/bin/python3 quantum-pci-monitor.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Запустить и включить автозапуск
sudo systemctl daemon-reload
sudo systemctl enable quantum-pci-monitor
sudo systemctl start quantum-pci-monitor

# Проверка статуса
sudo systemctl status quantum-pci-monitor
```

---

## 📞 Поддержка

Если возникли проблемы:

1. Проверьте логи: `journalctl -u quantum-pci-monitor -f`
2. Проверьте статус драйвера: `dmesg | grep ptp_ocp`
3. Создайте issue в репозитории GitHub

---

**Quantum-PCI Web Monitoring v2.0**









