# Детальная конфигурация Quantum-PCI

## Обзор

Подробное руководство по настройке Quantum-PCI с драйвером PTP OCP и связанных компонентов для различных сценариев использования.

## Архитектура системы

### Компоненты системы

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Приложения    │    │   LinuxPTP      │    │   Chrony/NTP    │
│                 │    │   (ptp4l)       │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│                        Пользовательское пространство               │
└─────────────────────────────────────────────────────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│                           Ядро Linux                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐   │
│  │ PTP Core    │    │ Network     │    │   Timekeeping       │   │
│  │ Subsystem   │    │ Stack       │    │   Subsystem         │   │
│  └─────────────┘    └─────────────┘    └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │
┌─────────────────────────────────────────────────────────────────┐
│                       PTP OCP Driver                           │
│  ┌─────────────────┐              ┌─────────────────────────┐   │
│  │ TimeCard Class  │              │    PTP Interface        │   │
│  │ /sys/class/     │              │    /sys/class/ptp/      │   │
│  │ timecard/ocpN/  │  <-------->  │    /dev/ptp*           │   │
│  └─────────────────┘              └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │
┌─────────────────────────────────────────────────────────────────┐
│                       PCI Hardware                             │
└─────────────────────────────────────────────────────────────────┘
```

## Конфигурация драйвера

### Параметры модуля

#### Основные параметры

```bash
# Файл: /etc/modprobe.d/ptp-ocp.conf

# Уровень отладки (0-7)
options ptp_ocp debug=0

# Принудительное включение устройства
options ptp_ocp force_enable=0

# Таймаут инициализации (в секундах)
options ptp_ocp init_timeout=30

# Режим GPIO
options ptp_ocp gpio_mode=auto
```

#### Отладочные параметры

```bash
# Детальная отладка
options ptp_ocp debug=7

# Отладка только инициализации
options ptp_ocp debug=1

# Отладка GPIO операций
options ptp_ocp gpio_debug=1
```

### Конфигурация через sysfs

#### Основные атрибуты

```bash
# Базовый путь к устройству
PTP_DEVICE="/sys/class/ptp/ptp0"

# Чтение информации о часах
cat $PTP_DEVICE/clock_name
cat $PTP_DEVICE/max_adjustment

# Конфигурация пинов
echo "1 2 0" > $PTP_DEVICE/pins/pin0
echo "2 3 0" > $PTP_DEVICE/pins/pin1
```

#### GPIO конфигурация

```bash
# Настройка GPIO пинов
GPIO_BASE="/sys/class/ptp/ptp0"

# Список доступных пинов
ls $GPIO_BASE/pins/

# Конфигурация пина как выход
echo "perout 0 0" > $GPIO_BASE/pins/SMA1

# Конфигурация пина как вход
echo "extts 0 0" > $GPIO_BASE/pins/SMA2
```

### Конфигурация Quantum-PCI

#### Основные операции с TimeCard

```bash
# Базовый путь к TimeCard устройству
TIMECARD_BASE="/sys/class/timecard/ocp0"

# Проверка доступности устройства
if [ -d "$TIMECARD_BASE" ]; then
    echo "TimeCard device found"
else
    echo "TimeCard device not found"
    exit 1
fi

# Просмотр доступных источников времени
cat $TIMECARD_BASE/available_clock_sources

# Установка источника времени
echo "GNSS" > $TIMECARD_BASE/clock_source

# Проверка синхронизации GNSS
cat $TIMECARD_BASE/gnss_sync
```

#### Конфигурация SMA коннекторов

```bash
# Просмотр доступных сигналов
cat $TIMECARD_BASE/available_sma_inputs
cat $TIMECARD_BASE/available_sma_outputs

# Настройка SMA1 как вход для 10MHz
echo "10MHz" > $TIMECARD_BASE/sma1_in

# Настройка SMA2 как вход для PPS
echo "PPS" > $TIMECARD_BASE/sma2_in

# Настройка SMA3 как выход 10MHz
echo "10MHz" > $TIMECARD_BASE/sma3_out

