# Скрипты интеграции TimeCard для протоколов точного времени

Эта документация содержит готовые скрипты для интеграции PCI карты времени с атомным стандартом и GNSS приемником с различными протоколами синхронизации времени.

## Инициализация и настройка

### 1. Базовая инициализация карты времени

```bash
#!/bin/bash
# timecard-init.sh - Инициализация PCI карты времени

TIMECARD_DEV="/sys/class/timecard/ocp0"
LOG_FILE="/var/log/timecard-init.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Проверка наличия карты
if [ ! -d "$TIMECARD_DEV" ]; then
    log "ОШИБКА: Карта времени не найдена в $TIMECARD_DEV"
    exit 1
fi

log "Инициализация карты времени..."

# Сброс к начальному состоянию
echo "reset" > $TIMECARD_DEV/control 2>/dev/null || true
sleep 2

# Настройка источника времени
echo "GNSS" > $TIMECARD_DEV/clock_source
log "Установлен источник времени: GNSS"

# Проверка статуса атомных часов
if [ -f "$TIMECARD_DEV/atomic_lock_status" ]; then
    atomic_status=$(cat $TIMECARD_DEV/atomic_lock_status)
    log "Статус атомных часов: $atomic_status"
fi

# Ожидание синхронизации GNSS
log "Ожидание синхронизации GNSS (максимум 5 минут)..."
timeout=300
while [ $timeout -gt 0 ]; do
    if [ -f "$TIMECARD_DEV/gnss_sync" ] && [ "$(cat $TIMECARD_DEV/gnss_sync)" = "1" ]; then
        log "✓ GNSS синхронизация установлена"
        break
    fi
    sleep 5
    timeout=$((timeout - 5))
    echo -n "."
done

if [ $timeout -le 0 ]; then
    log "⚠ ПРЕДУПРЕЖДЕНИЕ: GNSS синхронизация не установлена за отведенное время"
    log "Система будет работать только с атомными часами"
fi

# Проверка точности времени
if [ -f "$TIMECARD_DEV/time_accuracy_ns" ]; then
    accuracy=$(cat $TIMECARD_DEV/time_accuracy_ns)
    log "Точность времени: $accuracy нс"
fi

log "Инициализация карты времени завершена"
```

### 2. Скрипт настройки SMA выходов

```bash
#!/bin/bash
# configure-sma.sh - Настройка SMA выходов для различных протоколов

TIMECARD_DEV="/sys/class/timecard/ocp0"

configure_sma_output() {
    local sma_num=$1
    local function=$2
    local period_ns=$3
    local format="$4"
    
    echo "Настройка SMA$sma_num: $function"
    
    # Установка функции
    echo "$function" > $TIMECARD_DEV/sma${sma_num}_out
    
    # Установка периода (если указан)
    if [ -n "$period_ns" ]; then
        echo "$period_ns" > $TIMECARD_DEV/sma${sma_num}_period_ns
    fi
    
    # Дополнительные параметры
    case "$function" in
        "smpte")
            if [ -n "$format" ]; then
                echo "$format" > $TIMECARD_DEV/sma${sma_num}_smpte_format
            fi
            ;;
        "programmable")
            # Для программируемых выходов можно задать дополнительные параметры
            echo "square_wave" > $TIMECARD_DEV/sma${sma_num}_waveform 2>/dev/null || true
            ;;
    esac
    
    # Проверка статуса
    if [ -f "$TIMECARD_DEV/sma${sma_num}_status" ]; then
        status=$(cat $TIMECARD_DEV/sma${sma_num}_status)
        echo "  Статус: $status"
    fi
}

echo "=== Настройка SMA выходов ==="

# SMA1: PPS для общей синхронизации
configure_sma_output 1 "pps" "1000000000"

# SMA2: 10MHz опорная частота  
configure_sma_output 2 "10mhz" "100"

# SMA3: SMPTE timecode для вещания
configure_sma_output 3 "smpte" "" "25fps"

# SMA4: Программируемый выход 1MHz для тестирования
configure_sma_output 4 "programmable" "1000"

echo "Настройка SMA выходов завершена"
```

