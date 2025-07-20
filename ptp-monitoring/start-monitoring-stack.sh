#!/bin/bash
# start-monitoring-stack.sh - Запуск полной системы мониторинга TimeCard

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

# Проверка зависимостей
check_dependencies() {
    print_header "Проверка зависимостей"
    
    # Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен"
        exit 1
    fi
    print_success "Docker найден"
    
    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose не установлен"
        exit 1
    fi
    print_success "Docker Compose найден"
    
    # Проверка портов
    local ports=(3000 8080 9090 9091 9093 9100 9009)
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Порт $port уже используется"
        fi
    done
}

# Создание директорий
create_directories() {
    print_header "Создание директорий"
    
    mkdir -p config/grafana/dashboards
    mkdir -p config/grafana/provisioning/datasources
    mkdir -p config/grafana/provisioning/dashboards
    mkdir -p data/prometheus
    mkdir -p data/grafana
    mkdir -p data/alertmanager
    mkdir -p data/victoria
    
    print_success "Директории созданы"
}

# Установка зависимостей Python
install_python_deps() {
    print_header "Установка зависимостей Python"
    
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        print_info "Создание виртуального окружения..."
        python3 -m venv venv
        source venv/bin/activate
    fi
    
    print_info "Установка пакетов..."
    pip install --break-system-packages -r requirements.txt
    
    print_success "Зависимости установлены"
}

# Запуск с помощью Docker Compose
start_with_docker() {
    print_header "Запуск с Docker Compose"
    
    print_info "Сборка и запуск контейнеров..."
    docker-compose up -d --build
    
    print_info "Ожидание запуска сервисов..."
    sleep 30
    
    # Проверка статуса сервисов
    print_info "Проверка статуса сервисов..."
    docker-compose ps
    
    print_success "Docker Compose запущен"
}

# Запуск в development режиме
start_development() {
    print_header "Запуск в Development режиме"
    
    install_python_deps
    
    print_info "Запуск TimeCard API..."
    python demo-extended.py &
    API_PID=$!
    
    print_info "Ожидание запуска API..."
    sleep 10
    
    print_info "Запуск Prometheus Exporter..."
    python api/prometheus-exporter.py &
    EXPORTER_PID=$!
    
    print_success "Development сервисы запущены"
    print_info "API PID: $API_PID"
    print_info "Exporter PID: $EXPORTER_PID"
    
    # Сохранение PID для остановки
    echo $API_PID > .api.pid
    echo $EXPORTER_PID > .exporter.pid
}

# Остановка development сервисов
stop_development() {
    print_header "Остановка Development сервисов"
    
    if [[ -f .api.pid ]]; then
        API_PID=$(cat .api.pid)
        if kill -0 $API_PID 2>/dev/null; then
            kill $API_PID
            print_success "API остановлен"
        fi
        rm .api.pid
    fi
    
    if [[ -f .exporter.pid ]]; then
        EXPORTER_PID=$(cat .exporter.pid)
        if kill -0 $EXPORTER_PID 2>/dev/null; then
            kill $EXPORTER_PID
            print_success "Exporter остановлен"
        fi
        rm .exporter.pid
    fi
}

# Проверка статуса сервисов
check_services() {
    print_header "Проверка сервисов"
    
    local services=(
        "TimeCard API:http://localhost:8080/api/health"
        "TimeCard Dashboard:http://localhost:8080"
        "Prometheus Exporter:http://localhost:9090/metrics"
        "Prometheus:http://localhost:9091"
        "Grafana:http://localhost:3000"
        "AlertManager:http://localhost:9093"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -ra ADDR <<< "$service"
        name="${ADDR[0]}"
        url="${ADDR[1]}:${ADDR[2]}"
        
        if curl -s --max-time 5 "$url" > /dev/null 2>&1; then
            print_success "$name доступен"
        else
            print_warning "$name недоступен ($url)"
        fi
    done
}

# Просмотр логов
view_logs() {
    print_header "Просмотр логов"
    
    if [[ "$1" == "docker" ]]; then
        docker-compose logs -f
    else
        print_info "Логи Development режима:"
        if [[ -f .api.pid ]]; then
            print_info "API запущен (PID: $(cat .api.pid))"
        fi
        if [[ -f .exporter.pid ]]; then
            print_info "Exporter запущен (PID: $(cat .exporter.pid))"
        fi
    fi
}

# Показать информацию о доступе
show_access_info() {
    print_header "Информация о доступе"
    
    echo -e "${GREEN}🌐 Веб-интерфейсы:${NC}"
    echo "  TimeCard Dashboard:    http://localhost:8080"
    echo "  Grafana:              http://localhost:3000 (admin:timecard123)"
    echo "  Prometheus:           http://localhost:9091"
    echo "  AlertManager:         http://localhost:9093"
    echo ""
    
    echo -e "${GREEN}📊 API Endpoints:${NC}"
    echo "  Health Check:         http://localhost:8080/api/health"
    echo "  Extended Metrics:     http://localhost:8080/api/metrics/extended"
    echo "  Alerts:              http://localhost:8080/api/alerts"
    echo "  Prometheus Metrics:   http://localhost:9090/metrics"
    echo ""
    
    echo -e "${GREEN}📁 Директории данных:${NC}"
    echo "  Prometheus:           ./data/prometheus"
    echo "  Grafana:             ./data/grafana"
    echo "  AlertManager:        ./data/alertmanager"
    echo ""
}

# Главная функция
main() {
    case "${1:-start}" in
        "start")
            check_dependencies
            create_directories
            
            if [[ "${2:-docker}" == "docker" ]]; then
                start_with_docker
            else
                start_development
            fi
            
            sleep 10
            check_services
            show_access_info
            ;;
            
        "stop")
            if [[ "${2:-docker}" == "docker" ]]; then
                print_header "Остановка Docker Compose"
                docker-compose down
                print_success "Docker сервисы остановлены"
            else
                stop_development
            fi
            ;;
            
        "restart")
            $0 stop $2
            sleep 5
            $0 start $2
            ;;
            
        "status")
            check_services
            ;;
            
        "logs")
            view_logs $2
            ;;
            
        "clean")
            print_header "Очистка данных"
            docker-compose down -v
            sudo rm -rf data/
            print_success "Данные очищены"
            ;;
            
        "help"|*)
            echo "Использование: $0 {start|stop|restart|status|logs|clean} [docker|dev]"
            echo ""
            echo "Команды:"
            echo "  start [docker|dev]  - Запуск системы мониторинга"
            echo "  stop [docker|dev]   - Остановка системы"
            echo "  restart [docker|dev]- Перезапуск системы"
            echo "  status             - Проверка статуса сервисов"
            echo "  logs [docker|dev]  - Просмотр логов"
            echo "  clean              - Очистка всех данных"
            echo "  help               - Показать эту справку"
            echo ""
            echo "Режимы:"
            echo "  docker (по умолчанию) - Запуск в Docker контейнерах"
            echo "  dev                   - Запуск в development режиме"
            echo ""
            echo "Примеры:"
            echo "  $0 start docker       # Запуск с Docker"
            echo "  $0 start dev          # Запуск в dev режиме"
            echo "  $0 logs docker        # Просмотр логов Docker"
            ;;
    esac
}

# Обработка сигналов
trap 'print_info "Получен сигнал прерывания..."; stop_development; exit 0' INT TERM

# Запуск
main "$@"