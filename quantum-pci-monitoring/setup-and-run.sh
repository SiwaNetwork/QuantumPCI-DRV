#!/bin/bash
# setup-and-run.sh - Установка и запуск веб-мониторинга Quantum-PCI

set -e

echo "============================================================================"
echo "🚀 Quantum-PCI Web Monitoring - Setup and Launch"
echo "============================================================================"

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Определяем директорию скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}📁 Рабочая директория: $SCRIPT_DIR${NC}"
echo ""

# Проверка наличия Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 не найден! Установите Python 3.8+${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo -e "${GREEN}✅ Python версия: $PYTHON_VERSION${NC}"

# Проверка pip3
if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
    echo -e "${YELLOW}⚠️  pip3 не найден. Установка...${NC}"
    echo -e "${YELLOW}Выполните: sudo apt install -y python3-pip${NC}"
    echo ""
    echo "Попробуем продолжить без pip3..."
fi

# Попытка установки зависимостей
echo ""
echo -e "${YELLOW}📦 Установка зависимостей...${NC}"

if command -v pip3 &> /dev/null; then
    pip3 install -q -r requirements.txt --user 2>&1 || {
        echo -e "${YELLOW}⚠️  Не удалось установить все зависимости через pip3${NC}"
    }
elif python3 -m pip --version &> /dev/null; then
    python3 -m pip install -q -r requirements.txt --user 2>&1 || {
        echo -e "${YELLOW}⚠️  Не удалось установить все зависимости через python3 -m pip${NC}"
    }
else
    echo -e "${YELLOW}⚠️  pip не доступен, проверяем системные пакеты...${NC}"
fi

# Проверка основных зависимостей
echo ""
echo -e "${YELLOW}🔍 Проверка зависимостей...${NC}"

DEPS_OK=true

python3 -c "import flask" 2>/dev/null || {
    echo -e "${RED}❌ Flask не установлен${NC}"
    DEPS_OK=false
}

python3 -c "import flask_socketio" 2>/dev/null || {
    echo -e "${RED}❌ Flask-SocketIO не установлен${NC}"
    DEPS_OK=false
}

python3 -c "import flask_cors" 2>/dev/null || {
    echo -e "${RED}❌ Flask-CORS не установлен${NC}"
    DEPS_OK=false
}

if [ "$DEPS_OK" = false ]; then
    echo ""
    echo -e "${RED}❌ Не все зависимости установлены!${NC}"
    echo -e "${YELLOW}Выполните следующие команды:${NC}"
    echo ""
    echo "  sudo apt install -y python3-pip"
    echo "  pip3 install -r requirements.txt --user"
    echo ""
    echo -e "${YELLOW}Или установите системные пакеты:${NC}"
    echo "  sudo apt install -y python3-flask python3-flask-socketio python3-flask-cors"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Все зависимости установлены${NC}"

# Проверка драйвера ptp_ocp
echo ""
echo -e "${YELLOW}🔍 Проверка драйвера ptp_ocp...${NC}"
if lsmod | grep -q ptp_ocp; then
    echo -e "${GREEN}✅ Драйвер ptp_ocp загружен${NC}"
else
    echo -e "${YELLOW}⚠️  Драйвер ptp_ocp не загружен${NC}"
    echo -e "${YELLOW}   Мониторинг будет работать в демо-режиме${NC}"
fi

# Проверка устройств
if [ -d "/sys/class/timecard/" ]; then
    DEVICES=$(ls /sys/class/timecard/ 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ Найдено устройств Quantum-PCI: $DEVICES${NC}"
else
    echo -e "${YELLOW}⚠️  Устройства Quantum-PCI не найдены${NC}"
    echo -e "${YELLOW}   Мониторинг будет работать в демо-режиме${NC}"
fi

# Проверка порта 8080
echo ""
echo -e "${YELLOW}🔍 Проверка порта 8080...${NC}"
if lsof -i :8080 &> /dev/null; then
    echo -e "${RED}❌ Порт 8080 уже занят!${NC}"
    echo -e "${YELLOW}Остановите процесс или измените порт${NC}"
    lsof -i :8080
    exit 1
else
    echo -e "${GREEN}✅ Порт 8080 свободен${NC}"
fi

# Инициализация мультиплексора I2C
echo ""
echo -e "${YELLOW}🔧 Инициализация мультиплексора I2C...${NC}"
if command -v i2cset &> /dev/null; then
    echo -e "${YELLOW}   Настройка мультиплексора I2C (адрес 0x70)...${NC}"
    if sudo i2cset -y 1 0x70 0x0F 2>/dev/null; then
        echo -e "${GREEN}✅ Мультиплексор I2C настроен успешно${NC}"
        echo "   Активированы все шины мультиплексора"
    else
        echo -e "${YELLOW}ℹ Мультиплексор I2C не найден или не доступен${NC}"
        echo "   Продолжаем без настройки мультиплексора"
    fi
else
    echo -e "${YELLOW}⚠️  i2cset не найден - пропускаем настройку мультиплексора${NC}"
fi

echo ""

# Запуск мониторинга
echo ""
echo "============================================================================"
echo -e "${GREEN}🎯 Запуск веб-мониторинга Quantum-PCI...${NC}"
echo "============================================================================"
echo ""
echo -e "${GREEN}📊 Dashboard:    http://localhost:8080/realistic-dashboard${NC}"
echo -e "${GREEN}🏠 Main Page:    http://localhost:8080/${NC}"
echo -e "${GREEN}🔧 API:          http://localhost:8080/api/${NC}"
echo -e "${GREEN}🗺️  Roadmap:      http://localhost:8080/api/roadmap${NC}"
echo ""
echo -e "${YELLOW}Для остановки нажмите Ctrl+C${NC}"
echo "============================================================================"
echo ""

# Запуск сервера
python3 quantum-pci-monitor.py









