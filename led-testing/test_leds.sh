#!/bin/bash

# Улучшенный скрипт тестирования LED с интеграцией в драйвер TimeCard
# Дата: $(date)

TIMECARD_SYSFS="/sys/class/timecard/ocp0"
BUS=1
ADDR=0x37

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Тестирование LED через TimeCard драйвер ===${NC}"

# Проверка доступности TimeCard
if [ ! -d "$TIMECARD_SYSFS" ]; then
    echo -e "${RED}❌ TimeCard не найден в $TIMECARD_SYSFS${NC}"
    exit 1
fi

echo -e "${GREEN}✅ TimeCard найден: $(cat $TIMECARD_SYSFS/serialnum)${NC}"

# Проверка I2C шины
echo -e "${BLUE}🔍 Проверка I2C шины...${NC}"
if ! sudo i2cdetect -y $BUS | grep -q "37"; then
    echo -e "${RED}❌ IS32FL3207 не найден на I2C шине $BUS${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IS32FL3207 обнаружен на адресе 0x37${NC}"

# Проверка текущего состояния Control Register
echo -e "${BLUE}🔧 Проверка состояния IS32FL3207...${NC}"
current_ctrl=$(sudo i2cget -y $BUS $ADDR 0x00)
echo -e "   Текущее значение Control Register (0x00): 0x$(printf "%02x" $current_ctrl)"

# Если SSD=0, включим чип
if (( (current_ctrl & 0x01) == 0 )); then
    new_ctrl=$(( (current_ctrl & 0xFE) | 0x01 ))
    echo -e "${YELLOW}   Включение чипа (установка SSD=1)...${NC}"
    sudo i2cset -y $BUS $ADDR 0x00 $new_ctrl
    echo -e "   Новое значение Control Register: 0x$(printf "%02x" $(sudo i2cget -y $BUS $ADDR 0x00))"
else
    echo -e "${GREEN}   Чип уже включен (SSD=1)${NC}"
fi

# Инициализация общих параметров
echo -e "${BLUE}🔧 Инициализация общих параметров...${NC}"
# Установим максимальный Global Current
sudo i2cset -y $BUS $ADDR 0x6E 0xFF
echo -e "   Global Current Control установлен"

# Установим максимальные Scaling регистры для всех каналов
echo -e "   Установка Scaling регистров для всех каналов..."
for reg in {74..91}; do
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done
echo -e "${GREEN}   Все Scaling регистры установлены${NC}"

# Массивы регистров для каждого канала
declare -a pwm_regs=(0x01 0x03 0x05 0x07 0x09 0x0B 0x0D 0x0F 0x11 0x13 0x15 0x17 0x19 0x1B 0x1D 0x1F 0x21 0x23)
declare -a scale_regs=(0x4A 0x4B 0x4C 0x4D 0x4E 0x4F 0x50 0x51 0x52 0x53 0x54 0x55 0x56 0x57 0x58 0x59 0x5A 0x5B)

# Функция для выключения всех LED
turn_off_all_leds() {
    echo -e "${YELLOW}   Выключение всех LED...${NC}"
    for pwm_reg in "${pwm_regs[@]}"; do
        sudo i2cset -y $BUS $ADDR $pwm_reg 0x00
    done
    sudo i2cset -y $BUS $ADDR 0x49 0x00
}

# Функция для включения конкретного LED
turn_on_led() {
    local channel=$1
    local brightness=${2:-0xFF}
    local real_channel=$((channel + 1))
    
    echo -e "${GREEN}   Включение LED $real_channel (яркость: 0x$(printf "%02X" $brightness))${NC}"
    sudo i2cset -y $BUS $ADDR ${pwm_regs[$channel]} $brightness
    sudo i2cset -y $BUS $ADDR 0x49 0x00
}

# Функция для чтения статуса LED
read_led_status() {
    local channel=$1
    local real_channel=$((channel + 1))
    local brightness=$(sudo i2cget -y $BUS $ADDR ${pwm_regs[$channel]})
    echo -e "   LED $real_channel: 0x$(printf "%02X" $brightness)"
}

echo -e "${BLUE}🎯 Начинаем тестирование LED...${NC}"
echo -e "${YELLOW}   Нажмите Ctrl+C для остановки${NC}"

# Основной цикл тестирования
while true; do
    echo -e "${BLUE}--- Цикл тестирования ---${NC}"
    
    # Последовательная проверка каждого LED
    for channel in {0..17}; do
        real_channel=$((channel + 1))
        
        # Выключим все LED
        turn_off_all_leds
        
        # Включим текущий LED на полную яркость
        turn_on_led $channel 0xFF
        
        # Подождем для наблюдения
        sleep 1
    done
    
    echo -e "${BLUE}--- Тест с разной яркостью ---${NC}"
    
    # Тест с разной яркостью для LED 1
    for brightness in 0x20 0x40 0x60 0x80 0xA0 0xC0 0xE0 0xFF; do
        turn_off_all_leds
        turn_on_led 0 $brightness
        sleep 0.5
    done
    
    echo -e "${BLUE}--- Тест группы LED ---${NC}"
    
    # Включим группу LED (1, 5, 9, 13, 17)
    turn_off_all_leds
    for led in 0 4 8 12 16; do
        turn_on_led $led 0x80
    done
    sleep 2
    
    # Включим другую группу (2, 6, 10, 14, 18)
    turn_off_all_leds
    for led in 1 5 9 13 17; do
        turn_on_led $led 0x80
    done
    sleep 2
    
    echo -e "${BLUE}--- Проверка статуса всех LED ---${NC}"
    
    # Чтение статуса всех LED
    for channel in {0..17}; do
        read_led_status $channel
    done
    
    echo -e "${GREEN}✅ Цикл тестирования завершен${NC}"
    echo -e "${YELLOW}   Нажмите Ctrl+C для остановки или подождите 3 секунды...${NC}"
    sleep 3
done 

echo -e "${YELLOW}🛑 Остановка тестирования...${NC}"
echo -e "${BLUE}🔚 Выключение всех LED...${NC}"

# Выключим все LED
for reg in "${pwm_regs[@]}"; do
    sudo i2cset -y $BUS $ADDR $reg 0x00
done
sudo i2cset -y $BUS $ADDR 0x49 0x00

echo -e "${GREEN}✅ Все LED выключены${NC}"
echo -e "${CYAN}🎉 Тестирование завершено${NC}" 