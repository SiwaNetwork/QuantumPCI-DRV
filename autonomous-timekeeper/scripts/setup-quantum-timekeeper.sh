#!/bin/bash

# Автоматическая настройка Quantum-PCI как хранителя времени
# Для карт БЕЗ навигационных приемников GNSS
# Автор: Quantum-PCI Team
# Дата: 2025-10-06

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Функции для вывода сообщений
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_scenario() {
    echo -e "${PURPLE}[SCENARIO]${NC} $1"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Этот скрипт должен запускаться с правами root"
        log_info "Использование: sudo $0"
        exit 1
    fi
}

# Проверка наличия chrony
check_chrony() {
    log_info "Проверка установки Chrony..."
    
    if ! command -v chronyd >/dev/null 2>&1; then
        log_info "Установка Chrony..."
        if command -v apt >/dev/null 2>&1; then
            apt update
            apt install -y chrony ntpdate bc
        elif command -v yum >/dev/null 2>&1; then
            yum install -y chrony ntpdate bc
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y chrony ntpdate bc
        else
            log_error "Не удалось определить пакетный менеджер"
            exit 1
        fi
    fi
    
    local version=$(chronyd --version | head -1)
    log_success "Chrony установлен: $version"
}

# Проверка Quantum-PCI устройства
check_quantum_pci() {
    log_info "Проверка Quantum-PCI устройства..."
    
    if [ ! -d "/sys/class/timecard/ocp0" ]; then
        log_error "Quantum-PCI устройство не найдено"
        log_info "Убедитесь, что драйвер ptp_ocp загружен:"
        log_info "  sudo modprobe ptp_ocp"
        log_info "  lsmod | grep ptp_ocp"
        exit 1
    fi
    
    local clock_source=$(cat /sys/class/timecard/ocp0/clock_source 2>/dev/null || echo "N/A")
    local gnss_sync=$(cat /sys/class/timecard/ocp0/gnss_sync 2>/dev/null || echo "N/A")
    local serial=$(cat /sys/class/timecard/ocp0/serialnum 2>/dev/null || echo "N/A")
    
    log_success "Quantum-PCI обнаружено:"
    echo "  - Серийный номер: $serial"
    echo "  - Источник времени: $clock_source"
    echo "  - GNSS статус: $gnss_sync"
    
    # Проверяем PTP устройства
    local ptp_devices=$(ls /dev/ptp* 2>/dev/null || true)
    if [ -n "$ptp_devices" ]; then
        log_success "PTP устройства найдены:"
        for device in $ptp_devices; do
            echo "  - $device"
        done
    else
        log_error "PTP устройства не найдены"
        exit 1
    fi
    
    return 0
}

# Создание резервной копии конфигурации
backup_config() {
    local config_file="/etc/chrony/chrony.conf"
    local backup_file="/etc/chrony/chrony.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    log_info "Создание резервной копии конфигурации..."
    
    if [ -f "$config_file" ]; then
        cp "$config_file" "$backup_file"
        log_success "Резервная копия создана: $backup_file"
    else
        log_warning "Файл конфигурации не найден: $config_file"
    fi
}

