# Установка и настройка

## Обзор

Детальное руководство по установке и настройке драйвера PTP OCP.

## Системные требования

### Минимальные требования

- **ОС**: Linux с ядром версии 5.4+
- **Архитектура**: x86_64, ARM64
- **ОЗУ**: минимум 512 МБ
- **Дисковое пространство**: 100 МБ для исходников и сборки

### Рекомендуемые требования

- **ОС**: Linux с ядром версии 5.15+
- **ОЗУ**: 2 ГБ и более
- **Процессор**: современный многоядерный CPU

### Поддерживаемые дистрибутивы

- **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Debian**: 11 (Bullseye), 12 (Bookworm)
- **CentOS**: 8, 9
- **RHEL**: 8, 9
- **Fedora**: 35+
- **openSUSE**: Leap 15.4+

## Подготовка системы

### Установка зависимостей

#### Ubuntu/Debian

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка необходимых пакетов
sudo apt install -y \
    build-essential \
    linux-headers-$(uname -r) \
    git \
    make \
    gcc \
    dkms \
    pkg-config \
    linuxptp \
    chrony

# Дополнительные утилиты
sudo apt install -y \
    ethtool \
    pciutils \
    usbutils \
    kmod
```

#### CentOS/RHEL 8+

```bash
# Обновление системы
sudo dnf update -y

# Установка EPEL репозитория
sudo dnf install -y epel-release

# Установка необходимых пакетов
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y \
    kernel-devel \
    kernel-headers \
    git \
    make \
    gcc \
    dkms \
    pkg-config \
    linuxptp \
    chrony

# Дополнительные утилиты
sudo dnf install -y \
    ethtool \
    pciutils \
    usbutils \
    kmod
```

#### Fedora

```bash
# Обновление системы
sudo dnf update -y

# Установка необходимых пакетов
sudo dnf groupinstall -y "Development Tools" "C Development Tools and Libraries"
sudo dnf install -y \
    kernel-devel \
    kernel-headers \
    git \
    make \
    gcc \
    dkms \
    pkg-config \
    linuxptp \
    chrony
```

### Проверка ядра

```bash
# Проверка версии ядра
uname -r

# Проверка поддержки PTP
grep -i ptp /boot/config-$(uname -r)

# Проверка модулей PTP
find /lib/modules/$(uname -r) -name "*ptp*"
```

## Сборка и установка драйвера

### Получение исходного кода

```bash
# Клонирование репозитория
git clone <repository-url> ptp-ocp-driver
cd ptp-ocp-driver

# Переход в директорию с драйвером
cd ДРАЙВЕРА
```

### Сборка

```bash
# Проверка Makefile
cat Makefile

# Сборка модуля
make clean
make

# Проверка собранного модуля
ls -la *.ko
modinfo ptp_ocp.ko
```

### Установка

#### Временная установка

```bash
# Загрузка модуля
sudo insmod ptp_ocp.ko

# Проверка загрузки
lsmod | grep ptp_ocp
dmesg | tail -10
```

#### Постоянная установка

```bash
# Установка модуля в систему
sudo make install

# Обновление списка модулей
sudo depmod -a

# Автоматическая загрузка при старте
echo "ptp_ocp" | sudo tee -a /etc/modules

# Создание конфигурации modprobe
sudo tee /etc/modprobe.d/ptp-ocp.conf << EOF
# PTP OCP driver configuration
options ptp_ocp debug=0
EOF
```

#### Установка через DKMS

```bash
# Подготовка для DKMS
sudo mkdir -p /usr/src/ptp-ocp-1.0
sudo cp -r * /usr/src/ptp-ocp-1.0/

# Создание dkms.conf
sudo tee /usr/src/ptp-ocp-1.0/dkms.conf << EOF
PACKAGE_NAME="ptp-ocp"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="ptp_ocp"
DEST_MODULE_LOCATION[0]="/kernel/drivers/ptp/"
AUTOINSTALL="yes"
EOF

# Добавление в DKMS
sudo dkms add -m ptp-ocp -v 1.0
sudo dkms build -m ptp-ocp -v 1.0
sudo dkms install -m ptp-ocp -v 1.0
```

## Настройка системы

### Настройка udev правил

```bash
# Создание правил для устройств PTP
sudo tee /etc/udev/rules.d/99-ptp-ocp.rules << EOF
# PTP OCP device rules
SUBSYSTEM=="ptp", GROUP="dialout", MODE="0664"
KERNEL=="ptp[0-9]*", GROUP="dialout", MODE="0664"
EOF

# Перезагрузка правил udev
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Настройка групп пользователей

