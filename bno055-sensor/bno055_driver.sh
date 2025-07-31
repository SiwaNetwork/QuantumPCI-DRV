#!/bin/bash

# BNO055 I2C Driver Script
# 9-DOF IMU Sensor Driver with Fusion Algorithm
# Поддержка чтения ориентации, ускорения, гироскопа и магнетометра

export LC_NUMERIC=C

# Конфигурация I2C
I2CBUS=1
DEVADDR=0x28  # Стандартный адрес BNO055

# Регистры режимов работы
OPR_MODE=0x3D
PWR_MODE=0x3E
SYS_TRIGGER=0x3F

# Регистры данных
EUL_DATA_H=0x1A    # Euler angles (Heading, Roll, Pitch)
QUA_DATA_W=0x20    # Quaternions (W, X, Y, Z)
LIA_DATA_X=0x28    # Linear acceleration
GRV_DATA_X=0x2E    # Gravity vector
ACC_DATA_X=0x08    # Accelerometer
GYR_DATA_X=0x14    # Gyroscope
MAG_DATA_X=0x0E    # Magnetometer
TEMPERATURE=0x34   # Temperature

# Регистры калибровки
ACC_OFFSET_X_LSB=0x55
ACC_OFFSET_X_MSB=0x56
ACC_OFFSET_Y_LSB=0x57
ACC_OFFSET_Y_MSB=0x58
ACC_OFFSET_Z_LSB=0x59
ACC_OFFSET_Z_MSB=0x5A

MAG_OFFSET_X_LSB=0x5B
MAG_OFFSET_X_MSB=0x5C
MAG_OFFSET_Y_LSB=0x5D
MAG_OFFSET_Y_MSB=0x5E
MAG_OFFSET_Z_LSB=0x5F
MAG_OFFSET_Z_MSB=0x60

GYR_OFFSET_X_LSB=0x61
GYR_OFFSET_X_MSB=0x62
GYR_OFFSET_Y_LSB=0x63
GYR_OFFSET_Y_MSB=0x64
GYR_OFFSET_Z_LSB=0x65
GYR_OFFSET_Z_MSB=0x66

# Регистры статуса
CALIB_STAT=0x35
SYS_STATUS=0x39
SYS_ERR=0x3A

# Функция инициализации датчика
initialize_bno055() {
    echo "Инициализация датчика BNO055..."
    
    # Включение мультиплексора I2C для активации всех шин
    echo "Настройка мультиплексора I2C..."
    if i2cset -y $I2CBUS 0x70 0x0F 2>/dev/null; then
        echo "✓ Мультиплексор I2C настроен"
    else
        echo "ℹ Мультиплексор I2C не найден (это нормально)"
    fi
    
    # Проверка доступности I2C шины
    if ! i2cdetect -y $I2CBUS | grep -q $(echo $DEVADDR | sed 's/0x//'); then
        echo "Ошибка: Датчик BNO055 не найден на шине I2C $I2CBUS"
        echo "Проверьте адрес датчика (попробуйте 0x28 или 0x29)"
        return 1
    fi
    
    # Сброс датчика
    echo "Сброс датчика..."
    i2cset -y $I2CBUS $DEVADDR $SYS_TRIGGER 0x20
    
    # Ожидание инициализации
    sleep 1
    
    # Установка режима работы (NDOF - 9-DOF fusion)
    echo "Установка режима NDOF..."
    i2cset -y $I2CBUS $DEVADDR $OPR_MODE 0x0C
    
    # Ожидание стабилизации
    sleep 1
    
    echo "Датчик BNO055 инициализирован успешно"
    return 0
}

# Функция чтения слова из I2C
readWord() {
    echo $(($(i2cget -y $I2CBUS $DEVADDR $(($1+0)) w)))
}

# Функция чтения 3-х знаковых слов
readSigned3() {
    local base_addr=$1
    
    # Чтение X, Y, Z значений
    local tmp1=$(($(i2cget -y $I2CBUS $DEVADDR $(($base_addr+0)) w)))
    if [ "$tmp1" -gt "32767" ]; then
        tmp1=$(("$tmp1-65536"))
    fi
    
    local tmp2=$(($(i2cget -y $I2CBUS $DEVADDR $(($base_addr+2)) w)))
    if [ "$tmp2" -gt "32767" ]; then
        tmp2=$(("$tmp2-65536"))
    fi
    
    local tmp3=$(($(i2cget -y $I2CBUS $DEVADDR $(($base_addr+4)) w)))
    if [ "$tmp3" -gt "32767" ]; then
        tmp3=$(("$tmp3-65536"))
    fi
    
    echo "$tmp1 $tmp2 $tmp3"
}

