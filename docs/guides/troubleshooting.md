# Устранение неполадок

## Обзор

Руководство по диагностике и устранению типичных проблем с драйвером PTP OCP.

## Диагностические утилиты

### Основные команды диагностики

```bash
# Проверка состояния драйвера
lsmod | grep ptp
dmesg | grep -i ptp | tail -20
journalctl -k | grep ptp

# Проверка TimeCard устройств
ls -la /sys/class/timecard/
if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "TimeCard device info:"
    cat /sys/class/timecard/ocp0/serialnum
    cat /sys/class/timecard/ocp0/clock_source
    cat /sys/class/timecard/ocp0/gnss_sync
fi

# Проверка PTP устройств
ls -la /dev/ptp*
cat /sys/class/ptp/ptp*/clock_name

# Тестирование функциональности
# Определение PTP устройства из TimeCard
if [ -L "/sys/class/timecard/ocp0/ptp" ]; then
    PTP_DEV=$(basename $(readlink /sys/class/timecard/ocp0/ptp))
else
    PTP_DEV="ptp0"
fi

sudo testptp -d /dev/$PTP_DEV -c  # capabilities
sudo testptp -d /dev/$PTP_DEV -g  # get time
sudo testptp -d /dev/$PTP_DEV -k  # kernel info

# Проверка PCI устройств
lspci | grep -i time
lspci -vvv | grep -A 20 -B 5 -i ptp
```

### Утилиты мониторинга

```bash
# Мониторинг PTP статистики
pmc -u -b 0 'GET DEFAULT_DATA_SET'
pmc -u -b 0 'GET CURRENT_DATA_SET'
pmc -u -b 0 'GET PARENT_DATA_SET'
pmc -u -b 0 'GET TIME_PROPERTIES_DATA_SET'

# Непрерывный мониторинг offset
watch -n 1 'pmc -u -b 0 "GET CURRENT_DATA_SET" | grep offsetFromMaster'

# Проверка network timestamping
ethtool -T eth0
tcpdump -i eth0 -nn udp port 319 or udp port 320
```

## Типичные проблемы

### Проблемы с загрузкой драйвера

#### Драйвер не загружается

**Симптомы:**
```bash
$ sudo modprobe ptp_ocp
modprobe: ERROR: could not insert 'ptp_ocp': Operation not permitted
```

**Диагностика:**
```bash
# Проверка зависимостей
modprobe --show-depends ptp_ocp

# Проверка Secure Boot
mokutil --sb-state

# Проверка подписи модуля
modinfo ptp_ocp | grep sig
```

**Решения:**
```bash
# Загрузка зависимостей вручную
sudo modprobe ptp
sudo modprobe pps_core

# Отключение Secure Boot или подпись модуля
# Временное решение:
sudo modprobe --force-vermagic --force-modversion ptp_ocp

# Постоянное решение - пересборка модуля для текущего ядра
make clean && make
```

#### Модуль загружается, но устройство не обнаруживается

**Симптомы:**
```bash
$ lsmod | grep ptp_ocp
ptp_ocp                45056  0

$ ls /dev/ptp*
ls: cannot access '/dev/ptp*': No such file or directory
```

**Диагностика:**
```bash
# Проверка PCI устройств
lspci | grep -E "(1d9b|8086)" | grep -i time
sudo lspci -vvv | grep -A 30 -B 5 "Class 0c00"

# Проверка dmesg на ошибки
dmesg | grep -i ptp_ocp
dmesg | grep -i "probe failed"

# Проверка IOMMU
dmesg | grep -i iommu
```

**Решения:**
```bash
# Принудительная загрузка с отладкой
sudo rmmod ptp_ocp
sudo modprobe ptp_ocp debug=7

# Отключение IOMMU (если проблема в нем)
# Добавить в /etc/default/grub:
# GRUB_CMDLINE_LINUX_DEFAULT="... intel_iommu=off"
# sudo update-grub && sudo reboot

# Проверка BIOS настроек для PCI устройств
```

### Проблемы с временной синхронизацией

#### Большой offset от master

**Симптомы:**
```bash
$ pmc -u -b 0 'GET CURRENT_DATA_SET'
offsetFromMaster     152384567
```

