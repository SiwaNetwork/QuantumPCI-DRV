#!/bin/bash

# Скрипт для управления режимом автономного хранения генератора (Holdover)
# для устройства PTP OCP

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

# Функция для поиска устройства PTP OCP
find_ptp_ocp_device() {
    local device_path=""
    
    # Ищем устройство в sysfs
    for dev in /sys/class/timecard/ocp*; do
        if [ -d "$dev" ]; then
            device_path="$dev"
            break
        fi
    done
    
    if [ -z "$device_path" ]; then
        log_error "Устройство PTP OCP не найдено в системе"
        log_info "Убедитесь, что драйвер ptp_ocp загружен: modprobe ptp_ocp"
        exit 1
    fi
    
    echo "$device_path"
}

# Функция для проверки статуса holdover
check_holdover_status() {
    local device_path="$1"
    local holdover_file="$device_path/holdover"
    
    if [ ! -f "$holdover_file" ]; then
        log_warning "Атрибут holdover не найден, используем альтернативные методы"
        return 1
    fi
    
    local status=$(cat "$holdover_file")
    echo "$status"
}

# Функция для проверки статуса автономного хранения через альтернативные методы
check_holdover_status_alt() {
    local device_path="$1"
    
    # Проверяем статус GNSS синхронизации
    local gnss_sync=""
    if [ -f "$device_path/gnss_sync" ]; then
        gnss_sync=$(cat "$device_path/gnss_sync")
    fi
    
    # Проверяем источник часов
    local clock_source=""
    if [ -f "$device_path/clock_source" ]; then
        clock_source=$(cat "$device_path/clock_source")
    fi
    
    # Проверяем дрифт часов
    local drift=""
    if [ -f "$device_path/clock_status_drift" ]; then
        drift=$(cat "$device_path/clock_status_drift")
    fi
    
    # Проверяем смещение часов
    local offset=""
    if [ -f "$device_path/clock_status_offset" ]; then
        offset=$(cat "$device_path/clock_status_offset")
    fi
    
    echo "GNSS_SYNC: $gnss_sync"
    echo "CLOCK_SOURCE: $clock_source"
    echo "DRIFT: $drift"
    echo "OFFSET: $offset"
}

# Функция для установки режима holdover
set_holdover_mode() {
    local device_path="$1"
    local mode="$2"
    local holdover_file="$device_path/holdover"
    
    if [ ! -f "$holdover_file" ]; then
        log_warning "Атрибут holdover не найден, используем альтернативные методы"
        set_holdover_mode_alt "$device_path" "$mode"
        return $?
    fi
    
    # Проверяем права доступа
    if [ ! -w "$holdover_file" ]; then
        log_error "Нет прав на запись в атрибут holdover"
        log_info "Запустите скрипт с правами root: sudo $0"
        return 1
    fi
    
    echo "$mode" > "$holdover_file"
    if [ $? -eq 0 ]; then
        log_success "Режим holdover установлен в: $mode"
    else
        log_error "Не удалось установить режим holdover"
        return 1
    fi
}

# Альтернативная функция для установки режима holdover
set_holdover_mode_alt() {
    local device_path="$1"
    local mode="$2"
    local clock_source_file="$device_path/clock_source"
    
    log_info "Использование альтернативного метода управления автономным хранением"
    
    case "$mode" in
        "0")
            log_info "Переключение в нормальный режим (синхронизация с GNSS)"
            if [ -w "$clock_source_file" ]; then
                echo "PPS" > "$clock_source_file"
                log_success "Источник часов установлен в PPS (нормальный режим)"
            else
                log_error "Нет прав на запись в clock_source"
                return 1
            fi
            ;;
        "1"|"2"|"3")
            log_info "Переключение в автономный режим (holdover $mode)"
            if [ -w "$clock_source_file" ]; then
                echo "REGS" > "$clock_source_file"
                log_success "Источник часов установлен в REGS (автономный режим)"
                log_info "Устройство переведено в режим автономного хранения генератора"
            else
                log_error "Нет прав на запись в clock_source"
                return 1
            fi
            ;;
        *)
            log_error "Неверный режим: $mode"
            return 1
            ;;
    esac
}

