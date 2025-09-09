# Скрипты тестирования Intel сетевых карт

Данная папка содержит специализированные скрипты для тестирования и настройки Intel сетевых карт I210, I225, I226 с платой Quantum-PCI.

## Обзор скриптов

### 1. `intel-network-testing.sh` - Комплексное тестирование
**Назначение**: Полное тестирование Intel сетевых карт с детальной диагностикой

**Возможности**:
- Автоматическое обнаружение Intel сетевых карт I210, I225, I226
- Проверка поддержки hardware timestamping
- Настройка hardware timestamping
- Тестирование PTP синхронизации
- Проверка производительности
- Генерация подробного отчета

**Использование**:
```bash
sudo ./intel-network-testing.sh
```

**Выходные файлы**:
- `/tmp/intel-network-test-YYYYMMDD-HHMMSS.log` - Детальный лог тестирования
- `/tmp/intel-network-test-report-YYYYMMDD-HHMMSS.txt` - Отчет о тестировании

### 2. `quick-intel-setup.sh` - Быстрая настройка
**Назначение**: Быстрая настройка и запуск PTP для Intel сетевых карт

**Команды**:
- `setup` - Полная настройка и запуск PTP
- `start` - Запуск PTP
- `stop` - Остановка PTP
- `status` - Показать статус системы
- `help` - Показать справку

**Использование**:
```bash
# Быстрая настройка и запуск
sudo ./quick-intel-setup.sh setup

# Проверка статуса
sudo ./quick-intel-setup.sh status

# Остановка PTP
sudo ./quick-intel-setup.sh stop
```

### 3. `intel-monitoring-integration.py` - Мониторинг
**Назначение**: Интеграция мониторинга Intel сетевых карт с системой Quantum-PCI

**Возможности**:
- Сбор метрик Intel сетевых карт
- Мониторинг PTP статуса
- Генерация отчетов
- Режим демона для непрерывного мониторинга
- Интеграция с веб-системой мониторинга

**Использование**:
```bash
# Сбор метрик
python3 intel-monitoring-integration.py --collect

# Генерация отчета
python3 intel-monitoring-integration.py --report

# Запуск в режиме демона
python3 intel-monitoring-integration.py --daemon --interval 60

# Сохранение метрик в файл
python3 intel-monitoring-integration.py --save /tmp/intel-metrics.json
```

## Системные требования

### Аппаратные требования
- Intel сетевая карта I210, I225 или I226
- Плата Quantum-PCI (опционально)
- Linux система с ядром ≥ 5.4

### Программные требования
```bash
# Ubuntu/Debian
sudo apt-get install -y \
    linuxptp \
    ethtool \
    iperf3 \
    tcpdump \
    python3 \
    python3-pip

# RHEL/CentOS/Fedora
sudo dnf install -y \
    linuxptp \
    ethtool \
    iperf3 \
    tcpdump \
    python3 \
    python3-pip
```

### Python зависимости
```bash
pip3 install flask flask-socketio flask-cors
```

## Быстрый старт

### 1. Проверка системы
```bash
# Проверка Intel сетевых карт
lspci | grep -i "intel.*ethernet"

# Проверка драйверов
lsmod | grep -E "igb|igc|e1000e"

# Проверка Quantum-PCI
ls /sys/class/timecard/
```

### 2. Быстрая настройка
```bash
# Переход в папку скриптов
cd scripts

# Быстрая настройка
sudo ./quick-intel-setup.sh setup

# Проверка статуса
sudo ./quick-intel-setup.sh status
```

### 3. Комплексное тестирование
```bash
# Запуск полного тестирования
sudo ./intel-network-testing.sh

# Просмотр отчета
cat /tmp/intel-network-test-report-*.txt
```

## Интеграция с веб-мониторингом

### Запуск веб-мониторинга с Intel поддержкой
```bash
# Переход в папку мониторинга
cd ../ptp-monitoring

# Запуск системы мониторинга
python3 quantum-pci-monitor.py
```

