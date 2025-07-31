# Makefile для BMP280 I2C Driver

.PHONY: all install test clean help

# Переменные
DRIVER_SCRIPT = bmp280_driver.sh
TEST_SCRIPT = test_bmp280.sh
MUX_SCRIPT = setup_mux.sh
README_FILE = README.md

# Цвета для вывода
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
NC = \033[0m # No Color

all: help

# Установка (делает скрипты исполняемыми)
install:
	@echo "$(GREEN)Установка BMP280 драйвера...$(NC)"
	chmod +x $(DRIVER_SCRIPT)
	chmod +x $(TEST_SCRIPT)
	chmod +x $(MUX_SCRIPT)
	@echo "$(GREEN)✓ Скрипты сделаны исполняемыми$(NC)"

# Тестирование
test: install
	@echo "$(YELLOW)Запуск тестов BMP280...$(NC)"
	@if [ -f $(TEST_SCRIPT) ]; then \
		./$(TEST_SCRIPT); \
	else \
		echo "$(RED)✗ Тестовый скрипт не найден$(NC)"; \
		exit 1; \
	fi

# Быстрый тест I2C шины
test-i2c:
	@echo "$(YELLOW)Проверка I2C шины...$(NC)"
	@if command -v i2cdetect >/dev/null 2>&1; then \
		echo "$(GREEN)✓ i2c-tools установлены$(NC)"; \
		echo "$(YELLOW)Настройка мультиплексора I2C...$(NC)"; \
		if i2cset -y 1 0x70 0x0F 2>/dev/null; then \
			echo "$(GREEN)✓ Мультиплексор I2C настроен$(NC)"; \
		else \
			echo "$(YELLOW)ℹ Мультиплексор I2C не найден$(NC)"; \
		fi; \
		i2cdetect -y 1; \
	else \
		echo "$(RED)✗ i2c-tools не установлены$(NC)"; \
		echo "Установите: sudo apt-get install i2c-tools"; \
	fi

# Настройка мультиплексора I2C
setup-mux:
	@echo "$(YELLOW)Настройка мультиплексора I2C...$(NC)"
	@if [ -f $(MUX_SCRIPT) ]; then \
		./$(MUX_SCRIPT); \
	else \
		echo "$(YELLOW)Запуск встроенной настройки мультиплексора...$(NC)"; \
		if i2cset -y 1 0x70 0x0F 2>/dev/null; then \
			echo "$(GREEN)✓ Мультиплексор I2C настроен (все шины активированы)$(NC)"; \
			echo "$(YELLOW)Сканирование I2C устройств:$(NC)"; \
			i2cdetect -y 1; \
		else \
			echo "$(YELLOW)ℹ Мультиплексор I2C не найден или недоступен$(NC)"; \
			echo "$(YELLOW)Это нормально, если мультиплексор не используется$(NC)"; \
		fi; \
	fi

# Проверка датчика
check-sensor:
	@echo "$(YELLOW)Проверка датчика BMP280...$(NC)"
	@if [ -f $(DRIVER_SCRIPT) ]; then \
		./$(DRIVER_SCRIPT) init; \
	else \
		echo "$(RED)✗ Драйвер не найден$(NC)"; \
	fi

# Чтение данных
read-data:
	@echo "$(YELLOW)Чтение данных с датчика...$(NC)"
	@if [ -f $(DRIVER_SCRIPT) ]; then \
		./$(DRIVER_SCRIPT) all; \
	else \
		echo "$(RED)✗ Драйвер не найден$(NC)"; \
	fi

# Мониторинг
monitor:
	@echo "$(YELLOW)Запуск мониторинга...$(NC)"
	@if [ -f $(DRIVER_SCRIPT) ]; then \
		./$(DRIVER_SCRIPT) monitor; \
	else \
		echo "$(RED)✗ Драйвер не найден$(NC)"; \
	fi

# Очистка (удаление временных файлов)
clean:
	@echo "$(YELLOW)Очистка временных файлов...$(NC)"
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete
	@echo "$(GREEN)✓ Очистка завершена$(NC)"

# Проверка зависимостей
check-deps:
	@echo "$(YELLOW)Проверка зависимостей...$(NC)"
	@if command -v i2cdetect >/dev/null 2>&1; then \
		echo "$(GREEN)✓ i2c-tools установлены$(NC)"; \
	else \
		echo "$(RED)✗ i2c-tools не установлены$(NC)"; \
		echo "Установите: sudo apt-get install i2c-tools"; \
	fi
	@if command -v bc >/dev/null 2>&1; then \
		echo "$(GREEN)✓ bc установлен$(NC)"; \
	else \
		echo "$(RED)✗ bc не установлен$(NC)"; \
		echo "Установите: sudo apt-get install bc"; \
	fi

# Показать справку
help:
	@echo "$(GREEN)BMP280 I2C Driver - Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Доступные команды:$(NC)"
	@echo "  make install     - Сделать скрипты исполняемыми"
	@echo "  make setup-mux   - Настроить мультиплексор I2C"
	@echo "  make test        - Запустить полный тест"
	@echo "  make test-i2c    - Проверить I2C шину"
	@echo "  make check-sensor - Проверить датчик"
	@echo "  make read-data   - Прочитать данные"
	@echo "  make monitor     - Запустить мониторинг"
	@echo "  make check-deps  - Проверить зависимости"
	@echo "  make clean       - Очистить временные файлы"
	@echo "  make help        - Показать эту справку"
	@echo ""
	@echo "$(YELLOW)Примеры использования:$(NC)"
	@echo "  make install && make test"
	@echo "  make check-deps && make read-data"
	@echo "  sudo make monitor"

# Информация о проекте
info:
	@echo "$(GREEN)Информация о проекте BMP280:$(NC)"
	@echo "  Драйвер: $(DRIVER_SCRIPT)"
	@echo "  Тест: $(TEST_SCRIPT)"
	@echo "  Мультиплексор: $(MUX_SCRIPT)"
	@echo "  Документация: $(README_FILE)"
	@echo ""
	@echo "$(YELLOW)Файлы проекта:$(NC)"
	@ls -la *.sh *.md 2>/dev/null || echo "Файлы не найдены" 