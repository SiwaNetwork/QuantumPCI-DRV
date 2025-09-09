# Конфигурации PTP для Intel сетевых карт I210, I225, I226

## Обзор

Данный документ содержит готовые конфигурации PTP для различных сценариев использования Intel сетевых карт с Quantum-PCI.

## Базовая конфигурация

### Intel I210 - Стандартная настройка
```bash
# /etc/ptp4l-intel-i210.conf
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
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

### Intel I225 - Высокоскоростная настройка (2.5 Gbps)
```bash
# /etc/ptp4l-intel-i225.conf
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
logAnnounceInterval        0
logSyncInterval            -4
logMinDelayReqInterval     -4
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

### Intel I226 - Оптимизированная настройка
```bash
# /etc/ptp4l-intel-i226.conf
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
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

## Специализированные конфигурации

### Телекоммуникационный профиль (G.8275.1)
```bash
# /etc/ptp4l-intel-telecom.conf
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               44
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

### Высокоточный профиль
```bash
# /etc/ptp4l-intel-high-precision.conf
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
logAnnounceInterval        0
logSyncInterval            -4
logMinDelayReqInterval     -4
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

### Профиль для промышленной автоматизации
```bash
# /etc/ptp4l-intel-industrial.conf
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               100
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0
logAnnounceInterval        0
logSyncInterval            -2
logMinDelayReqInterval     -2
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

## Конфигурации с Quantum-PCI

### Quantum-PCI как Grand Master
```bash
# /etc/ptp4l-quantum-intel-master.conf
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
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

### Quantum-PCI как Boundary Clock
```bash
# /etc/ptp4l-quantum-intel-boundary.conf
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
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4

[eth1]
network_transport          UDPv4
```

## Скрипты автоматической настройки

### Скрипт выбора конфигурации
```bash
#!/bin/bash
# /usr/local/bin/select-intel-ptp-config.sh

INTERFACE="eth0"
CARD_TYPE=""

# Определение типа карты
PCI_INFO=$(lspci | grep -i "intel.*ethernet")
if echo "$PCI_INFO" | grep -q "I210"; then
    CARD_TYPE="i210"
elif echo "$PCI_INFO" | grep -q "I225"; then
    CARD_TYPE="i225"
elif echo "$PCI_INFO" | grep -q "I226"; then
    CARD_TYPE="i226"
else
    CARD_TYPE="generic"
fi

# Выбор конфигурации
case "$1" in
    "telecom")
        CONFIG="/etc/ptp4l-intel-telecom.conf"
        ;;
    "high-precision")
        CONFIG="/etc/ptp4l-intel-high-precision.conf"
        ;;
    "industrial")
        CONFIG="/etc/ptp4l-intel-industrial.conf"
        ;;
    "quantum-master")
        CONFIG="/etc/ptp4l-quantum-intel-master.conf"
        ;;
    "quantum-boundary")
        CONFIG="/etc/ptp4l-quantum-intel-boundary.conf"
        ;;
    *)
        CONFIG="/etc/ptp4l-intel-${CARD_TYPE}.conf"
        ;;
esac

echo "Используется конфигурация: $CONFIG"
echo "Тип карты: $CARD_TYPE"
echo "Интерфейс: $INTERFACE"

# Запуск PTP
sudo ptp4l -f "$CONFIG" -i "$INTERFACE" -m
```

## Systemd сервисы

### Сервис для Intel I210
```ini
# /etc/systemd/system/ptp4l-intel-i210.service
[Unit]
Description=PTP4L for Intel I210
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/ptp4l -f /etc/ptp4l-intel-i210.conf -i eth0 -m
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
```

### Сервис для Intel I225
```ini
# /etc/systemd/system/ptp4l-intel-i225.service
[Unit]
Description=PTP4L for Intel I225
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/ptp4l -f /etc/ptp4l-intel-i225.conf -i eth0 -m
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
```

### Сервис для Intel I226
```ini
# /etc/systemd/system/ptp4l-intel-i226.service
[Unit]
Description=PTP4L for Intel I226
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/ptp4l -f /etc/ptp4l-intel-i226.conf -i eth0 -m
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
```

## Мониторинг и логирование

### Конфигурация rsyslog для PTP
```bash
# /etc/rsyslog.d/50-ptp4l.conf
# PTP4L logging
:programname, isequal, "ptp4l" /var/log/ptp4l.log
& stop
```

### Скрипт мониторинга PTP
```bash
#!/bin/bash
# /usr/local/bin/monitor-intel-ptp.sh

INTERFACE="eth0"
LOG_FILE="/var/log/ptp4l-monitor.log"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Проверка статуса PTP
    if pgrep -f "ptp4l.*$INTERFACE" > /dev/null; then
        STATUS="RUNNING"
    else
        STATUS="STOPPED"
    fi
    
    # Проверка hardware timestamping
    TIMESTAMPING=$(ethtool -T "$INTERFACE" | grep "HW timestamping" | cut -d: -f2 | tr -d ' ')
    
    # Статистика
    STATS=$(ethtool -S "$INTERFACE" | grep -E "rx_packets|tx_packets|rx_errors|tx_errors" | tr '\n' ' ')
    
    echo "[$TIMESTAMP] PTP: $STATUS, Timestamping: $TIMESTAMPING, Stats: $STATS" >> "$LOG_FILE"
    
    sleep 60
done
```

## Устранение неполадок

### Диагностические команды
```bash
# Проверка статуса PTP
sudo systemctl status ptp4l-intel-*

# Проверка логов
sudo journalctl -u ptp4l-intel-* -f

# Проверка hardware timestamping
sudo ethtool -T eth0

# Проверка статистики
sudo ethtool -S eth0 | grep -E "ptp|timestamp"

# Проверка PTP времени
sudo testptp -d /dev/ptp0 -g
```

### Частые проблемы и решения

1. **Hardware timestamping не работает**
   ```bash
   sudo modprobe -r igb
   sudo modprobe igb
   sudo ethtool -T eth0 rx-filter on
   ```

2. **Высокая задержка PTP**
   ```bash
   sudo ethtool -G eth0 rx 8192 tx 8192
   sudo ethtool -s eth0 speed 1000 duplex full autoneg off
   ```

3. **PTP не синхронизируется**
   ```bash
   sudo ptp4l -f /etc/ptp4l-intel-i210.conf -i eth0 -m -l 7
   ```

## Заключение

Данные конфигурации обеспечивают оптимальную работу Intel сетевых карт I210, I225, I226 с Quantum-PCI в различных сценариях использования. Выберите подходящую конфигурацию в зависимости от ваших требований к точности и производительности.
