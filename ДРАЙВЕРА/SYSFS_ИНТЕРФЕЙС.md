# Интерфейс sysfs драйвера PTP OCP TimeCard

## Общее описание

Драйвер PTP OCP создает класс устройства `timecard` в файловой системе sysfs Linux. Каждое обнаруженное устройство TimeCard получает уникальный идентификатор и создается в директории:

```
/sys/class/timecard/ocpN/
```

где `N` - порядковый номер устройства, начиная с 0 (ocp0, ocp1, ocp2, и т.д.).

> 📌 **Примечание**: Для базовых примеров использования sysfs см. раздел "Управление через sysfs" в [TIMECARD_ИНСТРУКЦИЯ_ОПТИМИЗИРОВАННАЯ.md](../TIMECARD_ИНСТРУКЦИЯ_ОПТИМИЗИРОВАННАЯ.md)

## Полная структура директории

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
├── ts_window_adjust             # (rw) Коррекция окна временной метки (нс)
├── power/                       # Директория управления питанием
├── ptp -> ../../ptp/ptp4        # Ссылка на PTP устройство
├── serialnum                    # (r) Серийный номер устройства
├── sma1                          # (rw) Конфигурация SMA1 (IN:/OUT: <signal>)
├── sma2                          # (rw) Конфигурация SMA2 (IN:/OUT: <signal>)
├── sma3                          # (rw) Конфигурация SMA3 (IN:/OUT: <signal>)
├── sma4                          # (rw) Конфигурация SMA4 (IN:/OUT: <signal>)
├── subsystem -> ../../../../../../class/timecard  # Ссылка на класс
├── ttyGNSS -> ../../tty/ttyS5   # Ссылка на GNSS порт
├── ttyMAC -> ../../tty/ttyS6    # Ссылка на MAC порт
├── ttyNMEA -> ../../tty/ttyS7   # Ссылка на NMEA порт
├── uevent                       # (r) События устройства
└── utc_tai_offset               # (rw) Смещение UTC относительно TAI
```

*Обозначения: (r) - только чтение, (rw) - чтение и запись*

## Детальное описание атрибутов

### Атрибуты источников времени

#### `clock_source` (rw)
Текущий источник синхронизации часов. Возможные значения:
- `GNSS` - синхронизация с GNSS спутниками
- `MAC` - синхронизация с атомными часами
- `IRIG-B` - синхронизация с сигналом IRIG-B
- `external` - внешний источник синхронизации

#### `available_clock_sources` (r)
Список всех доступных источников синхронизации для данного устройства.

### Атрибуты SMA коннекторов

#### `sma[1-4]` (rw)
Конфигурация SMA коннекторов. Формат значения:

```
IN: <signal>
OUT: <signal>
```

Списки допустимых значений см. в `available_sma_inputs`/`available_sma_outputs`.

Возможные входные сигналы:
- `10MHz` - опорная частота 10 МГц
- `PPS` - импульс раз в секунду
- `TS1-TS4` - временные метки
- `IRIG-B` - сигнал IRIG-B
- `DCF77` - радиосигнал времени DCF77

Дополнительно:
- `tod_protocol`/`available_tod_protocols` — выбор протокола TOD
- `clock_status_drift`, `clock_status_offset` — статус частоты/смещения
- `tod_baud_rate` — скорость UART для TOD
- `holdover` — признак удержания
- `mac_i2c` — доступ к I2C MAC

Возможные выходные сигналы:
- `10MHz` - генерация опорной частоты
- `PPS` - генерация PPS
- `GEN[1-4]` - программируемые генераторы

#### `available_sma_inputs/outputs` (r)
Списки всех доступных входных и выходных сигналов для SMA коннекторов.

### Атрибуты калибровки задержек

#### `external_pps_cable_delay` (rw)
Задержка внешнего PPS кабеля в наносекундах (ns). Используется для компенсации задержки распространения сигнала по кабелю.

#### `internal_pps_cable_delay` (rw)
Задержка внутреннего PPS сигнала в наносекундах (ns).

#### `ts_window_adjust` (rw)
Коррекция окна временной метки в наносекундах (ns) — компенсация оценки задержки PCIe.

### Атрибуты синхронизации

#### `gnss_sync` (r)
Статус синхронизации с GNSS. Возможные значения и формат:

```
SYNC
LOST @ <timestamp>
```

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

### `ttyGNSS`, `ttyGNSS2`, `ttyMAC`, `ttyNMEA`
Ссылки на последовательные устройства для обмена данными с различными компонентами TimeCard.

## Расширенные примеры использования

### Автоматизация конфигурации

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
echo "IN: 10MHz" > "$TIMECARD/sma1"
echo "OUT: PPS" > "$TIMECARD/sma3"
echo "100" > "$TIMECARD/external_pps_cable_delay"

echo "TimeCard configured successfully"
```

### Дополнительные примеры

#### Настройка TOD

```bash
# Протокол TOD (выбор из available_tod_protocols)
echo "NMEA" > /sys/class/timecard/ocp0/tod_protocol

# Скорость UART для TOD (выбор из available_tod_baud_rates)
echo "9600" > /sys/class/timecard/ocp0/tod_baud_rate

# Коррекция TOD в секундах (может быть отрицательной)
echo "-1" > /sys/class/timecard/ocp0/tod_correction
```

#### Режим IRIG-B

```bash
# Режим IRIG-B, см. доступные значения (0..7)
echo "3" > /sys/class/timecard/ocp0/irig_b_mode
```

#### Holdover

```bash
# Установка режима удержания (0..3)
echo "1" > /sys/class/timecard/ocp0/holdover
```

### Мониторинг изменений

Можно отслеживать изменения атрибутов с помощью inotify или udev правил. 