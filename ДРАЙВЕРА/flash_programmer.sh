#!/bin/bash

# Скрипт для прошивки программатором MTD

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Проверка прав администратора
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен быть запущен с правами администратора"
        exit 1
    fi
}

# Проверка MTD устройств
check_mtd_devices() {
    print_header "Проверка MTD устройств"
    
    if [ ! -e "/dev/mtd1" ]; then
        print_error "MTD устройство /dev/mtd1 не найдено"
        exit 1
    fi
    
    print_status "MTD устройства найдены:"
    ls -la /dev/mtd*
    echo
    
    print_status "Информация о MTD устройствах:"
    cat /proc/mtd 2>/dev/null || print_warning "Не удалось получить информацию о MTD"
    echo
}

# Создание резервной копии
create_backup() {
    local backup_file="backup_firmware_$(date +%Y%m%d_%H%M%S).bin"
    
    print_header "Создание резервной копии"
    
    print_status "Создание резервной копии: $backup_file"
    dd if=/dev/mtd1 of="$backup_file" bs=1M status=progress
    
    local backup_size=$(stat -c%s "$backup_file")
    print_status "Резервная копия создана: $backup_size байт"
    
    echo "$backup_file"
}

# Прошивка устройства
flash_device() {
    local firmware_file=$1
    local mtd_device="/dev/mtd1"
    
    print_header "Прошивка устройства"
    
    # Проверка файла
    if [ ! -f "$firmware_file" ]; then
        print_error "Файл прошивки $firmware_file не найден"
        exit 1
    fi
    
    local firmware_size=$(stat -c%s "$firmware_file")
    print_status "Размер файла прошивки: $firmware_size байт"
    
    # Проверка размера MTD устройства
    local mtd_size=$(cat /sys/class/mtd/mtd1/size 2>/dev/null || echo "0")
    if [ "$mtd_size" != "0" ] && [ "$firmware_size" -gt "$mtd_size" ]; then
        print_warning "Размер прошивки ($firmware_size) больше размера MTD устройства ($mtd_size)"
        read -p "Продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Прошивка отменена пользователем"
            exit 1
        fi
    fi
    
    # Прошивка
    print_status "Начинаем прошивку..."
    print_warning "НЕ ПРЕРЫВАЙТЕ ПРОЦЕСС ПРОШИВКИ!"
    
    dd if="$firmware_file" of="$mtd_device" bs=1M status=progress
    
    # Синхронизация
    print_status "Синхронизация..."
    sync
    
    print_status "Прошивка завершена!"
}

# Проверка результата
verify_flash() {
    print_header "Проверка результата"
    
    print_status "Заголовок прошивки на устройстве:"
    dd if=/dev/mtd1 bs=1 count=16 2>/dev/null | hexdump -C
    
    print_status "Перезагрузка драйвера..."
    modprobe -r ptp_ocp 2>/dev/null || print_warning "Не удалось выгрузить драйвер"
    sleep 2
    modprobe ptp_ocp 2>/dev/null || print_warning "Не удалось загрузить драйвер"
    
    print_status "Состояние устройства:"
    lspci | grep "01:00.0" || print_warning "Устройство не найдено"
}

# Показать справку
show_help() {
    echo "Использование: $0 [опции]"
    echo
    echo "Опции:"
    echo "  -f, --firmware FILE    Файл прошивки для прошивки"
    echo "  -b, --backup           Только создать резервную копию"
    echo "  -v, --verify           Только проверить результат"
    echo "  -h, --help             Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0 -f ./QuantumPCI-Firmware-Tool/Factory_TimeCard.bin"
    echo "  $0 -f Factory_TimeCard_quantum.bin"
    echo "  $0 -b"
    echo "  $0 -v"
    echo
    echo "Доступные файлы прошивки:"
    ls -la *.bin 2>/dev/null || echo "Файлы прошивки не найдены"
}

# Основная логика
main() {
    check_root
    check_mtd_devices
    
    local firmware_file=""
    local backup_only=false
    local verify_only=false
    
    # Парсинг аргументов
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--firmware)
                firmware_file="$2"
                shift 2
                ;;
            -b|--backup)
                backup_only=true
                shift
                ;;
            -v|--verify)
                verify_only=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$backup_only" = true ]; then
        create_backup
        exit 0
    fi
    
    if [ "$verify_only" = true ]; then
        verify_flash
        exit 0
    fi
    
    if [ -z "$firmware_file" ]; then
        print_error "Не указан файл прошивки"
        show_help
        exit 1
    fi
    
    # Создание резервной копии
    local backup_file=$(create_backup)
    
    # Прошивка устройства
    flash_device "$firmware_file"
    
    # Проверка результата
    verify_flash
    
    print_header "Прошивка завершена успешно!"
    print_status "Резервная копия сохранена в: $backup_file"
    print_warning "В случае проблем используйте: sudo dd if=$backup_file of=/dev/mtd1 bs=1M"
}

# Запуск основной функции
main "$@"
