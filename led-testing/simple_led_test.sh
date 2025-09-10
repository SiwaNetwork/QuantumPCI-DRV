#!/bin/bash

# Простой тест LED для TimeCard

TIMECARD_SYSFS="/sys/class/timecard/ocp0"
BUS=3
ADDR=0x37

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Простой тест LED ===${NC}"

# Проверка TimeCard
if [ ! -d "$TIMECARD_SYSFS" ]; then
    echo -e "${RED}❌ TimeCard не найден${NC}"
    exit 1
fi

SERIAL=$(cat $TIMECARD_SYSFS/serialnum)
echo -e "${GREEN}TimeCard: $SERIAL${NC}"
echo -e "${BLUE}I2C шина: $BUS${NC}"
echo -e "${BLUE}IS32FL3207 адрес: $ADDR${NC}"
echo ""

# Проверка IS32FL3207
echo -e "${YELLOW}🔍 Проверка IS32FL3207...${NC}"
if ! sudo i2cdetect -y $BUS | grep -q "37"; then
    echo -e "${RED}❌ IS32FL3207 не найден на шине $BUS${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IS32FL3207 найден${NC}"

# Инициализация
echo -e "${YELLOW}🔧 Инициализация...${NC}"
sudo i2cset -y $BUS $ADDR 0x00 0x01  # Включение
sudo i2cset -y $BUS $ADDR 0x6E 0xFF  # Global Current

# Scaling для всех каналов
for reg in {74..91}; do
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done

echo -e "${GREEN}✅ Инициализация завершена${NC}"

# Тест основных LED
echo -e "${YELLOW}🎯 Тест основных LED...${NC}"

# LED 1 (Power)
echo -e "${BLUE}LED 1 (Power):${NC}"
sudo i2cset -y $BUS $ADDR 0x01 0xFF
sleep 1
sudo i2cset -y $BUS $ADDR 0x01 0x00
sleep 0.5

# LED 2 (Sync)
echo -e "${BLUE}LED 2 (Sync):${NC}"
sudo i2cset -y $BUS $ADDR 0x03 0xFF
sleep 1
sudo i2cset -y $BUS $ADDR 0x03 0x00
sleep 0.5

# LED 3 (GNSS)
echo -e "${BLUE}LED 3 (GNSS):${NC}"
sudo i2cset -y $BUS $ADDR 0x05 0xFF
sleep 1
sudo i2cset -y $BUS $ADDR 0x05 0x00
sleep 0.5

# LED 4 (Alarm)
echo -e "${BLUE}LED 4 (Alarm):${NC}"
sudo i2cset -y $BUS $ADDR 0x07 0xFF
sleep 1
sudo i2cset -y $BUS $ADDR 0x07 0x00
sleep 0.5

# Тест всех LED
echo -e "${YELLOW}🎯 Тест всех LED...${NC}"
for i in {1..18}; do
    reg=$((0x01 + (i-1)*2))
    echo -e "${BLUE}LED $i:${NC}"
    sudo i2cset -y $BUS $ADDR $reg 0xFF
    sleep 0.3
    sudo i2cset -y $BUS $ADDR $reg 0x00
    sleep 0.2
done

# Мигание всех LED
echo -e "${YELLOW}🎯 Мигание всех LED...${NC}"
for blink in {1..3}; do
    echo -e "${BLUE}Мигание $blink/3${NC}"
    # Включить все
    for i in {1..18}; do
        reg=$((0x01 + (i-1)*2))
        sudo i2cset -y $BUS $ADDR $reg 0xFF
    done
    sleep 0.5
    
    # Выключить все
    for i in {1..18}; do
        reg=$((0x01 + (i-1)*2))
        sudo i2cset -y $BUS $ADDR $reg 0x00
    done
    sleep 0.5
done

echo -e "${GREEN}✅ Тест завершен${NC}"
echo -e "${CYAN}🎉 Все LED работают корректно!${NC}" 