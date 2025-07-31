#!/bin/bash

# Простой тест LED для демонстрации
# Автор: AI Assistant

BUS=1
ADDR=0x37

echo "=== Простой тест LED ==="
echo "TimeCard: $(cat /sys/class/timecard/ocp0/serialnum)"
echo "I2C шина: $BUS"
echo "IS32FL3207 адрес: $ADDR"
echo ""

# Проверка IS32FL3207
echo "🔍 Проверка IS32FL3207..."
if sudo i2cdetect -y $BUS | grep -q "37"; then
    echo "✅ IS32FL3207 найден"
else
    echo "❌ IS32FL3207 не найден"
    exit 1
fi

# Инициализация
echo "🔧 Инициализация..."
sudo i2cset -y $BUS $ADDR 0x00 0x01  # Включение
sudo i2cset -y $BUS $ADDR 0x6E 0xFF  # Global Current

# Установка Scaling для всех каналов
for reg in {74..91}; do
    sudo i2cset -y $BUS $ADDR $reg 0xFF
done

echo "✅ Инициализация завершена"
echo ""

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
    echo "   LED $((led + 1)): 0x$(printf "%02X" $brightness)"
    sudo i2cset -y $BUS $ADDR $reg $brightness
    sudo i2cset -y $BUS $ADDR 0x49 0x00
}

# Тест 1: Последовательное включение
echo "🎯 Тест 1: Последовательное включение LED"
for i in {0..17}; do
    turn_off_all
    turn_on_led $i
    sleep 0.5
done

# Тест 2: Разная яркость
echo ""
echo "🎯 Тест 2: Разная яркость LED 1"
for brightness in 0x20 0x40 0x60 0x80 0xA0 0xC0 0xE0 0xFF; do
    turn_off_all
    turn_on_led 0 $brightness
    sleep 0.3
done

# Тест 3: Группы LED
echo ""
echo "🎯 Тест 3: Группы LED"
turn_off_all
for led in 0 4 8 12 16; do
    turn_on_led $led 0x80
done
echo "   Включены LED: 1, 5, 9, 13, 17"
sleep 2

turn_off_all
for led in 1 5 9 13 17; do
    turn_on_led $led 0x80
done
echo "   Включены LED: 2, 6, 10, 14, 18"
sleep 2

# Тест 4: Чтение статуса
echo ""
echo "🎯 Тест 4: Статус всех LED"
for i in {0..17}; do
    brightness=$(sudo i2cget -y $BUS $ADDR ${pwm_regs[$i]})
    echo "   LED $((i + 1)): 0x$(printf "%02X" $brightness)"
done

# Выключение всех
echo ""
echo "🔚 Выключение всех LED"
# Выключим все LED
for reg in "${pwm_regs[@]}"; do
    sudo i2cset -y $BUS $ADDR $reg 0x00
done
sudo i2cset -y $BUS $ADDR 0x49 0x00

echo "✅ Тест завершен"
echo "✅ Все LED выключены" 