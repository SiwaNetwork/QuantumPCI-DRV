#!/bin/bash

# Демонстрационный скрипт для BMP280
# Показывает различные возможности драйвера

echo "=== Демонстрация работы с датчиком BMP280 ==="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка наличия драйвера
if [ ! -f "./bmp280_driver.sh" ]; then
    echo -e "${RED}Ошибка: Драйвер bmp280_driver.sh не найден${NC}"
    exit 1
fi

# Функция для красивого вывода
print_section() {
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Демонстрация 1: Проверка системы
print_section "Проверка системы"
print_info "Проверка наличия i2c-tools..."
if command -v i2cdetect >/dev/null 2>&1; then
    print_success "i2c-tools установлены"
else
    echo -e "${RED}✗ i2c-tools не установлены${NC}"
    echo "Установите: sudo apt-get install i2c-tools"
    exit 1
fi

print_info "Проверка I2C шины..."
if i2cdetect -y 1 >/dev/null 2>&1; then
    print_success "I2C шина 1 доступна"
else
    echo -e "${RED}✗ I2C шина 1 недоступна${NC}"
    exit 1
fi

echo ""

# Демонстрация 2: Настройка мультиплексора и сканирование I2C устройств
print_section "Настройка мультиплексора I2C"
print_info "Включение мультиплексора I2C (адрес 0x70)..."
if i2cset -y 1 0x70 0x0F 2>/dev/null; then
    print_success "Мультиплексор I2C настроен (все шины активированы)"
else
    print_info "Мультиплексор I2C не найден или недоступен"
    print_info "Это нормально, если мультиплексор не используется"
fi

print_section "Сканирование I2C устройств"
echo "Устройства на I2C шине 1:"
i2cdetect -y 1
echo ""

# Демонстрация 3: Инициализация датчика
print_section "Инициализация датчика"
if ./bmp280_driver.sh init; then
    print_success "Датчик инициализирован"
else
    echo -e "${RED}✗ Ошибка инициализации датчика${NC}"
    echo "Проверьте подключение датчика BMP280"
    exit 1
fi
echo ""

# Демонстрация 4: Чтение температуры
print_section "Чтение температуры"
./bmp280_driver.sh temp
echo ""

# Демонстрация 5: Чтение давления
print_section "Чтение давления"
./bmp280_driver.sh press
echo ""

# Демонстрация 6: Чтение всех параметров
print_section "Чтение всех параметров"
./bmp280_driver.sh all
echo ""

# Демонстрация 7: Кратковременный мониторинг
print_section "Демонстрация мониторинга (3 измерения)"
print_info "Запуск мониторинга на 15 секунд..."
for i in {1..3}; do
    echo "Измерение $i:"
    ./bmp280_driver.sh all
    if [ $i -lt 3 ]; then
        echo "Ожидание 5 секунд..."
        sleep 5
    fi
done
echo ""

# Демонстрация 8: Информация о системе
print_section "Информация о системе"
print_info "Версия ядра:"
uname -r
print_info "I2C модули:"
lsmod | grep i2c || echo "Модули i2c не загружены"
print_info "Права доступа к I2C:"
ls -la /dev/i2c* 2>/dev/null || echo "Устройства I2C не найдены"
echo ""

# Демонстрация 9: Примеры использования
print_section "Примеры использования"
echo "Доступные команды:"
echo "  ./bmp280_driver.sh help     - Показать справку"
echo "  ./bmp280_driver.sh init     - Инициализация"
echo "  ./bmp280_driver.sh temp     - Только температура"
echo "  ./bmp280_driver.sh press    - Только давление"
echo "  ./bmp280_driver.sh all      - Все параметры"
echo "  ./bmp280_driver.sh monitor  - Непрерывный мониторинг"
echo ""
echo "Примеры с sudo (если нужны права):"
echo "  sudo ./bmp280_driver.sh all"
echo "  sudo ./bmp280_driver.sh monitor 10"
echo ""

# Демонстрация 10: Завершение
print_section "Завершение демонстрации"
print_success "Демонстрация завершена успешно!"
print_info "Для получения справки выполните: ./bmp280_driver.sh help"
print_info "Для запуска тестов выполните: ./test_bmp280.sh"
print_info "Для мониторинга выполните: ./bmp280_driver.sh monitor"
echo ""
echo -e "${GREEN}=== Демонстрация завершена ===${NC}" 