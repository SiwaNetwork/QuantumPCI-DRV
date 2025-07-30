#!/bin/bash

# Финальная демонстрация LED для TimeCard
# Автор: AI Assistant

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

# Функция очистки при выходе
cleanup() {
    echo -e "\n${YELLOW}🛑 Получен сигнал остановки...${NC}"
    echo -e "${BLUE}🔚 Выключение всех LED...${NC}"
    
    # Выключим все LED
    for reg in "${pwm_regs[@]}"; do
        sudo i2cset -y $BUS $ADDR $reg 0x00
    done
    sudo i2cset -y $BUS $ADDR 0x49 0x00
    
    echo -e "${GREEN}✅ Все LED выключены${NC}"
    echo -e "${CYAN}🎉 Демонстрация завершена${NC}"
    exit 0
}

# Установка обработчика сигналов
trap cleanup SIGINT SIGTERM

echo -e "${CYAN}🎯 ФИНАЛЬНАЯ ДЕМОНСТРАЦИЯ LED TIMECARD 🎯${NC}"
echo -e "${BLUE}===============================================${NC}"

# Проверка TimeCard
if [ ! -d "$TIMECARD_SYSFS" ]; then
    echo -e "${RED}❌ TimeCard не найден${NC}"
    exit 1
fi

SERIAL=$(cat $TIMECARD_SYSFS/serialnum)
echo -e "${GREEN}✅ TimeCard: $SERIAL${NC}"

# Проверка IS32FL3207
if ! sudo i2cdetect -y $BUS | grep -q "37"; then
    echo -e "${RED}❌ IS32FL3207 не найден${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IS32FL3207: 0x37${NC}"

# Инициализация
echo -e "${BLUE}🔧 Инициализация LED контроллера...${NC}"
sudo i2cset -y $BUS $ADDR 0x00 0x01  # Включение
sudo i2cset -y $BUS $ADDR 0x6E 0xFF  # Global Current

# Scaling для всех каналов
for reg in {74..91}; do
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done

echo -e "${GREEN}✅ Инициализация завершена${NC}"

# Массивы регистров
pwm_regs=(0x01 0x03 0x05 0x07 0x09 0x0B 0x0D 0x0F 0x11 0x13 0x15 0x17 0x19 0x1B 0x1D 0x1F 0x21 0x23)

# Функции
turn_off_all() {
    for reg in "${pwm_regs[@]}"; do
        sudo i2cset -y $BUS $ADDR $reg 0x00
    done
    sudo i2cset -y $BUS $ADDR 0x49 0x00
}

turn_on_led() {
    local led=$1
    local brightness=${2:-0xFF}
    local reg=${pwm_regs[$led]}
    sudo i2cset -y $BUS $ADDR $reg $brightness
    sudo i2cset -y $BUS $ADDR 0x49 0x00
}

echo -e "${PURPLE}🎭 Начинаем демонстрацию...${NC}"
echo -e "${YELLOW}   Нажмите Ctrl+C для остановки${NC}"
echo ""

# Демонстрация 1: Последовательное включение
echo -e "${BLUE}🎯 Демо 1: Последовательное включение LED${NC}"
for i in {0..17}; do
    turn_off_all
    turn_on_led $i
    echo -e "   ${GREEN}LED $((i + 1)) включен${NC}"
    sleep 0.3
done

# Демонстрация 2: Градиент яркости
echo -e "${BLUE}🎯 Демо 2: Градиент яркости${NC}"
for brightness in 0x10 0x20 0x30 0x40 0x50 0x60 0x70 0x80 0x90 0xA0 0xB0 0xC0 0xD0 0xE0 0xF0 0xFF; do
    turn_off_all
    turn_on_led 0 $brightness
    echo -e "   ${CYAN}LED 1: 0x$(printf "%02X" $brightness)${NC}"
    sleep 0.2
done

# Демонстрация 3: Бегущий огонь
echo -e "${BLUE}🎯 Демо 3: Бегущий огонь${NC}"
for cycle in {1..3}; do
    echo -e "   ${YELLOW}Цикл $cycle${NC}"
    for i in {0..17}; do
        turn_off_all
        turn_on_led $i
        sleep 0.1
    done
    for i in {16..1}; do
        turn_off_all
        turn_on_led $((i-1))
        sleep 0.1
    done
done

# Демонстрация 4: Группы LED
echo -e "${BLUE}🎯 Демо 4: Группы LED${NC}"

# Группа 1: Power, Sync, GNSS, Alarm
turn_off_all
for led in 0 1 2 3; do
    turn_on_led $led 0xFF
done
echo -e "   ${GREEN}Группа 1: Power, Sync, GNSS, Alarm${NC}"
sleep 2

# Группа 2: Status LEDs
turn_off_all
for led in 4 5 6 7; do
    turn_on_led $led 0x80
done
echo -e "   ${CYAN}Группа 2: Status LEDs${NC}"
sleep 2

# Группа 3: Debug LEDs
turn_off_all
for led in 8 9 10 11; do
    turn_on_led $led 0x60
done
echo -e "   ${YELLOW}Группа 3: Debug LEDs${NC}"
sleep 2

# Группа 4: Info LEDs
turn_off_all
for led in 12 13 14 15; do
    turn_on_led $led 0x40
done
echo -e "   ${PURPLE}Группа 4: Info LEDs${NC}"
sleep 2

# Группа 5: Test LEDs
turn_off_all
for led in 16 17; do
    turn_on_led $led 0x20
done
echo -e "   ${RED}Группа 5: Test LEDs${NC}"
sleep 2

# Демонстрация 5: Мигание
echo -e "${BLUE}🎯 Демо 5: Мигание${NC}"
for blink in {1..5}; do
    echo -e "   ${GREEN}Мигание $blink${NC}"
    turn_off_all
    sleep 0.5
    for i in {0..17}; do
        turn_on_led $i
    done
    sleep 0.5
done

# Демонстрация 6: Паттерны
echo -e "${BLUE}🎯 Демо 6: Паттерны${NC}"

# Паттерн 1: Шахматная доска
echo -e "   ${CYAN}Паттерн 1: Шахматная доска${NC}"
turn_off_all
for i in {0..17}; do
    if (( i % 2 == 0 )); then
        turn_on_led $i 0xFF
    fi
done
sleep 2

# Паттерн 2: Змейка
echo -e "   ${YELLOW}Паттерн 2: Змейка${NC}"
turn_off_all
for i in {0..8}; do
    turn_on_led $i 0xFF
    turn_on_led $((17-i)) 0xFF
    sleep 0.3
done
sleep 1

# Паттерн 3: Спираль
echo -e "   ${PURPLE}Паттерн 3: Спираль${NC}"
turn_off_all
for i in 0 4 8 12 16 17 13 9 5 1 2 6 10 14 15 11 7 3; do
    turn_on_led $i 0xFF
    sleep 0.2
done
sleep 2

# Финальная демонстрация: Все LED
echo -e "${BLUE}🎯 Финальная демонстрация: Все LED${NC}"
turn_off_all
for i in {0..17}; do
    turn_on_led $i
    echo -e "   ${GREEN}LED $((i + 1)) включен${NC}"
done

echo -e "${CYAN}🎉 Демонстрация завершена!${NC}"
echo -e "${YELLOW}   Все 18 LED включены${NC}"
echo -e "${BLUE}   Нажмите Ctrl+C для выключения${NC}"

# Ожидание пользователя
while true; do
    sleep 1
done 