## Интеграция с NTP (chrony)

### 3. Скрипт настройки NTP с аппаратными временными метками

```bash
#!/bin/bash
# setup-ntp-hwts.sh - Настройка NTP с hardware timestamping

TIMECARD_DEV="/sys/class/timecard/ocp0"
PHC_DEV="/dev/ptp0"
CHRONY_CONF="/etc/chrony/chrony.conf"

echo "=== Настройка NTP с аппаратными временными метками ==="

# Проверка поддержки PHC
if [ ! -c "$PHC_DEV" ]; then
    echo "ОШИБКА: PHC устройство $PHC_DEV не найдено"
    exit 1
fi

# Синхронизация PHC с картой времени
echo "Синхронизация PHC с картой времени..."
TIMECARD_TIME=$(cat $TIMECARD_DEV/time_ns)
phc_ctl $PHC_DEV set $TIMECARD_TIME

# Создание конфигурации chrony
cat > $CHRONY_CONF << 'EOF'
# Основной источник - PHC карты времени
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0.0 precision 1e-9 refid ATOM

# GNSS приемник карты через SHM
refclock SHM 0 refid GPS precision 1e-8 offset 0.0 poll 4

# Локальный источник как резерв
local stratum 1 orphan distance 0.1

# Аппаратные временные метки
hwtimestamp *

# Настройки высокой точности
maxupdateskew 0.1
makestep 1.0 3
rtcsync
maxdistance 0.01
maxdrift 0.000001

# Логирование
logdir /var/log/chrony
log tracking measurements statistics
logchange 0.001

# Доступ для клиентов
allow 192.168.0.0/24
allow 10.0.0.0/8

# Безопасность
bindcmdaddress 127.0.0.1
cmdallow 127.0.0.1
EOF

# Запуск chrony
systemctl enable chronyd
systemctl restart chronyd

echo "✓ NTP с аппаратными временными метками настроен"
```

## Интеграция с PTP (IEEE 1588)

### 4. Скрипт настройки PTP мастера

```bash
#!/bin/bash
# setup-ptp-master.sh - Настройка PTP мастера с картой времени

TIMECARD_DEV="/sys/class/timecard/ocp0"
PTP_CONF="/etc/ptp4l.conf"
INTERFACE="eth0"

echo "=== Настройка PTP мастера ==="

# Проверка поддержки hardware timestamping на интерфейсе
if ! ethtool -T $INTERFACE | grep -q "hardware-transmit"; then
    echo "ПРЕДУПРЕЖДЕНИЕ: $INTERFACE может не поддерживать hardware timestamping"
fi

# Создание конфигурации ptp4l
cat > $PTP_CONF << 'EOF'
[global]
clockClass 6
clockAccuracy 0x20
offsetScaledLogVariance 0x4000
priority1 128
priority2 128
domainNumber 0

time_stamping hardware
network_transport L2
delay_mechanism P2P

tx_timestamp_timeout 10
freq_est_interval 1
assume_two_step 0
logging_level 6

step_threshold 0.000001
first_step_threshold 0.000020
max_frequency 900000000

[eth0]
masterOnly 1
announceReceiptTimeout 3
syncReceiptTimeout 0
delayReqReceiptTimeout 3
logAnnounceInterval 1
logSyncInterval 0
logMinDelayReqInterval 0
EOF

# Создание скрипта синхронизации PHC
cat > /usr/local/bin/sync-phc-timecard.sh << 'EOF'
#!/bin/bash
TIMECARD_DEV="/sys/class/timecard/ocp0"

while true; do
    # Синхронизация PHC с картой времени каждые 10 секунд
    TIMECARD_TIME=$(cat $TIMECARD_DEV/time_ns)
    PHC_TIME=$(phc_ctl /dev/ptp0 get)
    
    OFFSET=$((TIMECARD_TIME - PHC_TIME))
    
    # Коррекция если смещение больше 1 микросекунды
    if [ ${OFFSET#-} -gt 1000 ]; then
        phc_ctl /dev/ptp0 adj $OFFSET
        echo "$(date): PHC скорректирован на $OFFSET нс"
    fi
    
    sleep 10
done
EOF

chmod +x /usr/local/bin/sync-phc-timecard.sh

# Создание systemd сервиса для PTP
cat > /etc/systemd/system/ptp-master.service << 'EOF'
[Unit]
Description=PTP Master with TimeCard
After=network.target

[Service]
Type=forking
ExecStartPre=/usr/local/bin/sync-phc-quantum-pci-timecard.sh &
ExecStart=/usr/bin/ptp4l -f /etc/ptp4l.conf -i eth0 -s
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ptp-master
systemctl start ptp-master

echo "✓ PTP мастер настроен и запущен"
```