**Диагностика:**
```bash
# Проверка network timestamping
ethtool -T eth0

# Проверка конфигурации PTP
cat /etc/ptp4l.conf | grep -E "(time_stamping|delay_mechanism)"

# Проверка сетевой задержки
ping -c 10 <master_ip>

# Анализ PTP трафика
sudo tcpdump -i eth0 -nn -v udp port 319
```

**Решения:**
```bash
# Включение hardware timestamping
echo "time_stamping hardware" >> /etc/ptp4l.conf

# Настройка правильного delay mechanism
echo "delay_mechanism E2E" >> /etc/ptp4l.conf  # для point-to-point
echo "delay_mechanism P2P" >> /etc/ptp4l.conf  # для peer-to-peer

# Оптимизация сетевого интерфейса
sudo ethtool -s eth0 speed 1000 duplex full autoneg off
sudo ethtool -G eth0 rx 4096 tx 4096
```

#### PTP не синхронизируется (UNCALIBRATED)

**Симптомы:**
```bash
$ pmc -u -b 0 'GET PORT_DATA_SET'
portState            UNCALIBRATED
```

**Диагностика:**
```bash
# Проверка логов ptp4l
journalctl -u ptp4l -f

# Проверка announce сообщений
sudo tcpdump -i eth0 -nn udp port 320

# Проверка master reachability
pmc -u -b 0 'GET PARENT_DATA_SET'
```

**Решения:**
```bash
# Увеличение timeout значений
echo "announceReceiptTimeout 6" >> /etc/ptp4l.conf
echo "syncReceiptTimeout 6" >> /etc/ptp4l.conf

# Проверка clockClass и priority
pmc -u -b 0 'SET PRIORITY1 128'
pmc -u -b 0 'SET PRIORITY2 128'

# Рестарт PTP с очисткой состояния
sudo systemctl stop ptp4l
sudo rm -f /var/run/ptp4l
sudo systemctl start ptp4l
```

### Проблемы с GPIO и периодическими выходами

#### GPIO пины не работают

**Симптомы:**
```bash
$ sudo testptp -d /dev/ptp0 -L
no pins available
```

**Диагностика:**
```bash
# Проверка capabilities
sudo testptp -d /dev/ptp0 -c | grep pins

# Проверка sysfs
ls -la /sys/class/ptp/ptp0/pins/

# Проверка dmesg для GPIO ошибок
dmesg | grep -i gpio
```

**Решения:**
```bash
# Загрузка драйвера с GPIO поддержкой
sudo rmmod ptp_ocp
sudo modprobe ptp_ocp gpio_mode=1

# Ручная настройка пинов через sysfs
echo "2 0 0" > /sys/class/ptp/ptp0/pins/SMA1
echo "1 0 0" > /sys/class/ptp/ptp0/pins/SMA2
```

#### Периодический выход не работает

**Симптомы:**
Нет сигнала на выходном пине

**Диагностика:**
```bash
# Проверка конфигурации перOut
sudo testptp -d /dev/ptp0 -p 1000000000 -w 500000000

# Проверка статуса пина
cat /sys/class/ptp/ptp0/pins/*/
```

**Решения:**
```bash
# Настройка периодического выхода с правильными параметрами
sudo testptp -d /dev/ptp0 -p 1000000000 -w 100000000 -i 0

# Проверка фазы и duty cycle
sudo testptp -d /dev/ptp0 -H 0 -w 500000000
```

### Проблемы с производительностью

#### Высокий jitter

**Симптомы:**
```bash
$ phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -m
phc2sys[1234]: offset    -1234 s0 freq  +12345 delay   567
```

**Диагностика:**
```bash
# Проверка загрузки CPU
top -p $(pgrep ptp4l)
iostat 1 5

# Проверка прерываний
cat /proc/interrupts | grep eth0
watch -n 1 'cat /proc/interrupts | grep eth0'

# Проверка настроек планировщика
chrt -p $(pgrep ptp4l)
```

