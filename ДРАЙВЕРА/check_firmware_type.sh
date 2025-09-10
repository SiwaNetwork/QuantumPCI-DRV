#!/bin/bash

# Скрипт для проверки типа прошивки устройства

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

# Функция для чтения заголовка прошивки из MTD
read_firmware_header() {
    local mtd_device="spi0.0"
    local header_size=16  # Размер заголовка ptp_ocp_firmware_header
    
    print_header "Чтение заголовка прошивки из MTD устройства"
    
    # Проверяем, существует ли MTD устройство
    if [ ! -e "/dev/mtd0" ]; then
        print_error "MTD устройство /dev/mtd0 не найдено"
        return 1
    fi
    
    # Читаем заголовок прошивки
    local header=$(dd if=/dev/mtd0 bs=1 count=$header_size 2>/dev/null | hexdump -C)
    
    if [ -z "$header" ]; then
        print_error "Не удалось прочитать заголовок прошивки"
        return 1
    fi
    
    echo "Заголовок прошивки (первые 16 байт):"
    echo "$header"
    echo
    
    # Извлекаем магический заголовок (первые 4 байта)
    local magic=$(dd if=/dev/mtd0 bs=1 count=4 2>/dev/null)
    
    if [ "$magic" = "OCPC" ]; then
        print_status "Обнаружена прошивка других систем (OCP) - магический заголовок: OCPC"
        return 0
    elif [ "$magic" = "SHIW" ]; then
        print_status "Обнаружена прошивка Quantum Platforms - магический заголовок: SHIW"
        return 0
    else
        local magic_hex=$(echo -n "$magic" | hexdump -C)
        print_warning "Неизвестный магический заголовок: $magic_hex"
        return 1
    fi
}

# Функция для проверки через sysfs (если доступно)
check_sysfs_firmware_type() {
    print_header "Проверка через sysfs"
    
    local sysfs_path="/sys/devices/pci0000:00/0000:00:01.0/0000:01:00.0/timecard/ocp0/firmware_type"
    
    if [ -f "$sysfs_path" ]; then
        local firmware_type=$(cat "$sysfs_path")
        print_status "Тип прошивки из sysfs: $firmware_type"
        return 0
    else
        print_warning "Sysfs атрибут firmware_type не найден"
        return 1
    fi
}

# Функция для проверки через devlink
check_devlink_info() {
    print_header "Информация через devlink"
    
    if command -v devlink >/dev/null 2>&1; then
        devlink dev info pci/0000:01:00.0 2>/dev/null || print_warning "Devlink недоступен"
    else
        print_warning "Команда devlink не найдена"
    fi
}

# Функция для показа общей информации
show_general_info() {
    print_header "Общая информация"
    
    echo "Устройство PCI:"
    lspci | grep "01:00.0" || print_error "Устройство 01:00.0 не найдено"
    echo
    
    echo "Статус драйвера:"
    lsmod | grep ptp_ocp || print_warning "Драйвер ptp_ocp не загружен"
    echo
    
    echo "MTD устройства:"
    ls -la /dev/mtd* 2>/dev/null || print_warning "MTD устройства не найдены"
    echo
    
    echo "PTP устройства:"
    ls -la /dev/ptp* 2>/dev/null || print_warning "PTP устройства не найдены"
    echo
}

# Основная функция
main() {
    check_root
    
    show_general_info
    check_devlink_info
    check_sysfs_firmware_type
    read_firmware_header
    
    print_header "Резюме"
    echo "Для переключения между типами прошивок используйте:"
    echo "  sudo ./switch_firmware_type.sh quantum  # Quantum Platforms (SHIW)"
    echo "  sudo ./switch_firmware_type.sh meta     # другие системы (OCPC)"
}

# Запуск основной функции
main "$@"
