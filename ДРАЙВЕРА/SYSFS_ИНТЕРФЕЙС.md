# Интерфейс sysfs драйвера PTP OCP TimeCard

## Общее описание

Драйвер PTP OCP создает класс устройства `timecard` в файловой системе sysfs Linux. Каждое обнаруженное устройство TimeCard получает уникальный идентификатор и создается в директории:

```
/sys/class/timecard/ocpN/
```

где `N` - порядковый номер устройства, начиная с 0 (ocp0, ocp1, ocp2, и т.д.).

## Структура директории

Типичная структура директории `/sys/class/timecard/ocp0/`:

```
/sys/class/timecard/ocp0/
├── available_clock_sources      # (r) Доступные источники часов
├── available_sma_inputs         # (r) Доступные входные сигналы для SMA
├── available_sma_outputs        # (r) Доступные выходные сигналы для SMA
├── clock_source                 # (rw) Текущий источник часов
├── device -> ../../../0000:02:00.0  # Ссылка на PCI устройство
├── external_pps_cable_delay     # (rw) Задержка внешнего PPS кабеля (нс)
├── gnss_sync                    # (r) Статус синхронизации GNSS
├── internal_pps_cable_delay     # (rw) Задержка внутреннего PPS кабеля (нс)
├── irig_b_mode                  # (rw) Режим работы IRIG-B
├── pci_delay                    # (rw) Задержка PCIe шины (нс)
├── power/                       # Директория управления питанием
├── ptp -> ../../ptp/ptp4        # Ссылка на PTP устройство
├── serialnum                    # (r) Серийный номер устройства
├── sma1_in                      # (rw) Конфигурация входа SMA1
├── sma2_in                      # (rw) Конфигурация входа SMA2
├── sma3_out                     # (rw) Конфигурация выхода SMA3
├── sma4_out                     # (rw) Конфигурация выхода SMA4
├── subsystem -> ../../../../../../class/timecard  # Ссылка на класс
├── ttyGNSS -> ../../tty/ttyS5   # Ссылка на GNSS порт
├── ttyMAC -> ../../tty/ttyS6    # Ссылка на MAC порт
├── ttyNMEA -> ../../tty/ttyS7   # Ссылка на NMEA порт
├── uevent                       # (r) События устройства
└── utc_tai_offset               # (rw) Смещение UTC относительно TAI
```

*Обозначения: (r) - только чтение, (rw) - чтение и запись*

## Описание атрибутов

### Атрибуты источников времени

#### `clock_source` (rw)
Текущий источник синхронизации часов. Возможные значения:
- `GNSS` - синхронизация с GNSS спутниками
- `MAC` - синхронизация с атомными часами
- `IRIG-B` - синхронизация с сигналом IRIG-B
- `external` - внешний источник синхронизации

Пример использования:
```bash
# Просмотр текущего источника
cat /sys/class/timecard/ocp0/clock_source

# Установка источника
echo "GNSS" > /sys/class/timecard/ocp0/clock_source
```

#### `available_clock_sources` (r)
Список всех доступных источников синхронизации для данного устройства.

### Атрибуты SMA коннекторов

#### `sma[1-4]_in/out` (rw)
Конфигурация SMA коннекторов. Каждый коннектор может быть настроен как вход или выход с различными сигналами.

Возможные входные сигналы:
- `10MHz` - опорная частота 10 МГц
- `PPS` - импульс раз в секунду
- `TS1-TS4` - временные метки
- `IRIG-B` - сигнал IRIG-B
- `DCF77` - радиосигнал времени DCF77

Возможные выходные сигналы:
- `10MHz` - генерация опорной частоты
- `PPS` - генерация PPS
- `GEN[1-4]` - программируемые генераторы

#### `available_sma_inputs/outputs` (r)
Списки всех доступных входных и выходных сигналов для SMA коннекторов.

### Атрибуты калибровки задержек

#### `external_pps_cable_delay` (rw)
Задержка внешнего PPS кабеля в наносекундах. Используется для компенсации задержки распространения сигнала по кабелю.

#### `internal_pps_cable_delay` (rw)
Задержка внутреннего PPS сигнала в наносекундах.

#### `pci_delay` (rw)
Задержка передачи данных через шину PCIe в наносекундах.