**Решения:**
```bash
# Повышение приоритета процесса
sudo chrt -f 80 ptp4l -f /etc/ptp4l.conf

# Настройка IRQ affinity
echo 2 > /proc/irq/$(grep eth0 /proc/interrupts | cut -d: -f1)/smp_affinity

# Изоляция CPU
# В /etc/default/grub:
# GRUB_CMDLINE_LINUX_DEFAULT="isolcpus=1,2 nohz_full=1,2"
```

#### Частые step corrections

**Симптомы:**
```bash
$ journalctl -u ptp4l | grep step
ptp4l: clockcheck: clock step detected
```

**Диагностика:**
```bash
# Проверка step_threshold
grep step_threshold /etc/ptp4l.conf

# Анализ frequency drift
pmc -u -b 0 'GET CURRENT_DATA_SET' | grep frequencyTracking
```

**Решения:**
```bash
# Уменьшение step_threshold
echo "step_threshold 0.000002" >> /etc/ptp4l.conf
echo "first_step_threshold 0.000020" >> /etc/ptp4l.conf

# Настройка servo parameters
echo "pi_proportional_const 0.0" >> /etc/ptp4l.conf
echo "pi_integral_const 0.0" >> /etc/ptp4l.conf
```

### Проблемы с TimeCard

#### TimeCard устройство не обнаружено

**Симптомы:**
```bash
$ ls /sys/class/timecard/
ls: cannot access '/sys/class/timecard/': No such file or directory
```

**Диагностика:**
```bash
# Проверка загрузки драйвера
lsmod | grep ptp_ocp

# Проверка PCI устройств
lspci | grep -E "(1d9b|18d4|1ad7)"
lspci -nn | grep -E "(1d9b:0400|18d4:1008|1ad7:a000)"

# Проверка логов драйвера
dmesg | grep -i ptp_ocp
journalctl -k | grep ptp_ocp
```

**Решения:**
```bash
# Перезагрузка драйвера
sudo rmmod ptp_ocp
sudo modprobe ptp_ocp

# Проверка идентификаторов устройств
lspci -nn | grep "Time\|Clock"

# Проверка BIOS настроек (VT-d должен быть включен)
# Перезагрузите систему и проверьте BIOS
```

#### GNSS не синхронизируется

**Симптомы:**
```bash
$ cat /sys/class/timecard/ocp0/gnss_sync
unlocked
```

**Диагностика:**
```bash
# Проверка GNSS порта
GNSS_TTY=$(basename $(readlink /sys/class/timecard/ocp0/ttyGNSS))
sudo cat /dev/$GNSS_TTY | head -20

# Проверка NMEA сообщений
NMEA_TTY=$(basename $(readlink /sys/class/timecard/ocp0/ttyNMEA))
sudo cat /dev/$NMEA_TTY | head -10

# Проверка источника часов
cat /sys/class/timecard/ocp0/clock_source
cat /sys/class/timecard/ocp0/available_clock_sources
```

**Решения:**
```bash
# Установка GNSS как источника времени
echo "GNSS" > /sys/class/timecard/ocp0/clock_source

# Проверка антенны GNSS (должна быть подключена и иметь обзор неба)
# Ожидание синхронизации (может занять до 15 минут)
timeout=900  # 15 минут
while [ $timeout -gt 0 ]; do
    sync_status=$(cat /sys/class/timecard/ocp0/gnss_sync)
    echo "GNSS status: $sync_status (timeout: ${timeout}s)"
    if [ "$sync_status" = "locked" ]; then
        echo "GNSS synchronized!"
        break
    fi
    sleep 10
    timeout=$((timeout - 10))
done
```

#### SMA коннекторы не работают

**Симптомы:**
Нет сигнала на SMA выходах или неправильная конфигурация входов

**Диагностика:**
```bash
# Проверка доступных сигналов
cat /sys/class/timecard/ocp0/available_sma_inputs
cat /sys/class/timecard/ocp0/available_sma_outputs

# Проверка текущей конфигурации
cat /sys/class/timecard/ocp0/sma1_in
cat /sys/class/timecard/ocp0/sma2_in
cat /sys/class/timecard/ocp0/sma3_out
cat /sys/class/timecard/ocp0/sma4_out
```

