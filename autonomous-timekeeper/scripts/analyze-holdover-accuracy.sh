#!/bin/bash

# Анализ точности Quantum-PCI в режиме holdover
# Оценка дрейфа частоты и точности автономного хранения времени

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Функции для вывода сообщений
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

log_analysis() {
    echo -e "${PURPLE}[ANALYSIS]${NC} $1"
}

# Получение текущих параметров дрейфа
get_drift_parameters() {
    log_analysis "=== Анализ параметров дрейфа ==="
    
    # Получаем данные из chronyc tracking
    local tracking_data=$(chronyc tracking)
    
    # Извлекаем ключевые параметры
    local frequency=$(echo "$tracking_data" | grep "Frequency" | awk '{print $3}')
    local residual_freq=$(echo "$tracking_data" | grep "Residual freq" | awk '{print $4}')
    local skew=$(echo "$tracking_data" | grep "Skew" | awk '{print $3}')
    local rms_offset=$(echo "$tracking_data" | grep "RMS offset" | awk '{print $4}')
    
    echo "  - Frequency: $frequency ppm"
    echo "  - Residual freq: $residual_freq ppm"
    echo "  - Skew: $skew ppm"
    echo "  - RMS offset: $rms_offset секунд"
    
    # Сохраняем для дальнейших расчетов
    echo "$frequency" > /tmp/frequency
    echo "$residual_freq" > /tmp/residual_freq
    echo "$skew" > /tmp/skew
    echo "$rms_offset" > /tmp/rms_offset
}

# Анализ стабильности Quantum-PCI
analyze_quantum_stability() {
    log_analysis "=== Анализ стабильности Quantum-PCI ==="
    
    if [ ! -d "/sys/class/timecard/ocp0" ]; then
        log_error "Quantum-PCI устройство не найдено"
        return 1
    fi
    
    local clock_source=$(cat /sys/class/timecard/ocp0/clock_source 2>/dev/null || echo "N/A")
    local gnss_sync=$(cat /sys/class/timecard/ocp0/gnss_sync 2>/dev/null || echo "N/A")
    local drift=$(cat /sys/class/timecard/ocp0/clock_status_drift 2>/dev/null || echo "N/A")
    local offset=$(cat /sys/class/timecard/ocp0/clock_status_offset 2>/dev/null || echo "N/A")
    
    echo "  - Clock source: $clock_source"
    echo "  - GNSS sync: $gnss_sync"
    echo "  - Clock drift: $drift ppb"
    echo "  - Clock offset: $offset нс"
    
    # Анализ типа генератора
    if [ "$clock_source" = "PPS" ]; then
        log_info "Режим: PPS (Pulse Per Second) - внешний источник"
    elif [ "$clock_source" = "INTERNAL" ]; then
        log_info "Режим: INTERNAL - внутренний генератор"
    else
        log_warning "Неизвестный режим: $clock_source"
    fi
}

# Расчет точности в режиме holdover
calculate_holdover_accuracy() {
    log_analysis "=== Расчет точности в режиме holdover ==="
    
    # Читаем сохраненные параметры
    local frequency=$(cat /tmp/frequency 2>/dev/null || echo "0")
    local residual_freq=$(cat /tmp/residual_freq 2>/dev/null || echo "0")
    local skew=$(cat /tmp/skew 2>/dev/null || echo "0")
    local rms_offset=$(cat /tmp/rms_offset 2>/dev/null || echo "0")
    
    # Убираем знаки для расчетов
    local freq_abs=$(echo "$frequency" | sed 's/-//')
    local residual_abs=$(echo "$residual_freq" | sed 's/-//')
    local skew_abs=$(echo "$skew" | sed 's/-//')
    
    echo "Параметры для расчета:"
    echo "  - Frequency: $frequency ppm"
    echo "  - Residual freq: $residual_freq ppm"
    echo "  - Skew: $skew ppm"
    echo "  - RMS offset: $rms_offset сек"
    echo
    
    # Расчет дрейфа времени для разных периодов
    log_info "Расчет накопления ошибки времени:"
    
    # 1 час
    local error_1h=$(echo "scale=6; $residual_abs * 3600 / 1000000" | bc -l 2>/dev/null || echo "0")
    echo "  - За 1 час: $error_1h секунд ($(echo "scale=3; $error_1h * 1000" | bc -l 2>/dev/null || echo "0") мс)"
    
    # 24 часа
    local error_24h=$(echo "scale=6; $residual_abs * 86400 / 1000000" | bc -l 2>/dev/null || echo "0")
    echo "  - За 24 часа: $error_24h секунд ($(echo "scale=3; $error_24h * 1000" | bc -l 2>/dev/null || echo "0") мс)"
    
    # 7 дней
    local error_7d=$(echo "scale=6; $residual_abs * 604800 / 1000000" | bc -l 2>/dev/null || echo "0")
    echo "  - За 7 дней: $error_7d секунд ($(echo "scale=3; $error_7d * 1000" | bc -l 2>/dev/null || echo "0") мс)"
    
    # 30 дней
    local error_30d=$(echo "scale=6; $residual_abs * 2592000 / 1000000" | bc -l 2>/dev/null || echo "0")
    echo "  - За 30 дней: $error_30d секунд ($(echo "scale=3; $error_30d * 1000" | bc -l 2>/dev/null || echo "0") мс)"
    
    # Классификация точности
    echo
    log_info "Классификация точности:"
    
    if (( $(echo "$residual_abs < 1" | bc -l 2>/dev/null || echo "0") )); then
        log_success "ОТЛИЧНАЯ точность (< 1 ppm) - пригодна для критических применений"
    elif (( $(echo "$residual_abs < 10" | bc -l 2>/dev/null || echo "0") )); then
        log_success "ХОРОШАЯ точность (< 10 ppm) - пригодна для большинства применений"
    elif (( $(echo "$residual_abs < 100" | bc -l 2>/dev/null || echo "0") )); then
        log_warning "СРЕДНЯЯ точность (< 100 ppm) - требует периодической коррекции"
    else
        log_error "НИЗКАЯ точность (> 100 ppm) - требует частой коррекции"
    fi
}

