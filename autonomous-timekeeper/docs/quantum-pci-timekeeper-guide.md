# Руководство по настройке Quantum-PCI как хранителя времени

## 🎯 Обзор

Данное руководство описывает настройку карты Quantum-PCI в качестве **хранителя времени** (Time Keeper) для случаев, когда карта поставляется **без навигационных приемников GNSS**. В этом сценарии Quantum-PCI использует свой высокоточный генератор для автономного ведения времени при пропадании NTP серверов.

## 📋 Сценарий использования

### Когда применяется:
- Quantum-PCI карта **без GNSS приемника**
- Требуется **автономное хранение времени** при потере сети
- Нужна **высокая стабильность** частоты генератора
- Система должна работать как **NTP сервер** для локальной сети

### Преимущества:
- ✅ **Автономная работа** без ограничений по времени
- ✅ **Высокая стабильность** частоты генератора
- ✅ **NTP сервер** для локальной сети
- ✅ **Плавные переходы** между режимами работы
- ✅ **Коррекция дрейфа** при восстановлении сети

## 🔧 Требования

### Аппаратные требования:
- Quantum-PCI карта с высокоточным генератором
- Загруженный драйвер `ptp_ocp`
- Доступ к `/sys/class/timecard/` и `/dev/ptp*`

### Программные требования:
- Linux с поддержкой PTP
- Chrony 4.5+
- Python 3.8+ (для мониторинга)
- Права root для настройки

## 📦 Установка и настройка

### 1. Проверка аппаратуры

```bash
# Проверка загрузки драйвера
lsmod | grep ptp_ocp

# Проверка обнаружения устройства
ls -la /sys/class/timecard/

# Проверка PTP устройств
ls -la /dev/ptp*

# Проверка статуса Quantum-PCI
cat /sys/class/timecard/ocp0/clock_source
cat /sys/class/timecard/ocp0/gnss_sync
```

**Ожидаемый результат:**
- Драйвер загружен
- Устройство `ocp0` обнаружено
- PTP устройства `/dev/ptp0` и `/dev/ptp1` доступны
- GNSS статус: `LOST` или `UNKNOWN` (нормально для карт без GNSS)

### 2. Установка зависимостей

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install chrony ntpdate bc

# RHEL/CentOS/Fedora
sudo yum install chrony ntpdate bc
# или
sudo dnf install chrony ntpdate bc
```

### 3. Конфигурация Chrony

Создайте файл конфигурации `/etc/chrony/chrony.conf`:

```bash
# Конфигурация Quantum-PCI как хранителя времени
# Сценарий: NTP серверы + Quantum-PCI fallback

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
refclock PHC /dev/ptp1 poll 3 dpoll -2 offset 0 stratum 2 precision 1e-9

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
```

### 4. Настройка прав доступа

```bash
# Права на PTP устройства
sudo chmod 666 /dev/ptp*

# Создание директории для логов
sudo mkdir -p /var/log/chrony
sudo chown chrony:chrony /var/log/chrony
```

### 5. Запуск и проверка

```bash
# Перезапуск службы
sudo systemctl restart chrony

# Включение автозапуска
sudo systemctl enable chrony

# Проверка статуса
sudo systemctl status chrony

# Ожидание синхронизации (30-60 секунд)
sleep 60

# Проверка синхронизации
chronyc tracking

# Проверка источников
chronyc sources -v
```

## 🔍 Мониторинг и диагностика

### Создание скрипта мониторинга

Создайте файл `/usr/local/bin/quantum-timekeeper-monitor.sh`:

```bash
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
```

Сделайте скрипт исполняемым:

```bash
sudo chmod +x /usr/local/bin/quantum-timekeeper-monitor.sh
```

### Ключевые команды мониторинга

```bash
# Основной мониторинг
/usr/local/bin/quantum-timekeeper-monitor.sh

# Статус синхронизации
chronyc tracking

# Источники времени
chronyc sources -v

# Статистика источников
chronyc sourcestats

# Проверка клиентов NTP
chronyc clients

# Проверка логов
sudo tail -f /var/log/chrony/chrony.log
```

## 🚨 Устранение неполадок

### Проблема: Quantum-PCI не обнаруживается

**Симптомы:**
- `ls /sys/class/timecard/` пустая
- `ls /dev/ptp*` не показывает устройства

**Решение:**
```bash
# Проверка загрузки драйвера
lsmod | grep ptp_ocp

# Загрузка драйвера
sudo modprobe ptp_ocp

# Проверка PCI устройства
lspci | grep -i quantum
```

### Проблема: Большой offset

**Симптомы:**
- Offset > 1 секунды
- Quantum-PCI помечается как "falseticker"

**Решение:**
```bash
# Применение коррекции времени
sudo chronyc makestep

# Проверка правильного PTP устройства
ls -la /dev/ptp*

# Обновление конфигурации для правильного устройства
# В /etc/chrony/chrony.conf изменить:
# refclock PHC /dev/ptp0 на refclock PHC /dev/ptp1
```

### Проблема: NTP серверы недоступны

**Симптомы:**
- Все NTP серверы помечены как "?"
- Система не синхронизируется

**Решение:**
```bash
# Проверка сетевого подключения
ping -c 3 8.8.8.8

# Проверка доступности NTP серверов
ntpdate -q 0.pool.ntp.org