**Решения:**
```bash
# Настройка SMA коннекторов
echo "10MHz" > /sys/class/timecard/ocp0/sma1_in
echo "PPS" > /sys/class/timecard/ocp0/sma2_in
echo "10MHz" > /sys/class/timecard/ocp0/sma3_out
echo "PPS" > /sys/class/timecard/ocp0/sma4_out

# Проверка кабельных соединений
# Убедитесь, что SMA кабели правильно подключены
```

#### Высокая задержка или неточность

**Симптомы:**
```bash
$ sudo testptp -d /dev/ptp0 -o
offset from CLOCK_REALTIME is 12345678ns
```

**Диагностика:**
```bash
# Проверка задержек кабелей
cat /sys/class/timecard/ocp0/external_pps_cable_delay
cat /sys/class/timecard/ocp0/internal_pps_cable_delay
cat /sys/class/timecard/ocp0/pci_delay

# Проверка UTC-TAI offset
cat /sys/class/timecard/ocp0/utc_tai_offset
```

**Решения:**
```bash
# Калибровка задержек (в наносекундах)
# Измерьте длину кабелей и используйте ~5ns на метр для коаксиальных кабелей
echo "100" > /sys/class/timecard/ocp0/external_pps_cable_delay
echo "50" > /sys/class/timecard/ocp0/internal_pps_cable_delay
echo "25" > /sys/class/timecard/ocp0/pci_delay

# Обновление UTC-TAI offset (37 секунд на 2024 год)
echo "37" > /sys/class/timecard/ocp0/utc_tai_offset
```

#### Скрипт диагностики TimeCard

```bash
#!/bin/bash
# Комплексная диагностика TimeCard

echo "=== TimeCard Diagnostics ==="

TIMECARD_BASE="/sys/class/timecard/ocp0"

if [ ! -d "$TIMECARD_BASE" ]; then
    echo "ERROR: TimeCard device not found"
    echo "Checking driver status..."
    lsmod | grep ptp_ocp
    echo "Checking PCI devices..."
    lspci | grep -E "(1d9b|18d4|1ad7)"
    exit 1
fi

echo "✓ TimeCard device found"
echo "Serial number: $(cat $TIMECARD_BASE/serialnum)"
echo "Clock source: $(cat $TIMECARD_BASE/clock_source)"
echo "GNSS sync: $(cat $TIMECARD_BASE/gnss_sync)"

echo
echo "=== SMA Configuration ==="
echo "SMA1 in: $(cat $TIMECARD_BASE/sma1_in 2>/dev/null || echo 'N/A')"
echo "SMA2 in: $(cat $TIMECARD_BASE/sma2_in 2>/dev/null || echo 'N/A')"
echo "SMA3 out: $(cat $TIMECARD_BASE/sma3_out 2>/dev/null || echo 'N/A')"
echo "SMA4 out: $(cat $TIMECARD_BASE/sma4_out 2>/dev/null || echo 'N/A')"

echo
echo "=== Delay Configuration ==="
echo "External PPS delay: $(cat $TIMECARD_BASE/external_pps_cable_delay)ns"
echo "Internal PPS delay: $(cat $TIMECARD_BASE/internal_pps_cable_delay)ns"
echo "PCI delay: $(cat $TIMECARD_BASE/pci_delay)ns"
echo "UTC-TAI offset: $(cat $TIMECARD_BASE/utc_tai_offset)s"

echo
echo "=== Linked Devices ==="
if [ -L "$TIMECARD_BASE/ptp" ]; then
    PTP_DEV=$(basename $(readlink $TIMECARD_BASE/ptp))
    echo "PTP device: /dev/$PTP_DEV"
fi

if [ -L "$TIMECARD_BASE/ttyGNSS" ]; then
    GNSS_TTY=$(basename $(readlink $TIMECARD_BASE/ttyGNSS))
    echo "GNSS port: /dev/$GNSS_TTY"
fi

if [ -L "$TIMECARD_BASE/ttyNMEA" ]; then
    NMEA_TTY=$(basename $(readlink $TIMECARD_BASE/ttyNMEA))
    echo "NMEA port: /dev/$NMEA_TTY"
fi

echo
echo "=== PTP Test ==="
if [ -n "$PTP_DEV" ]; then
    sudo testptp -d /dev/$PTP_DEV -g 2>/dev/null && echo "✓ PTP device responsive" || echo "✗ PTP device error"
fi

echo "=== TimeCard Diagnostics Complete ==="
```

