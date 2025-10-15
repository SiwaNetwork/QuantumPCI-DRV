#!/bin/bash
# Quantum-PCI TimeCard Diagnostic Script
# Комплексная диагностика устройства Quantum-PCI

set -e

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║    🔍 ДИАГНОСТИКА QUANTUM-PCI TIMECARD                                   ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция проверки с выводом результата
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

echo "════════════════════════════════════════════════════════════════════════════"
echo "  📦 1. ПРОВЕРКА ДРАЙВЕРА"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

if lsmod | grep -q ptp_ocp; then
    echo -e "${GREEN}✓${NC} Драйвер ptp_ocp загружен"
    lsmod | grep ptp_ocp
else
    echo -e "${RED}✗${NC} Драйвер ptp_ocp НЕ загружен"
    echo "  Рекомендация: sudo modprobe ptp_ocp"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  🔌 2. ПРОВЕРКА PCI УСТРОЙСТВА"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

if lspci -d 1d9b:0400 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Quantum-PCI обнаружено в системе"
    lspci -d 1d9b:0400 -vv | head -20
else
    echo -e "${YELLOW}⚠${NC} Quantum-PCI не найдено"
    echo "  Проверяем другие поддерживаемые устройства..."
    
    if lspci -d 1ad7:a000 > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Orolia ART Card обнаружено"
        lspci -d 1ad7:a000
    elif lspci -d 0b0b:0410 > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} ADVA TimeCard обнаружено"
        lspci -d 0b0b:0410
    else
        echo -e "${RED}✗${NC} Поддерживаемые устройства не найдены"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  ⏰ 3. ПРОВЕРКА PTP УСТРОЙСТВ"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

if ls /dev/ptp* > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PTP устройства найдены:"
    ls -la /dev/ptp*
else
    echo -e "${RED}✗${NC} PTP устройства не найдены"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  📂 4. ПРОВЕРКА SYSFS ИНТЕРФЕЙСА"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

if [ -d "/sys/class/timecard/" ]; then
    echo -e "${GREEN}✓${NC} Интерфейс /sys/class/timecard/ существует"
    
    for device in /sys/class/timecard/ocp*; do
        if [ -d "$device" ]; then
            echo ""
            echo "  Устройство: $(basename $device)"
            
            if [ -f "$device/serialnum" ]; then
                echo "    Серийный номер: $(cat $device/serialnum 2>/dev/null || echo 'N/A')"
            fi
            
            if [ -f "$device/clock_source" ]; then
                echo "    Источник времени: $(cat $device/clock_source 2>/dev/null || echo 'N/A')"
            fi
            
            if [ -f "$device/gnss_sync" ]; then
                echo "    GNSS sync: $(cat $device/gnss_sync 2>/dev/null || echo 'N/A')"
            fi
            
            if [ -f "$device/clock_status_drift" ]; then
                echo "    Drift: $(cat $device/clock_status_drift 2>/dev/null || echo 'N/A') ppb"
            fi
            
            if [ -f "$device/clock_status_offset" ]; then
                echo "    Offset: $(cat $device/clock_status_offset 2>/dev/null || echo 'N/A') ns"
            fi
        fi
    done
else
    echo -e "${RED}✗${NC} Интерфейс /sys/class/timecard/ не найден"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  🔌 5. ПРОВЕРКА SMA КОНФИГУРАЦИИ"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "  Конфигурация SMA разъемов:"
    for i in 1 2 3 4; do
        if [ -f "/sys/class/timecard/ocp0/sma$i" ]; then
            echo "    SMA$i: $(cat /sys/class/timecard/ocp0/sma$i 2>/dev/null || echo 'N/A')"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} Устройство ocp0 не найдено"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  📊 6. ПРОВЕРКА СИНХРОНИЗАЦИИ"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

if command -v chronyc > /dev/null 2>&1; then
    echo "  Chrony tracking:"
    chronyc tracking 2>/dev/null || echo "  Chrony не настроен или не запущен"
else
    echo -e "${YELLOW}⚠${NC} Chrony не установлен"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  🔍 7. СИСТЕМНЫЕ ЛОГИ"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

echo "  Последние сообщения ptp_ocp в dmesg:"
dmesg | grep -i ptp_ocp | tail -10 || echo "  Нет сообщений в dmesg"

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "  ✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

# Итоговая оценка
if lsmod | grep -q ptp_ocp && [ -d "/sys/class/timecard/ocp0" ]; then
    echo -e "${GREEN}✓ Система работает нормально${NC}"
    exit 0
elif lsmod | grep -q ptp_ocp; then
    echo -e "${YELLOW}⚠ Драйвер загружен, но устройства не найдены${NC}"
    exit 1
else
    echo -e "${RED}✗ Критические проблемы обнаружены${NC}"
    echo "  Рекомендации:"
    echo "    1. Проверьте физическое подключение карты"
    echo "    2. Загрузите драйвер: sudo modprobe ptp_ocp"
    echo "    3. Проверьте настройки BIOS (VT-d/IOMMU)"
    exit 2
fi

