# Скрипты настройки TimeCard

## Базовые скрипты управления

### Скрипт автоматической настройки

```bash
#!/bin/bash
# configure-timecard.sh - Автоматическая настройка TimeCard

set -e

TIMECARD_BASE="/sys/class/timecard/ocp0"
LOG_FILE="/var/log/timecard-setup.log"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Проверка существования устройства
check_device() {
    if [ ! -d "$TIMECARD_BASE" ]; then
        log "ERROR: TimeCard device not found at $TIMECARD_BASE"
        exit 1
    fi
    log "TimeCard device found"
}

# Базовая конфигурация
configure_basic() {
    log "Starting basic configuration..."
    
    # Установка источника времени
    echo "GNSS" > "$TIMECARD_BASE/clock_source"
    log "Clock source set to GNSS"
    
    # Настройка SMA коннекторов
    echo "10MHz" > "$TIMECARD_BASE/sma1_in" 2>/dev/null || true
    echo "PPS" > "$TIMECARD_BASE/sma2_in" 2>/dev/null || true
    echo "10MHz" > "$TIMECARD_BASE/sma3_out" 2>/dev/null || true
    echo "PPS" > "$TIMECARD_BASE/sma4_out" 2>/dev/null || true
    log "SMA connectors configured"
    
    # Калибровка задержек
    echo "100" > "$TIMECARD_BASE/external_pps_cable_delay"
    echo "50" > "$TIMECARD_BASE/internal_pps_cable_delay"
    echo "25" > "$TIMECARD_BASE/pci_delay"
    echo "37" > "$TIMECARD_BASE/utc_tai_offset"
    log "Delays calibrated"
}

# Ожидание синхронизации GNSS
wait_gnss_sync() {
    log "Waiting for GNSS synchronization..."
    local timeout=900  # 15 минут
    local count=0
    
    while [ $count -lt $timeout ]; do
        local sync_status=$(cat "$TIMECARD_BASE/gnss_sync" 2>/dev/null || echo "unknown")
        
        if [ "$sync_status" = "locked" ]; then
            log "GNSS synchronized successfully"
            return 0
        fi
        
        if [ $((count % 60)) -eq 0 ]; then
            log "GNSS status: $sync_status (${count}s elapsed)"
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    log "WARNING: GNSS sync timeout after ${timeout}s"
    return 1
}

# Проверка конфигурации
verify_config() {
    log "Verifying configuration..."
    
    local serial=$(cat "$TIMECARD_BASE/serialnum" 2>/dev/null || echo "unknown")
    local clock_source=$(cat "$TIMECARD_BASE/clock_source" 2>/dev/null || echo "unknown")
    local gnss_sync=$(cat "$TIMECARD_BASE/gnss_sync" 2>/dev/null || echo "unknown")
    
    log "Serial number: $serial"
    log "Clock source: $clock_source"
    log "GNSS sync: $gnss_sync"
    
    # Проверка PTP устройства
    if [ -L "$TIMECARD_BASE/ptp" ]; then
        local ptp_dev=$(basename $(readlink "$TIMECARD_BASE/ptp"))
        log "PTP device: /dev/$ptp_dev"
        
        # Тест PTP устройства
        if testptp -d "/dev/$ptp_dev" -g >/dev/null 2>&1; then
            log "PTP device is functional"
        else
            log "WARNING: PTP device test failed"
        fi
    fi
}

# Основная функция
main() {
    log "Starting TimeCard configuration"
    
    check_device
    configure_basic
    wait_gnss_sync
    verify_config
    
    log "TimeCard configuration completed successfully"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

main "$@"
```

### Скрипт мониторинга

