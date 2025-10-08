#!/bin/bash
# Быстрая настройка синхронизации между двумя устройствами Quantum-PCI

set -e

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  Настройка синхронизации между двумя устройствами Quantum-PCI     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Этот скрипт требует прав root"
    echo "   Запустите: sudo $0"
    exit 1
fi

echo "Выберите метод синхронизации:"
echo ""
echo "1️⃣  GNSS синхронизация (оба устройства с GNSS антеннами)"
echo "    ✅ Рекомендуется"
echo "    ✅ Точность: <100 нс"
echo "    ✅ Полная автономность"
echo ""
echo "2️⃣  PTP Master/Slave через Ethernet"
echo "    ✅ Точность: <1 мкс"
echo "    ⚠️  Требует сетевое подключение"
echo ""
echo "3️⃣  Аппаратная синхронизация (кабель SMA между устройствами)"
echo "    ✅ Точность: <50 нс"
echo "    ⚠️  Требует физическое соединение SMA кабелем"
echo ""
echo "4️⃣  Диагностика текущего состояния"
echo ""

read -p "Выберите вариант (1-4): " CHOICE

case $CHOICE in
    1)
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  ВАРИАНТ 1: GNSS синхронизация"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        DEVICE=${1:-ocp0}
        TIMECARD_PATH="/sys/class/timecard/$DEVICE"
        
        if [ ! -d "$TIMECARD_PATH" ]; then
            echo "❌ Устройство $DEVICE не найдено!"
            exit 1
        fi
        
        echo "📋 Настройка устройства: $DEVICE"
        echo ""
        
        # Проверка GNSS
        GNSS_STATUS=$(cat "$TIMECARD_PATH/gnss_sync")
        echo "🛰️  Текущий статус GNSS: $GNSS_STATUS"
        
        if [[ "$GNSS_STATUS" =~ "LOST" ]]; then
            echo ""
            echo "⚠️  ВНИМАНИЕ: GNSS синхронизация потеряна!"
            echo ""
            echo "Перед продолжением:"
            echo "  1. Подключите GNSS антенну к устройству"
            echo "  2. Разместите антенну с прямой видимостью неба"
            echo "  3. Подождите 5-10 минут для получения fix"
            echo ""
            read -p "Антенна подключена и готова? (y/N): " CONFIRM
            
            if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
                echo "❌ Отменено пользователем"
                exit 1
            fi
        fi
        
        echo ""
        echo "🔧 Переключаю источник времени на GNSS..."
        echo "GNSS" > "$TIMECARD_PATH/clock_source"
        
        echo "✅ Источник времени переключен на GNSS"
        echo ""
        echo "Новый источник: $(cat "$TIMECARD_PATH/clock_source")"
        echo ""
        
        echo "📊 Повторите эту процедуру на втором устройстве:"
        echo "   sudo $0 ocp1"
        echo ""
        echo "💡 После синхронизации обоих устройств с GNSS:"
        echo "   • Расхождение PPS будет <100 нс"
        echo "   • Запустите мониторинг: watch -n1 'cat $TIMECARD_PATH/gnss_sync'"
        ;;
        
    2)
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  ВАРИАНТ 2: PTP Master/Slave синхронизация"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        echo "Вы настраиваете это устройство как:"
        echo "  1) Master (Grandmaster) - источник времени"
        echo "  2) Slave - синхронизируется с Master"
        echo ""
        read -p "Выберите (1/2): " ROLE
        
        # Определение сетевого интерфейса
        echo ""
        echo "Доступные сетевые интерфейсы:"
        ip link show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | tr -d ':'
        echo ""
        read -p "Введите имя интерфейса (например, eth0, eno1): " IFACE
        
        if [ -z "$IFACE" ]; then
            echo "❌ Интерфейс не указан"
            exit 1
        fi
        
        case $ROLE in
            1)
                echo ""
                echo "🎯 Настройка как PTP Grandmaster"
                echo ""
                
                # Проверка ptp4l
                if ! command -v ptp4l &> /dev/null; then
                    echo "❌ ptp4l не найден!"
                    echo "   Установите: apt install linuxptp"
                    exit 1
                fi
                
                echo "📝 Создаю конфигурацию PTP..."
                cat > /tmp/ptp4l-master.conf <<EOF
