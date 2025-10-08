#!/bin/bash
# Диагностика синхронизации PPS между устройствами Quantum-PCI

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  Диагностика синхронизации PPS между устройствами Quantum-PCI     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

DEVICE=${1:-ocp0}
TIMECARD_PATH="/sys/class/timecard/$DEVICE"

if [ ! -d "$TIMECARD_PATH" ]; then
    echo "❌ Устройство $DEVICE не найдено!"
    echo "Доступные устройства:"
    ls /sys/class/timecard/ 2>/dev/null || echo "  Нет доступных устройств"
    exit 1
fi

echo "🔍 Проверка устройства: $DEVICE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Серийный номер
echo "📋 Серийный номер:"
cat "$TIMECARD_PATH/serialnum" 2>/dev/null || echo "  Недоступен"
echo ""

# GNSS синхронизация
echo "🛰️  GNSS синхронизация:"
GNSS_STATUS=$(cat "$TIMECARD_PATH/gnss_sync" 2>/dev/null)
if [[ "$GNSS_STATUS" =~ "SYNC" ]]; then
    echo "  ✅ $GNSS_STATUS"
else
    echo "  ❌ $GNSS_STATUS"
    echo "  ⚠️  КРИТИЧНО: GNSS синхронизация потеряна!"
fi
echo ""

# Источник времени
echo "🕐 Источник времени:"
CLOCK_SOURCE=$(cat "$TIMECARD_PATH/clock_source" 2>/dev/null)
echo "  Текущий: $CLOCK_SOURCE"
echo "  Доступные: $(cat "$TIMECARD_PATH/available_clock_sources" 2>/dev/null)"
echo ""

# PTP метрики
echo "📊 PTP метрики:"
OFFSET=$(cat "$TIMECARD_PATH/clock_status_offset" 2>/dev/null)
DRIFT=$(cat "$TIMECARD_PATH/clock_status_drift" 2>/dev/null)
echo "  Offset: $OFFSET нс"
echo "  Drift:  $DRIFT ppb"
echo ""

# SMA конфигурация
echo "🔌 SMA порты:"
for i in 1 2 3 4; do
    SMA_CFG=$(cat "$TIMECARD_PATH/sma$i" 2>/dev/null)
    echo "  SMA$i: $SMA_CFG"
done
echo ""

# Диагностика проблемы
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔬 ДИАГНОСТИКА:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$GNSS_STATUS" =~ "LOST" ]]; then
    echo "❌ ПРОБЛЕМА #1: GNSS синхронизация потеряна"
    echo "   Последствия:"
    echo "   • Устройство использует внутренний осциллятор"
    echo "   • Происходит накопление дрейфа времени"
    echo "   • Независимые устройства расходятся во времени"
    echo ""
    echo "   Решения:"
    echo "   1️⃣  Подключите GNSS антенну с прямой видимостью неба"
    echo "   2️⃣  Проверьте кабель антенны и разъем SMA"
    echo "   3️⃣  Убедитесь, что антенна имеет питание"
    echo ""
fi

if [[ "$CLOCK_SOURCE" == "PPS" && "$GNSS_STATUS" =~ "LOST" ]]; then
    echo "⚠️  ПРОБЛЕМА #2: Источник времени PPS без GNSS"
    echo "   Последствия:"
    echo "   • PPS есть, но нет метки времени (TOD - Time of Day)"
    echo "   • Устройство знает частоту, но не знает абсолютное время"
    echo "   • При перезагрузке время теряется"
    echo ""
fi

if [[ "$OFFSET" == "0" && "$DRIFT" == "0" ]]; then
    echo "⚠️  ПРОБЛЕМА #3: PTP метрики нулевые"
    echo "   Возможные причины:"
    echo "   • PTP синхронизация не настроена"
    echo "   • ptp4l не запущен"
    echo "   • Нет PTP мастера в сети"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 РЕКОМЕНДАЦИИ ПО СИНХРОНИЗАЦИИ ДВУХ УСТРОЙСТВ:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🎯 ВАРИАНТ 1: Синхронизация через GNSS (Рекомендуется)"
echo "   ────────────────────────────────────────────────────────────────"
echo "   • Подключите GNSS антенну к обоим устройствам"
echo "   • Оба устройства синхронизируются с GPS/ГЛОНАСС"
echo "   • Точность: <100 нс между устройствами"
echo "   • Команда: echo 'GNSS' | sudo tee /sys/class/timecard/ocp0/clock_source"
echo ""

echo "🎯 ВАРИАНТ 2: PTP синхронизация master/slave"
echo "   ────────────────────────────────────────────────────────────────"
echo "   Устройство 1 (Master):"
echo "   • Подключить GNSS антенну"
echo "   • Настроить как PTP Grandmaster"
echo "   • Команда: ptp4l -i eth0 -m -H"
echo ""
echo "   Устройство 2 (Slave):"
echo "   • Синхронизироваться с устройством 1 по Ethernet"
echo "   • Источник: PTP"
echo "   • Команда: ptp4l -i eth0 -m -s"
echo "   • Точность: <1 мкс по локальной сети"
echo ""

echo "🎯 ВАРИАНТ 3: Внешний PPS + NTP/chrony"
echo "   ────────────────────────────────────────────────────────────────"
echo "   • Один источник PPS (например, от GNSS receiver)"
echo "   • Разделить PPS на оба устройства через splitter"
echo "   • Синхронизировать метки времени через NTP/chrony"
echo "   • Точность: <1 мкс"
echo ""

echo "🎯 ВАРИАНТ 4: Аппаратное объединение"
echo "   ────────────────────────────────────────────────────────────────"
echo "   • Соединить SMA2 (вход PPS) устройства 2"
echo "   •   с SMA3 или SMA4 (выход PPS) устройства 1"
echo "   • На устройстве 1 настроить: echo 'PHC' | sudo tee /sys/class/timecard/ocp0/sma3"
echo "   • На устройстве 2 настроить: echo 'PPS' | sudo tee /sys/class/timecard/ocp0/clock_source"
echo "   • Точность: <50 нс"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 КОМАНДЫ ДЛЯ БЫСТРОЙ НАСТРОЙКИ:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "# Проверить, когда GNSS был в последний раз синхронизирован:"
echo "cat /sys/class/timecard/$DEVICE/gnss_sync"
echo ""
echo "# Переключить источник на GNSS (когда антенна подключена):"
echo "echo 'GNSS' | sudo tee /sys/class/timecard/$DEVICE/clock_source"
echo ""
echo "# Настроить вывод PHC на SMA3 (для синхронизации другого устройства):"
echo "echo 'PHC' | sudo tee /sys/class/timecard/$DEVICE/sma3"
echo ""
echo "# Запустить PTP4l как master:"
echo "sudo ptp4l -i eth0 -m -H"
echo ""
echo "# Запустить PTP4l как slave:"
echo "sudo ptp4l -i eth0 -m -s"
echo ""
echo "# Запустить этот скрипт для другого устройства:"
echo "$0 ocp1"
echo ""