```bash
#!/bin/bash
# monitor-timecard.sh - Мониторинг состояния TimeCard

TIMECARD_BASE="/sys/class/timecard/ocp0"
REFRESH_INTERVAL=5

# Функция отображения статуса
show_status() {
    clear
    echo "===== TimeCard Monitor ====="
    echo "Timestamp: $(date)"
    echo "Device: $TIMECARD_BASE"
    echo

    if [ ! -d "$TIMECARD_BASE" ]; then
        echo "ERROR: TimeCard device not found"
        return 1
    fi

    # Основная информация
    echo "=== Device Information ==="
    echo "Serial Number: $(cat $TIMECARD_BASE/serialnum 2>/dev/null || echo 'N/A')"
    echo "Clock Source: $(cat $TIMECARD_BASE/clock_source 2>/dev/null || echo 'N/A')"
    echo "GNSS Sync: $(cat $TIMECARD_BASE/gnss_sync 2>/dev/null || echo 'N/A')"
    echo

    # SMA конфигурация
    echo "=== SMA Configuration ==="
    echo "SMA1 (in):  $(cat $TIMECARD_BASE/sma1_in 2>/dev/null || echo 'N/A')"
    echo "SMA2 (in):  $(cat $TIMECARD_BASE/sma2_in 2>/dev/null || echo 'N/A')"
    echo "SMA3 (out): $(cat $TIMECARD_BASE/sma3_out 2>/dev/null || echo 'N/A')"
    echo "SMA4 (out): $(cat $TIMECARD_BASE/sma4_out 2>/dev/null || echo 'N/A')"
    echo

    # Задержки
    echo "=== Delay Configuration ==="
    echo "External PPS delay: $(cat $TIMECARD_BASE/external_pps_cable_delay 2>/dev/null || echo 'N/A') ns"
    echo "Internal PPS delay: $(cat $TIMECARD_BASE/internal_pps_cable_delay 2>/dev/null || echo 'N/A') ns"
    echo "PCI delay: $(cat $TIMECARD_BASE/pci_delay 2>/dev/null || echo 'N/A') ns"
    echo "UTC-TAI offset: $(cat $TIMECARD_BASE/utc_tai_offset 2>/dev/null || echo 'N/A') s"
    echo

    # Связанные устройства
    echo "=== Linked Devices ==="
    if [ -L "$TIMECARD_BASE/ptp" ]; then
        PTP_DEV=$(basename $(readlink $TIMECARD_BASE/ptp))
        echo "PTP: /dev/$PTP_DEV"
        
        # PTP статистика
        if command -v testptp >/dev/null 2>&1; then
            offset=$(testptp -d /dev/$PTP_DEV -o 2>/dev/null | grep "offset" | awk '{print $6}' || echo "N/A")
            echo "PTP Offset: $offset"
        fi
    fi

    if [ -L "$TIMECARD_BASE/ttyGNSS" ]; then
        GNSS_TTY=$(basename $(readlink $TIMECARD_BASE/ttyGNSS))
        echo "GNSS: /dev/$GNSS_TTY"
    fi

    if [ -L "$TIMECARD_BASE/ttyNMEA" ]; then
        NMEA_TTY=$(basename $(readlink $TIMECARD_BASE/ttyNMEA))
        echo "NMEA: /dev/$NMEA_TTY"
    fi
    
    echo
    echo "Press Ctrl+C to exit, any key to refresh..."
}

# Основной цикл
main() {
    echo "TimeCard Monitor - Press Ctrl+C to exit"
    
    while true; do
        show_status
        
        # Ожидание ввода или timeout
        if read -t $REFRESH_INTERVAL -n 1; then
            continue
        fi
    done
}

# Обработка сигнала завершения
trap 'echo -e "\n\nMonitoring stopped."; exit 0' INT TERM

main "$@"
```

### Скрипт диагностики

