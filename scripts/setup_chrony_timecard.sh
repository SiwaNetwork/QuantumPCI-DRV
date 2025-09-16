#!/bin/bash

# Скрипт автоматической настройки Chrony для TimeCard
# Создает оптимальную конфигурацию и проверяет интеграцию

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Этот скрипт должен запускаться с правами root"
        log_info "Использование: sudo $0"
        exit 1
    fi
}

# Проверка наличия chrony
check_chrony() {
    log_info "Проверка установки Chrony..."
    
    if ! command -v chronyd >/dev/null 2>&1; then
        log_error "Chrony не установлен"
        log_info "Установите Chrony:"
        log_info "  Ubuntu/Debian: sudo apt install chrony"
        log_info "  RHEL/CentOS: sudo yum install chrony"
        log_info "  Fedora: sudo dnf install chrony"
        exit 1
    fi
    
    local version=$(chronyd --version | head -1)
    log_success "Chrony установлен: $version"
}

# Проверка PTP устройств
check_ptp_devices() {
    log_info "Проверка PTP устройств..."
    
    local ptp_devices=$(ls /dev/ptp* 2>/dev/null || true)
    
    if [ -z "$ptp_devices" ]; then
        log_error "PTP устройства не найдены"
        log_info "Убедитесь, что драйвер ptp_ocp загружен: modprobe ptp_ocp"
        exit 1
    fi
    
    log_success "Найдены PTP устройства:"
    for device in $ptp_devices; do
        local device_name=$(basename "$device")
        local sys_path="/sys/class/ptp/$device_name"
        
        if [ -f "$sys_path/clock_name" ]; then
            local clock_name=$(cat "$sys_path/clock_name")
            echo "  - $device: $clock_name"
        else
            echo "  - $device: (неизвестный тип)"
        fi
    done
}

# Создание резервной копии конфигурации
backup_config() {
    local config_file="/etc/chrony/chrony.conf"
    local backup_file="/etc/chrony/chrony.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    log_info "Создание резервной копии конфигурации..."
    
    if [ -f "$config_file" ]; then
        cp "$config_file" "$backup_file"
        log_success "Резервная копия создана: $backup_file"
    else
        log_warning "Файл конфигурации не найден: $config_file"
    fi
}

# Создание оптимальной конфигурации
create_optimal_config() {
    local config_file="/etc/chrony/chrony.conf"
    
    log_info "Создание оптимальной конфигурации для TimeCard..."
    
    # Определение PTP устройства (используем первое доступное)
    local ptp_device="/dev/ptp0"
    if [ ! -c "$ptp_device" ]; then
        ptp_device=$(ls /dev/ptp* | head -1)
        if [ -z "$ptp_device" ]; then
            log_error "PTP устройство не найдено"
            exit 1
        fi
    fi
    
    log_info "Используется PTP устройство: $ptp_device"
    
    # Создание конфигурации
    cat > "$config_file" << EOF
# Оптимизированная конфигурация Chrony для TimeCard
# Создано скриптом setup_chrony_timecard.sh
# Дата: $(date)

# =============================================================================
# ОСНОВНЫЕ ИСТОЧНИКИ ВРЕМЕНИ
# =============================================================================

# TimeCard PHC как основной источник времени
refclock PHC $ptp_device poll 3 dpoll -2 offset 0 stratum 1 precision 1e-9 prefer

# Резервные NTP серверы для обеспечения надежности
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

# =============================================================================
# НАСТРОЙКИ СИНХРОНИЗАЦИИ
# =============================================================================

# Быстрая начальная синхронизация
makestep 1.0 3

# Синхронизация RTC с системными часами
rtcsync

# Файл для сохранения информации о дрейфе часов
driftfile /var/lib/chrony/drift

# =============================================================================
# НАСТРОЙКИ ТОЧНОСТИ
# =============================================================================

# Максимальное отклонение частоты (ppm)
maxupdateskew 100.0

# Соотношение коррекции времени
corrtimeratio 3

# Максимальный дрейф частоты (ppm)
maxdrift 500

# Максимальная дистанция до источника (секунды)
maxdistance 1.0

# =============================================================================
# ЛОГИРОВАНИЕ И МОНИТОРИНГ
# =============================================================================

# Директория для логов
logdir /var/log/chrony

# Типы логируемой информации
log tracking measurements statistics

# Логирование изменений больше указанного значения (секунды)
logchange 0.001

# =============================================================================
# СЕТЕВЫЕ НАСТРОЙКИ
# =============================================================================

# Разрешение доступа для локальной сети
allow 192.168.0.0/16
allow 10.0.0.0/8
allow 172.16.0.0/12

# Локальный NTP сервер
local stratum 2

# Порт NTP
port 123

# =============================================================================
# БЕЗОПАСНОСТЬ
# =============================================================================

# Адреса для команд управления
bindcmdaddress 127.0.0.1
bindcmdaddress ::1

# Разрешение команд
cmdallow 127.0.0.1
cmdallow ::1

# =============================================================================
# ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ
# =============================================================================

# Минимальное количество источников
minsources 1

# Плавная коррекция времени
smoothtime 400 0.01 leaponly

# Обработка leap seconds
leapsecmode slew
maxslewrate 83333.333

# Ограничения для клиентов
clientloglimit 1048576

# =============================================================================
# НАСТРОЙКИ ДЛЯ ВЫСОКОЙ НАГРУЗКИ
# =============================================================================

# Ограничение скорости запросов
ratelimit interval 1 burst 16 leak 2
EOF
    
    log_success "Конфигурация создана: $config_file"
}

