# 🚀 Быстрый старт Quantum-PCI

Это краткое руководство для быстрого запуска системы Quantum-PCI.

## 📚 Полная документация

- **Основной README**: [README.md](README.md)
- **Руководство по эксплуатации**: [docs/РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md](docs/РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md)
- **Документация проекта**: [docs/README.md](docs/README.md)

## 🎯 Выберите свой сценарий

### 1️⃣ Запуск веб-мониторинга

**Автоматическая установка и запуск:**
```bash
cd QuantumPCI-DRV
./install-and-start.sh
```

**Детали:** См. [quantum-pci-monitoring/START-MONITORING.md](quantum-pci-monitoring/START-MONITORING.md)

**Доступ к интерфейсу:**
- 🏠 Главная: http://localhost:8080/
- 📊 Dashboard: http://localhost:8080/realistic-dashboard
- 🔧 API: http://localhost:8080/api/

---

### 2️⃣ Установка драйвера

**Быстрая установка:**
```bash
cd QuantumPCI-DRV/ДРАЙВЕРА
make clean && make
sudo make install
sudo modprobe ptp_ocp
```

**Проверка:**
```bash
lsmod | grep ptp_ocp
ls /sys/class/timecard/
```

**Детали:** См. [docs/guides/installation.md](docs/guides/installation.md)

---

### 3️⃣ Настройка автономного хранения времени (для карт БЕЗ GNSS)

**Автоматическая настройка:**
```bash
cd QuantumPCI-DRV
sudo ./autonomous-timekeeper/scripts/setup-quantum-timekeeper.sh
```

**Детали:** См. [autonomous-timekeeper/README.md](autonomous-timekeeper/README.md)

---

### 4️⃣ Настройка Chrony (NTP с PHC)

**Базовая конфигурация:**
```bash
# Добавить в /etc/chrony/chrony.conf
refclock PHC /dev/ptp1 poll 3 dpoll -2 offset 0 stratum 1

# Перезапустить
sudo systemctl restart chrony
chronyc tracking
```

**Детали:** См. [docs/guides/chrony-guide.md](docs/guides/chrony-guide.md)

---

### 5️⃣ Настройка PTP (IEEE 1588)

**Базовая настройка:**
```bash
# PTP slave
sudo ptp4l -i eth0 -m -s

# Синхронизация системных часов
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -w -m
```

**Детали:** См. [docs/guides/linuxptp-guide.md](docs/guides/linuxptp-guide.md)

---

## 🛠️ Диагностика проблем

**Комплексная диагностика:**
```bash
sudo ./scripts/diagnose-timecard.sh
```

**Базовые проверки:**
```bash
# Драйвер
lsmod | grep ptp_ocp

# Устройства
ls /sys/class/timecard/
ls /dev/ptp*

# Статус
cat /sys/class/timecard/ocp0/gnss_sync
cat /sys/class/timecard/ocp0/clock_source
```

**Детали:** См. [docs/guides/troubleshooting.md](docs/guides/troubleshooting.md)

---

## 📁 Структура проекта

```
QuantumPCI-DRV/
├── README.md                      # Основная документация
├── QUICK-START.md                 # Этот файл
├── ДРАЙВЕРА/                      # Драйвер ptp_ocp
├── docs/                          # Полная документация
│   ├── guides/                    # Руководства пользователя
│   ├── api/                       # API документация
│   └── tools/                     # Инструменты
├── autonomous-timekeeper/         # Автономное хранение времени
├── quantum-pci-monitoring/        # Веб-мониторинг
└── scripts/                       # Утилиты и скрипты
```

---

## 🆘 Получить помощь

- **Issues**: https://github.com/SiwaNetwork/QuantumPCI-DRV/issues
- **Документация**: [docs/README.md](docs/README.md)
- **Wiki**: https://github.com/SiwaNetwork/QuantumPCI-DRV/wiki

---

## ✅ Следующие шаги

После запуска базовой системы:

1. Изучите [полную документацию](docs/README.md)
2. Настройте [мониторинг](docs/tools/monitoring-guide.md)
3. Оптимизируйте [конфигурацию](docs/guides/configuration.md)
4. Настройте [интеграцию](docs/guides/integration.md) с вашей инфраструктурой

---

**Quantum-PCI Driver v2.0** - Высокоточная синхронизация времени для Linux

