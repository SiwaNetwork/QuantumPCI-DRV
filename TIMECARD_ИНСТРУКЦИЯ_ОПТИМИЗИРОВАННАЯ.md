# Quantum-PCI TimeCard PTP OCP - Полная инструкция

## 📋 Содержание
1. [Быстрый старт](#быстрый-старт)
2. [Установка драйвера](#установка-драйвера)
3. [Мониторинг системы](#мониторинг-системы)
4. [Управление через sysfs](#управление-через-sysfs)
5. [API и интерфейсы](#api-и-интерфейсы)
6. [Устранение неполадок](#устранение-неполадок)

---

## 🚀 Быстрый старт

### Минимальные требования
- **ОС**: Linux с ядром 5.12+
- **Оборудование**: TimeCard PTP OCP (Rev C+)
- **BIOS**: VT-d включен
- **Python**: 3.7+ (для мониторинга)

### Шаг 1: Установка драйвера
```bash
# Переход в директорию драйвера
cd ДРАЙВЕРА/

# Компиляция и загрузка
./remake
sudo modprobe ptp_ocp

# Проверка установки
ls -la /sys/class/timecard/ocp0/
lspci -d 1d9b:  # Для Quantum-PCI TimeCard
```

### Шаг 2: Запуск мониторинга
```bash
# Переход в директорию мониторинга
cd ptp-monitoring/

# Установка зависимостей
pip install -r requirements.txt

# Запуск расширенной системы
python3 demo-extended.py
```

### Шаг 3: Доступ к интерфейсам
- **📊 Dashboard**: http://localhost:8080/dashboard
- **📱 Mobile PWA**: http://localhost:8080/pwa
- **🔧 API Docs**: http://localhost:8080/api/

---

## 🔧 Установка драйвера

### Поддерживаемые устройства
| Производитель | PCI ID | Модель |
|--------------|--------|--------|
| Quantum-PCI | 0x1d9b:0x0400 | TimeCard |
| Orolia | 0x1ad7:0xa000 | ART Card |
| ADVA | 0x0b0b:0x0410 | Timecard |

### Процесс установки
```bash
# 1. Проверка VT-d в BIOS
dmesg | grep -i vt-d

# 2. Компиляция драйвера
cd ДРАЙВЕРА/
./remake

# 3. Загрузка модуля
sudo modprobe ptp_ocp

# 4. Проверка загрузки
lsmod | grep ptp_ocp
dmesg | tail -20
```

### Создаваемые устройства
После успешной загрузки появятся:
- `/dev/ptp4` - PTP POSIX clock
- `/dev/ttyS5` - GNSS serial
- `/dev/ttyS6` - Atomic clock serial
- `/dev/ttyS7` - NMEA Master serial
- `/dev/i2c-*` - I2C устройство

---

## 📊 Мониторинг системы

### Режимы запуска

#### 1. Расширенный режим (рекомендуется)
```bash
cd ptp-monitoring/
python3 demo-extended.py
```

#### 2. Docker режим (production)
```bash
./start-monitoring-stack.sh start docker
```

#### 3. Базовый режим (legacy)
```bash
python3 demo.py
```

### Функции мониторинга

| Компонент | Метрики | Описание |
|-----------|---------|----------|
| **🌡️ Thermal** | 6 сенсоров | FPGA, осциллятор, плата, ambient, PLL, DDR |
| **⚡ Power** | 4 voltage rails | 3.3V, 1.8V, 1.2V, 12V + потребление тока |
| **🛰️ GNSS** | 4 созвездия | GPS, GLONASS, Galileo, BeiDou |
| **📡 PTP** | Расширенные метрики | Offset, path delay, packet stats |
| **⚡ Oscillator** | Allan deviation | Стабильность, lock status, frequency error |
| **🔧 Hardware** | Статусы | LEDs, SMA, FPGA, network ports |

---

## 🗂️ Управление через sysfs

### Основная директория
```
/sys/class/timecard/ocp0/
```

### Ключевые атрибуты

#### Источник синхронизации
```bash
# Просмотр текущего источника
cat /sys/class/timecard/ocp0/clock_source

# Установка источника (GNSS/MAC/IRIG-B/external)
echo "GNSS" > /sys/class/timecard/ocp0/clock_source
```

#### SMA коннекторы
```bash
# Конфигурация входов/выходов
echo "PPS" > /sys/class/timecard/ocp0/sma1_in
echo "10MHz" > /sys/class/timecard/ocp0/sma3_out
```

#### Калибровка задержек
```bash
# Установка задержек в наносекундах
echo 50 > /sys/class/timecard/ocp0/external_pps_cable_delay
echo 0 > /sys/class/timecard/ocp0/internal_pps_cable_delay
```

#### Быстрый доступ к устройствам
```bash
# Получение путей к устройствам
tty=$(basename $(readlink /sys/class/timecard/ocp0/ttyGNSS))
ptp=$(basename $(readlink /sys/class/timecard/ocp0/ptp))

echo "/dev/$tty"  # /dev/ttyS5
echo "/dev/$ptp"  # /dev/ptp4
```

---

## 🌐 API и интерфейсы

### REST API Endpoints

#### Основные метрики
```bash
# Статус системы
curl http://localhost:8080/api/health

# Расширенные метрики
curl http://localhost:8080/api/metrics/extended

# Список устройств
curl http://localhost:8080/api/devices
```

#### Специализированные метрики
```bash
# PTP метрики
curl http://localhost:8080/api/metrics/ptp/advanced

# Тепловые метрики
curl http://localhost:8080/api/metrics/thermal

# GNSS метрики
curl http://localhost:8080/api/metrics/gnss

# Состояние алертов
curl http://localhost:8080/api/alerts
```

### WebSocket подключение
```javascript
const socket = io();
socket.on('metrics_update', (data) => {
    console.log('New metrics:', data);
});
```

---

## 🐛 Устранение неполадок

### Проблема: Драйвер не загружается
```bash
# Проверка VT-d
dmesg | grep -i vt-d

# Проверка устройства
lspci -d 1d9b: -vv

# Перезагрузка модуля
sudo rmmod ptp_ocp
sudo modprobe ptp_ocp
```

### Проблема: Нет метрик в мониторинге
```bash
# Проверка sysfs
ls -la /sys/class/timecard/

# Проверка прав доступа
sudo chmod 644 /sys/class/timecard/ocp0/*

# Проверка API
curl -v http://localhost:8080/api/health
```

### Проблема: Ошибки WebSocket
```bash
# Проверка портов
sudo lsof -i :8080

# Перезапуск с отладкой
python3 demo-extended.py --debug
```

### Полезные команды диагностики
```bash
# Информация о PTP
sudo ptp4l -i enp1s0 -m

# Статистика PTP
sudo pmc -u -b 0 'GET CURRENT_DATA_SET'

# Мониторинг GNSS
cat /dev/ttyS5 | grep -E 'GGA|RMC'

# Проверка температур
find /sys/class/timecard/ocp0/ -name "*temp*" -exec cat {} \;
```

---

## 📌 Быстрые ссылки

### Документация
- [Структура драйвера](ДРАЙВЕРА/СТРУКТУРА_ДРАЙВЕРА.md)
- [SYSFS интерфейс](ДРАЙВЕРА/SYSFS_ИНТЕРФЕЙС.md)
- [Добавление устройств](ДРАЙВЕРА/ДОБАВЛЕНИЕ_НОВЫХ_УСТРОЙСТВ.md)

### Конфигурационные файлы
- Драйвер: `ДРАЙВЕРА/ptp_ocp.c`
- API: `ptp-monitoring/api/timecard-extended-api.py`
- Dashboard: `ptp-monitoring/web/timecard-dashboard.html`

### Логи и экспорт
```bash
# Экспорт логов
curl http://localhost:8080/api/logs/export > timecard-logs.txt

# Системные логи
journalctl -u ptp4l -f
dmesg | grep ptp_ocp
```

---

## 💡 Советы по оптимизации

1. **Производительность**: Увеличьте интервалы обновления для production
2. **Ресурсы**: Используйте Docker для изоляции сервисов
3. **Мониторинг**: Настройте пороги алертов под ваши требования
4. **Безопасность**: Смените пароли по умолчанию в Grafana

---

*TimeCard PTP OCP - Professional timing solution*