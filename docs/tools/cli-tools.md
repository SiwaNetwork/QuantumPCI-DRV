# Описание утилит CLI

## Обзор

Данный документ описывает утилиты командной строки для работы с PTP OCP драйвером и системой временной синхронизации.

## Работа с Quantum-PCI TimeCard через sysfs

### Основные команды

#### Проверка устройства

```bash
# Список Quantum-PCI TimeCard устройств
ls /sys/class/timecard/

# Информация о устройстве
cat /sys/class/timecard/ocp0/serialnum
cat /sys/class/timecard/ocp0/clock_source
cat /sys/class/timecard/ocp0/gnss_sync
```

#### Настройка источника времени

```bash
# Просмотр доступных источников
cat /sys/class/timecard/ocp0/available_clock_sources

# Установка источника
echo "GNSS" > /sys/class/timecard/ocp0/clock_source
echo "MAC" > /sys/class/timecard/ocp0/clock_source
echo "external" > /sys/class/timecard/ocp0/clock_source
```

#### Конфигурация SMA коннекторов

```bash
# Просмотр доступных сигналов
cat /sys/class/timecard/ocp0/available_sma_inputs
cat /sys/class/timecard/ocp0/available_sma_outputs

# Настройка входов
echo "10MHz" > /sys/class/timecard/ocp0/sma1_in
echo "PPS" > /sys/class/timecard/ocp0/sma2_in

# Настройка выходов
echo "10MHz" > /sys/class/timecard/ocp0/sma3_out
echo "PPS" > /sys/class/timecard/ocp0/sma4_out
```

#### Калибровка задержек

```bash
# Установка задержек (в наносекундах)
echo "100" > /sys/class/timecard/ocp0/external_pps_cable_delay
echo "50" > /sys/class/timecard/ocp0/internal_pps_cable_delay
echo "25" > /sys/class/timecard/ocp0/pci_delay

# UTC-TAI offset
echo "37" > /sys/class/timecard/ocp0/utc_tai_offset
```

#### Получение связанных устройств

```bash
# Автоматическое определение PTP устройства
PTP_DEV=$(basename $(readlink /sys/class/timecard/ocp0/ptp))
echo "PTP device: /dev/$PTP_DEV"

# Получение последовательных портов
GNSS_TTY=$(basename $(readlink /sys/class/timecard/ocp0/ttyGNSS))
MAC_TTY=$(basename $(readlink /sys/class/timecard/ocp0/ttyMAC))
NMEA_TTY=$(basename $(readlink /sys/class/timecard/ocp0/ttyNMEA))

echo "GNSS port: /dev/$GNSS_TTY"
echo "MAC port: /dev/$MAC_TTY"
echo "NMEA port: /dev/$NMEA_TTY"
```

## Основные утилиты PTP

### testptp

Основная тестовая утилита для работы с PTP устройствами.

#### Синтаксис

```bash
testptp [OPTIONS] -d DEVICE
```

#### Основные опции

```bash
-d DEVICE    # PTP устройство (например, /dev/ptp0)
-c           # Показать capabilities устройства
-g           # Получить текущее время
-s           # Установить время
-t SECONDS   # Установить время в секундах UNIX
-a           # Корректировка времени
-f FREQ      # Корректировка частоты в ppb
-p PERIOD    # Периодический выход (наносекунды)
-w WIDTH     # Ширина импульса (наносекунды)
-H SECONDS   # Фаза периодического выхода
-i INDEX     # Индекс пина
-k           # Показать kernel info
-l           # Список пинов
-L           # Показать pin functions
-n SAMPLES   # Количество образцов для тестирования
-o           # Одиночное измерение offset
-v           # Verbose режим
```

#### Примеры использования

```bash
# Показать capabilities
sudo testptp -d /dev/ptp0 -c

# Получить текущее время
sudo testptp -d /dev/ptp0 -g

# Установить время от системных часов
sudo testptp -d /dev/ptp0 -s

# Корректировка частоты на +100 ppb
sudo testptp -d /dev/ptp0 -f 100

# Настройка периодического выхода 1 PPS
sudo testptp -d /dev/ptp0 -p 1000000000

# Измерение offset 10 раз
sudo testptp -d /dev/ptp0 -n 10 -o

# Показать информацию о пинах
sudo testptp -d /dev/ptp0 -L
```

### ptp4l

Демон PTP версии 4 (IEEE 1588).

#### Синтаксис

```bash
ptp4l [OPTIONS] [CONFIG_FILE]
```

#### Основные опции

