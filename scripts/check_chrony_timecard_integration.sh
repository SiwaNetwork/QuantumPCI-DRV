#!/bin/bash

# Скрипт проверки интеграции Chrony с TimeCard
# Проверяет совместимость и корректность настройки

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

# Проверка версии chrony
check_chrony_version() {
    log_info "Проверка версии Chrony..."
    
    if command -v chronyd >/dev/null 2>&1; then
        local version=$(chronyd --version | head -1)
        log_success "Chrony установлен: $version"
        
        # Проверка минимальной версии (4.0+)
        local major_version=$(echo "$version" | grep -o '[0-9]\+\.[0-9]\+' | head -1 | cut -d. -f1)
        if [ "$major_version" -ge 4 ]; then
            log_success "Версия Chrony поддерживается (4.0+)"
        else
            log_warning "Рекомендуется обновить Chrony до версии 4.0+"
        fi
    else
        log_error "Chrony не установлен"
        return 1
    fi
}

# Проверка статуса службы chronyd
check_chronyd_service() {
    log_info "Проверка службы chronyd..."
    
    if systemctl is-active --quiet chronyd; then
        log_success "Служба chronyd активна"
    else
        log_error "Служба chronyd не запущена"
        return 1
    fi
    
    if systemctl is-enabled --quiet chronyd; then
        log_success "Служба chronyd включена для автозапуска"
    else
        log_warning "Служба chronyd не включена для автозапуска"
    fi
}

