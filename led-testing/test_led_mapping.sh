#!/bin/bash

# Тест альтернативной схемы нумерации LED

BUS=1
ADDR=0x37

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Тест альтернативной схемы нумерации LED ===${NC}"

# Инициализация
echo -e "${BLUE}Инициализация контроллера...${NC}"
sudo i2cset -y $BUS $ADDR 0x00 0x01
sudo i2cset -y $BUS $ADDR 0x6E 0xFF

# Настройка scaling регистров
for i in {0..17}; do
    reg=$((0x4A + i))
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done

sudo i2cset -y $BUS $ADDR 0x49 0x00
echo -e "${GREEN}✅ Инициализация завершена${NC}"
echo

# Выключение всех LED
echo "Выключение всех LED..."
for i in {1..18}; do
    pwm_reg=$((0x01 + i - 1))
    sudo i2cset -y $BUS $ADDR $pwm_reg 0x00
done
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 1

# Тест всех возможных регистров PWM
echo -e "${BLUE}Тест всех возможных регистров PWM:${NC}"
for reg in {0x01..0x12}; do
    echo -e "${YELLOW}--- Тест регистра 0x$(printf "%02x" $reg) ---${NC}"
    
    # Включение LED
    echo "Включение LED..."
    sudo i2cset -y $BUS $ADDR $reg 0xFF
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    sleep 2
    
    # Проверка значения
    value=$(sudo i2cget -y $BUS $ADDR $reg)
    echo "Прочитано: $value"
    
    # Выключение LED
    echo "Выключение LED..."
    sudo i2cset -y $BUS $ADDR $reg 0x00
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    sleep 1
    
    echo
done

# Тест альтернативной схемы нумерации (возможно LED 2,4,6 используют другие регистры)
echo -e "${BLUE}Тест альтернативной схемы нумерации:${NC}"
echo "Возможно LED 2,4,6 используют регистры 0x07,0x09,0x0B или другие..."

# Тест регистров 0x07, 0x09, 0x0B (альтернативные для LED 2,4,6)
for reg in 0x07 0x09 0x0B; do
    echo -e "${YELLOW}--- Тест регистра 0x$(printf "%02x" $reg) ---${NC}"
    
    # Включение LED
    echo "Включение LED..."
    sudo i2cset -y $BUS $ADDR $reg 0xFF
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    sleep 2
    
    # Проверка значения
    value=$(sudo i2cget -y $BUS $ADDR $reg)
    echo "Прочитано: $value"
    
    # Выключение LED
    echo "Выключение LED..."
    sudo i2cset -y $BUS $ADDR $reg 0x00
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    sleep 1
    
    echo
done

# Тест регистров 0x0D, 0x0F, 0x11 (еще альтернативные)
for reg in 0x0D 0x0F 0x11; do
    echo -e "${YELLOW}--- Тест регистра 0x$(printf "%02x" $reg) ---${NC}"
    
    # Включение LED
    echo "Включение LED..."
    sudo i2cset -y $BUS $ADDR $reg 0xFF
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    sleep 2
    
    # Проверка значения
    value=$(sudo i2cget -y $BUS $ADDR $reg)
    echo "Прочитано: $value"
    
    # Выключение LED
    echo "Выключение LED..."
    sudo i2cset -y $BUS $ADDR $reg 0x00
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    sleep 1
    
    echo
done

# Финальная проверка
echo -e "${BLUE}Финальная проверка всех LED:${NC}"
for i in {1..18}; do
    pwm_reg=$((0x01 + i - 1))
    value=$(sudo i2cget -y $BUS $ADDR $pwm_reg)
    echo -n "LED $i: $value "
    if [ "$value" = "0x00" ]; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
done

echo -e "${CYAN}=== Тест завершен ===${NC}" 