## Расширенная диагностика

### Анализ network timestamping

```bash
#!/bin/bash
# Скрипт для проверки network timestamping

ETH_DEV="eth0"

echo "=== Network Timestamping Analysis ==="
echo "Interface: $ETH_DEV"
echo

# Проверка capabilities
echo "Timestamping capabilities:"
ethtool -T $ETH_DEV
echo

# Проверка статистики
echo "Interface statistics:"
ethtool -S $ETH_DEV | grep -E "(timestamp|ptp|time)"
echo

# Проверка драйвера
echo "Driver information:"
ethtool -i $ETH_DEV
echo

# Проверка настроек
echo "Current settings:"
ethtool $ETH_DEV
```

### Анализ PTP трафика

```bash
#!/bin/bash
# Скрипт для анализа PTP трафика

ETH_DEV="eth0"
CAPTURE_TIME=60

echo "Capturing PTP traffic for $CAPTURE_TIME seconds..."

# Capture PTP packets
sudo timeout $CAPTURE_TIME tcpdump -i $ETH_DEV -w /tmp/ptp_capture.pcap \
    -nn udp port 319 or udp port 320

echo "Analysis results:"

# Analyze captured packets
if [ -f /tmp/ptp_capture.pcap ]; then
    echo "Total PTP packets:"
    tcpdump -r /tmp/ptp_capture.pcap -nn | wc -l
    
    echo -e "\nPacket breakdown:"
    tcpdump -r /tmp/ptp_capture.pcap -nn | \
        awk '{print $5}' | sort | uniq -c | sort -nr
    
    echo -e "\nTiming analysis:"
    tcpdump -r /tmp/ptp_capture.pcap -nn -t | \
        head -20
fi
```

### Автоматическая диагностика

```bash
#!/bin/bash
# Автоматический диагностический скрипт

echo "=== PTP OCP Automatic Diagnostics ==="
echo "Timestamp: $(date)"
echo

# Проверка драйвера
echo "1. Driver Status:"
if lsmod | grep -q ptp_ocp; then
    echo "✓ ptp_ocp module loaded"
    modinfo ptp_ocp | grep -E "(version|srcversion)"
else
    echo "✗ ptp_ocp module not loaded"
fi
echo

# Проверка устройств
echo "2. Device Status:"
if ls /dev/ptp* >/dev/null 2>&1; then
    echo "✓ PTP devices found:"
    ls -la /dev/ptp*
    for dev in /dev/ptp*; do
        echo "  $dev capabilities:"
        sudo testptp -d $dev -c 2>/dev/null | head -5
    done
else
    echo "✗ No PTP devices found"
fi
echo

# Проверка PCI
echo "3. PCI Devices:"
if lspci | grep -E "(1d9b|time)" >/dev/null; then
    echo "✓ PTP-related PCI devices:"
    lspci | grep -E "(1d9b|time)"
else
    echo "? No obvious PTP PCI devices found"
    echo "All timing devices:"
    lspci | grep -i time
fi
echo

# Проверка сетевых интерфейсов
echo "4. Network Timestamping:"
for iface in $(ip link show | grep '^[0-9]' | grep -v lo | awk -F: '{print $2}' | tr -d ' '); do
    echo "Interface $iface:"
    if ethtool -T $iface 2>/dev/null | grep -q "hardware-transmit"; then
        echo "  ✓ Hardware timestamping supported"
    else
        echo "  ✗ Hardware timestamping not supported"
    fi
done
echo

# Проверка PTP процессов
echo "5. PTP Processes:"
if pgrep -f ptp4l >/dev/null; then
    echo "✓ ptp4l running (PID: $(pgrep -f ptp4l))"
else
    echo "✗ ptp4l not running"
fi

if pgrep -f phc2sys >/dev/null; then
    echo "✓ phc2sys running (PID: $(pgrep -f phc2sys))"
else
    echo "✗ phc2sys not running"
fi
echo

# Проверка синхронизации
echo "6. Synchronization Status:"
if pgrep -f ptp4l >/dev/null; then
    OFFSET=$(pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null | grep offsetFromMaster | awk '{print $2}')
    if [ -n "$OFFSET" ]; then
        echo "Current offset: $OFFSET ns"
        if [ "${OFFSET#-}" -lt 1000000 ]; then
            echo "✓ Good synchronization (< 1ms offset)"
        else
            echo "⚠ Poor synchronization (> 1ms offset)"
        fi
    else
        echo "✗ Cannot determine synchronization status"
    fi
else
    echo "✗ PTP not running"
fi

echo
echo "=== Diagnostics Complete ==="
echo "For detailed troubleshooting, check:"
echo "- dmesg | grep ptp"
echo "- journalctl -u ptp4l"
echo "- /var/log/ptp*.log"
```