# Проверка PTP устройств
check_ptp_devices() {
    log_info "Проверка PTP устройств..."
    
    local ptp_devices=$(ls /dev/ptp* 2>/dev/null || true)
    
    if [ -z "$ptp_devices" ]; then
        log_error "PTP устройства не найдены"
        return 1
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

# Проверка TimeCard устройств
check_timecard_devices() {
    log_info "Проверка TimeCard устройств..."
    
    local timecard_devices=$(ls /sys/class/timecard/ocp* 2>/dev/null || true)
    
    if [ -z "$timecard_devices" ]; then
        log_warning "TimeCard устройства не найдены в sysfs"
        return 1
    fi
    
    log_success "Найдены TimeCard устройства:"
    for device in $timecard_devices; do
        local device_name=$(basename "$device")
        echo "  - $device_name"
        
        # Проверка основных атрибутов
        if [ -f "$device/clock_source" ]; then
            local clock_source=$(cat "$device/clock_source")
            echo "    Clock source: $clock_source"
        fi
        
        if [ -f "$device/gnss_sync" ]; then
            local gnss_sync=$(cat "$device/gnss_sync")
            echo "    GNSS sync: $gnss_sync"
        fi
        
        if [ -f "$device/serialnum" ]; then
            local serial=$(cat "$device/serialnum")
            echo "    Serial: $serial"
        fi
    done
}

# Проверка конфигурации chrony
check_chrony_config() {
    log_info "Проверка конфигурации Chrony..."
    
    local config_file="/etc/chrony/chrony.conf"
    
    if [ ! -f "$config_file" ]; then
        log_error "Файл конфигурации $config_file не найден"
        return 1
    fi
    
    log_success "Файл конфигурации найден: $config_file"
    
    # Проверка наличия PHC источников
    if grep -q "refclock PHC" "$config_file"; then
        log_success "PHC источники настроены в конфигурации"
        
        # Показать PHC конфигурации
        echo "PHC конфигурации:"
        grep "refclock PHC" "$config_file" | sed 's/^/  /'
    else
        log_warning "PHC источники не найдены в конфигурации"
    fi
    
    # Проверка других важных настроек
    local important_settings=("makestep" "rtcsync" "driftfile")
    for setting in "${important_settings[@]}"; do
        if grep -q "^$setting" "$config_file"; then
            log_success "Настройка $setting найдена"
        else
            log_warning "Настройка $setting не найдена"
        fi
    done
}

# Проверка источников времени в chrony
check_chrony_sources() {
    log_info "Проверка источников времени в Chrony..."
    
    # Проверка доступности chronyc
    if ! command -v chronyc >/dev/null 2>&1; then
        log_error "chronyc не найден"
        return 1
    fi
    
    # Проверка источников
    local sources_output=$(chronyc sources 2>/dev/null || true)
    if [ -n "$sources_output" ]; then
        log_success "Источники времени:"
        echo "$sources_output" | sed 's/^/  /'
        
        # Проверка PHC источников
        if echo "$sources_output" | grep -q "PHC"; then
            log_success "PHC источники активны"
        else
            log_warning "PHC источники не активны"
        fi
    else
        log_error "Не удалось получить список источников"
        return 1
    fi
}

# Проверка статуса синхронизации
check_sync_status() {
    log_info "Проверка статуса синхронизации..."
    
    local tracking_output=$(chronyc tracking 2>/dev/null || true)
    if [ -n "$tracking_output" ]; then
        log_success "Статус синхронизации:"
        echo "$tracking_output" | sed 's/^/  /'
        
        # Проверка Reference ID
        local ref_id=$(echo "$tracking_output" | grep "Reference ID" | awk '{print $4}')
        if [[ "$ref_id" =~ ^[0-9A-Fa-f]+$ ]]; then
            log_success "Reference ID: $ref_id"
        fi
        
        # Проверка Stratum
        local stratum=$(echo "$tracking_output" | grep "Stratum" | awk '{print $3}')
        if [ -n "$stratum" ]; then
            log_success "Stratum: $stratum"
        fi
        
        # Проверка System time offset
        local offset=$(echo "$tracking_output" | grep "System time" | awk '{print $4}')
        if [ -n "$offset" ]; then
            log_success "System time offset: $offset"
        fi
    else
        log_error "Не удалось получить статус синхронизации"
        return 1
    fi
}

# Проверка refclocks
check_refclocks() {
    log_info "Проверка refclocks..."
    
    local refclocks_output=$(chronyc refclocks 2>/dev/null || true)
    if [ -n "$refclocks_output" ]; then
        log_success "Refclocks:"
        echo "$refclocks_output" | sed 's/^/  /'
    else
        log_warning "Refclocks не найдены или недоступны"
    fi
}

# Проверка прав доступа
check_permissions() {
    log_info "Проверка прав доступа..."
    
    # Проверка прав на PTP устройства
    local ptp_devices=$(ls /dev/ptp* 2>/dev/null || true)
    for device in $ptp_devices; do
        local permissions=$(ls -l "$device" | awk '{print $1, $3, $4}')
        echo "  $device: $permissions"
    done
    
    # Проверка прав на конфигурацию
    local config_file="/etc/chrony/chrony.conf"
    if [ -f "$config_file" ]; then
        local config_permissions=$(ls -l "$config_file" | awk '{print $1, $3, $4}')
        echo "  $config_file: $config_permissions"
    fi
}

# Рекомендации по улучшению
provide_recommendations() {
    log_info "Рекомендации по улучшению конфигурации..."
    
    echo "1. Убедитесь, что в /etc/chrony/chrony.conf есть:"
    echo "   - refclock PHC /dev/ptp0 poll 3 dpoll -2 offset 0 stratum 1 precision 1e-9 prefer"
    echo "   - makestep 1.0 3"
    echo "   - rtcsync"
    echo "   - driftfile /var/lib/chrony/drift"
    
    echo "2. Для мониторинга добавьте:"
    echo "   - log tracking measurements statistics"
    echo "   - logdir /var/log/chrony"
    
    echo "3. Для резервирования добавьте NTP серверы:"
    echo "   - server 0.pool.ntp.org iburst"
    echo "   - server 1.pool.ntp.org iburst"
    
    echo "4. Проверьте права доступа к PTP устройствам:"
    echo "   - sudo chmod 666 /dev/ptp*"
    echo "   - или добавьте пользователя в группу ptp"
}

# Основная функция
main() {
    echo "=== Проверка интеграции Chrony с TimeCard ==="
    echo
    
    local errors=0
    
    # Выполнение проверок
    check_chrony_version || ((errors++))
    echo
    
    check_chronyd_service || ((errors++))
    echo
    
    check_ptp_devices || ((errors++))
    echo
    
    check_timecard_devices || ((errors++))
    echo
    
    check_chrony_config || ((errors++))
    echo
    
    check_chrony_sources || ((errors++))
    echo
    
    check_sync_status || ((errors++))
    echo
    
    check_refclocks
    echo
    
    check_permissions
    echo
    
    # Итоговый результат
    if [ $errors -eq 0 ]; then
        log_success "Все проверки пройдены успешно!"
        echo
        log_info "Интеграция Chrony с TimeCard работает корректно"
    else
        log_error "Обнаружено $errors проблем"
        echo
        provide_recommendations
    fi
    
    echo
    echo "=== Проверка завершена ==="
}

# Запуск основной функции
main "$@"
