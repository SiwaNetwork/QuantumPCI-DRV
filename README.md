# Quantum-PCI Driver & Tools

[![License](https://img.shields.io/badge/license-GPL-blue.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/platform-Linux-green.svg)](https://www.kernel.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange.svg)](https://ubuntu.com/)

## 🚀 Обзор

**Quantum-PCI** — высокоточная PCIe плата синхронизации времени для Linux систем, обеспечивающая:
- ⏰ Аппаратные часы PHC (PTP Hardware Clock)
- 🛰️ GNSS синхронизацию (GPS/GLONASS/Galileo/BeiDou)
- 📡 Вход/выход сигналов точного времени (1PPS, 10MHz, IRIG-B, DCF77)
- 🔧 Высокостабильный генератор (OCXO/CSAC/TCXO) с holdover
- 🎯 Поддержка PTP/IEEE-1588 и NTP протоколов

## 📋 Содержание

- [Системные требования](#системные-требования)
- [Быстрый старт](#быстрый-старт)
- [Установка](#установка)
- [Конфигурация](#конфигурация)
- [Мониторинг](#мониторинг)
- [Документация](#документация)
- [Структура репозитория](#структура-репозитория)

## 💻 Системные требования

### Операционная система
- **Ubuntu LTS**: 20.04/22.04/24.04
- **Ядро Linux**: ≥ 5.4 (рекомендуется 5.15+)
- **Архитектура**: x86_64

### Аппаратные требования
- **PCIe слот**: x1 электрически (совместим с x4/x8/x16 механически)
- **BIOS настройки**:
  - Intel CPU: включить VT-d/VT-x
  - AMD CPU: включить IOMMU

### Необходимые пакеты

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    build-essential linux-headers-$(uname -r) \
    libncurses-dev flex bison openssl libssl-dev \
    dkms libelf-dev libudev-dev libpci-dev \
    libiberty-dev autoconf zstd \
    linuxptp chrony ethtool pciutils \
    kmod i2c-tools gpsd gpsd-clients \
    python3 python3-pip
```

## 🚀 Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/SiwaNetwork/QuantumPCI-DRV.git
cd QuantumPCI-DRV
```

### 2. Сборка и установка драйвера

```bash
cd ДРАЙВЕРА
make clean
make
sudo make install
sudo modprobe ptp_ocp
```

### 3. Проверка установки

```bash
# Проверка загрузки драйвера
lsmod | grep ptp_ocp

# Проверка устройства
ls -la /dev/ptp*
ls -la /sys/class/timecard/

# Проверка в dmesg
dmesg | grep -i ptp_ocp
```

### 4. Базовая синхронизация

```bash
# NTP через Chrony
sudo systemctl enable chrony
sudo systemctl start chrony

# PTP через linuxptp
sudo ptp4l -i eth0 -m -s
```

## 🔧 Установка

### Полная установка драйвера

```bash
# Переход в директорию драйвера
cd ДРАЙВЕРА

# Очистка предыдущей сборки
make clean

# Сборка драйвера
make

# Установка (требует sudo)
sudo make install

# Загрузка модуля
sudo modprobe ptp_ocp

# Автозагрузка при старте
echo "ptp_ocp" | sudo tee -a /etc/modules
```

### Secure Boot (подпись модуля)

Для систем с Secure Boot требуется подпись модуля:

```bash
# Создание ключей MOK
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=Quantum-PCI/"

# Регистрация ключа
sudo mokutil --import MOK.der

# Перезагрузка и подтверждение в MOK Manager

# Подпись модуля
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./MOK.priv ./MOK.der ptp_ocp.ko

# Установка подписанного модуля
sudo cp ptp_ocp.ko /lib/modules/$(uname -r)/kernel/drivers/ptp/
sudo depmod -a
```

## ⚙️ Конфигурация

### Настройка SMA разъёмов

```bash
# Базовый путь sysfs
BASE=/sys/class/timecard/ocp0

# Просмотр доступных сигналов
cat $BASE/available_sma_inputs
cat $BASE/available_sma_outputs

# Настройка разъёмов
echo "10MHz" > $BASE/sma1   # Вход 10MHz
echo "PPS" > $BASE/sma2      # Вход PPS
echo "10MHz" > $BASE/sma3    # Выход 10MHz
echo "PPS" > $BASE/sma4      # Выход PPS
```

### Настройка GNSS

```bash
# Проверка GNSS статуса
cat /sys/class/timecard/ocp0/gnss_sync

# Настройка gpsd
sudo gpsd /dev/ttyS5 -F /var/run/gpsd.sock

# Мониторинг GNSS
cgps -s
```

### Chrony конфигурация

```bash
# /etc/chrony/chrony.conf
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 stratum 1
refclock PPS /dev/pps0 lock PHC poll 0 dpoll -2 offset 0 prefer trust

# Перезапуск
sudo systemctl restart chrony

# Проверка
chronyc sources -v
```

### PTP конфигурация

```bash
# /etc/ptp4l.conf
[global]
domainNumber 0
slaveOnly 1
time_stamping hardware
tx_timestamp_timeout 10

# Запуск PTP
sudo ptp4l -i eth0 -m -s

# Синхронизация системных часов
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -w -m
```

## 📊 Мониторинг

### Система мониторинга

```bash
# Установка зависимостей
cd ptp-monitoring
pip3 install -r requirements.txt

# Запуск мониторинга
python3 quantum-pci-monitor.py
```

Доступ к интерфейсам:
- 📊 **Dashboard**: http://localhost:8080/realistic-dashboard
- 🔧 **API**: http://localhost:8080/api/
- 🗺️ **Roadmap**: http://localhost:8080/api/roadmap

### ⚠️ Ограничения мониторинга

Текущий драйвер `ptp_ocp` предоставляет ограниченный набор метрик:

**✅ Доступные метрики:**
- PTP offset/drift из sysfs
- GNSS sync статус
- SMA конфигурация
- Информация об устройстве

**❌ НЕ доступные метрики:**
- Детальный мониторинг температуры
- Мониторинг питания и напряжений
- Детальный GNSS (спутники, качество)
- Состояние LED/FPGA/аппаратуры

## 📚 Документация

### Основные документы

- 📖 [**Полное руководство по эксплуатации**](docs/РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md) - подробная инструкция по всем аспектам работы
- 🚀 [Быстрый старт](docs/guides/quick-start.md)
- 🔧 [Руководство по установке](docs/guides/installation.md)
- ⚙️ [Детальная конфигурация](docs/guides/configuration.md)
- 🔍 [Устранение неполадок](docs/guides/troubleshooting.md)

### Технические руководства

- 🏗️ [Архитектура системы](docs/architecture.md)
- 🕐 [Настройка Chrony](docs/guides/chrony-guide.md)
- 📡 [Настройка LinuxPTP](docs/guides/linuxptp-guide.md)
- 🛠️ [CLI инструменты](docs/tools/cli-tools.md)
- 📊 [Руководство по мониторингу](docs/tools/monitoring-guide.md)

### API документация

- [Kernel API](docs/api/kernel-api.md)
- [Userspace API](docs/api/userspace-api.md)
- [Web API](docs/api/web-api.md)
- [IOCTL Reference](docs/api/ioctl-reference.md)

## 📁 Структура репозитория

```
QuantumPCI-DRV/
├── ДРАЙВЕРА/               # Драйвер ядра ptp_ocp
│   ├── ptp_ocp.c          # Основной код драйвера
│   ├── Makefile           # Сборка драйвера
│   └── README.md          # Инструкции по драйверу
├── docs/                   # Документация
│   ├── guides/            # Руководства пользователя
│   ├── api/               # API документация
│   ├── tools/             # Инструменты
│   └── РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md
├── ptp-monitoring/         # Система мониторинга
│   ├── api/               # REST API
│   ├── web/               # Web интерфейс
│   └── quantum-pci-monitor.py
├── bmp280-sensor/          # Драйвер датчика температуры
├── bno055-sensor/          # Драйвер IMU датчика
└── led-testing/            # Тесты LED индикации
```

## 🛠️ Утилиты и инструменты

### Работа с прошивками

```bash
cd ДРАЙВЕРА

# Проверка типа прошивки
./check_firmware_type.sh firmware.bin

# Конвертация прошивки
./convert_firmware.sh input.rpd output.bin

# Программирование через JTAG
./flash_programmer.sh firmware.bin
```

### Диагностика

```bash
# Проверка статуса драйвера
sudo dmesg | grep ptp_ocp

# Информация об устройстве
cat /sys/class/timecard/ocp0/serialnum
cat /sys/class/timecard/ocp0/clock_source
cat /sys/class/timecard/ocp0/gnss_sync

# PTP статистика
cat /sys/class/timecard/ocp0/clock_status_offset
cat /sys/class/timecard/ocp0/clock_status_drift

# Тест PTP
testptp -d /dev/ptp0 -T 1000
```

## 🔄 Обновления и поддержка

### Обновление драйвера

```bash
git pull origin main
cd ДРАЙВЕРА
make clean
make
sudo rmmod ptp_ocp
sudo make install
sudo modprobe ptp_ocp
```

### Известные проблемы

1. **Secure Boot**: Требуется подпись модуля MOK
2. **IOMMU/VT-d**: Должны быть включены в BIOS
3. **Права доступа**: Требуются права root для sysfs

## 📝 Лицензия

Этот проект распространяется под лицензией GPL. См. файл [LICENSE](LICENSE) для деталей.

## 🤝 Вклад в проект

Мы приветствуем вклад в развитие проекта! Пожалуйста:

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit изменения (`git commit -m 'Add some AmazingFeature'`)
4. Push в branch (`git push origin feature/AmazingFeature`)
5. Откройте Pull Request

## 📧 Контакты и поддержка

- **Issues**: [GitHub Issues](https://github.com/SiwaNetwork/QuantumPCI-DRV/issues)
- **Документация**: [Полное руководство](docs/РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md)
- **Wiki**: [GitHub Wiki](https://github.com/SiwaNetwork/QuantumPCI-DRV/wiki)

## ⚠️ Важные замечания

1. **Драйвер только для Linux** - Windows не поддерживается
2. **Требуется ядро 5.4+** - для старых версий возможны проблемы
3. **Мониторинг ограничен** - см. [ROADMAP](ptp-monitoring/ROADMAP.md) для планов развития
4. **BIOS настройки критичны** - VT-d/IOMMU обязательны

---

*Quantum-PCI Driver v2.0 - Высокоточная синхронизация времени для Linux*