## SMPTE timecode генерация

### 5. Скрипт настройки SMPTE

```bash
#!/bin/bash
# setup-smpte.sh - Настройка SMPTE timecode генерации

TIMECARD_DEV="/sys/class/timecard/ocp0"

setup_smpte_format() {
    local sma_num=$1
    local fps=$2
    local drop_frame=$3
    local description="$4"
    
    echo "Настройка SMA$sma_num для SMPTE $fps ($description)"
    
    # Настройка SMPTE выхода
    echo "smpte" > $TIMECARD_DEV/sma${sma_num}_out
    echo "$fps" > $TIMECARD_DEV/sma${sma_num}_smpte_format
    
    if [ "$drop_frame" = "true" ]; then
        echo "1" > $TIMECARD_DEV/sma${sma_num}_drop_frame
        echo "  Drop frame: включен"
    else
        echo "0" > $TIMECARD_DEV/sma${sma_num}_drop_frame
        echo "  Drop frame: выключен"
    fi
    
    # Проверка статуса
    if [ -f "$TIMECARD_DEV/sma${sma_num}_status" ]; then
        status=$(cat $TIMECARD_DEV/sma${sma_num}_status)
        echo "  Статус: $status"
    fi
}

echo "=== Настройка SMPTE timecode генерации ==="

# Различные форматы для разных применений
setup_smpte_format 1 "25fps" false "PAL стандарт (Европа)"
setup_smpte_format 2 "29.97fps" true "NTSC drop-frame (США)"
setup_smpte_format 3 "30fps" false "Film/Professional"
setup_smpte_format 4 "24fps" false "Cinema"

echo "✓ SMPTE timecode настроен для всех форматов"
```

## Мониторинг и диагностика

### 6. Комплексный скрипт мониторинга

