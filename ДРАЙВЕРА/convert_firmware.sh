#!/bin/bash

# Универсальный скрипт для конвертации любого .bin файла прошивки
# Добавляет нужный заголовок к существующему .bin файлу

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

# Функция для создания прошивки с заголовком
create_firmware_with_header() {
    local input_file=$1
    local output_file=$2
    local magic=$3
    local vendor_id=$4
    local device_id=$5
    
    print_header "Конвертация прошивки"
    
    # Проверяем входной файл
    if [ ! -f "$input_file" ]; then
        print_error "Входной файл $input_file не найден"
        exit 1
    fi
    
    # Получаем размер исходной прошивки
    local size=$(stat -c%s "$input_file")
    print_status "Размер исходной прошивки: $size байт"
    
    # Конвертируем размер в hex (little-endian)
    local size_hex=$(printf "%08x" $size)
    local size_bytes=$(printf "\x${size_hex:6:2}\x${size_hex:4:2}\x${size_hex:2:2}\x${size_hex:0:2}")
    
    # Создаем заголовок
    echo -n "$magic" > "$output_file"
    printf "\x${vendor_id:2:2}\x${vendor_id:0:2}" >> "$output_file"  # Vendor ID
    printf "\x${device_id:2:2}\x${device_id:0:2}" >> "$output_file"  # Device ID
    echo -n "$size_bytes" >> "$output_file"  # Размер образа
    printf "\x01\x00" >> "$output_file"  # Ревизия оборудования
    printf "\x00\x00" >> "$output_file"  # CRC (пока 0)
    
    # Добавляем данные прошивки
    cat "$input_file" >> "$output_file"
    
    local final_size=$(stat -c%s "$output_file")
    print_status "Размер итоговой прошивки: $final_size байт"
    print_status "Прошивка сохранена в: $output_file"
    
    # Показываем заголовок
    print_header "Заголовок прошивки"
    dd if="$output_file" bs=1 count=16 2>/dev/null | hexdump -C
}

# Функция для прошивки устройства
flash_device() {
    local firmware_file=$1
    local firmware_type=$2
    
    print_header "Прошивка устройства"
    
    # Копируем прошивку в /lib/firmware/
    cp "$firmware_file" /lib/firmware/
    
    # Прошиваем устройство
    if devlink dev flash pci/0000:01:00.0 file "$firmware_file"; then
        print_status "✅ Устройство успешно прошито прошивкой $firmware_type"
        
        # Показываем текущее состояние
        echo
        print_header "Текущее состояние устройства"
        lspci | grep "01:00.0"
        echo
        print_status "Тип прошивки: $firmware_type"
        
    else
        print_error "❌ Ошибка при прошивке устройства"
        exit 1
    fi
}

# Функция для показа справки
show_help() {
    echo "Использование: $0 [команда] [опции]"
    echo
    echo "Команды:"
    echo "  quantum <входной.bin> [выходной.bin] - Создать прошивку Quantum Platforms (SHIW)"
    echo "  meta <входной.bin> [выходной.bin]    - Создать прошивку Meta Platforms (OCPC)"
    echo "  flash <файл.bin> <тип>               - Прошить устройство"
    echo "  help                                 - Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0 quantum my_firmware.bin"
    echo "  $0 quantum my_firmware.bin quantum_firmware.bin"
    echo "  $0 meta my_firmware.bin meta_firmware.bin"
    echo "  $0 flash quantum_firmware.bin \"Quantum Platforms\""
    echo
    echo "Параметры по умолчанию:"
    echo "  Vendor ID: 0x1d9b"
    echo "  Device ID: 0x0400"
    echo "  HW Revision: 0x0001"
    echo
    echo "Структура заголовка:"
    echo "  [4 байта] Магический заголовок (SHIW/OCPC)"
    echo "  [2 байта] Vendor ID (little-endian)"
    echo "  [2 байта] Device ID (little-endian)"
    echo "  [4 байта] Размер образа (little-endian)"
    echo "  [2 байта] Ревизия оборудования (little-endian)"
    echo "  [2 байта] CRC (пока 0)"
    echo "  [N байт]  Данные прошивки"
}

# Основная логика
main() {
    check_root
    
    case "${1:-help}" in
        "quantum")
            if [ -z "$2" ]; then
                print_error "Укажите входной .bin файл"
                exit 1
            fi
            local input_file="$2"
            local output_file="${3:-${input_file%.*}_quantum.bin}"
            create_firmware_with_header "$input_file" "$output_file" "SHIW" "1d9b" "0400"
            ;;
        "meta")
            if [ -z "$2" ]; then
                print_error "Укажите входной .bin файл"
                exit 1
            fi
            local input_file="$2"
            local output_file="${3:-${input_file%.*}_meta.bin}"
            create_firmware_with_header "$input_file" "$output_file" "OCPC" "1d9b" "0400"
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