# Настройка прав доступа
setup_permissions() {
    log_info "Настройка прав доступа..."
    
    # Права на PTP устройства
    local ptp_devices=$(ls /dev/ptp* 2>/dev/null || true)
    for device in $ptp_devices; do
        chmod 666 "$device"
        log_success "Права установлены для $device"
    done
    
    # Создание директории для логов
    mkdir -p /var/log/chrony
    chown chrony:chrony /var/log/chrony
    log_success "Директория логов создана: /var/log/chrony"
}

# Перезапуск службы
restart_service() {
    log_info "Перезапуск службы chronyd..."
    
    systemctl restart chronyd
    sleep 3
    
    if systemctl is-active --quiet chronyd; then
        log_success "Служба chronyd успешно перезапущена"
    else
        log_error "Ошибка при перезапуске службы chronyd"
        return 1
    fi
}

# Проверка конфигурации
verify_config() {
    log_info "Проверка конфигурации..."
    
    # Проверка синтаксиса
    if chronyd -t; then
        log_success "Синтаксис конфигурации корректен"
    else
        log_error "Ошибка в синтаксисе конфигурации"
        return 1
    fi
    
    # Ожидание синхронизации
    log_info "Ожидание синхронизации (30 секунд)..."
    sleep 30
    
    # Проверка статуса
    local tracking_output=$(chronyc tracking 2>/dev/null || true)
    if [ -n "$tracking_output" ]; then
        log_success "Статус синхронизации:"
        echo "$tracking_output" | sed 's/^/  /'
    else
        log_warning "Не удалось получить статус синхронизации"
    fi
    
    # Проверка источников
    local sources_output=$(chronyc sources 2>/dev/null || true)
    if [ -n "$sources_output" ]; then
        log_success "Источники времени:"
        echo "$sources_output" | sed 's/^/  /'
    else
        log_warning "Не удалось получить список источников"
    fi
}

# Создание скрипта мониторинга
create_monitoring_script() {
    local script_path="/usr/local/bin/chrony-timecard-monitor.sh"
    
    log_info "Создание скрипта мониторинга..."
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Скрипт мониторинга Chrony + TimeCard

echo "=== Мониторинг Chrony + TimeCard ==="
echo "Время: $(date)"
echo

echo "--- Статус синхронизации ---"
chronyc tracking
echo

echo "--- Источники времени ---"
chronyc sources -v
echo

echo "--- Статистика источников ---"
chronyc sourcestats
echo

echo "--- Refclocks ---"
chronyc refclocks 2>/dev/null || echo "Refclocks недоступны"
echo

echo "--- TimeCard статус ---"
if [ -d /sys/class/timecard/ocp0 ]; then
    echo "Clock source: $(cat /sys/class/timecard/ocp0/clock_source 2>/dev/null || echo 'N/A')"
    echo "GNSS sync: $(cat /sys/class/timecard/ocp0/gnss_sync 2>/dev/null || echo 'N/A')"
    echo "Clock drift: $(cat /sys/class/timecard/ocp0/clock_status_drift 2>/dev/null || echo 'N/A')"
    echo "Clock offset: $(cat /sys/class/timecard/ocp0/clock_status_offset 2>/dev/null || echo 'N/A')"
else
    echo "TimeCard sysfs недоступен"
fi
EOF
    
    chmod +x "$script_path"
    log_success "Скрипт мониторинга создан: $script_path"
}

# Основная функция
main() {
    echo "=== Настройка Chrony для TimeCard ==="
    echo
    
    check_root
    check_chrony
    check_ptp_devices
    backup_config
    create_optimal_config
    setup_permissions
    restart_service
    verify_config
    create_monitoring_script
    
    echo
    log_success "Настройка завершена успешно!"
    echo
    log_info "Полезные команды:"
    log_info "  - Мониторинг: /usr/local/bin/chrony-timecard-monitor.sh"
    log_info "  - Статус: chronyc tracking"
    log_info "  - Источники: chronyc sources -v"
    log_info "  - Перезапуск: systemctl restart chronyd"
    echo
    log_info "Файлы конфигурации:"
    log_info "  - Основной: /etc/chrony/chrony.conf"
    log_info "  - Резервная копия: /etc/chrony/chrony.conf.backup.*"
    log_info "  - Логи: /var/log/chrony/"
    echo
    echo "=== Настройка завершена ==="
}

# Запуск основной функции
main "$@"
