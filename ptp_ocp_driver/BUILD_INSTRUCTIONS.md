# 🚀 Инструкции по сборке Enhanced PTP OCP Driver

## 📋 Предварительные требования

### Системные требования
- **ОС**: Linux (Ubuntu 20.04+, CentOS 8+, Debian 11+)
- **Ядро**: Linux kernel 5.4+ (рекомендуется 5.15+)
- **Архитектура**: x86_64
- **RAM**: минимум 4GB (рекомендуется 8GB+)
- **Диск**: минимум 2GB свободного места

### Зависимости
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y \
    build-essential \
    linux-headers-$(uname -r) \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    nodejs \
    npm

# CentOS/RHEL
sudo yum groupinstall -y "Development Tools"
sudo yum install -y \
    kernel-devel-$(uname -r) \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    nodejs \
    npm
```

### Проверка окружения
```bash
# Проверить версию ядра
uname -r

# Проверить заголовки ядра
ls /usr/src/linux-headers-$(uname -r)

# Проверить компилятор
gcc --version

# Проверить make
make --version
```

## 🔧 Сборка драйвера

### 1. Подготовка исходного кода
```bash
# Перейти в директорию драйвера
cd ptp_ocp_driver

# Проверить структуру
ls -la

# Проверить Makefile
cat Makefile
```

### 2. Компиляция
```bash
# Очистка предыдущих сборок
make clean

# Компиляция драйвера
make

# Проверка результатов
ls -la *.ko
```

### 3. Установка
```bash
# Установка модуля
sudo make install

# Обновление зависимостей модулей
sudo depmod -a

# Проверка установки
ls -la /lib/modules/$(uname -r)/extra/
```

## 🚀 Запуск драйвера

### 1. Загрузка модуля
```bash
# Загрузка драйвера
sudo modprobe ptp_ocp_enhanced

# Проверка загрузки
lsmod | grep ptp_ocp_enhanced

# Проверка устройств
ls -la /dev/ptp*
```

### 2. Использование менеджера
```bash
# Проверка статуса
sudo ./scripts/ptp_ocp_manager.sh status

# Установка через менеджер
sudo ./scripts/ptp_ocp_manager.sh install

# Запуск мониторинга
sudo ./scripts/ptp_ocp_manager.sh monitor
```

## 🧪 Тестирование

### 1. Автоматические тесты
```bash
# Запуск всех тестов
sudo ./tests/run_tests.sh

# Тесты производительности
sudo ./tests/run_tests.sh performance

# Тесты надежности
sudo ./tests/run_tests.sh reliability
```

### 2. Ручное тестирование
```bash
# Проверка sysfs интерфейса
ls -la /sys/class/ptp_ocp_enhanced/

# Проверка производительности
cat /sys/class/ptp_ocp_enhanced/ocp0/performance_stats

# Проверка здоровья системы
cat /sys/class/ptp_ocp_enhanced/ocp0/health_status
```

## 📊 Мониторинг

### 1. Веб-дашборд
```bash
# Запуск дашборда
cd web_interface/dashboard
python3 -m http.server 8080

# Открыть в браузере
firefox http://localhost:8080
```

### 2. Консольный мониторинг
```bash
# Запуск консольного мониторинга
sudo ./scripts/ptp_ocp_manager.sh monitor --console

# Мониторинг логов
tail -f /var/log/ptp_ocp_enhanced.log
```

## 🔧 Настройка

### 1. Конфигурация производительности
```bash
# Включение режима производительности
echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/performance_mode

# Настройка таймаута кэша (1ms)
echo "1000000" > /sys/class/ptp_ocp_enhanced/ocp0/cache_timeout
```

### 2. Конфигурация надежности
```bash
# Включение watchdog
echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/watchdog_enabled

# Включение автоматического восстановления
echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/auto_recovery

# Настройка максимального количества попыток
echo "3" > /sys/class/ptp_ocp_enhanced/ocp0/max_retries
```

### 3. Конфигурация мониторинга
```bash
# Установка уровня логирования
echo "INFO" > /sys/class/ptp_ocp_enhanced/ocp0/log_level

# Включение файлового логирования
echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/file_logging
```

## 🐛 Отладка

### 1. Проверка логов
```bash
# Логи ядра
dmesg | grep ptp_ocp_enhanced