# Функция для сохранения калибровки в EEPROM (MRO50)
save_calibration_to_eeprom() {
    local device_path="$1"
    local mro50_device=""
    
    # Ищем устройство MRO50
    for dev in /dev/mro50*; do
        if [ -c "$dev" ]; then
            mro50_device="$dev"
            break
        fi
    done
    
    if [ -z "$mro50_device" ]; then
        log_warning "Устройство MRO50 не найдено, пропускаем сохранение калибровки"
        return 0
    fi
    
    log_info "Сохранение калибровки в EEPROM через $mro50_device..."
    
    # Используем ioctl MRO50_SAVE_COARSE для сохранения
    if command -v mro50_save >/dev/null 2>&1; then
        mro50_save "$mro50_device"
        log_success "Калибровка сохранена в EEPROM"
    else
        log_warning "Утилита mro50_save не найдена, используем прямой ioctl"
        # Прямой вызов ioctl через программу на C
        cat > /tmp/save_calibration.c << 'EOF'
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define MRO50_SAVE_COARSE _IO('M', 7)

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Использование: %s <device>\n", argv[0]);
        return 1;
    }
    
    int fd = open(argv[1], O_RDWR);
    if (fd < 0) {
        perror("open");
        return 1;
    }
    
    if (ioctl(fd, MRO50_SAVE_COARSE) < 0) {
        perror("ioctl MRO50_SAVE_COARSE");
        close(fd);
        return 1;
    }
    
    close(fd);
    printf("Калибровка сохранена в EEPROM\n");
    return 0;
}
EOF
        gcc -o /tmp/save_calibration /tmp/save_calibration.c
        /tmp/save_calibration "$mro50_device"
        rm -f /tmp/save_calibration.c /tmp/save_calibration
    fi
}

# Функция для отображения справки
show_help() {
    echo "Использование: $0 [КОМАНДА] [РЕЖИМ]"
    echo ""
    echo "КОМАНДЫ:"
    echo "  status              - Показать текущий статус holdover"
    echo "  set <режим>         - Установить режим holdover (0-3)"
    echo "  save                - Сохранить калибровку в EEPROM"
    echo "  info                - Показать информацию об устройстве"
    echo "  help                - Показать эту справку"
    echo ""
    echo "РЕЖИМЫ HOLDOVER:"
    echo "  0 - Нормальный режим (синхронизация с GNSS)"
    echo "  1 - Holdover режим 1 (кратковременное автономное хранение)"
    echo "  2 - Holdover режим 2 (средне-временное автономное хранение)"
    echo "  3 - Holdover режим 3 (долговременное автономное хранение)"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0 status           - Проверить статус"
    echo "  $0 set 1            - Включить holdover режим 1"
    echo "  $0 save             - Сохранить калибровку"
    echo ""
}

# Функция для отображения информации об устройстве
show_device_info() {
    local device_path="$1"
    
    log_info "Информация об устройстве PTP OCP:"
    echo "  Путь к устройству: $device_path"
    
    # Проверяем доступные атрибуты
    if [ -f "$device_path/clock_source" ]; then
        local clock_source=$(cat "$device_path/clock_source")
        echo "  Источник часов: $clock_source"
    fi
    
    if [ -f "$device_path/gnss_sync" ]; then
        local gnss_sync=$(cat "$device_path/gnss_sync")
        echo "  GNSS синхронизация: $gnss_sync"
    fi
    
    if [ -f "$device_path/serialnum" ]; then
        local serial=$(cat "$device_path/serialnum")
        echo "  Серийный номер: $serial"
    fi
    
    # Проверяем PTP устройство
    if [ -L "$device_path/ptp" ]; then
        local ptp_link=$(readlink "$device_path/ptp")
        local ptp_device=$(basename "$ptp_link")
        echo "  PTP устройство: /dev/$ptp_device"
    fi
    
    # Проверяем статус holdover
    local holdover_status=$(check_holdover_status "$device_path")
    if [ $? -eq 0 ]; then
        echo "  Текущий режим holdover: $holdover_status"
    fi
}

# Основная функция
main() {
    local command="$1"
    local mode="$2"
    
    # Проверяем аргументы
    if [ $# -eq 0 ] || [ "$command" = "help" ]; then
        show_help
        exit 0
    fi
    
    # Находим устройство
    log_info "Поиск устройства PTP OCP..."
    local device_path=$(find_ptp_ocp_device)
    log_success "Устройство найдено: $device_path"
    
    case "$command" in
        "status")
            log_info "Проверка статуса holdover..."
            local status=$(check_holdover_status "$device_path")
            if [ $? -eq 0 ]; then
                log_success "Текущий режим holdover: $status"
            else
                log_info "Использование альтернативного метода проверки статуса:"
                check_holdover_status_alt "$device_path"
            fi
            ;;
            
        "set")
            if [ -z "$mode" ]; then
                log_error "Не указан режим для установки"
                show_help
                exit 1
            fi
            
            if ! [[ "$mode" =~ ^[0-3]$ ]]; then
                log_error "Неверный режим: $mode. Допустимые значения: 0-3"
                exit 1
            fi
            
            log_info "Установка режима holdover: $mode"
            set_holdover_mode "$device_path" "$mode"
            ;;
            
        "save")
            log_info "Сохранение калибровки в EEPROM..."
            save_calibration_to_eeprom "$device_path"
            ;;
            
        "info")
            show_device_info "$device_path"
            ;;
            
        *)
            log_error "Неизвестная команда: $command"
            show_help
            exit 1
            ;;
    esac
}

# Запуск основной функции
main "$@"