```bash
#!/bin/bash
# monitor-all-protocols.sh - Мониторинг всех протоколов времени

TIMECARD_DEV="/sys/class/timecard/ocp0"
LOG_FILE="/var/log/time-protocols-monitor.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

check_timecard() {
    log "=== Состояние карты времени ==="
    
    if [ -f "$TIMECARD_DEV/status" ]; then
        status=$(cat $TIMECARD_DEV/status)
        log "Статус карты: $status"
    fi
    
    if [ -f "$TIMECARD_DEV/atomic_lock_status" ]; then
        atomic_status=$(cat $TIMECARD_DEV/atomic_lock_status)
        log "Атомные часы: $atomic_status"
    fi
    
    if [ -f "$TIMECARD_DEV/gnss_status" ]; then
        gnss_status=$(cat $TIMECARD_DEV/gnss_status)
        log "GNSS: $gnss_status"
    fi
    
    if [ -f "$TIMECARD_DEV/time_accuracy_ns" ]; then
        accuracy=$(cat $TIMECARD_DEV/time_accuracy_ns)
        log "Точность: $accuracy нс"
    fi
}

check_ntp() {
    log "=== NTP статистика ==="
    
    if command -v chronyc >/dev/null; then
        chronyc tracking | while read line; do
            log "Chrony: $line"
        done
    fi
}

check_ptp() {
    log "=== PTP статистика ==="
    
    if pgrep ptp4l >/dev/null; then
        if command -v pmc >/dev/null; then
            pmc -u -b 0 'GET CURRENT_DATA_SET' | while read line; do
                log "PTP: $line"
            done
        fi
    else
        log "PTP: не запущен"
    fi
}

check_sma() {
    log "=== SMA выходы ==="
    
    for i in {1..4}; do
        if [ -f "$TIMECARD_DEV/sma${i}_status" ]; then
            status=$(cat $TIMECARD_DEV/sma${i}_status)
            function=$(cat $TIMECARD_DEV/sma${i}_out 2>/dev/null || echo "неизвестно")
            log "SMA$i: $function - $status"
        fi
    done
}

check_accuracy() {
    log "=== Проверка точности ==="
    
    if [ -f "$TIMECARD_DEV/time_ns" ]; then
        timecard_time=$(cat $TIMECARD_DEV/time_ns)
        system_time=$(date +%s%N)
        diff=$((timecard_time - system_time))
        
        log "Разность времени: $diff нс"
        
        # Предупреждения
        if [ ${diff#-} -gt 1000000 ]; then
            log "⚠ ВНИМАНИЕ: Большая разность времени (>1мс)!"
        elif [ ${diff#-} -gt 100000 ]; then
            log "⚠ Предупреждение: Разность времени >100мкс"
        fi
    fi
}

# Основной цикл мониторинга
main_monitor() {
    log "Начало мониторинга протоколов времени"
    
    check_timecard
    check_ntp
    check_ptp  
    check_sma
    check_accuracy
    
    log "Мониторинг завершен"
    log "==========================================="
}

# Режимы работы
case "$1" in
    "daemon")
        # Запуск как демон
        while true; do
            main_monitor
            sleep 60
        done
        ;;
    "once")
        main_monitor
        ;;
    *)
        echo "Использование: $0 {daemon|once}"
        echo "  daemon - непрерывный мониторинг"  
        echo "  once   - одноразовая проверка"
        exit 1
        ;;
esac
```

### 7. Скрипт диагностики проблем

