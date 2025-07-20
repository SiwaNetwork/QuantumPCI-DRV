# Документация по работе с LinuxPTP

## Оглавление
1. [Введение в LinuxPTP](#введение-в-linuxptp)
2. [Установка и настройка](#установка-и-настройка)
3. [PTP4L - основной демон PTP](#ptp4l---основной-демон-ptp)
4. [PHC2SYS - синхронизация системных часов](#phc2sys---синхронизация-системных-часов)
5. [TS2PHC - синхронизация с внешним источником времени](#ts2phc---синхронизация-с-внешним-источником-времени)
6. [Конфигурационные файлы](#конфигурационные-файлы)
7. [Практические примеры](#практические-примеры)
8. [Мониторинг и отладка](#мониторинг-и-отладка)
9. [Решение проблем](#решение-проблем)

## Введение в LinuxPTP

LinuxPTP - это реализация протокола Precision Time Protocol (PTP) для операционной системы Linux согласно стандарту IEEE 1588-2008. Пакет включает в себя несколько утилит для высокоточной синхронизации времени в сети.

### Основные компоненты:
- **ptp4l** - демон PTP для синхронизации сетевых интерфейсов
- **phc2sys** - утилита для синхронизации системных часов с PHC (PTP Hardware Clock)
- **ts2phc** - утилита для синхронизации PHC с внешним источником времени

### Преимущества PTP:
- Субмикросекундная точность синхронизации
- Автоматическая компенсация задержек сети
- Поддержка аппаратных временных меток
- Масштабируемость для больших сетей

## Установка и настройка

### Установка из пакетного менеджера

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install linuxptp
```

**RHEL/CentOS/Fedora:**
```bash
sudo yum install linuxptp
# или для новых версий
sudo dnf install linuxptp
```

### Проверка поддержки оборудования

Убедитесь, что сетевая карта поддерживает PTP:
```bash
# Проверка поддержки PTP временных меток
ethtool -T eth0

# Проверка наличия PHC
ls /dev/ptp*
```

### Настройка разрешений

```bash
# Добавление пользователя в группу для доступа к PTP устройствам
sudo usermod -a -G dialout $USER
```

## PTP4L - основной демон PTP

### Описание
`ptp4l` - это основной демон LinuxPTP, который реализует протокол PTP для синхронизации часов между устройствами в сети.

### Основные режимы работы

#### 1. Обычный режим (Ordinary Clock)
Устройство может быть либо мастером, либо слейвом:
```bash
# Запуск в режиме авто-выбора
sudo ptp4l -i eth0 -m

# Принудительный режим слейва
sudo ptp4l -i eth0 -s -m

# Принудительный режим мастера
sudo ptp4l -i eth0 -m --masterOnly
```

#### 2. Граничные часы (Boundary Clock)
Устройство синхронизируется с одним портом и предоставляет время через другие:
```bash
sudo ptp4l -i eth0 -i eth1 -m
```

#### 3. Прозрачные часы (Transparent Clock)
Пересылает PTP сообщения с коррекцией времени прохождения:
```bash
sudo ptp4l -i eth0 -E -m
```

### Основные параметры командной строки

| Параметр | Описание |
|----------|----------|
| `-i <interface>` | Сетевой интерфейс для PTP |
| `-m` | Вывод сообщений в stdout |
| `-s` | Режим слейва |
| `-f <config>` | Конфигурационный файл |
| `-l <level>` | Уровень логирования (0-7) |
| `-q` | Тихий режим |
| `-v` | Подробный вывод |
| `-H` | Использование аппаратных временных меток |
| `-S` | Использование программных временных меток |
| `-E` | Режим E2E (End-to-End) |
| `-P` | Режим P2P (Peer-to-Peer) |

### Примеры использования

```bash
# Базовый запуск с автоопределением роли
sudo ptp4l -i eth0 -m

# Запуск с конфигурационным файлом
sudo ptp4l -f /etc/ptp4l.conf -m

# Запуск в режиме слейва с высоким уровнем логирования
sudo ptp4l -i eth0 -s -l 7 -m

# Запуск с несколькими интерфейсами (Boundary Clock)
sudo ptp4l -i eth0 -i eth1 -f /etc/ptp4l.conf -m
```

## PHC2SYS - синхронизация системных часов

### Описание
`phc2sys` синхронизирует системные часы Linux с PTP Hardware Clock (PHC) или наоборот.

### Основные режимы работы

#### 1. Синхронизация системных часов с PHC
```bash
# Автоматическое определение лучшего PHC
sudo phc2sys -a -r

# Синхронизация с конкретным PHC
sudo phc2sys -s /dev/ptp0 -w
```

#### 2. Синхронизация PHC с системными часами
```bash
# Синхронизация PHC с системными часами
sudo phc2sys -s CLOCK_REALTIME -c /dev/ptp0 -w
```

#### 3. Синхронизация между PHC
```bash
# Синхронизация одного PHC с другим
sudo phc2sys -s /dev/ptp0 -c /dev/ptp1 -w
```

### Основные параметры

| Параметр | Описание |
|----------|----------|
| `-a` | Автоматический режим |
| `-r` | Только чтение, без коррекции |
| `-s <clock>` | Источник времени |
| `-c <clock>` | Целевые часы |
| `-w` | Ожидание синхронизации ptp4l |
| `-O <offset>` | Смещение в наносекундах |
| `-R <rate>` | Частота обновления (Гц) |
| `-n <domain>` | PTP домен |
| `-u <summary>` | Интервал сводной статистики |
| `-m` | Вывод в stdout |

### Примеры использования

```bash
# Автоматическая синхронизация с мониторингом
sudo phc2sys -a -r -m

# Синхронизация системных часов с eth0
sudo phc2sys -s eth0 -w -m

# Синхронизация с настраиваемой частотой
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -R 8 -m

# Синхронизация с добавлением смещения
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -O 1000000 -m
```

## TS2PHC - синхронизация с внешним источником времени

### Описание
`ts2phc` синхронизирует PTP Hardware Clock с внешним источником времени, таким как GPS или другие высокоточные источники.

### Принцип работы
- Использует внешний сигнал PPS (Pulse Per Second)
- Синхронизирует PHC с внешним источником
- Может работать в качестве источника времени для ptp4l

### Основные параметры

| Параметр | Описание |
|----------|----------|
| `-c <phc>` | Целевой PHC для синхронизации |
| `-s <source>` | Источник времени |
| `-f <config>` | Конфигурационный файл |
| `-l <level>` | Уровень логирования |
| `-m` | Вывод в stdout |
| `-q` | Тихий режим |

### Конфигурация для GPS

```bash
# Создание конфигурационного файла для GPS
cat << EOF > /etc/ts2phc.conf
[global]
use_syslog 1
verbose 1
logging_level 6

[/dev/ptp0]
ts2phc.pin_index 0
ts2phc.channel 0
ts2phc.extts_polarity rising
ts2phc.extts_correction 0

[/dev/pps0]
ts2phc.master 1
EOF
```

### Примеры использования

```bash
# Синхронизация PHC с GPS через PPS
sudo ts2phc -c /dev/ptp0 -s /dev/pps0 -m

# Использование конфигурационного файла
sudo ts2phc -f /etc/ts2phc.conf -m

# Синхронизация нескольких PHC
sudo ts2phc -c /dev/ptp0 -c /dev/ptp1 -s /dev/pps0 -m
```

## Конфигурационные файлы

### Конфигурация ptp4l (/etc/ptp4l.conf)

```ini
[global]
# Основные настройки
dataset_comparison                 ieee1588
domainNumber                       0
priority1                          128
priority2                          128
clockClass                         248
clockAccuracy                      0xFE
offsetScaledLogVariance           0xFFFF
free_running                       0
freq_est_interval                  1
dscp_event                         0
dscp_general                       0
assume_two_step                    0

# Сетевые настройки
network_transport                  UDPv4
udp_ttl                           1
udp6_scope                        0x0E
uds_address                       /var/run/ptp4l

# Временные интервалы (в степенях двойки секунд)
logAnnounceInterval               1
logSyncInterval                   0
logMinDelayReqInterval            0
logMinPdelayReqInterval           0

# Тайм-ауты
announceReceiptTimeout            3
syncReceiptTimeout                0
delayAsymmetry                    0
fault_reset_interval              4
fault_badpeernet_interval         16

# Алгоритм выбора мастера
G.8275.defaultDS.localPriority    128

# Часы и временные метки
time_stamping                     hardware
twoStepFlag                       1
slaveOnly                         0
gmCapable                         1
p2p_dst_mac                       01:1B:19:00:00:00
p2p_dst_mac                       01:80:C2:00:00:0E

# Настройки интерфейса
delay_mechanism                   E2E
egressLatency                     0
ingressLatency                    0
boundary_clock_jbod               0

# Алгоритм управления часами
pi_proportional_const             0.0
pi_integral_const                 0.0
pi_proportional_scale             0.0
pi_proportional_exponent          -0.3
pi_proportional_norm_max          0.7
pi_integral_scale                 0.0
pi_integral_exponent              0.4
pi_integral_norm_max              0.3
step_threshold                    0.0
max_frequency                     900000000

# Ведение журнала
use_syslog                        1
verbose                           0
summary_interval                  0
kernel_leap                       1
check_fup_sync                    0
```

### Конфигурация для специфических случаев

#### Конфигурация Grandmaster Clock
```ini
[global]
priority1                         0
clockClass                        6
clockAccuracy                     0x20
free_running                      0
slaveOnly                         0
```

#### Конфигурация Slave Clock
```ini
[global]
slaveOnly                         1
priority1                         255
clockClass                        255
```

#### Конфигурация Boundary Clock
```ini
[global]
boundary_clock_jbod               1

[eth0]
masterOnly                        0
hybrid_e2e                        1

[eth1]
masterOnly                        1
```

## Практические примеры

### Сценарий 1: Простая клиент-серверная синхронизация

**На сервере (Master):**
```bash
# Запуск ptp4l в режиме мастера
sudo ptp4l -i eth0 --masterOnly -m &

# Синхронизация системных часов с PHC
sudo phc2sys -s eth0 -w -m &
```

**На клиенте (Slave):**
```bash
# Запуск ptp4l в режиме слейва
sudo ptp4l -i eth0 -s -m &

# Синхронизация системных часов с PHC
sudo phc2sys -s eth0 -w -m &
```

### Сценарий 2: GPS-синхронизированный Grandmaster

```bash
# Синхронизация PHC с GPS
sudo ts2phc -c /dev/ptp0 -s /dev/pps0 -m &

# Запуск ptp4l как Grandmaster
sudo ptp4l -i eth0 -f /etc/ptp4l-gm.conf -m &

# Синхронизация системных часов
sudo phc2sys -s /dev/ptp0 -w -m &
```

### Сценарий 3: Boundary Clock

```bash
# Запуск boundary clock с двумя интерфейсами
sudo ptp4l -i eth0 -i eth1 -f /etc/ptp4l-bc.conf -m &

# Синхронизация системных часов с лучшим PHC
sudo phc2sys -a -r -m &
```

### Сценарий 4: Redundant Masters

**Первый мастер (приоритет 1):**
```ini
# /etc/ptp4l-master1.conf
[global]
priority1    100
clockClass   6
```

**Второй мастер (приоритет 2):**
```ini
# /etc/ptp4l-master2.conf
[global]
priority1    110
clockClass   6
```

## Мониторинг и отладка

### Команды для мониторинга

```bash
# Проверка статуса PTP портов
sudo pmc -u -b 0 'GET PORT_DATA_SET'

# Получение информации о текущем мастере
sudo pmc -u -b 0 'GET CURRENT_DATA_SET'

# Проверка качества синхронизации
sudo pmc -u -b 0 'GET TIME_PROPERTIES_DATA_SET'

# Мониторинг смещения времени
watch -n 1 'phc_ctl /dev/ptp0 cmp'

# Проверка статистики сетевого интерфейса
ethtool -S eth0 | grep ptp
```

### Утилиты для анализа

#### pmc (PTP Management Client)
```bash
# Получение всех доступных данных
sudo pmc -u -b 0 'GET DEFAULT_DATA_SET'
sudo pmc -u -b 0 'GET PARENT_DATA_SET'
sudo pmc -u -b 0 'GET PORT_DATA_SET'

# Управление портами
sudo pmc -u -b 0 'SET PORT_DATA_SET portState DISABLED'
sudo pmc -u -b 0 'SET PORT_DATA_SET portState LISTENING'
```

#### phc_ctl (PHC Control)
```bash
# Сравнение PHC с системными часами
phc_ctl /dev/ptp0 cmp

# Установка времени PHC
sudo phc_ctl /dev/ptp0 set $(date +%s)

# Получение времени PHC
phc_ctl /dev/ptp0 get

# Коррекция частоты PHC
sudo phc_ctl /dev/ptp0 freq 1000000
```

### Логирование и диагностика

```bash
# Запуск с подробным логированием
sudo ptp4l -i eth0 -l 7 -m 2>&1 | tee ptp4l.log

# Анализ логов в реальном времени
tail -f /var/log/syslog | grep ptp4l

# Фильтрация важных событий
journalctl -u ptp4l -f | grep -E "(MASTER|SLAVE|LISTENING|selected|best master)"
```

### Анализ производительности

```bash
# Создание скрипта для мониторинга смещения
cat << 'EOF' > monitor_offset.sh
#!/bin/bash
while true; do
    offset=$(phc_ctl /dev/ptp0 cmp 2>/dev/null | awk '{print $4}')
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp: PHC offset = $offset ns"
    sleep 1
done
EOF

chmod +x monitor_offset.sh
./monitor_offset.sh
```

## Решение проблем

### Частые проблемы и решения

#### 1. Отсутствие синхронизации

**Проблема:** ptp4l не синхронизируется
```bash
# Проверка поддержки аппаратных временных меток
ethtool -T eth0

# Проверка сетевого трафика PTP
sudo tcpdump -i eth0 port 319 or port 320

# Проверка firewall
sudo iptables -L | grep -E "(319|320)"
```

**Решение:**
```bash
# Открытие портов PTP
sudo iptables -A INPUT -p udp --dport 319 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 320 -j ACCEPT

# Принудительное использование программных временных меток
sudo ptp4l -i eth0 -S -m
```

#### 2. Большое смещение времени

**Проблема:** Большой offset между часами
```bash
# Проверка конфигурации PI контроллера
grep -E "pi_(proportional|integral)" /etc/ptp4l.conf

# Проверка step_threshold
grep step_threshold /etc/ptp4l.conf
```

**Решение:**
```ini
# Более агрессивные настройки PI контроллера
pi_proportional_const     0.7
pi_integral_const         0.3
step_threshold           20.0
```

#### 3. Проблемы с multicast

**Проблема:** PTP сообщения не доходят
```bash
# Проверка multicast маршрутов
ip route show | grep 224.0.1.129

# Проверка IGMP
cat /proc/net/igmp
```

**Решение:**
```bash
# Добавление multicast маршрута
sudo ip route add 224.0.1.129/32 dev eth0

# Использование unicast вместо multicast
# В конфигурации ptp4l:
# unicast_listen 1
# unicast_req_duration 3600
```

#### 4. Производительность PHC

**Проблема:** Нестабильная работа PHC
```bash
# Проверка стабильности частоты
watch -n 1 'phc_ctl /dev/ptp0 freq'

# Мониторинг джиттера
./monitor_offset.sh | awk '{print $6}' | sort -n | tail -20
```

**Решение:**
```ini
# Увеличение интервалов синхронизации
logSyncInterval          1
logMinDelayReqInterval   1
freq_est_interval        2
```

### Диагностические команды

```bash
# Полная диагностика системы PTP
cat << 'EOF' > ptp_diagnostics.sh
#!/bin/bash
echo "=== PTP System Diagnostics ==="
echo

echo "1. Network Interface Hardware Timestamping:"
for iface in $(ip link show | grep -o 'eth[0-9]*'); do
    echo "Interface $iface:"
    ethtool -T $iface 2>/dev/null | grep -E "(hardware-transmit|hardware-receive|hardware-raw-clock)"
done
echo

echo "2. Available PTP Hardware Clocks:"
ls -la /dev/ptp* 2>/dev/null
echo

echo "3. PTP Processes:"
ps aux | grep -E "(ptp4l|phc2sys|ts2phc)" | grep -v grep
echo

echo "4. Current PTP Status:"
sudo pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null
echo

echo "5. Port States:"
sudo pmc -u -b 0 'GET PORT_DATA_SET' 2>/dev/null
echo

echo "6. Network Traffic (last 10 seconds):"
timeout 10 sudo tcpdump -i any -c 10 port 319 or port 320 2>/dev/null
echo

echo "7. System Clock vs PHC:"
for ptp in /dev/ptp*; do
    [ -e "$ptp" ] && echo "$ptp: $(phc_ctl $ptp cmp 2>/dev/null)"
done
EOF

chmod +x ptp_diagnostics.sh
sudo ./ptp_diagnostics.sh
```

### Автоматизация и systemd

#### Создание systemd сервисов

**ptp4l.service:**
```ini
[Unit]
Description=PTP Boundary/Ordinary Clock
After=network.target
Documentation=man:ptp4l

[Service]
Type=simple
ExecStart=/usr/sbin/ptp4l -f /etc/ptp4l.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**phc2sys.service:**
```ini
[Unit]
Description=Synchronize PHC with system clock
After=ptp4l.service
Requires=ptp4l.service
Documentation=man:phc2sys

[Service]
Type=simple
ExecStart=/usr/sbin/phc2sys -a -r
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Установка сервисов:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable ptp4l phc2sys
sudo systemctl start ptp4l phc2sys
```

## Заключение

LinuxPTP предоставляет мощные инструменты для высокоточной синхронизации времени в Linux-системах. Правильная настройка и мониторинг позволяют достичь субмикросекундной точности синхронизации, что критично для многих промышленных и телекоммуникационных приложений.

Ключевые моменты для успешного развертывания:
1. Проверка поддержки аппаратных временных меток
2. Правильная конфигурация сетевого оборудования
3. Постоянный мониторинг качества синхронизации
4. Автоматизация через systemd для надежности

Для получения дополнительной информации обращайтесь к man-страницам:
- `man ptp4l`
- `man phc2sys` 
- `man ts2phc`
- `man pmc`