### Атрибуты синхронизации

#### `gnss_sync` (r)
Статус синхронизации с GNSS. Возможные значения:
- `locked` - синхронизация установлена
- `unlocked` - нет синхронизации
- `holdover` - режим удержания

#### `utc_tai_offset` (rw)
Смещение UTC относительно TAI (Международное атомное время) в секундах.

### Служебные атрибуты

#### `serialnum` (r)
Серийный номер устройства TimeCard.

#### `irig_b_mode` (rw)
Режим работы с сигналом IRIG-B:
- `B003` - стандартный формат IRIG-B
- `B006` - IEEE-1344 формат
- `disabled` - отключен

## Символические ссылки

### `device`
Ссылка на соответствующее PCI устройство в `/sys/devices/pci*/`.

### `ptp`
Ссылка на PTP устройство в `/sys/class/ptp/`. Используется для доступа к аппаратным часам (PHC).

### `ttyGNSS`, `ttyMAC`, `ttyNMEA`
Ссылки на последовательные устройства для обмена данными с различными компонентами TimeCard.

## Примеры использования

### Базовая конфигурация

```bash
# Установка GNSS как источника времени
echo "GNSS" > /sys/class/timecard/ocp0/clock_source

# Настройка SMA1 как вход для 10MHz
echo "10MHz" > /sys/class/timecard/ocp0/sma1_in

# Настройка SMA3 как выход PPS
echo "PPS" > /sys/class/timecard/ocp0/sma3_out

# Установка задержки кабеля
echo "50" > /sys/class/timecard/ocp0/external_pps_cable_delay
```

### Получение информации о устройстве

```bash
# Серийный номер
cat /sys/class/timecard/ocp0/serialnum

# Статус GNSS
cat /sys/class/timecard/ocp0/gnss_sync

# Доступные источники времени
cat /sys/class/timecard/ocp0/available_clock_sources
```

### Работа с PTP устройством

```bash
# Получение имени PTP устройства
PTP_DEV=$(basename $(readlink /sys/class/timecard/ocp0/ptp))
echo "PTP device: /dev/$PTP_DEV"

# Получение времени с PHC
phc_ctl /dev/$PTP_DEV get
```

### Работа с последовательными портами

```bash
# Получение GNSS порта
GNSS_TTY=$(basename $(readlink /sys/class/timecard/ocp0/ttyGNSS))
echo "GNSS port: /dev/$GNSS_TTY"

# Чтение NMEA сообщений
NMEA_TTY=$(basename $(readlink /sys/class/timecard/ocp0/ttyNMEA))
cat /dev/$NMEA_TTY
```

## Мониторинг изменений

Можно отслеживать изменения атрибутов с помощью inotify:

```bash
# Мониторинг изменений статуса GNSS
inotifywait -m /sys/class/timecard/ocp0/gnss_sync

# Или использовать systemd для создания триггеров
```

## Автоматизация конфигурации

Пример скрипта для автоматической настройки:

```bash
#!/bin/bash
TIMECARD="/sys/class/timecard/ocp0"

# Проверка существования устройства
if [ ! -d "$TIMECARD" ]; then
    echo "TimeCard not found!"
    exit 1
fi

# Настройка
echo "GNSS" > "$TIMECARD/clock_source"
echo "10MHz" > "$TIMECARD/sma1_in"  
echo "PPS" > "$TIMECARD/sma3_out"
echo "100" > "$TIMECARD/external_pps_cable_delay"

echo "TimeCard configured successfully"
```

## Устранение неполадок

### Проверка доступности устройства

```bash
# Проверка наличия класса timecard
ls /sys/class/timecard/

# Проверка PCI устройства
lspci | grep -i timecard
```

### Проверка состояния

```bash
# Проверка всех атрибутов
for attr in /sys/class/timecard/ocp0/*; do
    if [ -f "$attr" ] && [ -r "$attr" ]; then
        echo "$(basename $attr): $(cat $attr 2>/dev/null || echo 'not readable')"
    fi
done
```

### Логи и отладка

```bash
# Проверка сообщений драйвера
dmesg | grep -i ptp_ocp

# Проверка состояния модуля
lsmod | grep ptp_ocp
```