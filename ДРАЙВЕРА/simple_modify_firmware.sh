#!/bin/bash

# Упрощенный скрипт для модификации прошивки

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

# Функция для создания прошивки Quantum Platforms
create_quantum_firmware() {
    local input_file=$1
    local output_file=$2
    
    print_header "Создание прошивки Quantum Platforms (SHIW)"
    
    if [ ! -f "$input_file" ]; then
        print_error "Входной файл $input_file не найден"
        exit 1
    fi
    
    local size=$(stat -c%s "$input_file")
    print_status "Размер исходной прошивки: $size байт"
    
    # Создаем заголовок SHIW
    echo -n "SHIW" > "$output_file"
    
    # Vendor ID 0x1d9b (little-endian)
    printf "\x9b\x1d" >> "$output_file"
    
    # Device ID 0x0400 (little-endian)
    printf "\x00\x04" >> "$output_file"
    
    # Размер образа (little-endian)
    printf "\x00\x00\x00\x02" >> "$output_file"  # 32MB = 0x2000000
    
    # Ревизия оборудования (little-endian)
    printf "\x01\x00" >> "$output_file"
    
    # CRC (пока 0)
    printf "\x00\x00" >> "$output_file"
    
    # Добавляем данные прошивки
    cat "$input_file" >> "$output_file"
    
    local final_size=$(stat -c%s "$output_file")
    print_status "Размер итоговой прошивки: $final_size байт"
    
    # Показываем заголовок
    print_header "Заголовок прошивки Quantum Platforms"
    dd if="$output_file" bs=1 count=16 2>/dev/null | hexdump -C
}

# Функция для создания прошивки Meta Platforms
create_meta_firmware() {
    local input_file=$1
    local output_file=$2
    
    print_header "Создание прошивки Meta Platforms (OCPC)"
    
    if [ ! -f "$input_file" ]; then
        print_error "Входной файл $input_file не найден"
        exit 1
    fi
    
    local size=$(stat -c%s "$input_file")
    print_status "Размер исходной прошивки: $size байт"
    
    # Создаем заголовок OCPC
    echo -n "OCPC" > "$output_file"
    
    # Vendor ID 0x1d9b (little-endian)
    printf "\x9b\x1d" >> "$output_file"
    
    # Device ID 0x0400 (little-endian)
    printf "\x00\x04" >> "$output_file"
    
    # Размер образа (little-endian)
    printf "\x00\x00\x00\x02" >> "$output_file"  # 32MB = 0x2000000
    
    # Ревизия оборудования (little-endian)
    printf "\x01\x00" >> "$output_file"
    
    # CRC (пока 0)
    printf "\x00\x00" >> "$output_file"
    
    # Добавляем данные прошивки
    cat "$input_file" >> "$output_file"
    
    local final_size=$(stat -c%s "$output_file")
    print_status "Размер итоговой прошивки: $final_size байт"
    
    # Показываем заголовок
    print_header "Заголовок прошивки Meta Platforms"
    dd if="$output_file" bs=1 count=16 2>/dev/null | hexdump -C
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

# Функция для показа справки
show_help() {
    echo "Использование: $0 [команда] [опции]"
    echo
    echo "Команды:"
    echo "  quantum <входной_файл> [выходной] - Создать прошивку Quantum Platforms (SHIW)"
    echo "  meta <входной_файл> [выходной]    - Создать прошивку Meta Platforms (OCPC)"
    echo "  flash <файл> <тип>                - Прошить устройство"
    echo "  help                              - Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0 quantum firmware_original.bin firmware_quantum.bin"
    echo "  $0 meta firmware_original.bin firmware_meta.bin"
    echo "  $0 flash firmware_quantum.bin \"Quantum Platforms\""
}

# Основная логика
main() {
    check_root
    
    case "${1:-help}" in
        "quantum")
            if [ -z "$2" ]; then
                print_error "Укажите входной файл прошивки"
                exit 1
            fi
            local output_file="${3:-firmware_quantum.bin}"
            create_quantum_firmware "$2" "$output_file"
            ;;
        "meta")
            if [ -z "$2" ]; then
                print_error "Укажите входной файл прошивки"
                exit 1
            fi
            local output_file="${3:-firmware_meta.bin}"
            create_meta_firmware "$2" "$output_file"
            ;;
        "flash")
            if [ -z "$2" ] || [ -z "$3" ]; then
                print_error "Укажите файл прошивки и тип"
                exit 1
            fi
            flash_device "$2" "$3"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Запуск основной функции
main "$@"