```bash
-f FILE      # Конфигурационный файл
-i IFACE     # Сетевой интерфейс
-p /dev/ptpX # PTP устройство
-s           # Slave only режим
-m           # Печать сообщений в stdout
-q           # Не печатать сообщения в stdout
-v           # Verbose режим
-l LEVEL     # Уровень логирования (0-7)
-u ADDR      # Unix domain socket адрес
-2           # IEEE 802.3 transport
-4           # IPv4 UDP transport
-6           # IPv6 UDP transport
```

#### Примеры использования

```bash
# Запуск с конфигурационным файлом
sudo ptp4l -f /etc/ptp4l.conf -m

# Запуск в slave режиме
sudo ptp4l -i eth0 -s -m

# Запуск с hardware timestamping
sudo ptp4l -i eth0 -m -s /dev/ptp0

# Запуск с Layer 2 transport
sudo ptp4l -i eth0 -2 -m

# Запуск с отладкой
sudo ptp4l -f /etc/ptp4l.conf -m -l 7
```

### phc2sys

Синхронизация между PTP hardware clock и системными часами.

#### Синтаксис

```bash
phc2sys [OPTIONS]
```

#### Основные опции

```bash
-s DEVICE    # Источник времени (/dev/ptpX или CLOCK_REALTIME)
-c CLOCK     # Целевые часы (CLOCK_REALTIME или /dev/ptpX)
-w           # Ждать ptp4l синхронизации
-m           # Печать сообщений в stdout
-q           # Не печатать сообщения в stdout
-n DOMAIN    # PTP домен
-u SUMMARY   # Интервал summary сообщений
-R RATE      # Частота синхронизации
-E SERVO     # Тип сервосистемы (pi, linreg, ntpshm)
-P KP        # Пропорциональная константа PI
-I KI        # Интегральная константа PI
-S STEP      # Порог step коррекции
-F FIRST     # Порог первой step коррекции
-r           # Использовать syslog
-l LEVEL     # Уровень логирования
```

#### Примеры использования

```bash
# Синхронизация системных часов с PTP
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -w -m

# Синхронизация с автоматическим определением
sudo phc2sys -a -r

# Синхронизация с конкретной частотой
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -R 256 -m

# Синхронизация с пользовательскими параметрами PI
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -P 0.7 -I 0.3 -m
```

### pmc

PTP Management Client для управления и мониторинга PTP.

#### Синтаксис

```bash
pmc [OPTIONS] [COMMAND]
```

#### Основные опции

```bash
-u           # Использовать UDP transport
-2           # Использовать L2 transport
-4           # Использовать IPv4
-6           # Использовать IPv6
-i IFACE     # Сетевой интерфейс
-b BOUNDARY  # Target boundary hops
-d DOMAIN    # PTP домен
-s ADDR      # Source address
-t TIMEOUT   # Таймаут ответа
```

#### Основные команды

```bash
'GET DEFAULT_DATA_SET'       # Получить основные параметры часов
'GET CURRENT_DATA_SET'       # Получить текущее состояние
'GET PARENT_DATA_SET'        # Получить информацию о parent
'GET TIME_PROPERTIES_DATA_SET' # Получить временные свойства
'GET PORT_DATA_SET'          # Получить состояние порта
'GET PRIORITY1 <value>'      # Установить priority1
'GET PRIORITY2 <value>'      # Установить priority2
'GET DOMAIN <value>'         # Установить домен
'GET SLAVE_ONLY <value>'     # Установить slave-only режим
```

#### Примеры использования

```bash
# Получить основную информацию
pmc -u -b 0 'GET DEFAULT_DATA_SET'

# Получить текущий offset
pmc -u -b 0 'GET CURRENT_DATA_SET'

# Получить информацию о master
pmc -u -b 0 'GET PARENT_DATA_SET'

# Установить priority
pmc -u -b 0 'SET PRIORITY1 128'

# Мониторинг состояния порта
pmc -u -b 0 'GET PORT_DATA_SET'
```

## Утилиты для диагностики

### chronyc

Клиент для управления chronyd.

#### Основные команды

```bash
chronyc sources       # Показать источники времени
chronyc sourcestats   # Статистика источников
chronyc tracking      # Текущее состояние синхронизации
chronyc makestep      # Принудительная step коррекция
chronyc burst         # Burst режим
chronyc online        # Включить источник
chronyc offline       # Выключить источник
```

#### Примеры использования

```bash
# Показать все источники времени
chronyc sources -v

# Показать статистику источников
chronyc sourcestats

# Мониторинг состояния
chronyc tracking

# Принудительная синхронизация
chronyc makestep

# Работа с PHC источником
chronyc sources | grep PHC
```

### ntpq

Утилита для работы с NTP (при использовании ntpd вместо chrony).

