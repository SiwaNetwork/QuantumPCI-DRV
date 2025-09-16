#!/bin/bash

# Скрипт для тестирования функций надежности драйвера ptp_ocp

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
TIMECARD_PATH=""
TEST_DURATION=30
WATCHDOG_TIMEOUT=5000

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

# Проверка доступности sysfs атрибутов
check_sysfs_attributes() {
    log "Проверка доступности sysfs атрибутов надежности..."
    
    ATTRIBUTES=(
        "suspend_state"
        "error_count"
        "error_recovery"
        "auto_recovery"
        "max_retries"
        "watchdog_enabled"
        "watchdog_timeout"
        "watchdog_stats"
        "heartbeat"
        "log_level"
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

# Тест 1: Suspend/Resume функциональность
test_suspend_resume() {
    log "=== Тест 1: Suspend/Resume функциональность ==="
    
    # Проверяем текущее состояние suspend
    if state=$(cat "$TIMECARD_PATH/suspend_state" 2>/dev/null); then
        success "Состояние suspend получено"
        echo "Состояние suspend:"
        echo "$state" | head -5
    else
        warning "Не удалось получить состояние suspend"
    fi
    
    # Симулируем suspend/resume (только для демонстрации)
    log "Примечание: Реальный suspend/resume требует root прав и может повлиять на систему"
    log "Для тестирования используйте: echo mem > /sys/power/state"
}

# Тест 2: Обработка ошибок
test_error_handling() {
    log "=== Тест 2: Обработка ошибок ==="
    
    # Получаем текущий счетчик ошибок
    local error_count_before=$(cat "$TIMECARD_PATH/error_count" 2>/dev/null || echo "0")
    log "Счетчик ошибок до теста: $error_count_before"
    
    # Получаем статус восстановления
    if recovery=$(cat "$TIMECARD_PATH/error_recovery" 2>/dev/null); then
        success "Статус восстановления получен"
        echo "Статус восстановления:"
        echo "$recovery" | head -5
    else
        warning "Не удалось получить статус восстановления"
    fi
    
    # Проверяем автоматическое восстановление
    local auto_recovery=$(cat "$TIMECARD_PATH/auto_recovery" 2>/dev/null || echo "disabled")
    log "Автоматическое восстановление: $auto_recovery"
    
    # Получаем максимальное количество попыток
    local max_retries=$(cat "$TIMECARD_PATH/max_retries" 2>/dev/null || echo "0")
    log "Максимальное количество попыток: $max_retries"
    
    # Получаем счетчик ошибок после теста
    local error_count_after=$(cat "$TIMECARD_PATH/error_count" 2>/dev/null || echo "0")
    log "Счетчик ошибок после теста: $error_count_after"
}

# Тест 3: Watchdog функциональность
test_watchdog() {
    log "=== Тест 3: Watchdog функциональность ==="
    
    # Проверяем текущее состояние watchdog
    local watchdog_enabled=$(cat "$TIMECARD_PATH/watchdog_enabled" 2>/dev/null || echo "disabled")
    log "Watchdog включен: $watchdog_enabled"
    
    # Получаем таймаут watchdog
    local watchdog_timeout=$(cat "$TIMECARD_PATH/watchdog_timeout" 2>/dev/null || echo "0")
    log "Таймаут watchdog: $watchdog_timeout мс"
    
    # Получаем статистику watchdog
    if stats=$(cat "$TIMECARD_PATH/watchdog_stats" 2>/dev/null); then
        success "Статистика watchdog получена"
        echo "Статистика watchdog:"
        echo "$stats" | head -10
    else
        warning "Не удалось получить статистику watchdog"
    fi
    
    # Тестируем heartbeat
    log "Тестирование heartbeat..."
    if echo "1" > "$TIMECARD_PATH/heartbeat" 2>/dev/null; then
        success "Heartbeat отправлен успешно"
    else
        warning "Не удалось отправить heartbeat"
    fi
    
    # Включаем watchdog для тестирования
    log "Включение watchdog для тестирования..."
    if echo "enabled" > "$TIMECARD_PATH/watchdog_enabled" 2>/dev/null; then
        success "Watchdog включен"
        
        # Устанавливаем короткий таймаут для тестирования
        if echo "3000" > "$TIMECARD_PATH/watchdog_timeout" 2>/dev/null; then
            success "Таймаут watchdog установлен в 3 секунды"
        fi
        
        # Отправляем несколько heartbeat
        for i in {1..5}; do
            log "Отправка heartbeat $i/5..."
            echo "1" > "$TIMECARD_PATH/heartbeat" 2>/dev/null
            sleep 1
        done
        
        # Получаем обновленную статистику
        if stats=$(cat "$TIMECARD_PATH/watchdog_stats" 2>/dev/null); then
            log "Обновленная статистика watchdog:"
            echo "$stats" | head -5
        fi
        
        # Отключаем watchdog
        log "Отключение watchdog..."
        if echo "disabled" > "$TIMECARD_PATH/watchdog_enabled" 2>/dev/null; then
            success "Watchdog отключен"
        fi
    else
        warning "Не удалось включить watchdog"
    fi
}

# Тест 4: Логирование
test_logging() {
    log "=== Тест 4: Логирование ==="
    
    # Получаем текущий уровень логирования
    local log_level=$(cat "$TIMECARD_PATH/log_level" 2>/dev/null || echo "UNKNOWN")
    log "Текущий уровень логирования: $log_level"
    
    # Тестируем изменение уровня логирования
    local test_levels=("DEBUG" "INFO" "WARN" "ERROR")
    
    for level in "${test_levels[@]}"; do
        log "Тестирование уровня логирования: $level"
        if echo "$level" > "$TIMECARD_PATH/log_level" 2>/dev/null; then
            success "Уровень логирования установлен в $level"
            
            # Проверяем, что уровень установился
            local current_level=$(cat "$TIMECARD_PATH/log_level" 2>/dev/null || echo "UNKNOWN")
            if [ "$current_level" = "$level" ]; then
                success "Уровень логирования подтвержден: $current_level"
            else
                warning "Уровень логирования не подтвержден: ожидался $level, получен $current_level"
            fi
        else
            warning "Не удалось установить уровень логирования $level"
        fi
    done
    
    # Возвращаем уровень логирования в INFO
    echo "INFO" > "$TIMECARD_PATH/log_level" 2>/dev/null
    success "Уровень логирования возвращен в INFO"
}

# Тест 5: Нагрузочное тестирование
test_stress() {
    log "=== Тест 5: Нагрузочное тестирование ==="
    
    # Включаем автоматическое восстановление
    log "Включение автоматического восстановления..."
    if echo "enabled" > "$TIMECARD_PATH/auto_recovery" 2>/dev/null; then
        success "Автоматическое восстановление включено"
    fi
    
    # Устанавливаем максимальное количество попыток
    if echo "5" > "$TIMECARD_PATH/max_retries" 2>/dev/null; then
        success "Максимальное количество попыток установлено в 5"
    fi
    
    # Включаем watchdog
    if echo "enabled" > "$TIMECARD_PATH/watchdog_enabled" 2>/dev/null; then
        success "Watchdog включен для нагрузочного тестирования"
    fi
    
    # Устанавливаем таймаут watchdog
    if echo "2000" > "$TIMECARD_PATH/watchdog_timeout" 2>/dev/null; then
        success "Таймаут watchdog установлен в 2 секунды"
    fi
    
    log "Запуск нагрузочного тестирования на $TEST_DURATION секунд..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + TEST_DURATION))
    local heartbeat_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # Отправляем heartbeat
        echo "1" > "$TIMECARD_PATH/heartbeat" 2>/dev/null
        heartbeat_count=$((heartbeat_count + 1))
        
        # Читаем статистику каждые 5 секунд
        if [ $((heartbeat_count % 5)) -eq 0 ]; then
            if stats=$(cat "$TIMECARD_PATH/watchdog_stats" 2>/dev/null); then
                log "Heartbeat отправлен $heartbeat_count раз"
                echo "$stats" | grep -E "(Last Heartbeat|Timeout Count|Reset Count)" | head -3
            fi
        fi
        
        sleep 1
    done
    
    success "Нагрузочное тестирование завершено"
    log "Всего отправлено heartbeat: $heartbeat_count"
    
    # Получаем финальную статистику
    if stats=$(cat "$TIMECARD_PATH/watchdog_stats" 2>/dev/null); then
        log "Финальная статистика watchdog:"
        echo "$stats" | head -10
    fi
    
    # Отключаем watchdog
    echo "disabled" > "$TIMECARD_path/watchdog_enabled" 2>/dev/null
    success "Watchdog отключен"
}

# Мониторинг в реальном времени
monitor_reliability() {
    log "=== Мониторинг надежности в реальном времени ==="
    
    echo "Нажмите Ctrl+C для остановки мониторинга"
    echo
    
    while true; do
        clear
        echo "=== Мониторинг надежности ==="
        echo "Время: $(date)"
        echo
        
        # Показываем состояние suspend
        if [ -f "$TIMECARD_PATH/suspend_state" ]; then
            echo "=== Состояние Suspend ==="
            cat "$TIMECARD_PATH/suspend_state" | head -5
            echo
        fi
        
        # Показываем статистику ошибок
        if [ -f "$TIMECARD_PATH/error_recovery" ]; then
            echo "=== Статистика ошибок ==="
            cat "$TIMECARD_PATH/error_recovery" | head -5
            echo
        fi
        
        # Показываем статистику watchdog
        if [ -f "$TIMECARD_PATH/watchdog_stats" ]; then
            echo "=== Статистика Watchdog ==="
            cat "$TIMECARD_PATH/watchdog_stats" | head -8
            echo
        fi
        
        sleep 2
    done
}

# Создание отчета о надежности
create_reliability_report() {
    log "Создание отчета о надежности..."
    
    local report_file="reliability_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== Отчет о тестировании надежности ===
Дата: $(date)
Версия ядра: $(uname -r)
Архитектура: $(uname -m)
Устройство: $TIMECARD_PATH

=== Состояние Suspend/Resume ===
EOF

    # Добавляем состояние suspend
    if [ -f "$TIMECARD_PATH/suspend_state" ]; then
        echo "Состояние suspend:" >> "$report_file"
        cat "$TIMECARD_PATH/suspend_state" >> "$report_file"
        echo >> "$report_file"
    fi
    
    # Добавляем статистику ошибок
    if [ -f "$TIMECARD_PATH/error_recovery" ]; then
        echo "Статистика ошибок:" >> "$report_file"
        cat "$TIMECARD_PATH/error_recovery" >> "$report_file"
        echo >> "$report_file"
    fi
    
    # Добавляем статистику watchdog
    if [ -f "$TIMECARD_PATH/watchdog_stats" ]; then
        echo "Статистика watchdog:" >> "$report_file"
        cat "$TIMECARD_PATH/watchdog_stats" >> "$report_file"
        echo >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

=== Рекомендации по настройке ===
1. Watchdog timeout: 5-10 секунд для критических систем
2. Max retries: 3-5 попыток для автоматического восстановления
3. Log level: INFO для продакшена, DEBUG для отладки
4. Auto recovery: enabled для автоматического восстановления

=== Следующие шаги ===
1. Настройте мониторинг надежности
2. Интегрируйте с системой мониторинга
3. Настройте алерты на критические значения
4. Регулярно анализируйте статистику

EOF

    success "Отчет создан: $report_file"
}

# Основная функция
main() {
    log "=== Тестирование функций надежности драйвера ptp_ocp ==="
    
    find_timecard
    check_sysfs_attributes
    
    echo
    log "Выберите тип тестирования:"
    echo "1. Тест Suspend/Resume функциональности"
    echo "2. Тест обработки ошибок"
    echo "3. Тест Watchdog функциональности"
    echo "4. Тест логирования"
    echo "5. Нагрузочное тестирование"
    echo "6. Мониторинг в реальном времени"
    echo "7. Полный тест (все вышеперечисленное)"
    echo "8. Создать отчет"
    echo
    
    read -p "Введите номер (1-8): " choice
    
    case $choice in
        1)
            test_suspend_resume
            ;;
        2)
            test_error_handling
            ;;
        3)
            test_watchdog
            ;;
        4)
            test_logging
            ;;
        5)
            test_stress
            ;;
        6)
            monitor_reliability
            ;;
        7)
            test_suspend_resume
            echo
            test_error_handling
            echo
            test_watchdog
            echo
            test_logging
            echo
            test_stress
            echo
            create_reliability_report
            ;;
        8)
            create_reliability_report
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