# Логи драйвера
tail -f /var/log/ptp_ocp_enhanced.log

# Debug информация
cat /sys/kernel/debug/ptp_ocp_enhanced/ocp0/*
```

### 2. Диагностика проблем
```bash
# Проверка здоровья системы
cat /sys/class/ptp_ocp_enhanced/ocp0/health_status

# Статистика ошибок
cat /sys/class/ptp_ocp_enhanced/ocp0/error_count

# Статус watchdog
cat /sys/class/ptp_ocp_enhanced/ocp0/watchdog_status
```

### 3. Перезагрузка драйвера
```bash
# Выгрузка драйвера
sudo modprobe -r ptp_ocp_enhanced

# Загрузка драйвера
sudo modprobe ptp_ocp_enhanced

# Или через менеджер
sudo ./scripts/ptp_ocp_manager.sh remove
sudo ./scripts/ptp_ocp_manager.sh install
```

## 📦 Упаковка

### 1. Создание пакета
```bash
# Создание tar архива
tar -czf ptp_ocp_enhanced_v2.0.0.tar.gz ptp_ocp_driver/

# Создание RPM пакета (для CentOS/RHEL)
rpmbuild -ba ptp_ocp_enhanced.spec

# Создание DEB пакета (для Ubuntu/Debian)
dpkg-buildpackage -b
```

### 2. Распространение
```bash
# Проверка целостности
sha256sum ptp_ocp_enhanced_v2.0.0.tar.gz

# Создание подписи
gpg --armor --detach-sign ptp_ocp_enhanced_v2.0.0.tar.gz
```

## 🔄 Обновление

### 1. Обновление драйвера
```bash
# Остановка старой версии
sudo ./scripts/ptp_ocp_manager.sh remove

# Установка новой версии
sudo ./scripts/ptp_ocp_manager.sh install

# Проверка версии
cat /proc/modules | grep ptp_ocp_enhanced
```

### 2. Миграция настроек
```bash
# Сохранение текущих настроек
sudo ./scripts/ptp_ocp_manager.sh status > current_settings.txt

# Восстановление настроек после обновления
# (настройки восстанавливаются автоматически через sysfs)
```

## 🚨 Устранение неполадок

### Частые проблемы

#### 1. Ошибка компиляции
```bash
# Проблема: отсутствуют заголовки ядра
# Решение:
sudo apt install linux-headers-$(uname -r)
# или
sudo yum install kernel-devel-$(uname -r)
```

#### 2. Ошибка загрузки модуля
```bash
# Проблема: модуль не загружается
# Решение:
dmesg | tail -20
sudo modprobe -v ptp_ocp_enhanced
```

#### 3. Отсутствие sysfs интерфейса
```bash
# Проблема: нет sysfs атрибутов
# Решение:
ls -la /sys/class/ptp_ocp_enhanced/
sudo udevadm trigger
```

#### 4. Низкая производительность
```bash
# Проблема: медленная работа
# Решение:
echo "enabled" > /sys/class/ptp_ocp_enhanced/ocp0/performance_mode
echo "500000" > /sys/class/ptp_ocp_enhanced/ocp0/cache_timeout
```

## 📞 Поддержка

### Получение помощи
- **Документация**: [README.md](README.md)
- **Дорожная карта**: [ДОРОЖНАЯ_КАРТА_РАЗВИТИЯ_ДРАЙВЕРА.md](../ДОРОЖНАЯ_КАРТА_РАЗВИТИЯ_ДРАЙВЕРА.md)
- **Логи**: `/var/log/ptp_ocp_enhanced.log`
- **Debug**: `/sys/kernel/debug/ptp_ocp_enhanced/`

### Отчеты об ошибках
При возникновении проблем предоставьте:
1. Версию ядра: `uname -r`
2. Версию драйвера: `cat /proc/modules | grep ptp_ocp_enhanced`
3. Логи ядра: `dmesg | grep ptp_ocp_enhanced`
4. Логи драйвера: `tail -100 /var/log/ptp_ocp_enhanced.log`
5. Статус системы: `sudo ./scripts/ptp_ocp_manager.sh status`

---

*Enhanced PTP OCP Driver v2.0.0 - Инструкции по сборке и развертыванию*