# Функция чтения кватернионов
readQuaternions() {
    local w=$(($(i2cget -y $I2CBUS $DEVADDR 0x20 w)))
    local x=$(($(i2cget -y $I2CBUS $DEVADDR 0x22 w)))
    local y=$(($(i2cget -y $I2CBUS $DEVADDR 0x24 w)))
    local z=$(($(i2cget -y $I2CBUS $DEVADDR 0x26 w)))
    
    echo "$w $x $y $z"
}

# Функция проверки статуса калибровки
calibration_status() {
    local calib_stat=$(i2cget -y $I2CBUS $DEVADDR $CALIB_STAT)
    
    local sys_calib=$((calib_stat >> 6 & 0x03))
    local gyro_calib=$((calib_stat >> 4 & 0x03))
    local mag_calib=$((calib_stat >> 2 & 0x03))
    local accel_calib=$((calib_stat & 0x03))
    
    echo "Статус калибровки:"
    echo "  Система: $sys_calib/3"
    echo "  Гироскоп: $gyro_calib/3"
    echo "  Магнетометр: $mag_calib/3"
    echo "  Акселерометр: $accel_calib/3"
}

# Функция чтения углов Эйлера
euler_angles() {
    echo "Чтение углов Эйлера..."
    
    local data=$(readSigned3 $EUL_DATA_H)
    local heading=$(echo $data | cut -d' ' -f1)
    local roll=$(echo $data | cut -d' ' -f2)
    local pitch=$(echo $data | cut -d' ' -f3)
    
    printf "Углы Эйлера (градусы):\n"
    printf "  Heading (Yaw) = %.3f°\n" $(echo $heading / 16 | bc -l)
    printf "  Roll = %.3f°\n" $(echo $roll / 16 | bc -l)
    printf "  Pitch = %.3f°\n" $(echo $pitch / 16 | bc -l)
}

# Функция чтения кватернионов
quaternions() {
    echo "Чтение кватернионов..."
    
    local data=$(readQuaternions)
    local w=$(echo $data | cut -d' ' -f1)
    local x=$(echo $data | cut -d' ' -f2)
    local y=$(echo $data | cut -d' ' -f3)
    local z=$(echo $data | cut -d' ' -f4)
    
    printf "Кватернионы:\n"
    printf "  W = %.10f\n" $(echo $w / 16384 | bc -l)
    printf "  X = %.10f\n" $(echo $x / 16384 | bc -l)
    printf "  Y = %.10f\n" $(echo $y / 16384 | bc -l)
    printf "  Z = %.10f\n" $(echo $z / 16384 | bc -l)
}

# Функция чтения линейного ускорения
linear_acceleration() {
    echo "Чтение линейного ускорения..."
    
    local data=$(readSigned3 $LIA_DATA_X)
    local x=$(echo $data | cut -d' ' -f1)
    local y=$(echo $data | cut -d' ' -f2)
    local z=$(echo $data | cut -d' ' -f3)
    
    printf "Линейное ускорение (м/с²):\n"
    printf "  X = %.3f м/с²\n" $(echo $x / 100 | bc -l)
    printf "  Y = %.3f м/с²\n" $(echo $y / 100 | bc -l)
    printf "  Z = %.3f м/с²\n" $(echo $z / 100 | bc -l)
}

# Функция чтения вектора гравитации
gravity_vector() {
    echo "Чтение вектора гравитации..."
    
    local data=$(readSigned3 $GRV_DATA_X)
    local x=$(echo $data | cut -d' ' -f1)
    local y=$(echo $data | cut -d' ' -f2)
    local z=$(echo $data | cut -d' ' -f3)
    
    printf "Вектор гравитации (м/с²):\n"
    printf "  X = %.3f м/с²\n" $(echo $x / 100 | bc -l)
    printf "  Y = %.3f м/с²\n" $(echo $y / 100 | bc -l)
    printf "  Z = %.3f м/с²\n" $(echo $z / 100 | bc -l)
}