# Настройка SMA4 как выход PPS
echo "PPS" > $TIMECARD_BASE/sma4_out
```

#### Калибровка задержек

```bash
# Установка задержки внешнего PPS кабеля (в наносекундах)
echo "100" > $TIMECARD_BASE/external_pps_cable_delay

# Установка задержки внутреннего PPS
echo "50" > $TIMECARD_BASE/internal_pps_cable_delay

# Установка задержки PCIe
echo "25" > $TIMECARD_BASE/pci_delay

# Установка смещения UTC-TAI
echo "37" > $TIMECARD_BASE/utc_tai_offset
```

#### Получение информации о устройстве

```bash
# Серийный номер
cat $TIMECARD_BASE/serialnum

# Конфигурация IRIG-B
cat $TIMECARD_BASE/irig_b_mode
echo "B003" > $TIMECARD_BASE/irig_b_mode

# Получение связанных устройств
PTP_DEV=$(basename $(readlink $TIMECARD_BASE/ptp))
GNSS_TTY=$(basename $(readlink $TIMECARD_BASE/ttyGNSS))
MAC_TTY=$(basename $(readlink $TIMECARD_BASE/ttyMAC))
NMEA_TTY=$(basename $(readlink $TIMECARD_BASE/ttyNMEA))

echo "PTP device: /dev/$PTP_DEV"
echo "GNSS port: /dev/$GNSS_TTY"
echo "MAC port: /dev/$MAC_TTY"
echo "NMEA port: /dev/$NMEA_TTY"
```

#### Скрипт автоматической конфигурации

```bash
#!/bin/bash
# Файл: /usr/local/bin/configure-timecard.sh

TIMECARD_BASE="/sys/class/timecard/ocp0"

# Проверка устройства
if [ ! -d "$TIMECARD_BASE" ]; then
    echo "Error: TimeCard device not found"
    exit 1
fi

# Базовая конфигурация
echo "GNSS" > $TIMECARD_BASE/clock_source
echo "10MHz" > $TIMECARD_BASE/sma1_in
echo "PPS" > $TIMECARD_BASE/sma2_in
echo "10MHz" > $TIMECARD_BASE/sma3_out
echo "PPS" > $TIMECARD_BASE/sma4_out

# Калибровка задержек (настройте под ваши кабели)
echo "100" > $TIMECARD_BASE/external_pps_cable_delay
echo "50" > $TIMECARD_BASE/internal_pps_cable_delay
echo "25" > $TIMECARD_BASE/pci_delay
echo "37" > $TIMECARD_BASE/utc_tai_offset

# Настройка IRIG-B
echo "B003" > $TIMECARD_BASE/irig_b_mode

echo "TimeCard configured successfully"

# Ожидание синхронизации GNSS
echo "Waiting for GNSS sync..."
timeout=60
while [ $timeout -gt 0 ]; do
    sync_status=$(cat $TIMECARD_BASE/gnss_sync)
    if [ "$sync_status" = "locked" ]; then
        echo "GNSS synchronized"
        break
    fi
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "Warning: GNSS sync timeout"
fi
```

## PTP конфигурация

### Базовая конфигурация ptp4l

#### Файл /etc/ptp4l.conf

```ini
[global]
# Общие настройки
verbose                    1
time_stamping              hardware
tx_timestamp_timeout       50
use_syslog                 1
logSyncInterval           -3
logMinDelayReqInterval    -3
logAnnounceInterval        1
announceReceiptTimeout     3
syncReceiptTimeout         0
delay_mechanism            E2E
network_transport          UDPv4

# Настройки домена
domainNumber               0
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF

# Профиль временной синхронизации
dataset_comparison         ieee1588
G.8275.defaultDS.localPriority 128

# Настройки сервера
serverOnly                 0
slaveOnly                  0
free_running               0

# Фильтрация и сервосистема
step_threshold             0.000002
first_step_threshold       0.000020
max_frequency              900000000
clock_servo                pi
pi_proportional_const      0.0
pi_integral_const          0.0
pi_proportional_scale      0.0
pi_proportional_exponent   -0.3
pi_proportional_norm_max   0.7
pi_integral_scale          0.0
pi_integral_exponent       0.4
pi_integral_norm_max       0.3

