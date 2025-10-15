#!/bin/bash
# Тест режима Holdover для Quantum-PCI
# Проверяет стабильность генератора в автономном режиме

set -e

DEVICE="ocp0"
DEVICE_PATH="/sys/class/timecard/$DEVICE"
TEST_DURATION=300  # 5 минут для быстрого теста
LOG_FILE="/tmp/holdover-test-$(date +%Y%m%d-%H%M%S).log"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║    🧪 ТЕСТ РЕЖИМА HOLDOVER - QUANTUM-PCI                                ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗${NC} Этот скрипт требует прав root"
    echo "  Запустите: sudo $0"
    exit 1
fi

# Проверка наличия устройства
if [ ! -d "$DEVICE_PATH" ]; then
    echo -e "${RED}✗${NC} Устройство $DEVICE не найдено"
    echo "  Проверьте: ls /sys/class/timecard/"
    exit 1
fi

echo -e "${GREEN}✓${NC} Устройство $DEVICE обнаружено"
echo ""

# Функция для получения текущего времени
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Функция для записи в лог
log_data() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Начальный статус
echo "════════════════════════════════════════════════════════════════════════════"
echo "  📊 НАЧАЛЬНЫЙ СТАТУС УСТРОЙСТВА"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

log_data "=== HOLDOVER TEST START: $(get_timestamp) ==="
log_data ""

# Серийный номер
if [ -f "$DEVICE_PATH/serialnum" ]; then
    SERIAL=$(cat $DEVICE_PATH/serialnum 2>/dev/null || echo "N/A")
    echo "  Серийный номер: $SERIAL"
    log_data "Serial Number: $SERIAL"
fi

# Источник часов
if [ -f "$DEVICE_PATH/clock_source" ]; then
    CLOCK_SOURCE=$(cat $DEVICE_PATH/clock_source 2>/dev/null || echo "N/A")
    echo "  Источник времени: $CLOCK_SOURCE"
    log_data "Clock Source: $CLOCK_SOURCE"
fi

# GNSS статус
if [ -f "$DEVICE_PATH/gnss_sync" ]; then
    GNSS_STATUS=$(cat $DEVICE_PATH/gnss_sync 2>/dev/null || echo "N/A")
    echo "  GNSS sync: $GNSS_STATUS"
    log_data "GNSS Sync: $GNSS_STATUS"
fi

# Начальный drift
if [ -f "$DEVICE_PATH/clock_status_drift" ]; then
    INITIAL_DRIFT=$(cat $DEVICE_PATH/clock_status_drift 2>/dev/null || echo "N/A")
    echo "  Начальный drift: $INITIAL_DRIFT ppb"
    log_data "Initial Drift: $INITIAL_DRIFT ppb"
fi

# Начальный offset
if [ -f "$DEVICE_PATH/clock_status_offset" ]; then
    INITIAL_OFFSET=$(cat $DEVICE_PATH/clock_status_offset 2>/dev/null || echo "N/A")
    echo "  Начальный offset: $INITIAL_OFFSET ns"
    log_data "Initial Offset: $INITIAL_OFFSET ns"
fi

echo ""
log_data ""

# Проверка доступных PTP устройств
echo "════════════════════════════════════════════════════════════════════════════"
echo "  ⏰ PTP УСТРОЙСТВА"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

if ls /dev/ptp* > /dev/null 2>&1; then
    echo "  Найдены PTP устройства:"
    ls -la /dev/ptp* | while read line; do
        echo "    $line"
    done
    log_data "PTP Devices: $(ls /dev/ptp* 2>/dev/null | tr '\n' ' ')"
else
    echo -e "  ${YELLOW}⚠${NC} PTP устройства не найдены"
    log_data "PTP Devices: NONE"
fi

echo ""
log_data ""

# Начало теста
echo "════════════════════════════════════════════════════════════════════════════"
echo "  🧪 ЗАПУСК ТЕСТА HOLDOVER"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}ℹ${NC} Длительность теста: $TEST_DURATION секунд"
echo -e "${BLUE}ℹ${NC} Лог сохраняется в: $LOG_FILE"
echo -e "${BLUE}ℹ${NC} Интервал измерений: 10 секунд"
echo ""

# Заголовок таблицы
printf "%-20s | %-15s | %-15s | %-15s\n" "Время" "Drift (ppb)" "Offset (ns)" "GNSS Sync"
echo "--------------------------------------------------------------------------------"
log_data "Time | Drift (ppb) | Offset (ns) | GNSS Sync"
log_data "--------------------------------------------------------------------------------"

# Мониторинг в течение TEST_DURATION секунд
START_TIME=$(date +%s)
MEASUREMENT_COUNT=0
DRIFT_SUM=0
DRIFT_MIN=999999999
DRIFT_MAX=-999999999

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -ge $TEST_DURATION ]; then
        break
    fi
    
    # Получаем текущие значения
    TIMESTAMP=$(date +"%H:%M:%S")
    
    if [ -f "$DEVICE_PATH/clock_status_drift" ]; then
        DRIFT=$(cat $DEVICE_PATH/clock_status_drift 2>/dev/null || echo "N/A")
    else
        DRIFT="N/A"
    fi
    
    if [ -f "$DEVICE_PATH/clock_status_offset" ]; then
        OFFSET=$(cat $DEVICE_PATH/clock_status_offset 2>/dev/null || echo "N/A")
    else
        OFFSET="N/A"
    fi
    
    if [ -f "$DEVICE_PATH/gnss_sync" ]; then
        GNSS=$(cat $DEVICE_PATH/gnss_sync 2>/dev/null || echo "N/A")
    else
        GNSS="N/A"
    fi
    
    # Выводим данные
    printf "%-20s | %-15s | %-15s | %-15s\n" "$TIMESTAMP" "$DRIFT" "$OFFSET" "$GNSS"
    log_data "$TIMESTAMP | $DRIFT | $OFFSET | $GNSS"
    
    # Статистика drift (если это число)
    if [ "$DRIFT" != "N/A" ] && [[ "$DRIFT" =~ ^-?[0-9]+$ ]]; then
        DRIFT_SUM=$((DRIFT_SUM + DRIFT))
        MEASUREMENT_COUNT=$((MEASUREMENT_COUNT + 1))
        
        if [ $DRIFT -lt $DRIFT_MIN ]; then
            DRIFT_MIN=$DRIFT
        fi
        
        if [ $DRIFT -gt $DRIFT_MAX ]; then
            DRIFT_MAX=$DRIFT
        fi
    fi
    
    sleep 10
