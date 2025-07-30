#!/bin/bash

# Диагностика проблемы с LED
# Автор: AI Assistant

BUS=1
ADDR=0x37

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Диагностика проблемы с LED ===${NC}"
echo "I2C Bus: $BUS, Address: $ADDR"
echo

# Проверка I2C устройства
echo -e "${BLUE}1. Проверка I2C устройства...${NC}"
if sudo i2cdetect -y $BUS | grep -q "37"; then
    echo -e "${GREEN}✅ IS32FL3207 найден${NC}"
else
    echo -e "${RED}❌ IS32FL3207 не найден${NC}"
    exit 1
fi

# Проверка текущего состояния контроллера
echo -e "${BLUE}2. Проверка состояния контроллера...${NC}"
echo "Control register (0x00):"
sudo i2cget -y $BUS $ADDR 0x00
echo "Global current register (0x6E):"
sudo i2cget -y $BUS $ADDR 0x6E
echo

# Инициализация контроллера
echo -e "${BLUE}3. Инициализация контроллера...${NC}"
echo "Включение контроллера..."
sudo i2cset -y $BUS $ADDR 0x00 0x01
echo "Установка глобального тока..."
sudo i2cset -y $BUS $ADDR 0x6E 0xFF

# Настройка scaling регистров
echo "Настройка scaling регистров..."
for i in {0..17}; do
    reg=$((0x4A + i))
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done

echo "Обновление контроллера..."
sudo i2cset -y $BUS $ADDR 0x49 0x00
echo -e "${GREEN}✅ Инициализация завершена${NC}"
echo

# Проверка состояния после инициализации
echo -e "${BLUE}4. Проверка состояния после инициализации...${NC}"
echo "Control register (0x00):"
sudo i2cget -y $BUS $ADDR 0x00
echo "Global current register (0x6E):"
sudo i2cget -y $BUS $ADDR 0x6E
echo

# Тест отдельных LED
echo -e "${BLUE}5. Тест отдельных LED...${NC}"

# Тест LED 1 (Power LED)
echo "Тест LED 1 (Power LED) - зеленый..."
sudo i2cset -y $BUS $ADDR 0x01 0xFF
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 2

echo "Тест LED 2 (Sync LED) - сиреневый..."
sudo i2cset -y $BUS $ADDR 0x02 0x80
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 2

echo "Тест LED 3 (GNSS LED) - красный..."
sudo i2cset -y $BUS $ADDR 0x03 0xFF
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 2

echo "Тест LED 4 (Alarm LED) - желтый..."
sudo i2cset -y $BUS $ADDR 0x04 0xC0
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 2

echo "Тест LED 5 (Status1 LED) - зеленый..."
sudo i2cset -y $BUS $ADDR 0x05 0xFF
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 2

echo "Тест LED 6 (Status2 LED) - зеленый..."
sudo i2cset -y $BUS $ADDR 0x06 0xFF
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 2

# Проверка состояния всех LED
echo -e "${BLUE}6. Проверка состояния всех LED...${NC}"
for i in {1..18}; do
    reg=$((0x01 + i - 1))
    value=$(sudo i2cget -y $BUS $ADDR $reg)
    echo -n "LED $i: $value "
    if [ "$value" != "0x00" ]; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
done
echo

# Выключение всех LED
echo -e "${BLUE}7. Выключение всех LED...${NC}"
for i in {1..18}; do
    reg=$((0x01 + i - 1))
    sudo i2cset -y $BUS $ADDR $reg 0x00
done
sudo i2cset -y $BUS $ADDR 0x49 0x00
echo -e "${GREEN}✅ Все LED выключены${NC}"

echo -e "${CYAN}=== Диагностика завершена ===${NC}" 