```bash
#!/bin/bash
# diagnose-timecard.sh - Комплексная диагностика TimeCard

TIMECARD_BASE="/sys/class/timecard/ocp0"
REPORT_FILE="/tmp/timecard-diagnosis-$(date +%Y%m%d-%H%M%S).txt"

# Функция записи в отчет
report() {
    echo "$1" | tee -a "$REPORT_FILE"
}

# Заголовок отчета
report_header() {
    report "===== TimeCard Diagnostic Report ====="
    report "Generated: $(date)"
    report "Hostname: $(hostname)"
    report "Kernel: $(uname -r)"
    report ""
}

# Проверка драйвера
check_driver() {
    report "=== Driver Status ==="
    
    if lsmod | grep -q ptp_ocp; then
        report "✓ ptp_ocp driver is loaded"
        modinfo ptp_ocp | grep -E "(version|srcversion)" | while read line; do
            report "  $line"
        done
    else
        report "✗ ptp_ocp driver is NOT loaded"
    fi
    
    report ""
}

# Проверка PCI устройств
check_pci() {
    report "=== PCI Devices ==="
    
    local found=0
    for vendor_device in "1d9b:0400" "18d4:1008" "1ad7:a000"; do
        if lspci -nn | grep -q "$vendor_device"; then
            report "✓ Found PCI device: $vendor_device"
            lspci -nn | grep "$vendor_device" | while read line; do
                report "  $line"
            done
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        report "✗ No supported TimeCard PCI devices found"
    fi
    
    report ""
}

# Проверка TimeCard устройства
check_timecard() {
    report "=== TimeCard Device ==="
    
    if [ ! -d "$TIMECARD_BASE" ]; then
        report "✗ TimeCard device not found at $TIMECARD_BASE"
        return 1
    fi
    
    report "✓ TimeCard device found"
    
    # Основная информация
    local serial=$(cat "$TIMECARD_BASE/serialnum" 2>/dev/null || echo "unknown")
    local clock_source=$(cat "$TIMECARD_BASE/clock_source" 2>/dev/null || echo "unknown")
    local gnss_sync=$(cat "$TIMECARD_BASE/gnss_sync" 2>/dev/null || echo "unknown")
    
    report "  Serial Number: $serial"
    report "  Clock Source: $clock_source"
    report "  GNSS Sync: $gnss_sync"
    
    # Доступные источники
    if [ -f "$TIMECARD_BASE/available_clock_sources" ]; then
        report "  Available Clock Sources: $(cat $TIMECARD_BASE/available_clock_sources 2>/dev/null)"
    fi
    
    report ""
}

# Проверка SMA конфигурации
check_sma() {
    report "=== SMA Configuration ==="
    
    for sma in sma1_in sma2_in sma3_out sma4_out; do
        if [ -f "$TIMECARD_BASE/$sma" ]; then
            local value=$(cat "$TIMECARD_BASE/$sma" 2>/dev/null || echo "error")
            report "  $sma: $value"
        fi
    done
    
    # Доступные сигналы
    if [ -f "$TIMECARD_BASE/available_sma_inputs" ]; then
        report "  Available inputs: $(cat $TIMECARD_BASE/available_sma_inputs 2>/dev/null)"
    fi
    
    if [ -f "$TIMECARD_BASE/available_sma_outputs" ]; then
        report "  Available outputs: $(cat $TIMECARD_BASE/available_sma_outputs 2>/dev/null)"
    fi
    
    report ""
}

# Проверка задержек
check_delays() {
    report "=== Delay Configuration ==="
    
    for delay in external_pps_cable_delay internal_pps_cable_delay pci_delay utc_tai_offset; do
        if [ -f "$TIMECARD_BASE/$delay" ]; then
            local value=$(cat "$TIMECARD_BASE/$delay" 2>/dev/null || echo "error")
            local unit="ns"
            [ "$delay" = "utc_tai_offset" ] && unit="s"
            report "  $delay: $value $unit"
        fi
    done
    
    report ""
}

# Проверка связанных устройств
check_linked_devices() {
    report "=== Linked Devices ==="
    
    # PTP устройство
    if [ -L "$TIMECARD_BASE/ptp" ]; then
        local ptp_dev=$(basename $(readlink "$TIMECARD_BASE/ptp"))
        report "  PTP device: /dev/$ptp_dev"
        
        if [ -c "/dev/$ptp_dev" ]; then
            report "    ✓ PTP device file exists"
            
            if command -v testptp >/dev/null 2>&1; then
                if testptp -d "/dev/$ptp_dev" -c >/dev/null 2>&1; then
                    report "    ✓ PTP device is functional"
                else
                    report "    ✗ PTP device test failed"
                fi
            fi
        else
            report "    ✗ PTP device file missing"
        fi
    else
        report "  ✗ PTP device link missing"
    fi
    
    # Последовательные порты
    for port in ttyGNSS ttyMAC ttyNMEA; do
        if [ -L "$TIMECARD_BASE/$port" ]; then
            local tty_dev=$(basename $(readlink "$TIMECARD_BASE/$port"))
            report "  $port: /dev/$tty_dev"
            
            if [ -c "/dev/$tty_dev" ]; then
                report "    ✓ TTY device exists"
            else
                report "    ✗ TTY device missing"
            fi
        fi
    done
    
    report ""
}

# Проверка логов
check_logs() {
    report "=== Recent Logs ==="
    
    # Последние сообщения драйвера
    dmesg | grep -i ptp_ocp | tail -10 | while read line; do
        report "  $line"
    done
    
    report ""
}

# Рекомендации
provide_recommendations() {
    report "=== Recommendations ==="
    
    # Проверка GNSS синхронизации
    local gnss_sync=$(cat "$TIMECARD_BASE/gnss_sync" 2>/dev/null || echo "unknown")
    if [ "$gnss_sync" != "locked" ]; then
        report "• GNSS is not locked - check antenna connection and sky view"
        report "  Wait up to 15 minutes for initial sync"
    fi
    
    # Проверка источника часов
    local clock_source=$(cat "$TIMECARD_BASE/clock_source" 2>/dev/null || echo "unknown")
    if [ "$clock_source" != "GNSS" ]; then
        report "• Consider setting clock source to GNSS for best accuracy"
        report "  echo 'GNSS' > $TIMECARD_BASE/clock_source"
    fi
    
    # Проверка задержек
    local ext_delay=$(cat "$TIMECARD_BASE/external_pps_cable_delay" 2>/dev/null || echo "0")
    if [ "$ext_delay" = "0" ]; then
        report "• External PPS cable delay is 0 - consider calibrating for cable length"
        report "  Use ~5ns per meter for coaxial cables"
    fi
    
    report ""
}

# Основная функция
main() {
    echo "Running TimeCard diagnostics..."
    echo "Report will be saved to: $REPORT_FILE"
    
    report_header
    check_driver
    check_pci
    check_timecard
    check_sma
    check_delays
    check_linked_devices
    check_logs
    provide_recommendations
    
    report "===== End of Report ====="
    
    echo "Diagnosis complete. Report saved to: $REPORT_FILE"
}

main "$@"
```