[global]
priority1               127
priority2               128
domainNumber            0
logging_level           6
verbose                 1
time_stamping           hardware
network_transport       UDPv4

# Clock servo configuration
pi_proportional_const   0.000000
pi_integral_const       0.000000
pi_proportional_scale   0.700000
pi_integral_scale       0.300000
step_threshold          0.000002
first_step_threshold    0.000020
clock_servo             pi

# Better for LAN
twoStepFlag             1
summary_interval        -4
announceReceiptTimeout  3
syncReceiptTimeout      3
delay_mechanism         E2E

[${IFACE}]
EOF
                
                echo "✅ Конфигурация создана: /tmp/ptp4l-master.conf"
                echo ""
                echo "🚀 Запуск PTP4L в режиме Grandmaster..."
                echo ""
                echo "Команда запуска:"
                echo "  ptp4l -f /tmp/ptp4l-master.conf -i $IFACE -m"
                echo ""
                echo "Запустить сейчас? (будет работать в фоновом режиме)"
                read -p "(y/N): " START_NOW
                
                if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
                    ptp4l -f /tmp/ptp4l-master.conf -i $IFACE -m > /var/log/ptp4l-master.log 2>&1 &
                    PTP_PID=$!
                    echo "✅ PTP4L запущен (PID: $PTP_PID)"
                    echo "   Логи: /var/log/ptp4l-master.log"
                    echo ""
                    echo "Для остановки: sudo kill $PTP_PID"
                fi
                ;;
                
            2)
                echo ""
                echo "🎯 Настройка как PTP Slave"
                echo ""
                
                # Проверка ptp4l
                if ! command -v ptp4l &> /dev/null; then
                    echo "❌ ptp4l не найден!"
                    echo "   Установите: apt install linuxptp"
                    exit 1
                fi
                
                echo "📝 Создаю конфигурацию PTP..."
                cat > /tmp/ptp4l-slave.conf <<EOF
[global]
priority1               255
priority2               255
domainNumber            0
logging_level           6
verbose                 1
time_stamping           hardware
network_transport       UDPv4
slaveOnly               1

# Clock servo configuration
pi_proportional_const   0.000000
pi_integral_const       0.000000
pi_proportional_scale   0.700000
pi_integral_scale       0.300000
step_threshold          0.000002
first_step_threshold    0.000020
clock_servo             pi

# Better for LAN
twoStepFlag             1
summary_interval        -4
announceReceiptTimeout  3
syncReceiptTimeout      3
delay_mechanism         E2E

