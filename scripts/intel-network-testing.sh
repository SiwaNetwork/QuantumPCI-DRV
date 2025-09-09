#!/bin/bash

# Скрипт тестирования Intel сетевых карт I210, I225, I226 с Quantum-PCI
# Автор: AI Assistant
# Дата: $(date)

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Конфигурация
TIMECARD_SYSFS="/sys/class/timecard/ocp0"
LOG_FILE="/tmp/intel-network-test-$(date +%Y%m%d-%H%M%S).log"
TEST_DURATION=300  # 5 минут

# Функция логирования
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Функция проверки зависимостей
check_dependencies() {
    log "${BLUE}=== Проверка зависимостей ===${NC}"
    
    local deps=("ethtool" "ptp4l" "testptp" "lspci" "ip" "ping" "iperf3")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        else
            log "${GREEN}✅ $dep найден${NC}"
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "${RED}❌ Отсутствуют зависимости: ${missing[*]}${NC}"
        log "${YELLOW}Установите их с помощью:${NC}"
        log "sudo apt-get install -y linuxptp ethtool iperf3"
        exit 1
    fi
}

# Функция обнаружения Intel сетевых карт
detect_intel_cards() {
    log "${BLUE}=== Обнаружение Intel сетевых карт ===${NC}"
    
    local intel_cards=()
    local pci_devices=$(lspci | grep -i "intel.*ethernet\|intel.*network")
    
    if [ -z "$pci_devices" ]; then
        log "${RED}❌ Intel сетевые карты не найдены${NC}"
        return 1
    fi
    
    log "${GREEN}Найденные Intel сетевые карты:${NC}"
    echo "$pci_devices" | while read -r line; do
        local pci_id=$(echo "$line" | cut -d' ' -f1)
        local device_name=$(echo "$line" | sed 's/^[^:]*: //')
        
        log "${CYAN}  PCI ID: $pci_id - $device_name${NC}"
        
        # Определение типа карты
        case "$pci_id" in
            *:1533|*:1536|*:1537|*:1538|*:1539|*:153A|*:153B)
                log "${GREEN}    Тип: Intel I210${NC}"
                ;;
            *:15F2|*:15F3)
                log "${GREEN}    Тип: Intel I225${NC}"
                ;;
            *:125B|*:125C|*:125D|*:125E|*:125F|*:1260|*:1261|*:1262|*:1263|*:1264)
                log "${GREEN}    Тип: Intel I226${NC}"
                ;;
            *)
                log "${YELLOW}    Тип: Неизвестный Intel${NC}"
                ;;
        esac
        
        intel_cards+=("$pci_id")
    done
    
    return 0
}