# Создание конфигурации Time Keeper
create_timekeeper_config() {
    local config_file="/etc/chrony/chrony.conf"
    
    log_info "Создание конфигурации Quantum-PCI Time Keeper..."
    
    # Определяем правильное PTP устройство
    local ptp_device="/dev/ptp1"
    if [ ! -c "$ptp_device" ]; then
        ptp_device="/dev/ptp0"
        if [ ! -c "$ptp_device" ]; then
            log_error "PTP устройство не найдено"
            exit 1
        fi
    fi
    
    log_info "Используется PTP устройство: $ptp_device"
    
    # Создание конфигурации
    cat > "$config_file" << EOF
# Конфигурация Quantum-PCI как хранителя времени
# Сценарий: NTP серверы + Quantum-PCI fallback (БЕЗ GNSS)
# Создано скриптом setup-quantum-timekeeper.sh
# Дата: $(date)

# =============================================================================
# ИСТОЧНИКИ ВРЕМЕНИ (в порядке приоритета)
# =============================================================================

# 1. NTP серверы из интернета как ОСНОВНЫЕ источники времени
server 0.pool.ntp.org iburst minpoll 4 maxpoll 10 prefer
server 1.pool.ntp.org iburst minpoll 4 maxpoll 10 prefer
server 2.pool.ntp.org iburst minpoll 4 maxpoll 10 prefer
server 3.pool.ntp.org iburst minpoll 4 maxpoll 10 prefer

# 2. Дополнительные высокоточные NTP серверы
server time.google.com iburst minpoll 4 maxpoll 10
server time.cloudflare.com iburst minpoll 4 maxpoll 10
server ntp.ubuntu.com iburst minpoll 4 maxpoll 10

# 3. Quantum-PCI как резервный источник (низший приоритет)
# Высокоточный генератор используется при недоступности NTP
refclock PHC $ptp_device poll 3 dpoll -2 offset 0 stratum 2 precision 1e-9

# =============================================================================
# НАСТРОЙКИ АВТОНОМНОГО ХРАНЕНИЯ (HOLDOVER)
# =============================================================================

# Файл для сохранения информации о дрейфе часов
driftfile /var/lib/chrony/drift

# =============================================================================
# НАСТРОЙКИ СИНХРОНИЗАЦИИ
# =============================================================================

# Быстрая начальная синхронизация
makestep 1.0 3

# Синхронизация RTC с системными часами
rtcsync

# Плавная коррекция времени
smoothtime 400 0.01 leaponly

# =============================================================================
# НАСТРОЙКИ ТОЧНОСТИ И СТАБИЛЬНОСТИ
# =============================================================================

# Максимальное отклонение частоты (ppm)
maxupdateskew 100.0

# Соотношение коррекции времени
corrtimeratio 3

# Максимальный дрейф частоты (ppm) - увеличен для автономной работы
maxdrift 1000

# Максимальная дистанция до источника (секунды)
maxdistance 1.0

# Минимальное количество источников для синхронизации
minsources 2

# Настройки для точной синхронизации с NTP
maxchange 100 1 2

# =============================================================================
# НАСТРОЙКИ NTP СЕРВЕРА
# =============================================================================

# Локальный NTP сервер для сети
local stratum 2

# Разрешение доступа для локальной сети
allow 192.168.0.0/16
allow 10.0.0.0/8
allow 172.16.0.0/12

# Порт NTP
port 123

# =============================================================================
# ЛОГИРОВАНИЕ И МОНИТОРИНГ
# =============================================================================

# Директория для логов
logdir /var/log/chrony

# Типы логируемой информации
log tracking measurements statistics

# Логирование изменений больше указанного значения (секунды)
logchange 0.001

# =============================================================================
# БЕЗОПАСНОСТЬ
# =============================================================================

# Адреса для команд управления
bindcmdaddress 127.0.0.1
bindcmdaddress ::1

# Разрешение команд
cmdallow 127.0.0.1
cmdallow ::1

# =============================================================================
# ОБРАБОТКА LEAP SECONDS
# =============================================================================

# Режим обработки leap seconds
leapsecmode slew
maxslewrate 83333.333

# =============================================================================
# НАСТРОЙКИ ДЛЯ ВЫСОКОЙ НАГРУЗКИ
# =============================================================================

# Ограничение скорости запросов
ratelimit interval 1 burst 16 leak 2

# Ограничения для клиентов
clientloglimit 1048576
EOF
    
    log_success "Конфигурация создана: $config_file"
}

