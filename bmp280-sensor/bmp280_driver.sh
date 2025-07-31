#!/bin/bash

# BMP280 I2C Driver Script
# Поддержка чтения температуры и давления с датчика BMP280

export LC_NUMERIC=C

# Конфигурация I2C
I2CBUS=1
DEVADDR=0x76

# Регистры датчика BMP280
TEMP_XLSB=0xFC
TEMP_LSB=0xFB
TEMP_MSB=0xFA
PRESS_XLSB=0xF9
PRESS_LSB=0xF8
PRESS_MSB=0xF7
CONFIG=0xF5
CTRL_MEAS=0xF4

# Адреса калибровочных коэффициентов температуры
DIG_T1_ADDR=0x88
DIG_T2_ADDR=0x8A
DIG_T3_ADDR=0x8C

# Адреса калибровочных коэффициентов давления
DIG_P1_ADDR=0x8E
DIG_P2_ADDR=0x90
DIG_P3_ADDR=0x92
DIG_P4_ADDR=0x94
DIG_P5_ADDR=0x96
DIG_P6_ADDR=0x98
DIG_P7_ADDR=0x9A
DIG_P8_ADDR=0x9C
DIG_P9_ADDR=0x9E

# Функция инициализации датчика
initialize_bmp280() {
    echo "Инициализация датчика BMP280..."
    
    # Включение мультиплексора I2C для активации всех шин
    echo "Настройка мультиплексора I2C..."
    if i2cset -y $I2CBUS 0x70 0x0F 2>/dev/null; then
        echo "✓ Мультиплексор I2C настроен"
    else
        echo "ℹ Мультиплексор I2C не найден (это нормально)"
    fi
    
    # Проверка доступности I2C шины
    if ! i2cdetect -y $I2CBUS | grep -q $(echo $DEVADDR | sed 's/0x//'); then
        echo "Ошибка: Датчик BMP280 не найден на шине I2C $I2CBUS"
        return 1
    fi
    
    # Настройка конфигурации датчика
    i2cset -y $I2CBUS $DEVADDR $CONFIG 0xFF
    i2cset -y $I2CBUS $DEVADDR $CTRL_MEAS 0xFF
    
    echo "Датчик BMP280 инициализирован успешно"
    return 0
}

# Функция чтения слова из I2C
readWord() {
    echo $(($(i2cget -y $I2CBUS $DEVADDR $(($1+0)) w)))
}

# Функция чтения температуры
temperature() {
    echo "Чтение температуры..."
    
    # Чтение сырых данных температуры
    local adc_T_msb=$(($(i2cget -y $I2CBUS $DEVADDR $TEMP_MSB)))
    local adc_T_lsb=$(($(i2cget -y $I2CBUS $DEVADDR $TEMP_LSB)))
    local adc_T_xlsb=$(($(i2cget -y $I2CBUS $DEVADDR $TEMP_XLSB)))
    
    # Чтение калибровочных коэффициентов температуры
    local dig_T1=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_T1_ADDR w)))
    local dig_T2=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_T2_ADDR w)))
    if [ "$dig_T2" -gt "32767" ]; then
        dig_T2=$(("$dig_T2-65536"))
    fi
    local dig_T3=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_T3_ADDR w)))
    if [ "$dig_T3" -gt "32767" ]; then
        dig_T3=$(("$dig_T3-65536"))
    fi
    
    # Вычисление температуры согласно даташиту BMP280
    local adc_T=$(($(($(($(($adc_T_msb<<16))|$(($adc_T_lsb<<8))))|$adc_T_xlsb))>>4))
    local var1=$(($(($(($(($(($adc_T>>3))-$(($dig_T1<<1))))*$dig_T2))))>>11))
    local var2=$(($(($(($(($(($(($adc_T>>4))-$(($dig_T1))))*$(($(($adc_T >> 4))-$(($dig_T1)))))) >>12))*$(($dig_T3))))>>14))
    local t_fine=$(($var1+$var2))
    local Temp_val=$(($(($(($t_fine*5))+128))>>8))
    
    printf "Температура = %.2f °C\n" $(echo $Temp_val / 100 | bc -l)
}