## Коллекция логов для поддержки

### Скрипт сбора диагностической информации

```bash
#!/bin/bash
# Скрипт для сбора информации для службы поддержки

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGDIR="/tmp/ptp_diagnostics_$TIMESTAMP"

mkdir -p $LOGDIR

echo "Collecting PTP diagnostics to $LOGDIR..."

# Системная информация
uname -a > $LOGDIR/system_info.txt
cat /proc/version >> $LOGDIR/system_info.txt
lsb_release -a >> $LOGDIR/system_info.txt 2>/dev/null

# Информация о драйвере
lsmod | grep ptp > $LOGDIR/modules.txt
modinfo ptp_ocp > $LOGDIR/driver_info.txt 2>/dev/null

# Kernel logs
dmesg | grep -i ptp > $LOGDIR/dmesg_ptp.txt
journalctl -k --no-pager | grep -i ptp > $LOGDIR/journal_kernel.txt

# PCI информация
lspci -vvv > $LOGDIR/lspci_verbose.txt
lspci | grep -E "(time|ptp|1d9b)" > $LOGDIR/pci_timing.txt

# PTP устройства
ls -la /dev/ptp* > $LOGDIR/ptp_devices.txt 2>/dev/null
ls -la /sys/class/ptp/ > $LOGDIR/ptp_sysfs.txt 2>/dev/null

# Конфигурационные файлы
cp /etc/ptp4l.conf $LOGDIR/ 2>/dev/null
cp /etc/chrony/chrony.conf $LOGDIR/ 2>/dev/null

# Статус сервисов
systemctl status ptp4l > $LOGDIR/ptp4l_status.txt 2>/dev/null
systemctl status phc2sys > $LOGDIR/phc2sys_status.txt 2>/dev/null
systemctl status chronyd > $LOGDIR/chronyd_status.txt 2>/dev/null

# PTP статистика
pmc -u -b 0 'GET DEFAULT_DATA_SET' > $LOGDIR/ptp_default_dataset.txt 2>/dev/null
pmc -u -b 0 'GET CURRENT_DATA_SET' > $LOGDIR/ptp_current_dataset.txt 2>/dev/null
pmc -u -b 0 'GET PARENT_DATA_SET' > $LOGDIR/ptp_parent_dataset.txt 2>/dev/null

# Network timestamping
for iface in $(ip link show | grep '^[0-9]' | awk -F: '{print $2}' | tr -d ' '); do
    ethtool -T $iface > $LOGDIR/timestamping_$iface.txt 2>/dev/null
done

# Создание архива
tar -czf $LOGDIR.tar.gz -C /tmp ptp_diagnostics_$TIMESTAMP

echo "Diagnostics collected in $LOGDIR.tar.gz"
echo "Please send this file to technical support"
```

## Ресурсы для дальнейшего изучения

### Документация
- Linux PTP Project: http://linuxptp.sourceforge.net/
- IEEE 1588 Standard
- ITU-T G.8275 Recommendations

### Утилиты
- `ptp4l` - PTP демон
- `phc2sys` - Синхронизация системных часов
- `pmc` - PTP management client
- `testptp` - Тестовая утилита

### Мониторинг
- Wireshark для анализа PTP трафика
- Prometheus + Grafana для долгосрочного мониторинга
- Custom scripts для специфических метрик