### Доступные API endpoints
- `http://localhost:8080/api/intel-network` - Метрики Intel сетевых карт
- `http://localhost:8080/api/intel-network/health` - Статус здоровья
- `http://localhost:8080/api/intel-network/ptp` - PTP метрики
- `http://localhost:8080/api/intel-network/interface/<interface>` - Метрики интерфейса

## Конфигурации PTP

Готовые конфигурации PTP доступны в:
- `../docs/examples/advanced-config/intel-ptp-configs.md`

### Основные конфигурации:
- **Базовая** - для Intel I210
- **Высокоскоростная** - для Intel I225 (2.5 Gbps)
- **Оптимизированная** - для Intel I226
- **Телекоммуникационная** - профиль G.8275.1
- **Высокоточная** - максимальная точность
- **Промышленная** - для автоматизации

## Устранение неполадок

### Частые проблемы

#### 1. Intel сетевая карта не обнаружена
```bash
# Проверка PCI устройств
lspci | grep -i intel

# Проверка драйверов
lsmod | grep -E "igb|igc|e1000e"

# Принудительная загрузка драйвера
sudo modprobe igb  # для I210/I226
sudo modprobe igc  # для I225
```

#### 2. Hardware timestamping не работает
```bash
# Проверка поддержки
ethtool -T eth0

# Включение hardware timestamping
sudo ethtool -T eth0 rx-filter on

# Перезагрузка драйвера
sudo modprobe -r igb && sudo modprobe igb
```

#### 3. PTP не синхронизируется
```bash
# Проверка PTP устройств
ls /dev/ptp*

# Проверка времени PTP
sudo testptp -d /dev/ptp0 -g

# Запуск PTP с отладкой
sudo ptp4l -f /etc/ptp4l.conf -i eth0 -m -l 7
```

#### 4. Высокая задержка PTP
```bash
# Оптимизация буферов
sudo ethtool -G eth0 rx 8192 tx 8192

# Настройка скорости
sudo ethtool -s eth0 speed 1000 duplex full autoneg off

# Отключение энергосбережения
echo 'on' | sudo tee /sys/bus/pci/drivers/igb/*/power/control
```

### Диагностические команды

```bash
# Статус интерфейса
ip link show eth0

# Статистика интерфейса
ethtool -S eth0

# Hardware timestamping
ethtool -T eth0

# PTP статистика
sudo testptp -d /dev/ptp0 -g
sudo testptp -d /dev/ptp0 -f

# Системные ресурсы
top -p $(pgrep ptp4l)
```

## Логи и отчеты

### Расположение логов
- **Тестирование**: `/tmp/intel-network-test-*.log`
- **Отчеты**: `/tmp/intel-network-test-report-*.txt`
- **PTP логи**: `/tmp/ptp4l-*.log`
- **Мониторинг**: `/tmp/intel-monitoring.log`

### Просмотр логов
```bash
# Логи тестирования
tail -f /tmp/intel-network-test-*.log

# PTP логи
tail -f /tmp/ptp4l-*.log

# Системные логи
journalctl -u ptp4l -f
```

## Дополнительные ресурсы

### Документация
- [Руководство по тестированию Intel сетевых карт](../docs/guides/intel-network-cards-testing.md)
- [Конфигурации PTP](../docs/examples/advanced-config/intel-ptp-configs.md)
- [Основная документация Quantum-PCI](../docs/README.md)

### Полезные ссылки
- [Intel Ethernet Controller I210/I211 Datasheet](https://www.intel.com/content/www/us/en/ethernet-products/ethernet-controller-i210-i211-datasheet.html)
- [Intel Ethernet Controller I225/I226 Datasheet](https://www.intel.com/content/www/us/en/ethernet-products/ethernet-controller-i225-i226-datasheet.html)
- [LinuxPTP Documentation](http://linuxptp.sourceforge.net/)

## Поддержка

Для получения поддержки:
1. Проверьте логи и отчеты
2. Изучите документацию
3. Обратитесь к разработчикам проекта Quantum-PCI

---

**Версия**: 1.0  
**Дата**: 2025  
**Автор**: AI Assistant  
**Проект**: Quantum-PCI-DRV