# Временное использование только Quantum-PCI
# В /etc/chrony/chrony.conf закомментировать NTP серверы
```

### Проблема: Высокий дрейф частоты

**Симптомы:**
- Частые коррекции времени
- Нестабильная синхронизация

**Решение:**
```bash
# Увеличение maxdrift в конфигурации
# maxdrift 1000 -> maxdrift 2000

# Проверка температуры (если доступно)
cat /sys/class/timecard/ocp0/temperature_table 2>/dev/null || echo "Температурный мониторинг недоступен"
```

## 📊 Оптимизация производительности

### Настройки для высокой точности

```bash
# В /etc/chrony/chrony.conf добавить:

# Более частый опрос источников
server 0.pool.ntp.org iburst minpoll 3 maxpoll 6

# Строгие ограничения для точности
maxdistance 0.5
maxchange 50 1 2

# Улучшенное логирование
logchange 0.0001
```

### Настройки для стабильности

```bash
# В /etc/chrony/chrony.conf добавить:

# Менее частый опрос для экономии ресурсов
server 0.pool.ntp.org iburst minpoll 6 maxpoll 12

# Более мягкие ограничения
maxdistance 2.0
maxchange 200 1 2

# Увеличенный дрейф для автономной работы
maxdrift 2000
```

## 🔄 Автоматизация и обслуживание

### Создание скрипта автоматической настройки

```bash
#!/bin/bash
# Автоматическая настройка Quantum-PCI как хранителя времени

set -e

echo "=== Настройка Quantum-PCI Time Keeper ==="

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Этот скрипт должен запускаться с правами root"
    exit 1
fi

# Проверка Quantum-PCI
if [ ! -d "/sys/class/timecard/ocp0" ]; then
    echo "Ошибка: Quantum-PCI устройство не найдено"
    exit 1
fi

# Создание резервной копии конфигурации
cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.backup.$(date +%Y%m%d_%H%M%S)

# Установка конфигурации
cat > /etc/chrony/chrony.conf << 'EOF'
# [Конфигурация из раздела 3]
EOF

# Настройка прав доступа
chmod 666 /dev/ptp*
mkdir -p /var/log/chrony
chown chrony:chrony /var/log/chrony

# Перезапуск службы
systemctl restart chrony
systemctl enable chrony

echo "Настройка завершена успешно!"
echo "Проверьте статус: chronyc tracking"
```

### Настройка автоматического мониторинга

```bash
# Добавление в crontab
sudo crontab -e

# Добавить строку:
*/5 * * * * /usr/local/bin/quantum-timekeeper-monitor.sh >> /var/log/quantum-timekeeper.log 2>&1
```

## 📈 Метрики и KPI

### Ключевые показатели эффективности

1. **Точность синхронизации:**
   - Offset < 10 мс (отлично)
   - Offset < 100 мс (хорошо)
   - Offset > 100 мс (требует внимания)

2. **Стабильность частоты:**
   - Дрейф < 100 ppm (отлично)
   - Дрейф < 500 ppm (хорошо)
   - Дрейф > 500 ppm (требует калибровки)

3. **Доступность:**
   - Uptime > 99.9%
   - Время восстановления < 30 секунд

### Мониторинг через веб-интерфейс

Используйте веб-мониторинг Quantum-PCI для визуального контроля:

```bash
# Запуск веб-мониторинга
cd /home/shiwa-time/QuantumPCI-DRV/quantum-pci-monitoring
python3 api/quantum-pci-realistic-api.py
```

Доступ к интерфейсу: http://localhost:8080

## 🔒 Безопасность

### Рекомендации по безопасности

1. **Ограничение доступа к NTP серверу:**
   ```bash
   # В /etc/chrony/chrony.conf
   allow 192.168.1.0/24  # Только локальная сеть
   deny all
   ```

2. **Мониторинг подозрительной активности:**
   ```bash
   # Проверка клиентов
   chronyc clients
   
   # Логирование запросов
   log measurements
   ```

3. **Регулярное обновление:**
   ```bash
   # Обновление системы
   sudo apt update && sudo apt upgrade
   
   # Проверка конфигурации
   chronyd -t
   ```

## 📚 Дополнительные ресурсы

### Полезные ссылки

- [Chrony Documentation](https://chrony.tuxfamily.org/documentation.html)
- [PTP Hardware Clock](https://www.kernel.org/doc/html/latest/driver-api/ptp.html)
- [Quantum-PCI Driver](https://github.com/SiwaNetwork/QuantumPCI-DRV)

### Команды для отладки

```bash
# Подробная диагностика
chronyc sources -v
chronyc sourcestats -v
chronyc tracking -v

# Проверка системных часов
hwclock --show
timedatectl status

# Анализ логов
sudo journalctl -u chrony -f
sudo tail -f /var/log/chrony/chrony.log
```

## ✅ Заключение

Данное руководство позволяет настроить Quantum-PCI как надежный хранитель времени для случаев, когда карта поставляется без навигационных приемников. Система обеспечивает:

- **Высокую точность** синхронизации с NTP серверами
- **Автономную работу** при потере сети
- **Стабильность** высокоточного генератора
- **NTP сервер** для локальной сети
- **Мониторинг** и диагностику системы

При правильной настройке система обеспечивает точность времени в пределах 10 мс и может работать автономно неограниченное время при потере сетевого подключения.
