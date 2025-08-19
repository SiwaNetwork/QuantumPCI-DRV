#!/bin/bash

# Скрипт для переключения между типами прошивок
# Quantum Platforms и Meta Platforms (OCP)

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода с цветом
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

# Проверка наличия устройства
check_device() {
    if ! lspci | grep -q "01:00.0"; then
        print_error "Устройство 01:00.0 не найдено"
        exit 1
    fi
}

# Функция для создания прошивки с заголовком SHIW (Quantum Platforms)
create_quantum_firmware() {
    print_header "Создание прошивки Quantum Platforms"
    
    # Создаем тестовую прошивку
    dd if=/dev/zero of=quantum_firmware.bin bs=1M count=1 2>/dev/null
    
    print_warning "Создаем прошивку Quantum Platforms с заголовком SHIW"
    # Создаем заголовок SHIW
    echo -n "SHIW" > quantum_firmware_with_header.bin
    # Добавляем Vendor ID и Device ID (little-endian)
    printf "\x9b\x1d\x00\x04" >> quantum_firmware_with_header.bin
    # Добавляем размер образа (1MB, little-endian)
    printf "\x00\x00\x10\x00" >> quantum_firmware_with_header.bin
    # Добавляем ревизию оборудования (little-endian)
    printf "\x01\x00" >> quantum_firmware_with_header.bin
    # Добавляем CRC (пока 0, little-endian)
    printf "\x00\x00" >> quantum_firmware_with_header.bin
    # Добавляем данные прошивки
    dd if=/dev/zero bs=1M count=1 >> quantum_firmware_with_header.bin 2>/dev/null
    print_status "Прошивка Quantum Platforms создана: quantum_firmware_with_header.bin"
}

# Функция для создания прошивки с заголовком OCPC (Meta Platforms)
create_meta_firmware() {
    print_header "Создание прошивки Meta Platforms (OCP)"
    
    # Создаем тестовую прошивку
    dd if=/dev/zero of=meta_firmware.bin bs=1M count=1 2>/dev/null
    
    # Создаем заголовок OCPC
    echo -n "OCPC" > meta_firmware_with_header.bin
    # Добавляем Vendor ID и Device ID
    printf "\x9b\x1d\x00\x04" >> meta_firmware_with_header.bin
    # Добавляем размер образа (1MB)
    printf "\x00\x00\x10\x00" >> meta_firmware_with_header.bin
    # Добавляем ревизию оборудования
    printf "\x01\x00" >> meta_firmware_with_header.bin
    # Добавляем CRC (пока 0)
    printf "\x00\x00" >> meta_firmware_with_header.bin
    # Добавляем данные прошивки
    dd if=/dev/zero bs=1M count=1 >> meta_firmware_with_header.bin 2>/dev/null
    
    print_status "Прошивка Meta Platforms создана: meta_firmware_with_header.bin"
}

# Функция для прошивки устройства
flash_device() {
    local firmware_file=$1
    local firmware_type=$2
    
    print_header "Прошивка устройства прошивкой $firmware_type"
    
    # Копируем прошивку в /lib/firmware/
    cp "$firmware_file" /lib/firmware/
    
    # Прошиваем устройство
    if devlink dev flash pci/0000:01:00.0 file "$firmware_file"; then
        print_status "Устройство успешно прошито прошивкой $firmware_type"
        
        # Перезагружаем драйвер для применения изменений
        print_status "Перезагрузка драйвера..."
        modprobe -r ptp_ocp
        sleep 2
        modprobe ptp_ocp
        
        # Показываем текущее состояние
        echo
        print_header "Текущее состояние устройства"
        lspci | grep "01:00.0"
        echo
        print_status "Тип прошивки: $firmware_type"
        
    else
        print_error "Ошибка при прошивке устройства"
        exit 1
    fi
}

# Функция для показа текущего состояния
show_status() {
    print_header "Текущее состояние"
    
    echo "Устройство:"
    lspci | grep "01:00.0"
    echo
    
    echo "Статус драйвера:"
    lsmod | grep ptp_ocp || echo "Драйвер не загружен"
    echo
    
    echo "Доступные прошивки:"
    ls -la *.bin 2>/dev/null || echo "Прошивки не найдены"
    echo
    
    echo "Devlink информация:"
    devlink dev info pci/0000:01:00.0 2>/dev/null || echo "Devlink недоступен"
}

# Функция для показа справки
show_help() {
    echo "Использование: $0 [команда]"
    echo
    echo "Команды:"
    echo "  quantum    - Создать и прошить прошивку Quantum Platforms (SHIW)"
    echo "  meta       - Создать и прошить прошивку Meta Platforms (OCPC)"
    echo "  status     - Показать текущее состояние"
    echo "  help       - Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0 quantum    # Переключиться на Quantum Platforms"
    echo "  $0 meta       # Переключиться на Meta Platforms"
    echo "  $0 status     # Показать статус"
}

# Основная логика
main() {
    check_root
    check_device
    
    case "${1:-help}" in
        "quantum")
            create_quantum_firmware
            flash_device "quantum_firmware_with_header.bin" "Quantum Platforms (SHIW)"
            ;;
        "meta")
            create_meta_firmware
            flash_device "meta_firmware_with_header.bin" "Meta Platforms (OCPC)"
            ;;
        "status")
            show_status
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Запуск основной функции
main "$@"