### Скрипт сброса конфигурации

```bash
#!/bin/bash
# reset-timecard.sh - Сброс TimeCard к заводским настройкам

TIMECARD_BASE="/sys/class/timecard/ocp0"

reset_configuration() {
    echo "Resetting TimeCard configuration..."
    
    if [ ! -d "$TIMECARD_BASE" ]; then
        echo "ERROR: TimeCard device not found"
        exit 1
    fi
    
    # Сброс источника часов к GNSS
    echo "GNSS" > "$TIMECARD_BASE/clock_source" 2>/dev/null || true
    echo "Clock source reset to GNSS"
    
    # Сброс SMA коннекторов к базовым настройкам
    echo "10MHz" > "$TIMECARD_BASE/sma1_in" 2>/dev/null || true
    echo "PPS" > "$TIMECARD_BASE/sma2_in" 2>/dev/null || true
    echo "10MHz" > "$TIMECARD_BASE/sma3_out" 2>/dev/null || true
    echo "PPS" > "$TIMECARD_BASE/sma4_out" 2>/dev/null || true
    echo "SMA connectors reset to default"
    
    # Сброс задержек к нулю
    echo "0" > "$TIMECARD_BASE/external_pps_cable_delay" 2>/dev/null || true
    echo "0" > "$TIMECARD_BASE/internal_pps_cable_delay" 2>/dev/null || true
    echo "0" > "$TIMECARD_BASE/pci_delay" 2>/dev/null || true
    echo "Delays reset to zero"
    
    # Сброс UTC-TAI offset
    echo "37" > "$TIMECARD_BASE/utc_tai_offset" 2>/dev/null || true
    echo "UTC-TAI offset set to current value (37s)"
    
    # Сброс IRIG-B режима
    echo "B003" > "$TIMECARD_BASE/irig_b_mode" 2>/dev/null || true
    echo "IRIG-B mode reset to B003"
    
    echo "TimeCard configuration reset complete"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Подтверждение сброса
read -p "Are you sure you want to reset TimeCard configuration? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Reset cancelled"
    exit 0
fi

reset_configuration
```

## Установка скриптов

```bash
# Создание директории для скриптов
sudo mkdir -p /usr/local/bin/timecard

# Копирование скриптов
sudo cp configure-timecard.sh /usr/local/bin/timecard/
sudo cp monitor-timecard.sh /usr/local/bin/timecard/
sudo cp diagnose-timecard.sh /usr/local/bin/timecard/
sudo cp reset-timecard.sh /usr/local/bin/timecard/

# Установка прав выполнения
sudo chmod +x /usr/local/bin/timecard/*.sh

# Создание символических ссылок для удобства
sudo ln -sf /usr/local/bin/timecard/configure-timecard.sh /usr/local/bin/configure-timecard
sudo ln -sf /usr/local/bin/timecard/monitor-timecard.sh /usr/local/bin/monitor-timecard
sudo ln -sf /usr/local/bin/timecard/diagnose-timecard.sh /usr/local/bin/diagnose-timecard
sudo ln -sf /usr/local/bin/timecard/reset-timecard.sh /usr/local/bin/reset-timecard
```

## Использование

```bash
# Автоматическая настройка
sudo configure-timecard

# Мониторинг в реальном времени
sudo monitor-timecard

# Диагностика проблем
sudo diagnose-timecard

# Сброс конфигурации
sudo reset-timecard
```