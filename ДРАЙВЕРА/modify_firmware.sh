#!/bin/bash

# Скрипт для модификации готовой прошивки
# Добавляет магический заголовок к существующей прошивке

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

# Функция для создания заголовка прошивки
create_firmware_header() {
    local magic=$1
    local vendor_id=$2
    local device_id=$3
    local image_size=$4
    local hw_revision=$5
    
    print_header "Создание заголовка прошивки"
    echo "Магический заголовок: $magic"
    echo "Vendor ID: 0x$vendor_id"
    echo "Device ID: 0x$device_id"
    echo "Размер образа: $image_size байт"
    echo "Ревизия оборудования: 0x$hw_revision"
    echo
    
    # Создаем временный файл для заголовка
    local header_file=$(mktemp)
    
    # Записываем магический заголовок (4 байта)
    echo -n "$magic" > "$header_file"
    
    # Добавляем Vendor ID (2 байта, little-endian)
    printf "\x${vendor_id:2:2}\x${vendor_id:0:2}" >> "$header_file"
    
    # Добавляем Device ID (2 байта, little-endian)
    printf "\x${device_id:2:2}\x${device_id:0:2}" >> "$header_file"
    
    # Добавляем размер образа (4 байта, little-endian)
    local size_hex=$(printf "%08x" $image_size)
    printf "\x${size_hex:6:2}\x${size_hex:4:2}\x${size_hex:2:2}\x${size_hex:0:2}" >> "$header_file"
    
    # Добавляем ревизию оборудования (2 байта, little-endian)
    printf "\x${hw_revision:2:2}\x${hw_revision:0:2}" >> "$header_file"
    
    # Добавляем CRC (2 байта, пока 0)
    printf "\x00\x00" >> "$header_file"
    
    echo "$header_file"
}

# Функция для вычисления CRC16 (упрощенная версия)
calculate_crc16() {
    local file=$1
    local offset=$2
    local size=$3
    
    # Для простоты используем фиксированный CRC
    # В реальной реализации здесь должен быть правильный алгоритм CRC16
    echo "0000"
}

# Функция для модификации прошивки
modify_firmware() {
    local input_file=$1
    local output_file=$2
    local magic=$3
    local vendor_id=$4
    local device_id=$5
    local hw_revision=$6
    
    print_header "Модификация прошивки"
    
    # Проверяем, что входной файл существует
    if [ ! -f "$input_file" ]; then
        print_error "Входной файл $input_file не найден"
        exit 1
    fi
    
    # Получаем размер исходной прошивки
    local original_size=$(stat -c%s "$input_file")
    print_status "Размер исходной прошивки: $original_size байт"
    
    # Создаем заголовок
    local header_file=$(create_firmware_header "$magic" "$vendor_id" "$device_id" "$original_size" "$hw_revision")
    
    # Вычисляем CRC для данных прошивки
    print_status "Вычисление CRC..."
    local crc=$(calculate_crc16 "$input_file" 0 "$original_size")
    print_status "CRC: 0x$crc"
    
    # Обновляем CRC в заголовке (позиция 14-15)
    local crc_file=$(mktemp)
    dd if="$header_file" bs=1 count=14 2>/dev/null > "$crc_file"
    printf "\x${crc:2:2}\x${crc:0:2}" >> "$crc_file"
    
    # Создаем итоговую прошивку: заголовок + данные
    cat "$crc_file" "$input_file" > "$output_file"
    
    # Очищаем временные файлы
    rm -f "$header_file" "$crc_file"
    
    local final_size=$(stat -c%s "$output_file")
    print_status "Размер модифицированной прошивки: $final_size байт"
    print_status "Прошивка сохранена в: $output_file"
    
    # Показываем заголовок итоговой прошивки
    print_header "Заголовок итоговой прошивки"
    dd if="$output_file" bs=1 count=16 2>/dev/null | hexdump -C
}

# Функция для извлечения прошивки с устройства
extract_firmware() {
    local output_file=$1
    
    print_header "Извлечение прошивки с устройства"
    
    if [ ! -e "/dev/mtd0" ]; then
        print_error "MTD устройство /dev/mtd0 не найдено"
        exit 1
    fi
    
    # Читаем прошивку с устройства
    dd if=/dev/mtd0 of="$output_file" 2>/dev/null
    
    local size=$(stat -c%s "$output_file")
    print_status "Извлечено $size байт прошивки"
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
        modprobe -r ptp_ocp 2>/dev/null || print_warning "Не удалось выгрузить драйвер"
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

# Функция для показа справки
show_help() {
    echo "Использование: $0 [команда] [опции]"
    echo
    echo "Команды:"
    echo "  extract <файл>                    - Извлечь прошивку с устройства"
    echo "  quantum <входной_файл> [выходной] - Создать прошивку Quantum Platforms (SHIW)"
    echo "  meta <входной_файл> [выходной]    - Создать прошивку других систем (OCPC)"
    echo "  flash <файл> <тип>                - Прошить устройство"
    echo "  help                              - Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0 extract firmware_original.bin"
    echo "  $0 quantum firmware_original.bin firmware_quantum.bin"
    echo "  $0 meta firmware_original.bin firmware_meta.bin"
    echo "  $0 flash firmware_quantum.bin \"Quantum Platforms\""
    echo
    echo "Параметры по умолчанию:"
    echo "  Vendor ID: 0x1d9b"
    echo "  Device ID: 0x0400"
    echo "  HW Revision: 0x0001"
}

# Основная логика
main() {
    check_root
    
    case "${1:-help}" in
        "extract")
            if [ -z "$2" ]; then
                print_error "Укажите имя файла для сохранения прошивки"
                exit 1
            fi
            extract_firmware "$2"
            ;;
        "quantum")
            if [ -z "$2" ]; then
                print_error "Укажите входной файл прошивки"
                exit 1
            fi
            local output_file="${3:-quantum_firmware.bin}"
            modify_firmware "$2" "$output_file" "SHIW" "1d9b" "0400" "0001"
            ;;
        "meta")
            if [ -z "$2" ]; then
                print_error "Укажите входной файл прошивки"
                exit 1
            fi
            local output_file="${3:-meta_firmware.bin}"
            modify_firmware "$2" "$output_file" "OCPC" "1d9b" "0400" "0001"
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
