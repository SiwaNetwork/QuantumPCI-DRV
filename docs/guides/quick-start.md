# Быстрый старт с Quantum-PCI

## Обзор

Данное руководство поможет вам быстро начать работу с Quantum-PCI и драйвером PTP OCP для временной синхронизации.

## Предварительные требования

### Системные требования

- Linux ядро версии 5.4 или выше
- Поддержка PCI в ядре
- Модули PTP включены в ядро
- Root права для установки драйвера

### Необходимые пакеты

```bash
# Ubuntu/Debian
sudo apt-get install build-essential linux-headers-$(uname -r) git

# CentOS/RHEL/Fedora
sudo yum install gcc kernel-devel kernel-headers git
# или для новых версий
sudo dnf install gcc kernel-devel kernel-headers git
```

## Быстрая установка

### 1. Получение исходного кода

```bash
git clone <repository-url>
cd ptp-ocp-driver
```

### 2. Сборка драйвера

```bash
cd ДРАЙВЕРА
make
```

### 3. Установка драйвера

```bash
sudo make install
sudo modprobe ptp_ocp
```

### 4. Проверка установки

```bash
# Проверка загрузки модуля
lsmod | grep ptp_ocp

# Проверка обнаружения TimeCard устройств
ls /sys/class/timecard/

# Проверка обнаружения PTP устройств
ls /dev/ptp*

# Проверка через dmesg
dmesg | grep ptp_ocp
```

## Первоначальная настройка

### Проверка устройства

```bash
# Проверка TimeCard устройства
if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "TimeCard device found"
    cat /sys/class/timecard/ocp0/serialnum
    cat /sys/class/timecard/ocp0/clock_source
else
    echo "TimeCard device not found"
fi

# Получение PTP устройства из TimeCard
if [ -L "/sys/class/timecard/ocp0/ptp" ]; then
    PTP_DEV=$(basename $(readlink /sys/class/timecard/ocp0/ptp))
    echo "PTP device: /dev/$PTP_DEV"
else
    PTP_DEV="ptp0"
fi

# Получение информации о PTP устройстве
sudo testptp -d /dev/$PTP_DEV -c

# Проверка capabilities
sudo testptp -d /dev/$PTP_DEV -k
```

### Базовая конфигурация

```bash
# Настройка TimeCard (если доступно)
if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "Configuring TimeCard..."
    echo "GNSS" > /sys/class/timecard/ocp0/clock_source
    echo "PPS" > /sys/class/timecard/ocp0/sma3
    echo "TimeCard configured"
fi

# Получение текущего времени
sudo testptp -d /dev/$PTP_DEV -g

# Установка времени (пример)
sudo testptp -d /dev/$PTP_DEV -t $(date +%s)

# Проверка точности
sudo testptp -d /dev/$PTP_DEV -o
```

## Первый тест

### Запуск демона PTP

```bash
# Установка LinuxPTP (если не установлен)
sudo apt-get install linuxptp  # Ubuntu/Debian
# или
sudo yum install linuxptp      # CentOS/RHEL

# Запуск PTP master (используя переменную PTP_DEV из предыдущего раздела)
sudo ptp4l -i eth0 -m -p /dev/$PTP_DEV

# В другом терминале - синхронизация системного времени
sudo phc2sys -s /dev/$PTP_DEV -m
```

### Проверка синхронизации

```bash
# Проверка синхронизации TimeCard (если доступно)
if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "GNSS sync status: $(cat /sys/class/timecard/ocp0/gnss_sync)"
fi

# Проверка offset между PTP и системным временем
sudo phc2sys -s /dev/$PTP_DEV -c CLOCK_REALTIME -O 0 -u 10

# Мониторинг статистики
watch -n 1 'sudo testptp -d /dev/$PTP_DEV -o'
```

## Типичные проблемы и решения

### Драйвер не загружается

```bash
# Проверка ошибок в dmesg
dmesg | tail -20

# Проверка зависимостей
modinfo ptp_ocp

# Принудительная загрузка
sudo insmod ./ptp_ocp.ko
```

### Устройство не обнаружено

```bash
# Проверка PCI устройств
lspci | grep -i ptp
lspci | grep -i time

# Проверка идентификаторов устройств
lspci -nn | grep -E "(1d9b|8086)"
```

### Проблемы с правами доступа

```bash
# Добавление пользователя в группу
sudo usermod -a -G dialout $USER

# Установка правил udev
echo 'SUBSYSTEM=="ptp", GROUP="dialout", MODE="0664"' | sudo tee /etc/udev/rules.d/99-ptp.rules
sudo udevadm control --reload-rules
```

## Следующие шаги

1. **Детальная конфигурация**: См. [configuration.md](configuration.md)
2. **Интеграция в систему**: См. [integration examples](../examples/integration/)
3. **Мониторинг и отладка**: См. [troubleshooting.md](troubleshooting.md)
4. **API документация**: См. [API reference](../api/)

## Полезные команды

### Мониторинг

```bash
# Непрерывный мониторинг времени
watch -n 1 'date; sudo testptp -d /dev/ptp0 -g'

# Статистика PTP
sudo pmc -u -b 0 'GET DEFAULT_DATA_SET'
sudo pmc -u -b 0 'GET CURRENT_DATA_SET'
```

### Отладка

```bash
# Увеличение уровня логирования
echo 8 > /proc/sys/kernel/printk

# Проверка системного лога
journalctl -k -f | grep ptp
```

### Конфигурационные файлы

Примеры конфигурационных файлов находятся в директории `examples/`:

- `basic-setup/` - базовые конфигурации
- `advanced-config/` - продвинутые настройки
- `integration/` - интеграция с другими системами