# Анализ влияния температуры
analyze_temperature_impact() {
    log_analysis "=== Анализ влияния температуры ==="
    
    # Проверяем доступность температурных данных
    if [ -f "/sys/class/timecard/ocp0/temperature_table" ]; then
        log_info "Температурная таблица доступна (ART Card)"
        local temp_data=$(cat /sys/class/timecard/ocp0/temperature_table 2>/dev/null || echo "N/A")
        echo "  - Temperature table: $temp_data"
    else
        log_warning "Температурная таблица недоступна"
        echo "  - Примечание: Влияние температуры не учитывается"
    fi
    
    # Общие рекомендации по температуре
    echo
    log_info "Рекомендации по температуре:"
    echo "  - Оптимальная температура: 20-25°C"
    echo "  - Допустимый диапазон: 0-70°C"
    echo "  - Коэффициент температурного дрейфа: ~0.1 ppm/°C (типично)"
}

# Рекомендации по оптимизации
provide_optimization_recommendations() {
    log_analysis "=== Рекомендации по оптимизации ==="
    
    local residual_freq=$(cat /tmp/residual_freq 2>/dev/null || echo "0")
    local residual_abs=$(echo "$residual_freq" | sed 's/-//')
    
    echo "Текущий residual freq: $residual_freq ppm"
    echo
    
    if (( $(echo "$residual_abs > 10" | bc -l 2>/dev/null || echo "0") )); then
        log_warning "Рекомендации для улучшения точности:"
        echo "  1. Увеличить время синхронизации с NTP серверами"
        echo "  2. Использовать более стабильные NTP серверы"
        echo "  3. Настроить более частый опрос источников"
        echo "  4. Проверить стабильность питания"
        echo "  5. Обеспечить стабильную температуру"
    else
        log_success "Текущая точность отличная, дополнительные оптимизации не требуются"
    fi
    
    echo
    log_info "Настройки chrony для улучшения точности:"
    echo "  - Уменьшить minpoll: minpoll 3"
    echo "  - Увеличить maxpoll: maxpoll 6"
    echo "  - Настроить smoothtime: smoothtime 400 0.01"
    echo "  - Уменьшить maxdistance: maxdistance 0.5"
}

# Основная функция
main() {
    echo "=========================================="
    echo "🔬 Анализ точности Quantum-PCI в режиме holdover"
    echo "=========================================="
    echo
    
    # Проверка наличия bc для расчетов
    if ! command -v bc >/dev/null 2>&1; then
        log_error "Требуется установить bc для расчетов"
        log_info "Установка: sudo apt install bc"
        exit 1
    fi
    
    get_drift_parameters
    echo
    analyze_quantum_stability
    echo
    calculate_holdover_accuracy
    echo
    analyze_temperature_impact
    echo
    provide_optimization_recommendations
    
    echo
    echo "=========================================="
    echo "✅ Анализ завершен"
    echo "=========================================="
    
    # Очистка временных файлов
    rm -f /tmp/frequency /tmp/residual_freq /tmp/skew /tmp/rms_offset
}

# Запуск основной функции
main "$@"