done

echo "--------------------------------------------------------------------------------"
echo ""
log_data "--------------------------------------------------------------------------------"
log_data ""

# Финальная статистика
echo "════════════════════════════════════════════════════════════════════════════"
echo "  📈 РЕЗУЛЬТАТЫ ТЕСТА"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

log_data "=== TEST RESULTS ==="
log_data ""

echo "  Длительность теста: $TEST_DURATION секунд"
echo "  Количество измерений: $MEASUREMENT_COUNT"
log_data "Test Duration: $TEST_DURATION seconds"
log_data "Measurements: $MEASUREMENT_COUNT"

if [ $MEASUREMENT_COUNT -gt 0 ]; then
    DRIFT_AVG=$((DRIFT_SUM / MEASUREMENT_COUNT))
    DRIFT_RANGE=$((DRIFT_MAX - DRIFT_MIN))
    
    echo ""
    echo "  Статистика Drift:"
    echo "    Среднее: $DRIFT_AVG ppb"
    echo "    Минимум: $DRIFT_MIN ppb"
    echo "    Максимум: $DRIFT_MAX ppb"
    echo "    Разброс: $DRIFT_RANGE ppb"
    
    log_data ""
    log_data "Drift Statistics:"
    log_data "  Average: $DRIFT_AVG ppb"
    log_data "  Minimum: $DRIFT_MIN ppb"
    log_data "  Maximum: $DRIFT_MAX ppb"
    log_data "  Range: $DRIFT_RANGE ppb"
    
    # Оценка качества
    echo ""
    echo "  Оценка стабильности:"
    
    DRIFT_AVG_ABS=${DRIFT_AVG#-}  # Абсолютное значение
    
    if [ $DRIFT_AVG_ABS -lt 10 ]; then
        echo -e "    ${GREEN}★★★★★ ОТЛИЧНО${NC} (drift < 10 ppb)"
        QUALITY="EXCELLENT"
    elif [ $DRIFT_AVG_ABS -lt 50 ]; then
        echo -e "    ${GREEN}★★★★☆ ОЧЕНЬ ХОРОШО${NC} (drift < 50 ppb)"
        QUALITY="VERY_GOOD"
    elif [ $DRIFT_AVG_ABS -lt 100 ]; then
        echo -e "    ${BLUE}★★★☆☆ ХОРОШО${NC} (drift < 100 ppb)"
        QUALITY="GOOD"
    elif [ $DRIFT_AVG_ABS -lt 1000 ]; then
        echo -e "    ${YELLOW}★★☆☆☆ ПРИЕМЛЕМО${NC} (drift < 1000 ppb = 1 ppm)"
        QUALITY="ACCEPTABLE"
    else
        echo -e "    ${RED}★☆☆☆☆ ТРЕБУЕТ ВНИМАНИЯ${NC} (drift >= 1 ppm)"
        QUALITY="NEEDS_ATTENTION"
    fi
    
    log_data "Quality Assessment: $QUALITY"
    
    # Прогноз накопления ошибки
    echo ""
    echo "  Прогноз накопления ошибки времени:"
    
    # Расчет в микросекундах
    ERROR_1H=$(echo "scale=3; $DRIFT_AVG_ABS * 3600 / 1000" | bc)
    ERROR_24H=$(echo "scale=3; $DRIFT_AVG_ABS * 86400 / 1000" | bc)
    ERROR_7D=$(echo "scale=3; $DRIFT_AVG_ABS * 604800 / 1000" | bc)
    
    echo "    За 1 час: $ERROR_1H мкс"
    echo "    За 24 часа: $ERROR_24H мкс"
    echo "    За 7 дней: $ERROR_7D мкс"
    
    log_data ""
    log_data "Time Error Accumulation:"
    log_data "  1 hour: $ERROR_1H μs"
    log_data "  24 hours: $ERROR_24H μs"
    log_data "  7 days: $ERROR_7D μs"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  ✅ ТЕСТ ЗАВЕРШЕН"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}✓${NC} Лог сохранен: $LOG_FILE"
echo ""

log_data ""
log_data "=== TEST COMPLETED: $(get_timestamp) ==="

# Предложение следующих шагов
echo "📋 Следующие шаги:"
echo ""
echo "  1. Просмотр полного лога:"
echo "     cat $LOG_FILE"
echo ""
echo "  2. Анализ точности holdover:"
echo "     sudo ./autonomous-timekeeper/scripts/analyze-holdover-accuracy.sh"
echo ""
echo "  3. Настройка автономного хранения времени:"
echo "     sudo ./autonomous-timekeeper/scripts/setup-quantum-timekeeper.sh"
echo ""

