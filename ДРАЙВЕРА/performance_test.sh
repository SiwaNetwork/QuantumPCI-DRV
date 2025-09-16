#!/bin/bash

# Скрипт для тестирования производительности оптимизированного драйвера ptp_ocp

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Настройки тестирования
TEST_ITERATIONS=10000
WARMUP_ITERATIONS=1000
TIMECARD_PATH=""
PTP_DEVICE=""

# Поиск устройства timecard
find_timecard() {
    log "Поиск устройства timecard..."
    
    TIMECARD_PATH=$(find /sys/class/timecard -name "ocp*" | head -1)
    
    if [ -z "$TIMECARD_PATH" ]; then
        error "Устройство timecard не найдено!"
        error "Убедитесь, что драйвер ptp_ocp загружен"
        exit 1
    fi
    
    success "Найдено устройство: $TIMECARD_PATH"
}

# Поиск PTP устройства
find_ptp_device() {
    log "Поиск PTP устройства..."
    
    # Ищем символическую ссылку на PTP устройство
    if [ -L "$TIMECARD_PATH/ptp" ]; then
        PTP_DEVICE=$(readlink "$TIMECARD_PATH/ptp")
        PTP_DEVICE="/dev/$(basename "$PTP_DEVICE")"
        
        if [ -c "$PTP_DEVICE" ]; then
            success "Найдено PTP устройство: $PTP_DEVICE"
        else
            error "PTP устройство $PTP_DEVICE не найдено!"
            exit 1
        fi
    else
        error "Символическая ссылка на PTP устройство не найдена!"
        exit 1
    fi
}

# Проверка доступности sysfs атрибутов
check_sysfs_attributes() {
    log "Проверка доступности sysfs атрибутов производительности..."
    
    ATTRIBUTES=(
        "performance_stats"
        "cache_stats"
        "cache_timeout"
        "performance_mode"
        "latency_stats"
    )
    
    for attr in "${ATTRIBUTES[@]}"; do
        if [ -f "$TIMECARD_PATH/$attr" ]; then
            success "Атрибут $attr доступен"
        else
            error "Атрибут $attr не найден!"
            exit 1
        fi
    done
}

# Сброс статистики производительности
reset_performance_stats() {
    log "Сброс статистики производительности..."
    
    if echo 1 > "$TIMECARD_PATH/reset_performance_stats" 2>/dev/null; then
        success "Статистика производительности сброшена"
    else
        warning "Не удалось сбросить статистику производительности"
    fi
}

# Настройка режима производительности
setup_performance_mode() {
    log "Настройка режима производительности..."
    
    # Включаем режим производительности
    if echo "enabled" > "$TIMECARD_PATH/performance_mode" 2>/dev/null; then
        success "Режим производительности включен"
    else
        warning "Не удалось включить режим производительности"
    fi
    
    # Устанавливаем таймаут кэша
    if echo "1000000" > "$TIMECARD_PATH/cache_timeout" 2>/dev/null; then
        success "Таймаут кэша установлен в 1 мс"
    else
        warning "Не удалось установить таймаут кэша"
    fi
}

# Тест производительности gettime
test_gettime_performance() {
    log "Тестирование производительности gettime..."
    
    # Создаем временный файл для результатов
    local temp_file=$(mktemp)
    
    # Запускаем тест
    for ((i=1; i<=TEST_ITERATIONS; i++)); do
        if [ -c "$PTP_DEVICE" ]; then
            # Используем testptp для тестирования
            if command -v testptp >/dev/null 2>&1; then
                start_time=$(date +%s%N)
                testptp -d "$PTP_DEVICE" -g >/dev/null 2>&1
                end_time=$(date +%s%N)
                echo $((end_time - start_time)) >> "$temp_file"
            else
                # Альтернативный метод через sysfs
                start_time=$(date +%s%N)
                cat "$TIMECARD_PATH/clock_status_drift" >/dev/null 2>&1
                end_time=$(date +%s%N)
                echo $((end_time - start_time)) >> "$temp_file"
            fi
        fi
        
        # Показываем прогресс
        if [ $((i % 1000)) -eq 0 ]; then
            log "Выполнено $i/$TEST_ITERATIONS итераций"
        fi
    done
    
    # Анализируем результаты
    if [ -s "$temp_file" ]; then
        local min_time=$(sort -n "$temp_file" | head -1)
        local max_time=$(sort -n "$temp_file" | tail -1)
        local avg_time=$(awk '{sum+=$1} END {print int(sum/NR)}' "$temp_file")
        
        success "Результаты теста gettime:"
        echo "  Минимальное время: ${min_time} нс"
        echo "  Максимальное время: ${max_time} нс"
        echo "  Среднее время: ${avg_time} нс"
        echo "  Итераций: $TEST_ITERATIONS"
    else
        error "Не удалось получить результаты теста gettime"
    fi
    
    # Очищаем временный файл
    rm -f "$temp_file"
}

