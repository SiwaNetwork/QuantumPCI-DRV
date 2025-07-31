#!/bin/bash

# Скрипт для настройки мультиплексора I2C
# Активирует все шины мультиплексора для доступа к датчикам

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
I2CBUS=1
MUX_ADDR=0x70
MUX_VALUE=0x0F

echo -e "${BLUE}=== Настройка мультиплексора I2C ===${NC}"
echo ""

# Проверка наличия i2c-tools
if ! command -v i2cset >/dev/null 2>&1; then
    echo -e "${RED}Ошибка: i2c-tools не установлены${NC}"
    echo "Установите: sudo apt-get install i2c-tools"
    exit 1
fi

# Проверка доступности I2C шины
echo -e "${YELLOW}Проверка I2C шины $I2CBUS...${NC}"
if ! i2cdetect -y $I2CBUS >/dev/null 2>&1; then
    echo -e "${RED}Ошибка: I2C шина $I2CBUS недоступна${NC}"
    exit 1
fi

echo -e "${GREEN}✓ I2C шина $I2CBUS доступна${NC}"
echo ""

# Сканирование до настройки мультиплексора
echo -e "${YELLOW}Сканирование I2C устройств ДО настройки мультиплексора:${NC}"
i2cdetect -y $I2CBUS
echo ""

# Настройка мультиплексора
echo -e "${YELLOW}Настройка мультиплексора I2C (адрес $MUX_ADDR)...${NC}"
if i2cset -y $I2CBUS $MUX_ADDR $MUX_VALUE 2>/dev/null; then
    echo -e "${GREEN}✓ Мультиплексор I2C настроен успешно${NC}"
    echo "   Активированы все шины мультиплексора"
else
    echo -e "${YELLOW}ℹ Мультиплексор I2C не найден по адресу $MUX_ADDR${NC}"
    echo "   Это нормально, если мультиплексор не используется"
fi
echo ""

# Сканирование после настройки мультиплексора
echo -e "${YELLOW}Сканирование I2C устройств ПОСЛЕ настройки мультиплексора:${NC}"
i2cdetect -y $I2CBUS
echo ""

# Проверка наличия датчика BMP280
BMP280_ADDR=0x76
echo -e "${YELLOW}Проверка наличия датчика BMP280 (адрес $BMP280_ADDR)...${NC}"
if i2cdetect -y $I2CBUS | grep -q $(echo $BMP280_ADDR | sed 's/0x//'); then
    echo -e "${GREEN}✓ Датчик BMP280 найден${NC}"
else
    echo -e "${YELLOW}ℹ Датчик BMP280 не найден${NC}"
    echo "   Возможные причины:"
    echo "   - Датчик не подключен"
    echo "   - Датчик подключен к другой шине мультиплексора"
    echo "   - Неправильный адрес датчика"
fi
echo ""

# Информация о мультиплексоре
echo -e "${BLUE}Информация о мультиплексоре I2C:${NC}"
echo "   Адрес мультиплексора: $MUX_ADDR"
echo "   Значение активации: $MUX_VALUE (все шины)"
echo "   I2C шина: $I2CBUS"
echo ""
echo "   Команда для ручной настройки:"
echo "   sudo i2cset -y $I2CBUS $MUX_ADDR $MUX_VALUE"
echo ""

echo -e "${GREEN}=== Настройка мультиплексора завершена ===${NC}" 