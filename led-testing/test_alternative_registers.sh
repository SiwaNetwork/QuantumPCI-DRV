#!/bin/bash

# Тест альтернативных регистров и конфигурации

BUS=1
ADDR=0x37

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Тест альтернативных регистров ===${NC}"

# Проверка всех регистров контроллера
echo -e "${BLUE}1. Проверка всех регистров контроллера:${NC}"
for reg in {0x00..0x6F}; do
    value=$(sudo i2cget -y $BUS $ADDR $reg 2>/dev/null || echo "ERROR")
    echo "Регистр 0x$(printf "%02x" $reg): $value"
done
echo

# Проверка регистров состояния
echo -e "${BLUE}2. Проверка регистров состояния:${NC}"
echo "Control register (0x00):"
sudo i2cget -y $BUS $ADDR 0x00
echo "Global current register (0x6E):"
sudo i2cget -y $BUS $ADDR 0x6E
echo "Update register (0x49):"
sudo i2cget -y $BUS $ADDR 0x49
echo

# Проверка scaling регистров для проблемных LED
echo -e "${BLUE}3. Проверка scaling регистров для LED 2,4,6:${NC}"
for led in 2 4 6; do
    scaling_reg=$((0x4A + led - 1))
    echo "Scaling регистр для LED $led (0x$(printf "%02x" $scaling_reg)):"
    sudo i2cget -y $BUS $ADDR $scaling_reg
done
echo

# Попытка альтернативной инициализации
echo -e "${BLUE}4. Альтернативная инициализация:${NC}"
echo "Сброс контроллера..."
sudo i2cset -y $BUS $ADDR 0x00 0x00
sleep 1
sudo i2cset -y $BUS $ADDR 0x00 0x01
echo "Установка максимального тока..."
sudo i2cset -y $BUS $ADDR 0x6E 0xFF

# Установка scaling регистров в максимальное значение
echo "Установка scaling регистров в максимум..."
for i in {0..17}; do
    reg=$((0x4A + i))
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done

# Обновление контроллера
sudo i2cset -y $BUS $ADDR 0x49 0x00
echo -e "${GREEN}✅ Альтернативная инициализация завершена${NC}"
echo

# Тест проблемных LED с разными подходами
echo -e "${BLUE}5. Тест проблемных LED с разными подходами:${NC}"
for led in 2 4 6; do
    echo -e "${YELLOW}--- Тест LED $led ---${NC}"
    pwm_reg=$((0x01 + led - 1))
    
    # Подход 1: Прямая установка
    echo "Подход 1: Прямая установка..."
    sudo i2cset -y $BUS $ADDR $pwm_reg 0xFF
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    value1=$(sudo i2cget -y $BUS $ADDR $pwm_reg)
    echo "  Результат: $value1"
    
    # Подход 2: С задержкой
    echo "Подход 2: С задержкой..."
    sudo i2cset -y $BUS $ADDR $pwm_reg 0x80
    sleep 0.1
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    sleep 0.1
    value2=$(sudo i2cget -y $BUS $ADDR $pwm_reg)
    echo "  Результат: $value2"
    
    # Подход 3: Постепенное увеличение
    echo "Подход 3: Постепенное увеличение..."
    for brightness in 0x20 0x40 0x60 0x80 0xA0 0xC0 0xE0 0xFF; do
        sudo i2cset -y $BUS $ADDR $pwm_reg $brightness
        sudo i2cset -y $BUS $ADDR 0x49 0x00
        sleep 0.05
    done
    value3=$(sudo i2cget -y $BUS $ADDR $pwm_reg)
    echo "  Финальный результат: $value3"
    
    # Выключение
    sudo i2cset -y $BUS $ADDR $pwm_reg 0x00
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    echo
done

# Проверка альтернативных адресов регистров
echo -e "${BLUE}6. Проверка альтернативных адресов регистров:${NC}"
echo "Проверка регистров 0x07-0x12 (альтернативные PWM регистры)..."
for reg in {0x07..0x12}; do
    value=$(sudo i2cget -y $BUS $ADDR $reg 2>/dev/null || echo "ERROR")
    echo "Регистр 0x$(printf "%02x" $reg): $value"
done
echo

# Финальная проверка
echo -e "${BLUE}7. Финальная проверка всех LED:${NC}"
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