# Тест производительности settime
test_settime_performance() {
    log "Тестирование производительности settime..."
    
    # Создаем временный файл для результатов
    local temp_file=$(mktemp)
    
    # Запускаем тест
    for ((i=1; i<=1000; i++)); do  # Меньше итераций для settime
        if [ -c "$PTP_DEVICE" ]; then
            if command -v testptp >/dev/null 2>&1; then
                start_time=$(date +%s%N)
                # Устанавливаем текущее время
                testptp -d "$PTP_DEVICE" -s >/dev/null 2>&1
                end_time=$(date +%s%N)
                echo $((end_time - start_time)) >> "$temp_file"
            fi
        fi
        
        # Показываем прогресс
        if [ $((i % 100)) -eq 0 ]; then
            log "Выполнено $i/1000 итераций"
        fi
    done
    
    # Анализируем результаты
    if [ -s "$temp_file" ]; then
        local min_time=$(sort -n "$temp_file" | head -1)
        local max_time=$(sort -n "$temp_file" | tail -1)
        local avg_time=$(awk '{sum+=$1} END {print int(sum/NR)}' "$temp_file")
        
        success "Результаты теста settime:"
        echo "  Минимальное время: ${min_time} нс"
        echo "  Максимальное время: ${max_time} нс"
        echo "  Среднее время: ${avg_time} нс"
        echo "  Итераций: 1000"
    else
        error "Не удалось получить результаты теста settime"
    fi
    
    # Очищаем временный файл
    rm -f "$temp_file"
}

# Тест кэширования
test_cache_performance() {
    log "Тестирование производительности кэширования..."
    
    # Получаем статистику кэша до теста
    local cache_stats_before=$(cat "$TIMECARD_PATH/cache_stats" 2>/dev/null || echo "")
    
    # Выполняем множественные чтения
    for ((i=1; i<=1000; i++)); do
        cat "$TIMECARD_PATH/performance_stats" >/dev/null 2>&1
        cat "$TIMECARD_PATH/cache_stats" >/dev/null 2>&1
    done
    
    # Получаем статистику кэша после теста
    local cache_stats_after=$(cat "$TIMECARD_PATH/cache_stats" 2>/dev/null || echo "")
    
    success "Статистика кэширования:"
    echo "$cache_stats_after"
}

# Мониторинг производительности в реальном времени
monitor_performance() {
    log "Мониторинг производительности в реальном времени..."
    
    echo "Нажмите Ctrl+C для остановки мониторинга"
    echo
    
    while true; do
        clear
        echo "=== Мониторинг производительности ==="
        echo "Время: $(date)"
        echo
        
        # Показываем статистику производительности
        if [ -f "$TIMECARD_PATH/performance_stats" ]; then
            echo "=== Статистика производительности ==="
            cat "$TIMECARD_PATH/performance_stats"
            echo
        fi
        
        # Показываем статистику кэша
        if [ -f "$TIMECARD_PATH/cache_stats" ]; then
            echo "=== Статистика кэша ==="
            cat "$TIMECARD_PATH/cache_stats"
            echo
        fi
        
        # Показываем статистику задержек
        if [ -f "$TIMECARD_PATH/latency_stats" ]; then
            echo "=== Статистика задержек ==="
            cat "$TIMECARD_PATH/latency_stats"
            echo
        fi
        
        sleep 2
    done
}

# Создание отчета о производительности
create_performance_report() {
    log "Создание отчета о производительности..."
    
    local report_file="performance_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== Отчет о тестировании производительности ===
Дата: $(date)
Версия ядра: $(uname -r)
Архитектура: $(uname -m)
Устройство: $TIMECARD_PATH
PTP устройство: $PTP_DEVICE

=== Статистика производительности ===
EOF

    # Добавляем статистику производительности
    if [ -f "$TIMECARD_PATH/performance_stats" ]; then
        echo "Статистика производительности:" >> "$report_file"
        cat "$TIMECARD_PATH/performance_stats" >> "$report_file"
        echo >> "$report_file"
    fi
    
    # Добавляем статистику кэша
    if [ -f "$TIMECARD_PATH/cache_stats" ]; then
        echo "Статистика кэша:" >> "$report_file"
        cat "$TIMECARD_PATH/cache_stats" >> "$report_file"
        echo >> "$report_file"
    fi
    
    # Добавляем статистику задержек
    if [ -f "$TIMECARD_PATH/latency_stats" ]; then
        echo "Статистика задержек:" >> "$report_file"
        cat "$TIMECARD_PATH/latency_stats" >> "$report_file"
        echo >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

=== Рекомендации по оптимизации ===
1. Если hit ratio кэша < 80%, увеличьте cache_timeout
2. Если задержки gettime > 5 мкс, проверьте настройки кэша
3. Если задержки settime > 10 мкс, проверьте PCIe настройки
4. Мониторьте статистику регулярно для выявления проблем

=== Следующие шаги ===
1. Настройте мониторинг производительности
2. Интегрируйте с системой мониторинга
3. Настройте алерты на критические значения
4. Регулярно анализируйте статистику

EOF

    success "Отчет создан: $report_file"
}

# Основная функция
main() {
    log "=== Тестирование производительности оптимизированного драйвера ==="
    
    find_timecard
    find_ptp_device
    check_sysfs_attributes
    reset_performance_stats
    setup_performance_mode
    
    echo
    log "Выберите тип тестирования:"
    echo "1. Тест производительности gettime"
    echo "2. Тест производительности settime"
    echo "3. Тест кэширования"
    echo "4. Мониторинг в реальном времени"
    echo "5. Полный тест (все вышеперечисленное)"
    echo "6. Создать отчет"
    echo
    
    read -p "Введите номер (1-6): " choice
    
    case $choice in
        1)
            test_gettime_performance
            ;;
        2)
            test_settime_performance
            ;;
        3)
            test_cache_performance
            ;;
        4)
            monitor_performance
            ;;
        5)
            test_gettime_performance
            echo
            test_settime_performance
            echo
            test_cache_performance
            echo
            create_performance_report
            ;;
        6)
            create_performance_report
            ;;
        *)
            error "Неверный выбор!"
            exit 1
            ;;
    esac
    
    success "=== Тестирование завершено! ==="
}

# Запуск основной функции
main "$@"