[${IFACE}]
EOF
                
                echo "✅ Конфигурация создана: /tmp/ptp4l-slave.conf"
                echo ""
                
                DEVICE=${1:-ocp0}
                TIMECARD_PATH="/sys/class/timecard/$DEVICE"
                
                if [ -d "$TIMECARD_PATH" ]; then
                    echo "🔧 Переключаю источник времени на PTP..."
                    echo "PTP" > "$TIMECARD_PATH/clock_source"
                    echo "✅ Источник: $(cat "$TIMECARD_PATH/clock_source")"
                    echo ""
                fi
                
                echo "🚀 Запуск PTP4L в режиме Slave..."
                echo ""
                echo "Команда запуска:"
                echo "  ptp4l -f /tmp/ptp4l-slave.conf -i $IFACE -m -s"
                echo ""
                echo "Запустить сейчас? (будет работать в фоновом режиме)"
                read -p "(y/N): " START_NOW
                
                if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
                    ptp4l -f /tmp/ptp4l-slave.conf -i $IFACE -m -s > /var/log/ptp4l-slave.log 2>&1 &
                    PTP_PID=$!
                    echo "✅ PTP4L запущен (PID: $PTP_PID)"
                    echo "   Логи: /var/log/ptp4l-slave.log"
                    echo ""
                    echo "💡 Мониторинг синхронизации:"
                    echo "   tail -f /var/log/ptp4l-slave.log"
                    echo "   watch -n1 'cat $TIMECARD_PATH/clock_status_offset'"
                    echo ""
                    echo "Для остановки: sudo kill $PTP_PID"
                fi
                ;;
        esac
        ;;
        
    3)
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  ВАРИАНТ 3: Аппаратная синхронизация через SMA"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        echo "Подключите устройства следующим образом:"
        echo ""
        echo "  Устройство 1 (Master):                 Устройство 2 (Slave):"
        echo "  ┌──────────────┐                      ┌──────────────┐"
        echo "  │              │                      │              │"
        echo "  │  [GNSS ANT]  │                      │              │"
        echo "  │      ↓       │    SMA кабель        │      ↓       │"
        echo "  │   [SMA3] ────┼──────────────────────┼────[SMA2]    │"
        echo "  │    PHC out   │    (PPS signal)      │   PPS1 in    │"
        echo "  │              │                      │              │"
        echo "  └──────────────┘                      └──────────────┘"
        echo ""
        
        read -p "Настроить это устройство как Master или Slave? (M/S): " DEV_ROLE
        
        DEVICE=${1:-ocp0}
        TIMECARD_PATH="/sys/class/timecard/$DEVICE"
        
        if [ ! -d "$TIMECARD_PATH" ]; then
            echo "❌ Устройство $DEVICE не найдено!"
            exit 1
        fi
        
        case $DEV_ROLE in
            [Mm])
                echo ""
                echo "🎯 Настройка устройства как Master"
                echo ""
                
                # Сначала синхронизируем с GNSS
                echo "1️⃣  Переключаю источник времени на GNSS..."
                echo "GNSS" > "$TIMECARD_PATH/clock_source"
                sleep 1
                
                # Настраиваем выход PHC на SMA3
                echo "2️⃣  Настраиваю SMA3 на выход PHC (PPS)..."
                echo "PHC" > "$TIMECARD_PATH/sma3"
                
                echo ""
                echo "✅ Устройство Master настроено!"
                echo ""
                echo "Конфигурация:"
                echo "  Источник: $(cat "$TIMECARD_PATH/clock_source")"
                echo "  SMA3: $(cat "$TIMECARD_PATH/sma3")"
                echo ""
                echo "📡 GNSS статус: $(cat "$TIMECARD_PATH/gnss_sync")"
                echo ""
                echo "💡 Теперь подключите SMA3 этого устройства к SMA2 второго устройства"
                ;;
                
            [Ss])
                echo ""
                echo "🎯 Настройка устройства как Slave"
                echo ""
                
                # Проверяем, что SMA2 настроен на вход PPS
                echo "1️⃣  Настраиваю SMA2 на вход PPS1..."
                echo "PPS1" > "$TIMECARD_PATH/sma2"
                sleep 1
                
                # Переключаем источник времени на PPS
                echo "2️⃣  Переключаю источник времени на PPS..."
                echo "PPS" > "$TIMECARD_PATH/clock_source"
                
                echo ""
                echo "✅ Устройство Slave настроено!"
                echo ""
                echo "Конфигурация:"
                echo "  Источник: $(cat "$TIMECARD_PATH/clock_source")"
                echo "  SMA2: $(cat "$TIMECARD_PATH/sma2")"
                echo ""
                echo "💡 Убедитесь, что SMA2 подключен к SMA3 устройства Master"
                echo ""
                echo "📊 Мониторинг синхронизации:"
                echo "   watch -n1 'cat $TIMECARD_PATH/clock_status_offset'"
                ;;
                
            *)
                echo "❌ Неверный выбор"
                exit 1
                ;;
        esac
        ;;
        
    4)
        echo ""
        /home/shiwa-time/QuantumPCI-DRV/scripts/diagnose_pps_sync.sh ${1:-ocp0}
        ;;
        
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Настройка завершена!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

