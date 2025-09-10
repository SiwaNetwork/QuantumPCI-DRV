#!/bin/bash

# Тест статусов GNSS и SMA для Quantum-PCI TimeCard

# Пути sysfs
TIMECARD_SYSFS="/sys/class/timecard/ocp0"
BUS=1
ADDR=0x37

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# LED индексы
LED_GNSS_SYNC=0      # Power LED
LED_HOLDOVER=1        # Sync LED  
LED_SMA3=2           # GNSS LED
LED_SMA4=3           # Alarm LED
LED_CLOCK_SOURCE=4   # Status1 LED
LED_SYSTEM=5         # Status2 LED

# Цветовые коды
COLOR_OFF=0x00
COLOR_GREEN=0xFF
COLOR_RED=0xFF
COLOR_PURPLE=0x80
COLOR_YELLOW=0xC0

echo -e "${CYAN}=== Тест статусов GNSS и SMA ===${NC}"
echo "Quantum-PCI TimeCard: $TIMECARD_SYSFS"
echo "I2C Bus: $BUS, Address: $ADDR"
echo

# Проверка Quantum-PCI TimeCard
if [ ! -d "$TIMECARD_SYSFS" ]; then
    echo -e "${RED}❌ Quantum-PCI TimeCard не найден${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Quantum-PCI TimeCard найден${NC}"
fi

# Проверка IS32FL3207
if ! sudo i2cdetect -y $BUS | grep -q "37"; then
    echo -e "${RED}❌ IS32FL3207 не найден${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IS32FL3207 найден${NC}"

# Инициализация LED контроллера
echo -e "${BLUE}🔧 Инициализация LED контроллера...${NC}"
sudo i2cset -y $BUS $ADDR 0x00 0x01
sudo i2cset -y $BUS $ADDR 0x6E 0xFF

# Настройка scaling регистров
for i in {0..17}; do
    reg=$((0x4A + i))
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done

sudo i2cset -y $BUS $ADDR 0x49 0x00
echo -e "${GREEN}✅ Инициализация завершена${NC}"

# Функция установки LED
set_led() {
    local led=$1
    local brightness=$2
    local pwm_reg=$((0x01 + led))
    sudo i2cset -y $BUS $ADDR $pwm_reg $brightness
    sudo i2cset -y $BUS $ADDR 0x49 0x00
}

# Функция чтения статуса
read_status() {
    local path="$TIMECARD_SYSFS/$1"
    if [ -f "$path" ]; then
        cat "$path" 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

# Функция определения цвета статуса
get_status_color() {
    local status=$1
    local type=$2
    
    case $status in
        "SYNC")
            echo $COLOR_GREEN
            ;;
        "LOST")
            echo $COLOR_RED
            ;;
        "MAC"|"IRIG-B"|"external")
            if [ "$type" = "holdover" ]; then
                echo $COLOR_PURPLE
            else
                echo $COLOR_GREEN
            fi
            ;;
        *)
            echo $COLOR_YELLOW
            ;;
    esac
}

# Функция определения достоверности SMA
is_sma_reliable() {
    local sma_value=$1
    if [[ "$sma_value" == *"PHC"* ]] || [[ "$sma_value" == *"10Mhz"* ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Основной цикл тестирования
echo -e "${CYAN}🎯 Начинаем тестирование статусов...${NC}"
echo "Нажмите Ctrl+C для остановки"
echo

while true; do
    timestamp=$(date '+%H:%M:%S')
    echo -e "${BLUE}[$timestamp] === Статус GNSS/SMA ===${NC}"
    
    # Чтение статусов
    gnss_sync=$(read_status "gnss_sync")
    clock_source=$(read_status "clock_source")
    sma3_status=$(read_status "sma3")
    sma4_status=$(read_status "sma4")
    
    # Определение режима работы
    if [ "$gnss_sync" = "SYNC" ]; then
        mode="sync"
        gnss_color=$COLOR_GREEN
    elif [ "$gnss_sync" = "LOST" ]; then
        mode="lost"
        gnss_color=$COLOR_RED
    elif [ "$clock_source" = "MAC" ] || [ "$clock_source" = "IRIG-B" ] || [ "$clock_source" = "external" ]; then
        mode="holdover"
        gnss_color=$COLOR_PURPLE
    else
        mode="unknown"
        gnss_color=$COLOR_YELLOW
    fi
    
    # Определение цвета источника часов
    if [ "$clock_source" = "GNSS" ]; then
        clock_color=$COLOR_GREEN
    elif [ "$clock_source" = "MAC" ] || [ "$clock_source" = "IRIG-B" ]; then
        clock_color=$COLOR_PURPLE
    else
        clock_color=$COLOR_YELLOW
    fi
    
    # Определение статуса SMA
    if is_sma_reliable "$sma3_status"; then
        sma3_color=$COLOR_GREEN
        sma3_icon="🟢"
    else
        sma3_color=$COLOR_RED
        sma3_icon="🔴"
    fi
    
    if is_sma_reliable "$sma4_status"; then
        sma4_color=$COLOR_GREEN
        sma4_icon="🟢"
    else
        sma4_color=$COLOR_RED
        sma4_icon="🔴"
    fi
    
    # Определение общего статуса системы
    if [ "$mode" = "lost" ]; then
        system_color=$COLOR_RED
    elif [ "$mode" = "holdover" ]; then
        system_color=$COLOR_PURPLE
    elif ! is_sma_reliable "$sma3_status" || ! is_sma_reliable "$sma4_status"; then
        system_color=$COLOR_YELLOW
    else
        system_color=$COLOR_GREEN
    fi
    
    # Обновление LED
    set_led $LED_GNSS_SYNC $gnss_color
    set_led $LED_CLOCK_SOURCE $clock_color
    set_led $LED_SMA3 $sma3_color
    set_led $LED_SMA4 $sma4_color
    set_led $LED_SYSTEM $system_color
    
    # Holdover LED
    if [ "$mode" = "holdover" ]; then
        set_led $LED_HOLDOVER $COLOR_PURPLE
    else
        set_led $LED_HOLDOVER $COLOR_OFF
    fi
    
    # Вывод статуса
    echo -e "GNSS Sync: ${gnss_sync} (${mode})"
    echo -e "Clock Source: ${clock_source}"
    echo -e "SMA Status:"
    echo -e "  SMA3: ${sma3_icon} ${sma3_status}"
    echo -e "  SMA4: ${sma4_icon} ${sma4_status}"
    echo
    
    sleep 5
done

# Обработка Ctrl+C
trap cleanup EXIT

cleanup() {
    echo -e "\n${YELLOW}🛑 Остановка тестирования...${NC}"
    echo -e "${BLUE}🔚 Выключение всех LED...${NC}"
    
    # Выключим все LED
    for i in {0..17}; do
        pwm_reg=$((0x01 + i))
        sudo i2cset -y $BUS $ADDR $pwm_reg 0x00
    done
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    
    echo -e "${GREEN}✅ Все LED выключены${NC}"
    echo -e "${CYAN}🎉 Тестирование завершено${NC}"
    exit 0
} 