# Настройка прав доступа
setup_permissions() {
    log_info "Настройка прав доступа..."
    
    # Права на PTP устройства
    local ptp_devices=$(ls /dev/ptp* 2>/dev/null || true)
    for device in $ptp_devices; do
        chmod 666 "$device" 2>/dev/null || true
        log_success "Права установлены для $device"
    done
    
    # Создание директории для логов
    mkdir -p /var/log/chrony
    chown chrony:chrony /var/log/chrony 2>/dev/null || true
    log_success "Директория логов создана: /var/log/chrony"
}

# Перезапуск службы
restart_service() {
    log_info "Перезапуск службы chronyd..."
    
    systemctl restart chrony
    sleep 5
    
    if systemctl is-active --quiet chrony; then
        log_success "Служба chronyd успешно перезапущена"
    else
        log_error "Ошибка при перезапуске службы chronyd"
        systemctl status chrony
        return 1
    fi
    
    # Включение автозапуска
    systemctl enable chrony
    log_success "Автозапуск chrony включен"
}

# Проверка конфигурации
verify_config() {
    log_info "Проверка конфигурации..."
    
    # Проверка синтаксиса (останавливаем chrony для проверки)
    systemctl stop chrony >/dev/null 2>&1 || true
    sleep 2
    
    if chronyd -f /etc/chrony/chrony.conf -n -d -t 1 >/dev/null 2>&1; then
        log_success "Синтаксис конфигурации корректен"
    else
        log_error "Ошибка в синтаксисе конфигурации"
        return 1
    fi
    
    # Запускаем chrony обратно
    systemctl start chrony >/dev/null 2>&1 || true
}

# Ожидание синхронизации и проверка статуса
wait_and_check_sync() {
    log_info "Ожидание синхронизации (60 секунд)..."
    sleep 60
    
    log_info "Проверка статуса синхронизации..."
    
    # Проверка статуса
    local tracking_output=$(chronyc tracking 2>/dev/null || true)
    if [ -n "$tracking_output" ]; then
        log_success "Статус синхронизации:"
        echo "$tracking_output" | sed 's/^/  /'
    else
        log_warning "Не удалось получить статус синхронизации"
    fi
    
    # Проверка источников
    local sources_output=$(chronyc sources -v 2>/dev/null || true)
    if [ -n "$sources_output" ]; then
        log_success "Источники времени:"
        echo "$sources_output" | sed 's/^/  /'
    else
        log_warning "Не удалось получить список источников"
    fi
}

# Создание скрипта мониторинга
create_monitoring_script() {
    local script_path="/usr/local/bin/quantum-timekeeper-monitor.sh"
    
    log_info "Создание скрипта мониторинга..."
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Мониторинг Quantum-PCI как хранителя времени

echo "=== Мониторинг Quantum-PCI Time Keeper ==="
echo "Время: $(date)"
echo

echo "--- Статус синхронизации ---"
chronyc tracking
echo

echo "--- Источники времени ---"
chronyc sources -v
echo

echo "--- Статистика источников ---"
chronyc sourcestats
echo

echo "--- Quantum-PCI статус ---"
if [ -d /sys/class/timecard/ocp0 ]; then
    echo "Clock source: $(cat /sys/class/timecard/ocp0/clock_source 2>/dev/null || echo 'N/A')"
    echo "GNSS sync: $(cat /sys/class/timecard/ocp0/gnss_sync 2>/dev/null || echo 'N/A')"
    echo "Clock drift: $(cat /sys/class/timecard/ocp0/clock_status_drift 2>/dev/null || echo 'N/A')"
    echo "Clock offset: $(cat /sys/class/timecard/ocp0/clock_status_offset 2>/dev/null || echo 'N/A')"
else
    echo "TimeCard sysfs недоступен"
fi
echo

echo "--- Сетевые клиенты ---"
chronyc clients 2>/dev/null || echo "Информация о клиентах недоступна"
echo

echo "--- Системное время ---"
echo "System time: $(date)"
echo "UTC time: $(date -u)"
echo "Uptime: $(uptime)"
EOF
    
    chmod +x "$script_path"
    log_success "Скрипт мониторинга создан: $script_path"
}