```bash
#!/bin/bash
# diagnose-timecard.sh - Диагностика проблем с картой времени

TIMECARD_DEV="/sys/class/timecard/ocp0"

echo "=== Диагностика карты времени ==="

# Проверка базовых компонентов
echo "1. Проверка драйвера..."
if lsmod | grep -q ptp_ocp; then
    echo "✓ Драйвер ptp_ocp загружен"
else
    echo "✗ Драйвер ptp_ocp не загружен"
    echo "  Попробуйте: modprobe ptp_ocp"
fi

echo ""
echo "2. Проверка PCI устройства..."
if lspci | grep -i time; then
    echo "✓ TimeCard обнаружена в PCI"
else
    echo "✗ TimeCard не найдена в PCI"
    echo "  Проверьте подключение карты"
fi

echo ""
echo "3. Проверка sysfs интерфейса..."
if [ -d "$TIMECARD_DEV" ]; then
    echo "✓ Sysfs интерфейс доступен"
    ls -la $TIMECARD_DEV/
else
    echo "✗ Sysfs интерфейс недоступен"
    echo "  Проверьте загрузку драйвера"
fi

echo ""
echo "4. Проверка PHC устройства..."
for ptp_dev in /dev/ptp*; do
    if [ -c "$ptp_dev" ]; then
        echo "✓ Найдено PHC устройство: $ptp_dev"
        if command -v phc_ctl >/dev/null; then
            phc_ctl $ptp_dev get
        fi
    fi
done

echo ""
echo "5. Проверка GNSS..."
if [ -f "$TIMECARD_DEV/gnss_status" ]; then
    gnss_status=$(cat $TIMECARD_DEV/gnss_status)
    case "$gnss_status" in
        "locked")
            echo "✓ GNSS синхронизирован"
            ;;
        "acquiring")
            echo "⚠ GNSS в процессе синхронизации"
            ;;
        "error"|"disconnected")
            echo "✗ Проблемы с GNSS: $gnss_status"
            echo "  Проверьте подключение антенны"
            ;;
    esac
fi

echo ""
echo "6. Проверка сетевых интерфейсов..."
for iface in eth0 eth1; do
    if ip link show $iface >/dev/null 2>&1; then
        echo "✓ Интерфейс $iface доступен"
        if ethtool -T $iface 2>/dev/null | grep -q "hardware-transmit"; then
            echo "  ✓ Hardware timestamping поддерживается"
        else
            echo "  ✗ Hardware timestamping не поддерживается"
        fi
    fi
done

echo ""
echo "7. Рекомендации..."
if [ -f "$TIMECARD_DEV/gnss_sync" ] && [ "$(cat $TIMECARD_DEV/gnss_sync)" != "1" ]; then
    echo "• Дождитесь синхронизации GNSS (может занять до 15 минут)"
fi

if ! systemctl is-active chronyd >/dev/null; then
    echo "• Запустите chrony: systemctl start chronyd"
fi

if ! pgrep ptp4l >/dev/null; then
    echo "• Запустите PTP: systemctl start ptp-master"
fi

echo ""
echo "Диагностика завершена"
```

## Автоматический запуск

### 8. Главный скрипт автоматизации

```bash
#!/bin/bash
# autostart-time-protocols.sh - Автоматический запуск всех протоколов

SCRIPT_DIR="/usr/local/bin"

echo "=== Автоматический запуск протоколов времени ==="

# 1. Инициализация карты
echo "Шаг 1: Инициализация карты времени..."
$SCRIPT_DIR/timecard-init.sh

# 2. Настройка SMA выходов  
echo "Шаг 2: Настройка SMA выходов..."
$SCRIPT_DIR/configure-sma.sh

# 3. Настройка NTP
echo "Шаг 3: Настройка NTP..."
$SCRIPT_DIR/setup-ntp-hwts.sh

# 4. Настройка PTP
echo "Шаг 4: Настройка PTP..."
$SCRIPT_DIR/setup-ptp-master.sh

# 5. Настройка SMPTE
echo "Шаг 5: Настройка SMPTE..."
$SCRIPT_DIR/setup-smpte.sh

# 6. Запуск мониторинга
echo "Шаг 6: Запуск мониторинга..."
$SCRIPT_DIR/monitor-all-protocols.sh daemon &
echo $! > /var/run/time-monitor.pid

echo ""
echo "✓ Все протоколы времени настроены и запущены"
echo ""
echo "Для проверки статуса используйте:"
echo "  $SCRIPT_DIR/monitor-all-protocols.sh once"
echo ""
echo "Для диагностики проблем:"
echo "  $SCRIPT_DIR/diagnose-timecard.sh"
```

## Установка скриптов

Чтобы установить все скрипты, выполните:

```bash
# Копирование скриптов
sudo cp *.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/timecard-*.sh
sudo chmod +x /usr/local/bin/setup-*.sh
sudo chmod +x /usr/local/bin/configure-*.sh
sudo chmod +x /usr/local/bin/monitor-*.sh
sudo chmod +x /usr/local/bin/diagnose-*.sh
sudo chmod +x /usr/local/bin/autostart-*.sh

# Создание директорий для логов
sudo mkdir -p /var/log/chrony
sudo mkdir -p /etc/timecard

# Запуск автоматической настройки
sudo /usr/local/bin/autostart-time-protocols.sh
```