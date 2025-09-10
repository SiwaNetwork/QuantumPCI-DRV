#!/bin/bash

# Детальный тест регистров LED

BUS=1
ADDR=0x37

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Детальный тест регистров LED ===${NC}"

# Функция для установки LED с проверкой
set_led_with_check() {
    local led=$1
    local brightness=$2
    local pwm_reg=$((0x01 + led - 1))
    
    echo -e "${BLUE}Установка LED $led в $brightness (регистр 0x$(printf "%02x" $pwm_reg))${NC}"
    
    # Установка значения
    sudo i2cset -y $BUS $ADDR $pwm_reg $brightness
    
    # Обновление контроллера
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    
    # Проверка установленного значения
    local read_value=$(sudo i2cget -y $BUS $ADDR $pwm_reg)
    echo -n "  Прочитано: $read_value "
    
    if [ "$read_value" = "$brightness" ]; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌ (ожидалось $brightness)${NC}"
    fi
    
    sleep 1
}

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

# Тест каждого LED по отдельности
echo -e "${BLUE}Тест каждого LED по отдельности:${NC}"

# Выключение всех LED сначала
echo "Выключение всех LED..."
for i in {1..18}; do
    pwm_reg=$((0x01 + i - 1))
    sudo i2cset -y $BUS $ADDR $pwm_reg 0x00
done
sudo i2cset -y $BUS $ADDR 0x49 0x00
sleep 1

# Тест LED 1-6 (основные LED)
for led in 1 2 3 4 5 6; do
    echo -e "${YELLOW}--- Тест LED $led ---${NC}"
    
    # Включение LED
    set_led_with_check $led 0xFF
    
    # Проверка что другие LED не затронуты
    echo "  Проверка других LED..."
    for other in 1 2 3 4 5 6; do
        if [ $other -ne $led ]; then
            pwm_reg=$((0x01 + other - 1))
            value=$(sudo i2cget -y $BUS $ADDR $pwm_reg)
            if [ "$value" = "0x00" ]; then
                echo -n "    LED $other: $value ✅"
            else
                echo -n "    LED $other: $value ❌"
            fi
            echo
        fi
    done
    
    # Выключение LED
    set_led_with_check $led 0x00
    echo
done

# Тест с разными уровнями яркости
echo -e "${BLUE}Тест с разными уровнями яркости:${NC}"
for led in 1 2 3 4 5 6; do
    echo -e "${YELLOW}--- LED $led с разной яркостью ---${NC}"
    
    for brightness in 0x20 0x40 0x60 0x80 0xA0 0xC0 0xE0 0xFF; do
        set_led_with_check $led $brightness
    done
    
    # Выключение
    set_led_with_check $led 0x00
    echo
done

# Финальная проверка всех LED
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