# Функция обнаружения сетевых интерфейсов
detect_network_interfaces() {
    log "${BLUE}=== Обнаружение сетевых интерфейсов ===${NC}"
    
    local interfaces=()
    local ip_output=$(ip link show)
    
    while IFS= read -r line; do
        if [[ $line =~ ^[0-9]+:\ (eth[0-9]+|en[0-9]+s[0-9]+) ]]; then
            local interface="${BASH_REMATCH[1]}"
            local state=$(ip link show "$interface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
            
            log "${CYAN}Интерфейс: $interface (состояние: $state)${NC}"
            
            # Проверка, что это Intel карта
            if ethtool -i "$interface" 2>/dev/null | grep -qi "intel"; then
                log "${GREEN}  ✅ Intel сетевая карта${NC}"
                interfaces+=("$interface")
            else
                log "${YELLOW}  ⚠️  Не Intel карта${NC}"
            fi
        fi
    done <<< "$ip_output"
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        log "${RED}❌ Intel сетевые интерфейсы не найдены${NC}"
        return 1
    fi
    
    log "${GREEN}Найденные Intel интерфейсы: ${interfaces[*]}${NC}"
    echo "${interfaces[@]}"
}

# Функция проверки hardware timestamping
check_hardware_timestamping() {
    local interface="$1"
    
    log "${BLUE}=== Проверка hardware timestamping для $interface ===${NC}"
    
    # Проверка поддержки timestamping
    local timestamping_output=$(ethtool -T "$interface" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log "${RED}❌ Ошибка получения информации о timestamping${NC}"
        return 1
    fi
    
    log "${CYAN}Поддерживаемые типы timestamping:${NC}"
    echo "$timestamping_output" | grep -E "SOF|SYS|HW" | while read -r line; do
        log "  $line"
    done
    
    # Проверка PTP поддержки
    if echo "$timestamping_output" | grep -qi "ptp"; then
        log "${GREEN}✅ PTP поддержка доступна${NC}"
    else
        log "${YELLOW}⚠️  PTP поддержка не обнаружена${NC}"
    fi
    
    # Проверка hardware timestamping
    if echo "$timestamping_output" | grep -q "hardware"; then
        log "${GREEN}✅ Hardware timestamping поддерживается${NC}"
    else
        log "${RED}❌ Hardware timestamping не поддерживается${NC}"
        return 1
    fi
}

# Функция настройки hardware timestamping
setup_hardware_timestamping() {
    local interface="$1"
    
    log "${BLUE}=== Настройка hardware timestamping для $interface ===${NC}"
    
    # Остановка интерфейса
    log "${YELLOW}Остановка интерфейса $interface...${NC}"
    sudo ip link set "$interface" down
    
    # Включение hardware timestamping
    log "${YELLOW}Включение hardware timestamping...${NC}"
    sudo ethtool -T "$interface" rx-filter on
    
    # Настройка буферов
    log "${YELLOW}Настройка буферов...${NC}"
    sudo ethtool -G "$interface" rx 4096 tx 4096
    
    # Определение максимальной скорости
    local speed_info=$(ethtool "$interface" | grep -E "Speed|Supported link modes")
    log "${CYAN}Информация о скорости:${NC}"
    echo "$speed_info"
    
    # Настройка скорости (автоматическое определение)
    if echo "$speed_info" | grep -q "2500"; then
        log "${YELLOW}Настройка для 2.5 Gbps (Intel I225)...${NC}"
        sudo ethtool -s "$interface" speed 2500 duplex full autoneg off
    else
        log "${YELLOW}Настройка для 1 Gbps...${NC}"
        sudo ethtool -s "$interface" speed 1000 duplex full autoneg off
    fi
    
    # Включение интерфейса
    log "${YELLOW}Включение интерфейса...${NC}"
    sudo ip link set "$interface" up
    
    # Ожидание стабилизации
    sleep 3
    
    # Проверка результата
    log "${CYAN}Проверка настройки:${NC}"
    ethtool -T "$interface" | grep -E "SOF|SYS|HW"
    
    log "${GREEN}✅ Настройка hardware timestamping завершена${NC}"
}

# Функция проверки Quantum-PCI
check_quantum_pci() {
    log "${BLUE}=== Проверка Quantum-PCI ===${NC}"
    
    if [ ! -d "$TIMECARD_SYSFS" ]; then
        log "${RED}❌ Quantum-PCI не найден в $TIMECARD_SYSFS${NC}"
        return 1
    fi
    
    local serial=$(cat "$TIMECARD_SYSFS/serialnum" 2>/dev/null || echo "неизвестно")
    log "${GREEN}✅ Quantum-PCI найден: $serial${NC}"
    
    # Проверка статуса GNSS
    local gnss_sync=$(cat "$TIMECARD_SYSFS/gnss_sync" 2>/dev/null || echo "0")
    if [ "$gnss_sync" = "1" ]; then
        log "${GREEN}✅ GNSS синхронизирован${NC}"
    else
        log "${YELLOW}⚠️  GNSS не синхронизирован${NC}"
    fi
    
    # Проверка источника времени
    local clock_source=$(cat "$TIMECARD_SYSFS/clock_source" 2>/dev/null || echo "неизвестно")
    log "${CYAN}Источник времени: $clock_source${NC}"
    
    return 0
}

# Функция создания конфигурации PTP
create_ptp_config() {
    local interface="$1"
    local config_file="/tmp/ptp4l-intel-test.conf"
    
    log "${BLUE}=== Создание конфигурации PTP ===${NC}"
    
    cat > "$config_file" << EOF
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               24
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[$interface]
network_transport          UDPv4
EOF
    
    log "${GREEN}✅ Конфигурация PTP создана: $config_file${NC}"
    echo "$config_file"
}

# Функция тестирования PTP
test_ptp() {
    local interface="$1"
    local config_file="$2"
    
    log "${BLUE}=== Тестирование PTP для $interface ===${NC}"
    
    # Запуск PTP в фоновом режиме
    log "${YELLOW}Запуск PTP4L...${NC}"
    sudo ptp4l -f "$config_file" -i "$interface" -m > /tmp/ptp4l-output.log 2>&1 &
    local ptp_pid=$!
    
    # Ожидание стабилизации
    log "${YELLOW}Ожидание стабилизации PTP (30 секунд)...${NC}"
    sleep 30
    
    # Проверка статуса PTP
    if kill -0 "$ptp_pid" 2>/dev/null; then
        log "${GREEN}✅ PTP4L запущен (PID: $ptp_pid)${NC}"
        
        # Анализ логов
        log "${CYAN}Анализ PTP логов:${NC}"
        tail -20 /tmp/ptp4l-output.log | while read -r line; do
            if echo "$line" | grep -q "master\|slave\|offset"; then
                log "  $line"
            fi
        done
        
        # Остановка PTP
        log "${YELLOW}Остановка PTP4L...${NC}"
        sudo kill "$ptp_pid"
        wait "$ptp_pid" 2>/dev/null
        
        return 0
    else
        log "${RED}❌ PTP4L не запустился${NC}"
        log "${CYAN}Логи ошибок:${NC}"
        cat /tmp/ptp4l-output.log
        return 1
    fi
}

# Функция тестирования производительности
test_performance() {
    local interface="$1"
    
    log "${BLUE}=== Тестирование производительности $interface ===${NC}"
    
    # Получение IP адреса
    local ip_addr=$(ip addr show "$interface" | grep -oP 'inet \K[0-9.]+' | head -1)
    
    if [ -z "$ip_addr" ]; then
        log "${YELLOW}⚠️  IP адрес не настроен для $interface${NC}"
        return 0
    fi
    
    log "${CYAN}IP адрес: $ip_addr${NC}"
    
    # Тест задержки
    log "${YELLOW}Тест задержки (ping)...${NC}"
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ]; then
        ping -c 10 "$gateway" | tail -1
    else
        log "${YELLOW}Шлюз не найден, пропускаем тест ping${NC}"
    fi
    
    # Тест статистики
    log "${YELLOW}Статистика интерфейса:${NC}"
    ethtool -S "$interface" | grep -E "rx_packets|tx_packets|rx_bytes|tx_bytes|rx_errors|tx_errors" | head -10
    
    # Тест PTP статистики
    if [ -e "/dev/ptp0" ]; then
        log "${YELLOW}PTP статистика:${NC}"
        sudo testptp -d /dev/ptp0 -g
    fi
}

# Функция генерации отчета
generate_report() {
    log "${BLUE}=== Генерация отчета ===${NC}"
    
    local report_file="/tmp/intel-network-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
# Отчет о тестировании Intel сетевых карт
Дата: $(date)
Лог файл: $LOG_FILE

## Обнаруженные устройства
$(lspci | grep -i "intel.*ethernet\|intel.*network")

## Сетевые интерфейсы
$(ip link show | grep -E "eth[0-9]+|en[0-9]+s[0-9]+")

## Hardware timestamping
$(for iface in $(ip link show | grep -E "eth[0-9]+|en[0-9]+s[0-9]+" | cut -d: -f2 | tr -d ' '); do
    if ethtool -i "$iface" 2>/dev/null | grep -qi "intel"; then
        echo "=== $iface ==="
        ethtool -T "$iface" 2>/dev/null | grep -E "SOF|SYS|HW"
    fi
done)

## Quantum-PCI статус
$(if [ -d "$TIMECARD_SYSFS" ]; then
    echo "Serial: $(cat $TIMECARD_SYSFS/serialnum 2>/dev/null)"
    echo "GNSS Sync: $(cat $TIMECARD_SYSFS/gnss_sync 2>/dev/null)"
    echo "Clock Source: $(cat $TIMECARD_SYSFS/clock_source 2>/dev/null)"
else
    echo "Quantum-PCI не найден"
fi)

## Системная информация
$(uname -a)
$(lsb_release -a 2>/dev/null || cat /etc/os-release)

EOF
    
    log "${GREEN}✅ Отчет сохранен: $report_file${NC}"
    echo "$report_file"
}

# Основная функция
main() {
    log "${PURPLE}========================================${NC}"
    log "${PURPLE}  Тестирование Intel сетевых карт      ${NC}"
    log "${PURPLE}  I210, I225, I226 с Quantum-PCI       ${NC}"
    log "${PURPLE}========================================${NC}"
    
    # Проверка зависимостей
    check_dependencies
    
    # Обнаружение Intel карт
    if ! detect_intel_cards; then
        log "${RED}❌ Intel сетевые карты не найдены${NC}"
        exit 1
    fi
    
    # Обнаружение интерфейсов
    local interfaces=($(detect_network_interfaces))
    if [ ${#interfaces[@]} -eq 0 ]; then
        log "${RED}❌ Intel сетевые интерфейсы не найдены${NC}"
        exit 1
    fi
    
    # Проверка Quantum-PCI
    check_quantum_pci
    
    # Тестирование каждого интерфейса
    for interface in "${interfaces[@]}"; do
        log "${PURPLE}--- Тестирование $interface ---${NC}"
        
        # Проверка hardware timestamping
        if check_hardware_timestamping "$interface"; then
            # Настройка hardware timestamping
            setup_hardware_timestamping "$interface"
            
            # Создание конфигурации PTP
            local config_file=$(create_ptp_config "$interface")
            
            # Тестирование PTP
            test_ptp "$interface" "$config_file"
            
            # Тестирование производительности
            test_performance "$interface"
        else
            log "${RED}❌ Hardware timestamping не поддерживается для $interface${NC}"
        fi
        
        log ""
    done
    
    # Генерация отчета
    local report_file=$(generate_report)
    
    log "${GREEN}========================================${NC}"
    log "${GREEN}  Тестирование завершено                ${NC}"
    log "${GREEN}  Лог: $LOG_FILE                        ${NC}"
    log "${GREEN}  Отчет: $report_file                   ${NC}"
    log "${GREEN}========================================${NC}"
}

# Обработка сигналов
trap 'log "${RED}Тестирование прервано${NC}"; exit 1' INT TERM

# Запуск основной функции
main "$@"
