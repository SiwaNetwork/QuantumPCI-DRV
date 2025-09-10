#!/bin/bash

# Финальная демонстрация LED для TimeCard
# Автор: AI Assistant

TIMECARD_SYSFS="/sys/class/timecard/ocp0"
BUS=3
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
    echo -e "${RED}❌ IS32FL3207 не найден на шине $BUS${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IS32FL3207: 0x37 на шине $BUS${NC}"

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

# Демонстрация 2: Бегущий огонек
echo -e "${BLUE}🎯 Демо 2: Бегущий огонек${NC}"
for cycle in {1..3}; do
    for i in {0..17}; do
        turn_off_all
        turn_on_led $i
        sleep 0.1
    done
    for i in {16..1}; do
        turn_off_all
        turn_on_led $i
        sleep 0.1
    done
done

# Демонстрация 3: Пульсация
echo -e "${BLUE}🎯 Демо 3: Пульсация всех LED${NC}"
for brightness in 0x10 0x30 0x50 0x70 0x90 0xB0 0xD0 0xFF 0xD0 0xB0 0x90 0x70 0x50 0x30 0x10 0x00; do
    for i in {0..17}; do
        turn_on_led $i $brightness
    done
    sleep 0.2
done

# Демонстрация 4: Случайные паттерны
echo -e "${BLUE}🎯 Демо 4: Случайные паттерны${NC}"
for pattern in {1..5}; do
    turn_off_all
    for i in {0..17}; do
        if [ $((RANDOM % 2)) -eq 1 ]; then
            turn_on_led $i
        fi
    done
    sleep 0.5
done

# Демонстрация 5: Волна
echo -e "${BLUE}🎯 Демо 5: Волна${NC}"
for wave in {1..3}; do
    for i in {0..17}; do
        turn_off_all
        # Включаем несколько LED в виде волны
        for j in {0..5}; do
            pos=$(( (i + j) % 18 ))
            turn_on_led $pos
        done
        sleep 0.2
    done
done

# Демонстрация 6: Мигание
echo -e "${BLUE}🎯 Демо 6: Мигание${NC}"
for blink in {1..10}; do
    turn_off_all
    sleep 0.3
    for i in {0..17}; do
        turn_on_led $i
    done
    sleep 0.3
done

echo -e "${GREEN}✅ Демонстрация завершена${NC}"
cleanup 