# Настройки сети
dscp_event                 46
dscp_general               34
socket_priority            0

[eth0]
# Настройки сетевого интерфейса
network_transport          UDPv4
delay_mechanism            E2E
```

### Продвинутая конфигурация

#### Телеком профиль (G.8275.1)

```ini
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               24
priority1                  128
priority2                  128
clockClass                 165
clockAccuracy              0x21
offsetScaledLogVariance    0x4E5D
free_running               0
freq_est_interval          1
assume_two_step            0
tx_timestamp_timeout       10
check_fup_sync             0
clock_servo                linreg
step_threshold             0.000002
first_step_threshold       0.000020
max_frequency              900000000
sanity_freq_limit          200000000
ntpshm_segment             0
msg_interval_request       0
servo_num_offset_values    10
servo_offset_threshold     0
write_phase_mode           0
network_transport          L2
ptp_dst_mac                01:1B:19:00:00:00
p2p_dst_mac                01:80:C2:00:00:0E
udp6_scope                 0x0E
uds_address                /var/run/ptp4l
logging_level              6
verbose                    0
use_syslog                 1
userDescription            "PTP OCP Telecom Profile"
manufacturerIdentity       00:00:00
summary_interval           0
kernel_leap                1
check_fup_sync             0
clock_class_threshold      7
G.8275.portDS.localPriority 128

[eth0]
logAnnounceInterval        0
logSyncInterval           -4
logMinDelayReqInterval    -4
logMinPdelayReqInterval   -4
announceReceiptTimeout     3
syncReceiptTimeout         3
delay_mechanism            P2P
network_transport          L2
masterOnly                 0
G.8275.portDS.localPriority 128
```

#### High Accuracy Profile

```ini
[global]
dataset_comparison         ieee1588
domainNumber               0
priority1                  128
priority2                  128
clockClass                 6
clockAccuracy              0x20
offsetScaledLogVariance    0x436A
free_running               0
freq_est_interval          1
assume_two_step            0
tx_timestamp_timeout       1
check_fup_sync             0
clock_servo                pi
step_threshold             0.000000002
first_step_threshold       0.000000020
max_frequency              900000000
pi_proportional_const      0.0
pi_integral_const          0.0
pi_proportional_scale      0.0
pi_proportional_exponent   -0.3
pi_proportional_norm_max   0.7
pi_integral_scale          0.0
pi_integral_exponent       0.4
pi_integral_norm_max       0.3
servo_num_offset_values    10
servo_offset_threshold     0
write_phase_mode           0
network_transport          UDPv4
delay_mechanism            E2E
time_stamping              hardware
twoStepFlag                1
summary_interval           0
kernel_leap                1
check_fup_sync             0

[eth0]
logAnnounceInterval       -2
logSyncInterval           -5
logMinDelayReqInterval    -5
announceReceiptTimeout     3
syncReceiptTimeout         3
delay_mechanism            E2E
network_transport          UDPv4
```

## Сетевая конфигурация

### Настройка сетевого интерфейса

#### Hardware timestamping

```bash
# Проверка поддержки
ethtool -T eth0

# Настройка интерфейса для PTP
sudo ethtool -s eth0 speed 1000 duplex full autoneg off

# Оптимизация буферов
sudo ethtool -G eth0 rx 4096 tx 4096
sudo ethtool -C eth0 rx-usecs 1 tx-usecs 1
```

#### Multicast конфигурация

```bash
# Настройка multicast для PTP
sudo ip maddr add 01:1b:19:00:00:00 dev eth0
sudo ip maddr add 01:80:c2:00:00:0e dev eth0

# Проверка multicast групп
ip maddr show dev eth0
```

### Оптимизация производительности

#### Настройка IRQ affinity

```bash
#!/bin/bash
# Скрипт для настройки IRQ affinity

# Найти IRQ для сетевого интерфейса
ETH_IRQ=$(grep eth0 /proc/interrupts | awk -F: '{print $1}' | tr -d ' ')