# Функция чтения температуры
temperature() {
    echo "Чтение температуры..."
    
    local temp=$(i2cget -y $I2CBUS $DEVADDR $TEMPERATURE)
    
    printf "Температура:\n"
    printf "  Температура = %d°C\n" $temp
}

# Функция чтения акселерометра
accelerometer() {
    echo "Чтение акселерометра..."
    
    local data=$(readSigned3 $ACC_DATA_X)
    local x=$(echo $data | cut -d' ' -f1)
    local y=$(echo $data | cut -d' ' -f2)
    local z=$(echo $data | cut -d' ' -f3)
    
    printf "Акселерометр (м/с²):\n"
    printf "  X = %.3f м/с²\n" $(echo $x / 100 | bc -l)
    printf "  Y = %.3f м/с²\n" $(echo $y / 100 | bc -l)
    printf "  Z = %.3f м/с²\n" $(echo $z / 100 | bc -l)
}

# Функция чтения магнетометра
magnetometer() {
    echo "Чтение магнетометра..."
    
    local data=$(readSigned3 $MAG_DATA_X)
    local x=$(echo $data | cut -d' ' -f1)
    local y=$(echo $data | cut -d' ' -f2)
    local z=$(echo $data | cut -d' ' -f3)
    
    printf "Магнетометр (мкТл):\n"
    printf "  X = %.3f мкТл\n" $(echo $x / 16 | bc -l)
    printf "  Y = %.3f мкТл\n" $(echo $y / 16 | bc -l)
    printf "  Z = %.3f мкТл\n" $(echo $z / 16 | bc -l)
}

# Функция чтения гироскопа
gyroscope() {
    echo "Чтение гироскопа..."
    
    local data=$(readSigned3 $GYR_DATA_X)
    local x=$(echo $data | cut -d' ' -f1)
    local y=$(echo $data | cut -d' ' -f2)
    local z=$(echo $data | cut -d' ' -f3)
    
    printf "Гироскоп (град/с):\n"
    printf "  X = %.3f град/с\n" $(echo $x / 16 | bc -l)
    printf "  Y = %.3f град/с\n" $(echo $y / 16 | bc -l)
    printf "  Z = %.3f град/с\n" $(echo $z / 16 | bc -l)
}

# Функция чтения всех сенсоров
sensors() {
    echo "Чтение всех сенсоров..."
    temperature
    echo ""
    accelerometer
    echo ""
    gyroscope
    echo ""
    magnetometer
}

# Функция чтения всех данных
read_all() {
    echo "=== Показания датчика BNO055 ==="
    calibration_status
    echo ""
    euler_angles
    echo ""
    linear_acceleration
    echo ""
    gravity_vector
    echo ""
    quaternions
    echo ""
    sensors
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
    echo "  calib    - Статус калибровки"
    echo "  euler    - Углы Эйлера"
    echo "  quat     - Кватернионы"
    echo "  linear   - Линейное ускорение"
    echo "  gravity  - Вектор гравитации"
    echo "  temp     - Температура"
    echo "  accel    - Акселерометр"
    echo "  gyro     - Гироскоп"
    echo "  mag      - Магнетометр"
    echo "  sensors  - Все сенсоры"
    echo "  all      - Все данные"
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
            initialize_bno055
            ;;
        calib)
            initialize_bno055 && calibration_status
            ;;
        euler)
            initialize_bno055 && euler_angles
            ;;
        quat)
            initialize_bno055 && quaternions
            ;;
        linear)
            initialize_bno055 && linear_acceleration
            ;;
        gravity)
            initialize_bno055 && gravity_vector
            ;;
        temp)
            initialize_bno055 && temperature
            ;;
        accel)
            initialize_bno055 && accelerometer
            ;;
        gyro)
            initialize_bno055 && gyroscope
            ;;
        mag)
            initialize_bno055 && magnetometer
            ;;
        sensors)
            initialize_bno055 && sensors
            ;;
        all)
            initialize_bno055 && read_all
            ;;
        monitor)
            initialize_bno055 && monitor $2
            ;;
        help|*)
            show_help
            ;;
    esac
}

# Запуск основной функции
main "$@" 