# Скрипты и автоматизация для Chrony

## Оглавление
1. [Скрипты установки и настройки](#скрипты-установки-и-настройки)
2. [Мониторинг и алертинг](#мониторинг-и-алертинг)
3. [Автоматическая диагностика](#автоматическая-диагностика)
4. [Backup и восстановление](#backup-и-восстановление)
5. [Интеграция с системами мониторинга](#интеграция-с-системами-мониторинга)
6. [Скрипты для разных сценариев](#скрипты-для-разных-сценариев)

## Скрипты установки и настройки

### Скрипт автоматической установки Chrony

```bash
#!/bin/bash
# install_chrony.sh - Автоматическая установка и базовая настройка Chrony

set -e

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Установка Chrony
install_chrony() {
    local distro=$(detect_distro)
    
    echo "Установка Chrony для дистрибутива: $distro"
    
    case $distro in
        ubuntu|debian)
            apt update
            apt install -y chrony
            ;;
        rhel|centos|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y chrony
            else
                yum install -y chrony
            fi
            ;;
        arch)
            pacman -S --noconfirm chrony
            ;;
        *)
            echo "Неподдерживаемый дистрибутив: $distro"
            exit 1
            ;;
    esac
}

# Создание резервной копии конфигурации
backup_config() {
    local config_file=""
    
    if [ -f /etc/chrony/chrony.conf ]; then
        config_file="/etc/chrony/chrony.conf"
    elif [ -f /etc/chrony.conf ]; then
        config_file="/etc/chrony.conf"
    else
        echo "Конфигурационный файл не найден"
        return 1
    fi
    
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Резервная копия создана: ${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
}

# Базовая конфигурация
configure_chrony() {
    local config_file=""
    
    if [ -f /etc/chrony/chrony.conf ]; then
        config_file="/etc/chrony/chrony.conf"
    elif [ -f /etc/chrony.conf ]; then
        config_file="/etc/chrony.conf"
    fi
    
    cat > "$config_file" << 'EOF'
# Chrony configuration
# NTP servers
pool 2.pool.ntp.org iburst maxsources 4
server time.cloudflare.com iburst
server time.google.com iburst

# Allow step if time is off by more than 1 second
makestep 1.0 3

# Drift file
driftfile /var/lib/chrony/chrony.drift

# Logging
logdir /var/log/chrony
log measurements statistics tracking

# Minimum sources
minsources 2

# Maximum distance
maxdistance 16.0

# RTC sync
rtcsync

# Command access
cmdallow 127.0.0.1
cmdallow ::1
EOF

    echo "Базовая конфигурация создана в $config_file"
}

# Запуск и включение службы
enable_service() {
    # Остановка systemd-timesyncd если он запущен
    if systemctl is-active --quiet systemd-timesyncd; then
        echo "Остановка systemd-timesyncd..."
        systemctl stop systemd-timesyncd
        systemctl disable systemd-timesyncd
    fi
    
    # Запуск chronyd
    systemctl enable chronyd
    systemctl start chronyd
    
    echo "Служба chronyd запущена и включена"
}

# Проверка работы
verify_installation() {
    echo "Проверка установки..."
    
    if systemctl is-active --quiet chronyd; then
        echo "✓ Служба chronyd запущена"
    else
        echo "✗ Служба chronyd не запущена"
        return 1
    fi
    
    if chronyc tracking > /dev/null 2>&1; then
        echo "✓ Chrony работает корректно"
        chronyc tracking
    else
        echo "✗ Проблемы с работой Chrony"
        return 1
    fi
}

# Основная функция
main() {
    echo "=== Установка и настройка Chrony ==="
    
    if [ "$EUID" -ne 0 ]; then
        echo "Скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    install_chrony
    backup_config
    configure_chrony
    enable_service
    
    sleep 5  # Ждем запуска службы
    
    verify_installation
    
    echo "=== Установка завершена ==="
}

main "$@"
```

### Скрипт настройки для PTP интеграции

```bash
#!/bin/bash
# setup_chrony_ptp.sh - Настройка Chrony для работы с PTP устройствами

set -e

# Проверка наличия PTP устройств
check_ptp_devices() {
    echo "Проверка PTP устройств..."
    
    if [ ! -d /dev ]; then
        echo "Каталог /dev не найден"
        return 1
    fi
    
    local ptp_devices=($(ls /dev/ptp* 2>/dev/null || true))
    
    if [ ${#ptp_devices[@]} -eq 0 ]; then
        echo "PTP устройства не найдены"
        echo "Убедитесь что:"
        echo "1. Драйвер сетевой карты поддерживает PTP"
        echo "2. Модуль ptp загружен"
        echo "3. LinuxPTP настроен и работает"
        return 1
    fi
    
    echo "Найдены PTP устройства:"
    for device in "${ptp_devices[@]}"; do
        echo "  - $device"
        
        # Проверка доступности устройства
        if [ -c "$device" ]; then
            echo "    ✓ Устройство доступно"
        else
            echo "    ✗ Устройство недоступно"
        fi
    done
    
    return 0
}

# Проверка сетевых интерфейсов
check_network_interfaces() {
    echo "Проверка поддержки timestamping..."
    
    for interface in $(ip link show | grep -o '^[0-9]*: [^:]*' | cut -d' ' -f2); do
        if [ "$interface" != "lo" ]; then
            echo "Проверка интерфейса $interface:"
            if command -v ethtool &> /dev/null; then
                ethtool -T "$interface" 2>/dev/null | grep -E "hardware-transmit|hardware-receive" || true
            fi
        fi
    done
}

# Настройка Chrony для PTP
configure_chrony_ptp() {
    local config_file=""
    local primary_ptp="/dev/ptp0"
    
    if [ -f /etc/chrony/chrony.conf ]; then
        config_file="/etc/chrony/chrony.conf"
    elif [ -f /etc/chrony.conf ]; then
        config_file="/etc/chrony.conf"
    fi
    
    # Создание резервной копии
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    cat > "$config_file" << EOF
# Chrony PTP configuration
# Primary PTP source
refclock PHC $primary_ptp poll 3 dpoll -2 prefer

# Backup NTP servers
server pool.ntp.org iburst

# Hardware timestamping (adjust interface name)
hwtimestamp eth0

# Allow larger time corrections
makestep 1.0 1

# Drift file
driftfile /var/lib/chrony/chrony.drift

# RTC synchronization
rtcsync
rtcautotrim 30

# Logging
logdir /var/log/chrony
log measurements statistics tracking rtc refclocks

# Command access
cmdallow 127.0.0.1
cmdallow ::1

# Performance tuning for PTP
maxupdateskew 100.0
corrtimeratio 1.0

# Local fallback
local stratum 10
EOF

    echo "Конфигурация для PTP создана в $config_file"
}

# Тестирование PTP интеграции
test_ptp_integration() {
    echo "Тестирование PTP интеграции..."
    
    systemctl restart chronyd
    sleep 10
    
    # Проверка источников
    echo "Источники времени:"
    chronyc sources -v
    
    echo ""
    echo "Статус синхронизации:"
    chronyc tracking
    
    echo ""
    echo "Статистика источников:"
    chronyc sourcestats
}

# Основная функция
main() {
    echo "=== Настройка Chrony для PTP ==="
    
    if [ "$EUID" -ne 0 ]; then
        echo "Скрипт должен быть запущен с правами root"
        exit 1
    fi
    
    check_ptp_devices || {
        echo "Настройка остановлена из-за отсутствия PTP устройств"
        exit 1
    }
    
    check_network_interfaces
    configure_chrony_ptp
    test_ptp_integration
    
    echo "=== Настройка PTP завершена ==="
    echo "Мониторьте синхронизацию командой: chronyc tracking"
}

main "$@"
```

## Мониторинг и алертинг

### Скрипт мониторинга синхронизации

```bash
#!/bin/bash
# chrony_monitor.sh - Мониторинг состояния синхронизации Chrony

# Конфигурация
MAX_OFFSET=0.001  # Максимальный offset в секундах
MAX_JITTER=0.0001 # Максимальный jitter в секундах
MIN_SOURCES=2     # Минимальное количество источников
ALERT_EMAIL="admin@example.com"
LOG_FILE="/var/log/chrony_monitor.log"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Проверка службы
check_service() {
    if ! systemctl is-active --quiet chronyd; then
        log_message "КРИТИЧЕСКАЯ ОШИБКА: Служба chronyd не запущена"
        return 1
    fi
    return 0
}

# Получение статистики
get_tracking_info() {
    chronyc tracking 2>/dev/null || {
        log_message "ОШИБКА: Не удается получить информацию о синхронизации"
        return 1
    }
}

# Анализ смещения времени
check_time_offset() {
    local tracking_output="$1"
    local offset=$(echo "$tracking_output" | grep "System time" | awk '{print $4}' | sed 's/seconds//')
    
    if [ -z "$offset" ]; then
        log_message "ПРЕДУПРЕЖДЕНИЕ: Не удается определить смещение времени"
        return 1
    fi
    
    # Преобразование в абсолютное значение
    local abs_offset=$(echo "$offset" | awk '{print ($1 < 0) ? -$1 : $1}')
    
    if (( $(echo "$abs_offset > $MAX_OFFSET" | bc -l) )); then
        log_message "ПРЕДУПРЕЖДЕНИЕ: Большое смещение времени: ${offset}s (предел: ${MAX_OFFSET}s)"
        return 1
    else
        log_message "ОК: Смещение времени в норме: ${offset}s"
        return 0
    fi
}

# Проверка источников
check_sources() {
    local sources_output=$(chronyc sources 2>/dev/null)
    local active_sources=$(echo "$sources_output" | grep -c "^[*+]" || echo "0")
    
    if [ "$active_sources" -lt "$MIN_SOURCES" ]; then
        log_message "ПРЕДУПРЕЖДЕНИЕ: Недостаточно активных источников: $active_sources (минимум: $MIN_SOURCES)"
        return 1
    else
        log_message "ОК: Активных источников: $active_sources"
        return 0
    fi
}

# Отправка уведомления
send_alert() {
    local message="$1"
    local subject="Chrony Alert - $(hostname)"
    
    # Отправка email если настроена
    if command -v mail &> /dev/null && [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    fi
    
    # Запись в syslog
    logger -p daemon.warning "chrony_monitor: $message"
}

# Генерация отчета
generate_report() {
    local report="/tmp/chrony_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== Отчет о состоянии Chrony ==="
        echo "Время: $(date)"
        echo "Хост: $(hostname)"
        echo ""
        
        echo "Статус службы:"
        systemctl status chronyd --no-pager -l
        echo ""
        
        echo "Информация о синхронизации:"
        chronyc tracking
        echo ""
        
        echo "Источники времени:"
        chronyc sources -v
        echo ""
        
        echo "Статистика источников:"
        chronyc sourcestats
        echo ""
        
        echo "Активность:"
        chronyc activity
        
    } > "$report"
    
    echo "$report"
}

# Основная функция мониторинга
monitor() {
    local error_count=0
    
    log_message "Начало проверки синхронизации Chrony"
    
    # Проверка службы
    if ! check_service; then
        ((error_count++))
        send_alert "Служба chronyd не запущена на $(hostname)"
    fi
    
    # Получение информации о синхронизации
    local tracking_info=$(get_tracking_info)
    if [ $? -ne 0 ]; then
        ((error_count++))
        send_alert "Не удается получить информацию о синхронизации на $(hostname)"
        return 1
    fi
    
    # Проверка смещения времени
    if ! check_time_offset "$tracking_info"; then
        ((error_count++))
    fi
    
    # Проверка источников
    if ! check_sources; then
        ((error_count++))
    fi
    
    # Итоговый результат
    if [ "$error_count" -eq 0 ]; then
        log_message "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ: Синхронизация работает нормально"
    else
        log_message "ОБНАРУЖЕНЫ ПРОБЛЕМЫ: $error_count ошибок"
        send_alert "Обнаружены проблемы с синхронизацией времени на $(hostname). Подробности в логе: $LOG_FILE"
    fi
    
    return "$error_count"
}

# Daemon режим
daemon_mode() {
    local interval="${1:-300}"  # По умолчанию 5 минут
    
    log_message "Запуск в daemon режиме с интервалом $interval секунд"
    
    while true; do
        monitor
        sleep "$interval"
    done
}

# Показ помощи
show_help() {
    cat << EOF
Использование: $0 [опции]

Опции:
  -h, --help          Показать эту справку
  -m, --monitor       Выполнить одну проверку
  -d, --daemon [INT]  Запустить в daemon режиме (интервал в секундах, по умолчанию 300)
  -r, --report        Сгенерировать полный отчет
  
Примеры:
  $0 -m                 # Одна проверка
  $0 -d 600            # Daemon режим с интервалом 10 минут
  $0 -r                # Генерация отчета

EOF
}

# Основная логика
case "${1:-}" in
    -h|--help)
        show_help
        ;;
    -m|--monitor)
        monitor
        ;;
    -d|--daemon)
        daemon_mode "${2:-300}"
        ;;
    -r|--report)
        report_file=$(generate_report)
        echo "Отчет создан: $report_file"
        cat "$report_file"
        ;;
    *)
        monitor
        ;;
esac
```

### Скрипт для Prometheus мониторинга

```bash
#!/bin/bash
# chrony_exporter.sh - Экспорт метрик Chrony для Prometheus

METRICS_FILE="/var/lib/node_exporter/textfile_collector/chrony.prom"
METRICS_DIR=$(dirname "$METRICS_FILE")

# Создание директории если не существует
mkdir -p "$METRICS_DIR"

# Временный файл для атомарного обновления
TEMP_FILE=$(mktemp)

# Функция очистки
cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# Получение метрик
collect_metrics() {
    # Проверка статуса службы
    if systemctl is-active --quiet chronyd; then
        echo "chrony_service_up 1" >> "$TEMP_FILE"
    else
        echo "chrony_service_up 0" >> "$TEMP_FILE"
        mv "$TEMP_FILE" "$METRICS_FILE"
        return
    fi
    
    # Получение информации о синхронизации
    local tracking_output=$(chronyc tracking 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Парсинг данных tracking
        local stratum=$(echo "$tracking_output" | grep "Stratum" | awk '{print $3}')
        local ref_time=$(echo "$tracking_output" | grep "Ref time" | awk '{print $4}')
        local system_time=$(echo "$tracking_output" | grep "System time" | awk '{print $4}')
        local last_offset=$(echo "$tracking_output" | grep "Last offset" | awk '{print $4}')
        local rms_offset=$(echo "$tracking_output" | grep "RMS offset" | awk '{print $4}')
        local frequency=$(echo "$tracking_output" | grep "Frequency" | awk '{print $3}')
        local residual_freq=$(echo "$tracking_output" | grep "Residual freq" | awk '{print $4}')
        local skew=$(echo "$tracking_output" | grep "Skew" | awk '{print $3}')
        local root_delay=$(echo "$tracking_output" | grep "Root delay" | awk '{print $4}')
        local root_dispersion=$(echo "$tracking_output" | grep "Root dispersion" | awk '{print $4}')
        local update_interval=$(echo "$tracking_output" | grep "Update interval" | awk '{print $4}')
        
        # Запись метрик
        [ -n "$stratum" ] && echo "chrony_stratum $stratum" >> "$TEMP_FILE"
        [ -n "$system_time" ] && echo "chrony_system_time_offset_seconds $system_time" >> "$TEMP_FILE"
        [ -n "$last_offset" ] && echo "chrony_last_offset_seconds $last_offset" >> "$TEMP_FILE"
        [ -n "$rms_offset" ] && echo "chrony_rms_offset_seconds $rms_offset" >> "$TEMP_FILE"
        [ -n "$frequency" ] && echo "chrony_frequency_ppm $frequency" >> "$TEMP_FILE"
        [ -n "$residual_freq" ] && echo "chrony_residual_frequency_ppm $residual_freq" >> "$TEMP_FILE"
        [ -n "$skew" ] && echo "chrony_skew_ppm $skew" >> "$TEMP_FILE"
        [ -n "$root_delay" ] && echo "chrony_root_delay_seconds $root_delay" >> "$TEMP_FILE"
        [ -n "$root_dispersion" ] && echo "chrony_root_dispersion_seconds $root_dispersion" >> "$TEMP_FILE"
        [ -n "$update_interval" ] && echo "chrony_update_interval_seconds $update_interval" >> "$TEMP_FILE"
    fi
    
    # Получение информации об источниках
    local sources_output=$(chronyc sources 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local total_sources=$(echo "$sources_output" | grep -c "^[*.+x?-]" || echo "0")
        local synced_sources=$(echo "$sources_output" | grep -c "^[*+]" || echo "0")
        local candidate_sources=$(echo "$sources_output" | grep -c "^+" || echo "0")
        local falseticker_sources=$(echo "$sources_output" | grep -c "^x" || echo "0")
        
        echo "chrony_sources_total $total_sources" >> "$TEMP_FILE"
        echo "chrony_sources_synced $synced_sources" >> "$TEMP_FILE"
        echo "chrony_sources_candidate $candidate_sources" >> "$TEMP_FILE"
        echo "chrony_sources_falseticker $falseticker_sources" >> "$TEMP_FILE"
    fi
    
    # Метрика времени последнего обновления
    echo "chrony_last_update_timestamp $(date +%s)" >> "$TEMP_FILE"
    
    # Атомарное обновление файла метрик
    mv "$TEMP_FILE" "$METRICS_FILE"
}

# Основная функция
main() {
    if [ "$1" = "--daemon" ]; then
        # Daemon режим для cron
        while true; do
            collect_metrics
            sleep 30
        done
    else
        # Одноразовый сбор метрик
        collect_metrics
    fi
}

main "$@"
```

## Автоматическая диагностика

### Диагностический скрипт

```bash
#!/bin/bash
# chrony_diagnostics.sh - Комплексная диагностика Chrony

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции вывода
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка статуса службы
check_service_status() {
    info "Проверка статуса службы chronyd..."
    
    if systemctl is-enabled --quiet chronyd; then
        success "Служба chronyd включена для автозапуска"
    else
        warning "Служба chronyd не включена для автозапуска"
    fi
    
    if systemctl is-active --quiet chronyd; then
        success "Служба chronyd запущена"
    else
        error "Служба chronyd не запущена"
        return 1
    fi
    
    # Проверка конфликтующих служб
    if systemctl is-active --quiet systemd-timesyncd; then
        warning "Обнаружена активная служба systemd-timesyncd (может конфликтовать)"
    fi
    
    if systemctl is-active --quiet ntpd; then
        warning "Обнаружена активная служба ntpd (может конфликтовать)"
    fi
}

# Проверка конфигурации
check_configuration() {
    info "Проверка конфигурации..."
    
    local config_file=""
    if [ -f /etc/chrony/chrony.conf ]; then
        config_file="/etc/chrony/chrony.conf"
    elif [ -f /etc/chrony.conf ]; then
        config_file="/etc/chrony.conf"
    else
        error "Конфигурационный файл не найден"
        return 1
    fi
    
    success "Конфигурационный файл: $config_file"
    
    # Проверка синтаксиса
    if chronyd -Q 'quit' >/dev/null 2>&1; then
        success "Синтаксис конфигурации корректен"
    else
        error "Ошибки в синтаксисе конфигурации"
    fi
    
    # Анализ конфигурации
    echo ""
    info "Анализ конфигурации:"
    
    local servers=$(grep -c "^server\|^pool" "$config_file" 2>/dev/null || echo "0")
    local refclocks=$(grep -c "^refclock" "$config_file" 2>/dev/null || echo "0")
    
    echo "  - NTP серверы/пулы: $servers"
    echo "  - Референсные часы: $refclocks"
    
    if grep -q "^makestep" "$config_file"; then
        success "  - Настроена коррекция больших смещений"
    else
        warning "  - Не настроена коррекция больших смещений"
    fi
    
    if grep -q "^driftfile" "$config_file"; then
        success "  - Настроен drift файл"
    else
        warning "  - Не настроен drift файл"
    fi
}

# Проверка сетевого подключения
check_network_connectivity() {
    info "Проверка сетевого подключения к NTP серверам..."
    
    local config_file=""
    if [ -f /etc/chrony/chrony.conf ]; then
        config_file="/etc/chrony/chrony.conf"
    elif [ -f /etc/chrony.conf ]; then
        config_file="/etc/chrony.conf"
    fi
    
    # Извлечение серверов из конфигурации
    local servers=$(grep -E "^(server|pool)" "$config_file" 2>/dev/null | awk '{print $2}' | head -5)
    
    for server in $servers; do
        if ping -c 1 -W 3 "$server" >/dev/null 2>&1; then
            success "  - $server доступен"
        else
            warning "  - $server недоступен"
        fi
        
        # Проверка NTP порта
        if nc -u -w 3 -z "$server" 123 >/dev/null 2>&1; then
            success "  - NTP порт 123 на $server доступен"
        else
            warning "  - NTP порт 123 на $server недоступен"
        fi
    done
}

# Проверка PTP устройств
check_ptp_devices() {
    info "Проверка PTP устройств..."
    
    local ptp_devices=($(ls /dev/ptp* 2>/dev/null || true))
    
    if [ ${#ptp_devices[@]} -eq 0 ]; then
        info "  - PTP устройства не найдены"
        return 0
    fi
    
    success "  - Найдено PTP устройств: ${#ptp_devices[@]}"
    
    for device in "${ptp_devices[@]}"; do
        echo "    $device:"
        
        if [ -c "$device" ]; then
            success "      ✓ Устройство доступно"
            
            # Проверка возможности чтения времени
            if command -v phc_ctl &> /dev/null; then
                if phc_ctl "$device" get >/dev/null 2>&1; then
                    success "      ✓ Время можно прочитать"
                else
                    warning "      - Не удается прочитать время"
                fi
            fi
        else
            error "      ✗ Устройство недоступно"
        fi
    done
}

# Проверка сетевых интерфейсов
check_network_interfaces() {
    info "Проверка поддержки hardware timestamping..."
    
    if ! command -v ethtool &> /dev/null; then
        warning "  - ethtool не установлен, проверка пропущена"
        return 0
    fi
    
    for interface in $(ip link show | grep -o '^[0-9]*: [^:]*:' | cut -d' ' -f2 | tr -d ':'); do
        if [ "$interface" != "lo" ]; then
            echo "  Интерфейс $interface:"
            
            local hw_tx=$(ethtool -T "$interface" 2>/dev/null | grep -c "hardware-transmit" || echo "0")
            local hw_rx=$(ethtool -T "$interface" 2>/dev/null | grep -c "hardware-receive" || echo "0")
            
            if [ "$hw_tx" -gt 0 ] && [ "$hw_rx" -gt 0 ]; then
                success "    ✓ Поддерживает hardware timestamping"
            else
                info "    - Hardware timestamping не поддерживается"
            fi
        fi
    done
}

# Проверка текущей синхронизации
check_synchronization() {
    info "Проверка текущей синхронизации..."
    
    if ! chronyc tracking >/dev/null 2>&1; then
        error "Не удается получить информацию о синхронизации"
        return 1
    fi
    
    echo ""
    chronyc tracking
    echo ""
    
    # Анализ источников
    info "Анализ источников времени:"
    chronyc sources -v
    echo ""
    
    # Проверка качества синхронизации
    local system_time=$(chronyc tracking | grep "System time" | awk '{print $4}' | sed 's/seconds//')
    local stratum=$(chronyc tracking | grep "Stratum" | awk '{print $3}')
    
    if [ -n "$system_time" ]; then
        local abs_offset=$(echo "$system_time" | awk '{print ($1 < 0) ? -$1 : $1}')
        if (( $(echo "$abs_offset < 0.001" | bc -l 2>/dev/null || echo "0") )); then
            success "Смещение времени в норме: ${system_time}s"
        else
            warning "Большое смещение времени: ${system_time}s"
        fi
    fi
    
    if [ -n "$stratum" ] && [ "$stratum" -le 15 ]; then
        success "Stratum в норме: $stratum"
    else
        warning "Высокий stratum: $stratum"
    fi
}

# Проверка логов
check_logs() {
    info "Проверка логов (последние 10 записей)..."
    
    echo ""
    journalctl -u chronyd --no-pager -n 10 || {
        warning "Не удается получить логи systemd"
    }
    
    # Проверка пользовательских логов chrony
    if [ -d /var/log/chrony ]; then
        echo ""
        info "Файлы логов chrony:"
        ls -la /var/log/chrony/
    fi
}

# Генерация рекомендаций
generate_recommendations() {
    info "Рекомендации по оптимизации:"
    echo ""
    
    local config_file=""
    if [ -f /etc/chrony/chrony.conf ]; then
        config_file="/etc/chrony/chrony.conf"
    elif [ -f /etc/chrony.conf ]; then
        config_file="/etc/chrony.conf"
    fi
    
    # Проверка количества источников
    local sources_count=$(chronyc sources 2>/dev/null | grep -c "^[*.+x?-]" || echo "0")
    if [ "$sources_count" -lt 3 ]; then
        echo "  - Рекомендуется использовать минимум 3-4 источника времени"
    fi
    
    # Проверка makestep
    if ! grep -q "^makestep" "$config_file" 2>/dev/null; then
        echo "  - Добавьте 'makestep 1.0 3' для коррекции больших смещений"
    fi
    
    # Проверка rtcsync
    if ! grep -q "^rtcsync" "$config_file" 2>/dev/null; then
        echo "  - Добавьте 'rtcsync' для синхронизации аппаратных часов"
    fi
    
    # Проверка логирования
    if ! grep -q "^log" "$config_file" 2>/dev/null; then
        echo "  - Включите логирование: 'log measurements statistics tracking'"
    fi
    
    # Проверка PTP интеграции
    local ptp_devices=($(ls /dev/ptp* 2>/dev/null || true))
    if [ ${#ptp_devices[@]} -gt 0 ] && ! grep -q "^refclock PHC" "$config_file" 2>/dev/null; then
        echo "  - Рассмотрите возможность использования PTP устройств как источника времени"
    fi
}

# Основная функция
main() {
    echo "============================================="
    echo "    Диагностика Chrony $(date)"
    echo "    Хост: $(hostname)"
    echo "============================================="
    echo ""
    
    check_service_status
    echo ""
    
    check_configuration
    echo ""
    
    check_network_connectivity
    echo ""
    
    check_ptp_devices
    echo ""
    
    check_network_interfaces
    echo ""
    
    check_synchronization
    echo ""
    
    check_logs
    echo ""
    
    generate_recommendations
    echo ""
    
    echo "============================================="
    echo "    Диагностика завершена"
    echo "============================================="
}

# Проверка зависимостей
if ! command -v chronyc &> /dev/null; then
    error "chronyc не найден. Убедитесь, что chrony установлен."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    warning "bc не найден. Некоторые проверки могут быть недоступны."
fi

main "$@"
```

Эти скрипты обеспечивают полную автоматизацию установки, настройки, мониторинга и диагностики Chrony, включая специфические настройки для работы с PTP устройствами.