# Привязать IRQ к определенному CPU
echo 2 > /proc/irq/$ETH_IRQ/smp_affinity

# Изоляция CPU для real-time обработки
echo 2 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
```

#### Настройка ядра для real-time

```bash
# Файл: /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash isolcpus=1,2 nohz_full=1,2 rcu_nocbs=1,2"

# Обновление grub
sudo update-grub
```

## Chrony интеграция

### Конфигурация chronyd

#### Файл /etc/chrony/chrony.conf

```bash
# Использование PTP в качестве источника времени
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 stratum 1

# Альтернативные источники
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst

# Настройки синхронизации
makestep 1.0 3
rtcsync
driftfile /var/lib/chrony/drift
logdir /var/log/chrony

# Разрешения
allow 192.168.0.0/16
allow 10.0.0.0/8

# Локальные настройки
local stratum 2
smoothtime 400 0.01 leaponly
```

### phc2sys конфигурация

#### Автоматическая синхронизация

```bash
# Systemd сервис: /etc/systemd/system/phc2sys.service
[Unit]
Description=Synchronize system clock to PTP hardware clock
After=ptp4l.service
Requires=ptp4l.service

[Service]
ExecStart=/usr/sbin/phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -w -m -q -R 256
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Мониторинг и логирование

### Настройка логирования

#### rsyslog конфигурация

```bash
# Файл: /etc/rsyslog.d/50-ptp.conf

# PTP логи
:programname, isequal, "ptp4l" /var/log/ptp4l.log
:programname, isequal, "phc2sys" /var/log/phc2sys.log

# Kernel PTP сообщения
:msg, contains, "ptp_ocp" /var/log/ptp-driver.log

# Остановить дальнейшую обработку
& stop
```

#### journald конфигурация

```bash
# Файл: /etc/systemd/journald.conf
[Journal]
Storage=persistent
Compress=yes
SplitMode=uid
RateLimitInterval=30s
RateLimitBurst=1000
SystemMaxUse=100M
RuntimeMaxUse=50M
```

### Мониторинг метрик

#### Prometheus exporter

```bash
#!/bin/bash
# Скрипт для экспорта метрик PTP

# Создание метрик файла
METRICS_FILE="/var/lib/prometheus/node-exporter/ptp.prom"

# Получение offset
OFFSET=$(pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null | grep offsetFromMaster | awk '{print $2}')

# Получение master clock ID
MASTER_ID=$(pmc -u -b 0 'GET PARENT_DATA_SET' 2>/dev/null | grep grandmasterIdentity | awk '{print $2}')

# Запись метрик
cat << EOF > $METRICS_FILE
# HELP ptp_offset_ns PTP offset from master in nanoseconds
# TYPE ptp_offset_ns gauge
ptp_offset_ns $OFFSET

# HELP ptp_master_clock_id PTP master clock identifier
# TYPE ptp_master_clock_id gauge
ptp_master_clock_id{master_id="$MASTER_ID"} 1
EOF
```

## Безопасность

### Настройка firewall

```bash
# PTP порты
sudo ufw allow 319/udp comment "PTP Event"
sudo ufw allow 320/udp comment "PTP General"

# Для multicast (если необходимо)
sudo iptables -I INPUT -d 224.0.1.129 -j ACCEPT
sudo iptables -I INPUT -d 224.0.0.107 -j ACCEPT
```

### Контроль доступа

```bash
# Ограничение доступа к PTP устройствам
# Файл: /etc/security/limits.conf
@ptp    hard    rtprio    99
@ptp    soft    rtprio    99

# Создание группы для PTP
sudo groupadd ptp
sudo usermod -a -G ptp ptp4l_user
```

## Профили конфигураций

### Telecom профиль

Оптимизирован для телекоммуникационных применений с высокими требованиями к точности.

### Industrial профиль

Подходит для промышленных автоматических систем с умеренными требованиями к точности.

### Datacenter профиль

Оптимизирован для синхронизации в дата-центрах с большим количеством серверов.

### Testing профиль

Конфигурация для тестирования и отладки системы.