# Создание скрипта тестирования сценария
create_test_script() {
    local script_path="/usr/local/bin/test-timekeeper-scenario.sh"
    
    log_info "Создание скрипта тестирования сценария..."
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Скрипт тестирования сценария Time Keeper

echo "=== Тестирование сценария Quantum-PCI Time Keeper ==="
echo

# Функция для проверки статуса
check_status() {
    echo "--- Проверка $1 ---"
    chronyc tracking | grep -E "(Reference time|System time|Last offset|RMS offset)"
    echo
}

# Исходное состояние
echo "1. Исходное состояние (с сетью):"
check_status "с сетью"

# Симуляция потери сети (блокировка NTP трафика)
echo "2. Симуляция потери сети..."
echo "   (ВНИМАНИЕ: Это заблокирует NTP трафик на 30 секунд)"
read -p "Продолжить? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Блокировка NTP трафика
    iptables -A OUTPUT -p udp --dport 123 -j DROP
    echo "   NTP трафик заблокирован"
    
    # Ожидание переключения
    echo "   Ожидание переключения на Quantum-PCI (30 сек)..."
    sleep 30
    
    # Проверка статуса после потери сети
    echo "3. Состояние после потери сети:"
    check_status "без сети"
    
    # Восстановление сети
    echo "4. Восстановление сети..."
    iptables -D OUTPUT -p udp --dport 123 -j DROP
    echo "   NTP трафик восстановлен"
    
    # Ожидание восстановления
    echo "   Ожидание восстановления синхронизации (30 сек)..."
    sleep 30
    
    # Финальная проверка
    echo "5. Финальное состояние:"
    check_status "после восстановления"
else
    echo "Тестирование отменено"
fi

echo "=== Тестирование завершено ==="
EOF
    
    chmod +x "$script_path"
    log_success "Скрипт тестирования создан: $script_path"
}

# Основная функция
main() {
    echo "=========================================="
    echo "🕐 Настройка Quantum-PCI Time Keeper"
    echo "=========================================="
    echo
    
    log_scenario "СЦЕНАРИЙ: Quantum-PCI как хранитель времени (БЕЗ GNSS)"
    log_scenario "1. NTP серверы - основные источники времени (UTC синхронизация)"
    log_scenario "2. Quantum-PCI - резервный источник при потере сети"
    log_scenario "3. Высокоточный генератор обеспечивает стабильность"
    log_scenario "4. Автономная работа при недоступности NTP серверов"
    echo
    
    check_root
    check_chrony
    check_quantum_pci
    backup_config
    create_timekeeper_config
    setup_permissions
    restart_service
    verify_config
    wait_and_check_sync
    create_monitoring_script
    create_test_script
    
    echo
    log_success "Настройка завершена успешно!"
    echo
    log_info "Полезные команды:"
    log_info "  - Мониторинг: /usr/local/bin/quantum-timekeeper-monitor.sh"
    log_info "  - Тестирование: /usr/local/bin/test-timekeeper-scenario.sh"
    log_info "  - Статус: chronyc tracking"
    log_info "  - Источники: chronyc sources -v"
    log_info "  - Перезапуск: systemctl restart chrony"
    echo
    log_info "Файлы конфигурации:"
    log_info "  - Основной: /etc/chrony/chrony.conf"
    log_info "  - Резервная копия: /etc/chrony/chrony.conf.backup.*"
    log_info "  - Логи: /var/log/chrony/"
    echo
    log_info "NTP сервер доступен для клиентов на порту 123"
    log_info "Разрешенные сети: 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12"
    echo
    log_info "Документация:"
    log_info "  - Руководство: docs/guides/quantum-pci-timekeeper-guide.md"
    echo
    echo "=========================================="
    echo "✅ Настройка завершена"
    echo "=========================================="
}

# Запуск основной функции
main "$@"