```bash
# Добавление пользователя в группы
sudo usermod -a -G dialout,tty $USER

# Проверка членства в группах
groups $USER
```

### Настройка systemd сервисов

```bash
# Создание сервиса для автозагрузки драйвера
sudo tee /etc/systemd/system/ptp-ocp.service << EOF
[Unit]
Description=PTP OCP Driver
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe ptp_ocp
ExecStop=/sbin/rmmod ptp_ocp
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Включение сервиса
sudo systemctl enable ptp-ocp.service
sudo systemctl start ptp-ocp.service
```

## Проверка установки

### Проверка драйвера

```bash
# Статус модуля
lsmod | grep ptp

# Информация о модуле
modinfo ptp_ocp

# Сообщения ядра
dmesg | grep -i ptp | tail -10
```

### Проверка устройств

```bash
# PTP устройства
ls -la /dev/ptp*

# PCI устройства
lspci | grep -i time
lspci | grep -i ptp

# Sysfs интерфейсы
ls -la /sys/class/ptp/
```

### Функциональная проверка

```bash
# Тест PTP устройства
sudo testptp -d /dev/ptp0 -c
sudo testptp -d /dev/ptp0 -g

# Проверка capabilities
sudo testptp -d /dev/ptp0 -k

# Тест GPIO (если поддерживается)
sudo testptp -d /dev/ptp0 -L
```

## Настройка сети

### Настройка сетевого интерфейса

```bash
# Проверка поддержки hardware timestamping
ethtool -T eth0

# Включение hardware timestamping
sudo ethtool -s eth0 speed 1000 duplex full autoneg off

# Настройка буферов
sudo ethtool -G eth0 rx 4096 tx 4096
```

### Настройка PTP профиля

```bash
# Создание базовой конфигурации PTP
sudo tee /etc/ptp4l.conf << EOF
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               24
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0

[eth0]
network_transport          UDPv4
delay_mechanism            E2E
EOF
```

## Устранение проблем

### Общие проблемы

#### Модуль не загружается

```bash
# Проверка зависимостей
sudo modprobe --show-depends ptp_ocp

# Принудительная загрузка зависимостей
sudo modprobe ptp
sudo modprobe pps_core
```

#### Устройство не обнаруживается

```bash
# Проверка PCI устройств
sudo lspci -vvv | grep -A 20 -B 5 -i time

# Проверка IOMMU
dmesg | grep -i iommu

# Отключение IOMMU (если необходимо)
# Добавить в GRUB: intel_iommu=off или amd_iommu=off
```

#### Проблемы с правами доступа

```bash
# Проверка владельца устройства
ls -la /dev/ptp*

# Изменение прав временно
sudo chmod 666 /dev/ptp*

# Проверка SELinux/AppArmor
sudo getenforce  # для SELinux
sudo aa-status   # для AppArmor
```

### Логирование и отладка

```bash
# Включение отладочных сообщений
echo 'module ptp_ocp +p' | sudo tee /sys/kernel/debug/dynamic_debug/control

# Мониторинг логов
sudo journalctl -k -f | grep ptp
tail -f /var/log/messages | grep ptp
```

## Обновление

### Обновление драйвера

```bash
# Остановка использования драйвера
sudo systemctl stop ptp4l
sudo rmmod ptp_ocp

# Получение обновлений
git pull origin main

# Пересборка и установка
cd ДРАЙВЕРА
make clean
make
sudo make install

# Перезагрузка драйвера
sudo modprobe ptp_ocp
```

### Обновление через DKMS

```bash
# Удаление старой версии
sudo dkms remove -m ptp-ocp -v 1.0 --all

# Установка новой версии
sudo dkms install -m ptp-ocp -v 1.1
```

## Деинсталляция

### Удаление драйвера

```bash
# Остановка сервисов
sudo systemctl stop ptp4l
sudo systemctl disable ptp-ocp.service

# Выгрузка модуля
sudo rmmod ptp_ocp

# Удаление файлов
sudo rm -f /lib/modules/$(uname -r)/kernel/drivers/ptp/ptp_ocp.ko
sudo rm -f /etc/systemd/system/ptp-ocp.service
sudo rm -f /etc/udev/rules.d/99-ptp-ocp.rules
sudo rm -f /etc/modprobe.d/ptp-ocp.conf

# Обновление базы модулей
sudo depmod -a

# Перезагрузка udev
sudo udevadm control --reload-rules
```

### Удаление через DKMS

```bash
sudo dkms remove -m ptp-ocp -v 1.0 --all
sudo rm -rf /usr/src/ptp-ocp-1.0
```