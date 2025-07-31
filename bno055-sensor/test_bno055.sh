#!/bin/bash

# Тестовый скрипт для датчика BNO055
# Проверяет доступность I2C шины и датчика

echo "=== Тест датчика BNO055 ==="

# Проверка наличия i2c-tools
if ! command -v i2cdetect &> /dev/null; then
    echo "Ошибка: i2c-tools не установлены"
    echo "Установите: sudo apt-get install i2c-tools"
    exit 1
fi

# Проверка доступности I2C шины
I2CBUS=1
echo "Проверка I2C шины $I2CBUS..."

# Включение мультиплексора I2C для активации всех шин
echo "Включение мультиплексора I2C (адрес 0x70)..."
if ! i2cset -y $I2CBUS 0x70 0x0F 2>/dev/null; then
    echo "Предупреждение: Не удалось настроить мультиплексор I2C"
    echo "Это может быть нормально, если мультиплексор не используется"
else
    echo "✓ Мультиплексор I2C настроен (все шины активированы)"
fi

if ! i2cdetect -y $I2CBUS &> /dev/null; then
    echo "Ошибка: I2C шина $I2CBUS недоступна"
    echo "Проверьте права доступа и загружен ли модуль i2c-dev"
    exit 1
fi

echo "I2C шина $I2CBUS доступна"

# Сканирование I2C устройств
echo "Сканирование I2C устройств на шине $I2CBUS:"
i2cdetect -y $I2CBUS

# Проверка наличия датчика BNO055 (проверяем оба возможных адреса)
DEVADDR1=0x28
DEVADDR2=0x29
FOUND_DEVICE=false

if i2cdetect -y $I2CBUS | grep -q $(echo $DEVADDR1 | sed 's/0x//'); then
    echo "Датчик BNO055 найден по адресу $DEVADDR1"
    FOUND_DEVICE=true
elif i2cdetect -y $I2CBUS | grep -q $(echo $DEVADDR2 | sed 's/0x//'); then
    echo "Датчик BNO055 найден по адресу $DEVADDR2"
    FOUND_DEVICE=true
else
    echo "Датчик BNO055 не найден по адресам $DEVADDR1 или $DEVADDR2"
    echo "Проверьте подключение датчика"
    exit 1
fi

# Тест чтения регистров
echo "Тест чтения регистров датчика..."

# Чтение ID датчика (должен быть 0xA0 для BNO055)
CHIP_ID=0x00
chip_id=$(i2cget -y $I2CBUS $DEVADDR1 $CHIP_ID 2>/dev/null || i2cget -y $I2CBUS $DEVADDR2 $CHIP_ID)
echo "ID датчика: $chip_id (ожидается 0xA0)"

if [ "$chip_id" = "0xa0" ]; then
    echo "✓ ID датчика корректный"
else
    echo "✗ Неверный ID датчика"
fi

# Тест инициализации
echo "Тест инициализации датчика..."
if ./bno055_driver.sh init; then
    echo "✓ Инициализация прошла успешно"
else
    echo "✗ Ошибка инициализации"
    exit 1
fi

# Тест чтения данных
echo "Тест чтения данных..."
./bno055_driver.sh all

echo "=== Тест завершен ===" 