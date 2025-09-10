#!/bin/bash

# Быстрая настройка Intel сетевых карт I210, I225, I226 для Quantum-PCI
# Дата: $(date)

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
TIMECARD_SYSFS="/sys/class/timecard/ocp0"
INTERFACE="eth0"  # Будет определен автоматически

# Функция логирования
log() {
    echo -e "$1"
}

# Функция определения Intel интерфейса
detect_intel_interface() {
    log "${BLUE}🔍 Поиск Intel сетевых интерфейсов...${NC}"
    
    local interfaces=$(ip link show | grep -E "eth[0-9]+|en[0-9]+s[0-9]+" | cut -d: -f2 | tr -d ' ')
    
    for iface in $interfaces; do
        if ethtool -i "$iface" 2>/dev/null | grep -qi "intel"; then
            log "${GREEN}✅ Найден Intel интерфейс: $iface${NC}"
            echo "$iface"
            return 0
        fi
    done
    
    log "${RED}❌ Intel сетевые интерфейсы не найдены${NC}"
    return 1
}

# Функция быстрой настройки
quick_setup() {
    local interface="$1"
    
    log "${BLUE}⚡ Быстрая настройка $interface${NC}"
    
    # Остановка интерфейса
    log "${YELLOW}⏹️  Остановка интерфейса...${NC}"
    sudo ip link set "$interface" down
    
    # Включение hardware timestamping
    log "${YELLOW}🔧 Включение hardware timestamping...${NC}"
    sudo ethtool -T "$interface" rx-filter on
    
    # Настройка буферов
    log "${YELLOW}📊 Настройка буферов...${NC}"
    sudo ethtool -G "$interface" rx 4096 tx 4096
    
    # Автоматическая настройка скорости
    local speed_info=$(ethtool "$interface" | grep -E "Speed|Supported link modes")
    if echo "$speed_info" | grep -q "2500"; then
        log "${YELLOW}🚀 Настройка для 2.5 Gbps (Intel I225)...${NC}"
        sudo ethtool -s "$interface" speed 2500 duplex full autoneg off
    else
        log "${YELLOW}🚀 Настройка для 1 Gbps...${NC}"
        sudo ethtool -s "$interface" speed 1000 duplex full autoneg off
    fi
    
    # Включение интерфейса
    log "${YELLOW}▶️  Включение интерфейса...${NC}"
    sudo ip link set "$interface" up
    
    # Ожидание стабилизации
    sleep 2
    
    log "${GREEN}✅ Быстрая настройка завершена${NC}"
}

# Функция проверки Quantum-PCI
check_quantum_pci() {
    log "${BLUE}🔍 Проверка Quantum-PCI...${NC}"
    
    if [ ! -d "$TIMECARD_SYSFS" ]; then
        log "${RED}❌ Quantum-PCI не найден${NC}"
        return 1
    fi
    
    local serial=$(cat "$TIMECARD_SYSFS/serialnum" 2>/dev/null || echo "неизвестно")
    log "${GREEN}✅ Quantum-PCI найден: $serial${NC}"
    
    # Настройка источника времени на GNSS
    log "${YELLOW}🛰️  Настройка источника времени на GNSS...${NC}"
    echo "GNSS" | sudo tee "$TIMECARD_SYSFS/clock_source" > /dev/null
    
    # Проверка статуса GNSS
    local gnss_sync=$(cat "$TIMECARD_SYSFS/gnss_sync" 2>/dev/null || echo "0")
    if [ "$gnss_sync" = "1" ]; then
        log "${GREEN}✅ GNSS синхронизирован${NC}"
    else
        log "${YELLOW}⚠️  GNSS не синхронизирован (может потребоваться время)${NC}"
    fi
    
    return 0
}

# Функция создания простой конфигурации PTP
create_simple_ptp_config() {
    local interface="$1"
    local config_file="/tmp/ptp4l-simple.conf"
    
    log "${BLUE}📝 Создание простой конфигурации PTP...${NC}"
    
    cat > "$config_file" << EOF
[global]
domainNumber               24
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delay_mechanism            E2E
time_stamping              hardware

[$interface]
network_transport          UDPv4
EOF
    
    log "${GREEN}✅ Конфигурация PTP создана: $config_file${NC}"
    echo "$config_file"
}