#### Основные команды

```bash
ntpq -p              # Показать peers
ntpq -c rv           # Показать переменные системы
ntpq -c as           # Показать ассоциации
ntpq -c pe           # Подробная информация о peers
```

## Системные утилиты

### ethtool

Утилита для настройки сетевых интерфейсов.

#### PTP-специфичные команды

```bash
# Проверка hardware timestamping
ethtool -T eth0

# Настройка интерфейса
ethtool -s eth0 speed 1000 duplex full autoneg off

# Настройка буферов
ethtool -G eth0 rx 4096 tx 4096

# Настройка coalescing
ethtool -C eth0 rx-usecs 1 tx-usecs 1

# Показать статистику
ethtool -S eth0

# Показать информацию о драйвере
ethtool -i eth0
```

### lspci

Просмотр PCI устройств.

```bash
# Показать все PCI устройства
lspci

# Показать детальную информацию
lspci -vvv

# Найти PTP-related устройства
lspci | grep -i time
lspci | grep -i ptp
lspci | grep 1d9b  # Facebook/Meta vendor ID
```

### dmesg

Просмотр сообщений ядра.

```bash
# Показать все PTP сообщения
dmesg | grep -i ptp

# Показать сообщения драйвера
dmesg | grep ptp_ocp

# Мониторинг в реальном времени
dmesg -w | grep -i ptp
```

## Скрипты мониторинга

### Скрипт проверки состояния PTP

```bash
#!/bin/bash
# ptp-status.sh - Проверка состояния PTP

echo "=== PTP Status Check ==="
echo "Date: $(date)"
echo

# Проверка драйвера
echo "Driver Status:"
if lsmod | grep -q ptp_ocp; then
    echo "✓ ptp_ocp loaded"
else
    echo "✗ ptp_ocp not loaded"
fi
echo

# Проверка устройств
echo "PTP Devices:"
ls /dev/ptp* 2>/dev/null || echo "No PTP devices found"
echo

# Проверка процессов
echo "PTP Processes:"
pgrep -fa ptp4l || echo "ptp4l not running"
pgrep -fa phc2sys || echo "phc2sys not running"
echo

# Проверка синхронизации
if pgrep -q ptp4l; then
    echo "PTP Synchronization:"
    pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null | grep -E "(offsetFromMaster|clockIdentity)"
fi
```

### Скрипт мониторинга offset

```bash
#!/bin/bash
# ptp-monitor.sh - Непрерывный мониторинг PTP offset

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    offset=$(pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null | grep offsetFromMaster | awk '{print $2}')
    
    if [ -n "$offset" ]; then
        echo "$timestamp: Offset = $offset ns"
    else
        echo "$timestamp: Unable to get offset"
    fi
    
    sleep 1
done
```

### Скрипт проверки network timestamping

```bash
#!/bin/bash
# check-timestamping.sh - Проверка hardware timestamping

for iface in $(ls /sys/class/net/ | grep -v lo); do
    echo "Interface: $iface"
    ethtool -T $iface 2>/dev/null | grep -E "(hardware|software)" || echo "  No timestamping info"
    echo
done
```

## Автоматизация

### Systemd timer для мониторинга

```ini
# /etc/systemd/system/ptp-health-check.timer
[Unit]
Description=PTP Health Check Timer
Requires=ptp-health-check.service

[Timer]
OnBootSec=15min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/ptp-health-check.service
[Unit]
Description=PTP Health Check
Type=oneshot

[Service]
ExecStart=/usr/local/bin/ptp-status.sh
User=root
```

### Cron задачи

```bash
# /etc/cron.d/ptp-monitoring
# Проверка каждые 5 минут
*/5 * * * * root /usr/local/bin/ptp-status.sh >> /var/log/ptp-health.log 2>&1

# Ротация логов
0 0 * * * root find /var/log -name "ptp-*.log" -mtime +7 -delete
```

## Отладка и профилирование

### Включение отладки

```bash
# Включение kernel debug для PTP
echo 'module ptp_ocp +p' > /sys/kernel/debug/dynamic_debug/control

# Увеличение log level для ptp4l
ptp4l -f /etc/ptp4l.conf -m -l 7

# Отладка phc2sys
phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -w -m -l 7
```

### Профилирование производительности

```bash
# Мониторинг CPU использования
top -p $(pgrep ptp4l)

# Мониторинг прерываний
watch -n 1 'cat /proc/interrupts | grep eth0'

# Анализ сетевого трафика
tcpdump -i eth0 -nn udp port 319 or udp port 320

# Профилирование с perf
perf top -p $(pgrep ptp4l)
```