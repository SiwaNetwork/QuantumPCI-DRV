#!/bin/bash
# start-real-monitoring.sh - Запуск реального мониторинга TimeCard PTP OCP

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции вывода
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Проверка драйвера TimeCard
check_timecard_driver() {
    print_header "Проверка драйвера TimeCard"
    
    if [ -d "/sys/class/timecard" ]; then
        print_success "Драйвер TimeCard найден"
        
        # Поиск устройств
        devices=$(ls /sys/class/timecard/ 2>/dev/null | wc -l)
        if [ $devices -gt 0 ]; then
            print_success "Найдено устройств: $devices"
            for device in /sys/class/timecard/*; do
                device_id=$(basename $device)
                serial=$(cat $device/serialnum 2>/dev/null || echo "UNKNOWN")
                print_info "  🕐 $device_id: $serial"
            done
        else
            print_warning "Устройства TimeCard не найдены"
        fi
    else
        print_error "Драйвер TimeCard не найден"
        print_info "Убедитесь, что драйвер загружен: sudo modprobe timecard"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    print_header "Проверка зависимостей"
    
    # Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 не установлен"
        exit 1
    fi
    print_success "Python3 найден"
    
    # Flask
    if ! python3 -c "import flask" &> /dev/null; then
        print_warning "Flask не установлен, устанавливаем..."
        pip3 install flask flask-socketio flask-cors
    fi
    print_success "Flask установлен"
    
    # Проверка портов
    if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Порт 8080 уже используется"
    fi
}

# Запуск реального API
start_real_api() {
    print_header "Запуск реального API мониторинга"
    
    cd api
    
    print_info "Запуск TimeCard Real API..."
    nohup python3 timecard-real-api.py > ../real-api.log 2>&1 &
    API_PID=$!
    
    print_info "Ожидание запуска API..."
    sleep 5
    
    # Проверка запуска
    if curl -s http://localhost:8080/api/devices > /dev/null 2>&1; then
        print_success "API запущен успешно (PID: $API_PID)"
    else
        print_error "API не запустился"
        exit 1
    fi
}

# Проверка реальных данных
check_real_data() {
    print_header "Проверка реальных данных"
    
    print_info "Получение данных устройств..."
    devices_response=$(curl -s http://localhost:8080/api/devices)
    device_count=$(echo $devices_response | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['count'])")
    
    if [ $device_count -gt 0 ]; then
        print_success "Найдено устройств: $device_count"
        
        print_info "Получение реальных метрик..."
        metrics_response=$(curl -s http://localhost:8080/api/metrics/real)
        
        # Извлечение ключевых данных
        ptp_offset=$(echo $metrics_response | python3 -c "import sys, json; data=json.load(sys.stdin); device=list(data.keys())[0]; print(data[device]['ptp']['offset_ns'])")
        gnss_status=$(echo $metrics_response | python3 -c "import sys, json; data=json.load(sys.stdin); device=list(data.keys())[0]; print(data[device]['gnss']['sync_status'])")
        
        print_info "📡 PTP Offset: ${ptp_offset} ns"
        print_info "🛰️  GNSS Status: ${gnss_status}"
        
    else
        print_warning "Устройства не найдены"
    fi
}

# Проверка алертов
check_alerts() {
    print_header "Проверка системы алертов"
    
    alerts_response=$(curl -s http://localhost:8080/api/alerts)
    alert_count=$(echo $alerts_response | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['count'])")
    
    if [ $alert_count -gt 0 ]; then
        print_warning "Активных алертов: $alert_count"
        echo $alerts_response | python3 -c "
import sys, json
data = json.load(sys.stdin)
for alert in data['alerts']:
    print(f\"  🚨 {alert['severity'].upper()}: {alert['message']}\")
"
    else
        print_success "Алертов нет"
    fi
}

# Показать информацию о доступе
show_access_info() {
    print_header "Информация о доступе"
    
    echo -e "${GREEN}🌐 Веб-интерфейсы:${NC}"
    echo "  Real Dashboard:    http://localhost:8080/dashboard"
    echo "  API Endpoints:     http://localhost:8080/api/"
    echo "  Main Page:         http://localhost:8080/"
    echo ""
    
    echo -e "${GREEN}📊 API Endpoints:${NC}"
    echo "  Devices:           http://localhost:8080/api/devices"
    echo "  Real Metrics:      http://localhost:8080/api/metrics/real"
    echo "  Alerts:            http://localhost:8080/api/alerts"
    echo "  Device Status:     http://localhost:8080/api/device/ocp0/status"
    echo ""
    
    echo -e "${GREEN}📁 Логи:${NC}"
    echo "  API Log:           ./real-api.log"
    echo ""
}

# Остановка сервисов
stop_services() {
    print_header "Остановка сервисов"
    
    if pkill -f "python.*timecard-real-api" 2>/dev/null; then
        print_success "API остановлен"
    else
        print_info "API не был запущен"
    fi
}

# Проверка статуса
check_status() {
    print_header "Проверка статуса"
    
    if curl -s http://localhost:8080/api/devices > /dev/null 2>&1; then
        print_success "API работает"
        
        # Проверка реальных данных
        metrics_response=$(curl -s http://localhost:8080/api/metrics/real)
        if [ $? -eq 0 ]; then
            print_success "Реальные данные доступны"
            
            # Показать текущие значения
            ptp_offset=$(echo $metrics_response | python3 -c "import sys, json; data=json.load(sys.stdin); device=list(data.keys())[0]; print(data[device]['ptp']['offset_ns'])")
            gnss_status=$(echo $metrics_response | python3 -c "import sys, json; data=json.load(sys.stdin); device=list(data.keys())[0]; print(data[device]['gnss']['sync_status'])")
            
            print_info "📡 PTP Offset: ${ptp_offset} ns"
            print_info "🛰️  GNSS Status: ${gnss_status}"
        else
            print_warning "Реальные данные недоступны"
        fi
    else
        print_error "API не отвечает"
    fi
}

# Главная функция
main() {
    case "${1:-start}" in
        "start")
            check_timecard_driver
            check_dependencies
            start_real_api
            sleep 3
            check_real_data
            check_alerts
            show_access_info
            ;;
            
        "stop")
            stop_services
            ;;
            
        "restart")
            $0 stop
            sleep 2
            $0 start
            ;;
            
        "status")
            check_status
            ;;
            
        "logs")
            if [ -f "real-api.log" ]; then
                tail -f real-api.log
            else
                print_error "Лог файл не найден"
            fi
            ;;
            
        "help"|*)
            echo "Использование: $0 {start|stop|restart|status|logs}"
            echo ""
            echo "Команды:"
            echo "  start   - Запуск реального мониторинга"
            echo "  stop    - Остановка мониторинга"
            echo "  restart - Перезапуск мониторинга"
            echo "  status  - Проверка статуса"
            echo "  logs    - Просмотр логов"
            echo "  help    - Показать эту справку"
            echo ""
            echo "Реальные данные:"
            echo "  📡 PTP offset и drift из драйвера"
            echo "  🛰️  GNSS sync status из драйвера"
            echo "  🔌 SMA connector status из драйвера"
            echo "  🚨 Real-time alerts на основе данных"
            ;;
    esac
}

# Обработка сигналов
trap 'print_info "Получен сигнал прерывания..."; stop_services; exit 0' INT TERM

# Запуск
main "$@" 