# Функция чтения давления
pressure() {
    echo "Чтение давления..."
    
    # Чтение сырых данных температуры (необходимо для компенсации)
    local adc_T_msb=$(($(i2cget -y $I2CBUS $DEVADDR $TEMP_MSB)))
    local adc_T_lsb=$(($(i2cget -y $I2CBUS $DEVADDR $TEMP_LSB)))
    local adc_T_xlsb=$(($(i2cget -y $I2CBUS $DEVADDR $TEMP_XLSB)))
    local dig_T1=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_T1_ADDR w)))
    local dig_T2=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_T2_ADDR w)))
    if [ "$dig_T2" -gt "32767" ]; then
        dig_T2=$(("$dig_T2-65536"))
    fi
    local dig_T3=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_T3_ADDR w)))
    if [ "$dig_T3" -gt "32767" ]; then
        dig_T3=$(("$dig_T3-65536"))
    fi
    
    # Вычисление t_fine для компенсации давления
    local adc_T=$(($(($(($adc_T_msb<<16))|$(($adc_T_lsb<<8))|$adc_T_xlsb))>>4))
    local var1=$(($(($(($(($(($adc_T>>3))-$(($dig_T1<<1))))*$dig_T2))))>>11))
    local var2=$(($(($(($(($(($(($adc_T>>4))-$(($dig_T1))))*$(($(($adc_T >> 4))-$(($dig_T1)))))) >>12))*$(($dig_T3))))>>14))
    local t_fine=$(($var1+$var2))
    
    # Чтение сырых данных давления
    local adc_P_msb=$(($(i2cget -y $I2CBUS $DEVADDR $PRESS_MSB)))
    local adc_P_lsb=$(($(i2cget -y $I2CBUS $DEVADDR $PRESS_LSB)))
    local adc_P_xlsb=$(($(i2cget -y $I2CBUS $DEVADDR $PRESS_XLSB)))
    
    # Чтение калибровочных коэффициентов давления
    local dig_P1=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P1_ADDR w)))
    local dig_P2=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P2_ADDR w)))
    if [ "$dig_P2" -gt "32767" ]; then
        dig_P2=$(("$dig_P2-65536"))
    fi
    local dig_P3=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P3_ADDR w)))
    if [ "$dig_P3" -gt "32767" ]; then
        dig_P3=$(("$dig_P3-65536"))
    fi
    local dig_P4=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P4_ADDR w)))
    if [ "$dig_P4" -gt "32767" ]; then
        dig_P4=$(("$dig_P4-65536"))
    fi
    local dig_P5=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P5_ADDR w)))
    if [ "$dig_P5" -gt "32767" ]; then
        dig_P5=$(("$dig_P5-65536"))
    fi
    local dig_P6=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P6_ADDR w)))
    if [ "$dig_P6" -gt "32767" ]; then
        dig_P6=$(("$dig_P6-65536"))
    fi
    local dig_P7=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P7_ADDR w)))
    if [ "$dig_P7" -gt "32767" ]; then
        dig_P7=$(("$dig_P7-65536"))
    fi
    local dig_P8=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P8_ADDR w)))
    if [ "$dig_P8" -gt "32767" ]; then
        dig_P8=$(("$dig_P8-65536"))
    fi
    local dig_P9=$(($(i2cget -y $I2CBUS $DEVADDR $DIG_P9_ADDR w)))
    if [ "$dig_P9" -gt "32767" ]; then
        dig_P9=$(("$dig_P9-65536"))
    fi
    
    # Вычисление давления согласно даташиту BMP280
    local adc_P=$(($(($(($adc_P_msb<<16))|$(($adc_P_lsb<<8))|$adc_P_xlsb))>>4))
    local var1=$(($t_fine - 128000))
    local var2=$(($var1*$var1*$dig_P6))
    local var2=$(($var2+$(($(($var1*$dig_P5))<<17))))
    local var2=$(($var2+$(($(($dig_P4))<<35))))
    local var1=$(($(($(($var1*$var1*$dig_P3))>>8))+$(($(($var1*$dig_P2))<<12))))
    local var1=$(($(($(($((1<<47))+$var1))))*$(($dig_P1))>>33))
    local p=$((1048576 - $adc_P))
    local p=$(($(($(($(($p<<31))-$var2))*3125))/$var1))
    local var1=$(($(($(($dig_P9))*$(($p>>13))*$(($p>>13))))>>25))
    local var2=$(($(($dig_P8*$p))>>19))
    local p=$(($(($(($p+$var1+$var2))>>8))+$(($(($dig_P7))<<4))))
    
    printf "Давление = %.3f Па\n" $(echo $p / 256 | bc -l)
}

# Функция чтения всех параметров
read_all() {
    echo "=== Показания датчика BMP280 ==="
    temperature
    pressure
    echo "================================"
}

# Функция непрерывного мониторинга
monitor() {
    local interval=${1:-5}
    echo "Запуск мониторинга с интервалом ${interval} секунд..."
    echo "Нажмите Ctrl+C для остановки"
    
    while true; do
        read_all
        sleep $interval
    done
}

# Функция помощи
show_help() {
    echo "Использование: $0 [команда]"
    echo ""
    echo "Команды:"
    echo "  init     - Инициализация датчика"
    echo "  temp     - Чтение температуры"
    echo "  press    - Чтение давления"
    echo "  all      - Чтение всех параметров"
    echo "  monitor [интервал] - Непрерывный мониторинг (по умолчанию 5 сек)"
    echo "  help     - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 init"
    echo "  $0 all"
    echo "  $0 monitor 10"
}

# Основная логика скрипта
main() {
    case "${1:-help}" in
        init)
            initialize_bmp280
            ;;
        temp)
            initialize_bmp280 && temperature
            ;;
        press)
            initialize_bmp280 && pressure
            ;;
        all)
            initialize_bmp280 && read_all
            ;;
        monitor)
            initialize_bmp280 && monitor $2
            ;;
        help|*)
            show_help
            ;;
    esac
}

# Запуск основной функции
main "$@" 