# Функция запуска PTP
start_ptp() {
    local interface="$1"
    local config_file="$2"
    
    log "${BLUE}🚀 Запуск PTP...${NC}"
    
    # Запуск PTP в фоновом режиме
    sudo ptp4l -f "$config_file" -i "$interface" -m > /tmp/ptp4l-simple.log 2>&1 &
    local ptp_pid=$!
    
    # Сохранение PID
    echo "$ptp_pid" > /tmp/ptp4l.pid
    
    log "${GREEN}✅ PTP4L запущен (PID: $ptp_pid)${NC}"
    log "${YELLOW}📋 Логи: /tmp/ptp4l-simple.log${NC}"
    log "${YELLOW}🛑 Для остановки: sudo kill $ptp_pid${NC}"
    
    # Показ первых логов
    sleep 5
    log "${BLUE}📊 Первые логи PTP:${NC}"
    tail -10 /tmp/ptp4l-simple.log | while read -r line; do
        if echo "$line" | grep -q "master\|slave\|offset"; then
            log "  $line"
        fi
    done
}

# Функция проверки статуса
check_status() {
    local interface="$1"
    
    log "${BLUE}📊 Проверка статуса системы...${NC}"
    
    # Статус интерфейса
    log "${CYAN}🌐 Статус интерфейса $interface:${NC}"
    ip link show "$interface" | grep -E "state|mtu"
    
    # Hardware timestamping
    log "${CYAN}⏰ Hardware timestamping:${NC}"
    ethtool -T "$interface" | grep -E "SOF|SYS|HW" | head -3
    
    # Статистика
    log "${CYAN}📈 Статистика:${NC}"
    ethtool -S "$interface" | grep -E "rx_packets|tx_packets|rx_errors|tx_errors" | head -4
    
    # PTP статус
    if [ -e "/dev/ptp0" ]; then
        log "${CYAN}🕐 PTP время:${NC}"
        sudo testptp -d /dev/ptp0 -g
    fi
    
    # Quantum-PCI статус
    if [ -d "$TIMECARD_SYSFS" ]; then
        log "${CYAN}🛰️  Quantum-PCI:${NC}"
        log "  GNSS Sync: $(cat $TIMECARD_SYSFS/gnss_sync 2>/dev/null)"
        log "  Clock Source: $(cat $TIMECARD_SYSFS/clock_source 2>/dev/null)"
    fi
}

# Функция остановки PTP
stop_ptp() {
    log "${BLUE}🛑 Остановка PTP...${NC}"
    
    if [ -f "/tmp/ptp4l.pid" ]; then
        local pid=$(cat /tmp/ptp4l.pid)
        if kill -0 "$pid" 2>/dev/null; then
            sudo kill "$pid"
            log "${GREEN}✅ PTP остановлен${NC}"
        else
            log "${YELLOW}⚠️  PTP уже остановлен${NC}"
        fi
        rm -f /tmp/ptp4l.pid
    else
        log "${YELLOW}⚠️  PID файл не найден${NC}"
    fi
}

# Функция показа помощи
show_help() {
    cat << EOF
Быстрая настройка Intel сетевых карт для Quantum-PCI

Использование: $0 [команда]

Команды:
  setup     - Быстрая настройка Intel сетевой карты
  start     - Запуск PTP
  stop      - Остановка PTP
  status    - Показать статус системы
  help      - Показать эту справку

Примеры:
  $0 setup    # Настроить и запустить PTP
  $0 status   # Проверить статус
  $0 stop     # Остановить PTP

EOF
}

# Основная функция
main() {
    case "${1:-setup}" in
        "setup")
            log "${GREEN}🚀 Быстрая настройка Intel сетевых карт${NC}"
            
            # Определение интерфейса
            if ! INTERFACE=$(detect_intel_interface); then
                exit 1
            fi
            
            # Быстрая настройка
            quick_setup "$INTERFACE"
            
            # Проверка Quantum-PCI
            check_quantum_pci
            
            # Создание конфигурации PTP
            local config_file=$(create_simple_ptp_config "$INTERFACE")
            
            # Запуск PTP
            start_ptp "$INTERFACE" "$config_file"
            
            # Показать статус
            sleep 3
            check_status "$INTERFACE"
            ;;
            
        "start")
            # Определение интерфейса
            if ! INTERFACE=$(detect_intel_interface); then
                exit 1
            fi
            
            # Создание конфигурации PTP
            local config_file=$(create_simple_ptp_config "$INTERFACE")
            
            # Запуск PTP
            start_ptp "$INTERFACE" "$config_file"
            ;;
            
        "stop")
            stop_ptp
            ;;
            
        "status")
            # Определение интерфейса
            if ! INTERFACE=$(detect_intel_interface); then
                exit 1
            fi
            
            check_status "$INTERFACE"
            ;;
            
        "help"|"-h"|"--help")
            show_help
            ;;
            
        *)
            log "${RED}❌ Неизвестная команда: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'log "${RED}Прервано${NC}"; exit 1' INT TERM

# Запуск основной функции
main "$@"
