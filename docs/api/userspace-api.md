# Пользовательский API

## Обзор

Данный документ описывает пользовательский API для работы с драйвером PTP.

## Интерфейсы устройств

### /dev/ptp*

Основной интерфейс для работы с PTP устройством.

#### Основные операции

```c
int fd = open("/dev/ptp0", O_RDWR);
```

### Sysfs интерфейсы

#### /sys/class/timecard/ocpN/

Основной интерфейс драйвера PTP для управления устройствами TimeCard:

**Основные атрибуты:**
- `clock_source` - текущий источник синхронизации (GNSS, MAC, IRIG-B, external)
- `available_clock_sources` - список доступных источников времени
- `sma[1-4]` - конфигурация SMA коннекторов (вход/выход)
- `available_sma_inputs/outputs` - доступные сигналы для SMA портов

**Атрибуты синхронизации:**
- `gnss_sync` - статус синхронизации GNSS (locked/unlocked/holdover)
- `external_pps_cable_delay` - задержка внешнего PPS кабеля (нс)
- `internal_pps_cable_delay` - задержка внутреннего PPS кабеля (нс)
- `utc_tai_offset` - смещение UTC относительно TAI (секунды)
- `holdover` - режим holdover (включен/выключен)
- `tod_protocol` - протокол TOD (NMEA/GPSTM)
- `available_tod_protocols` - список доступных TOD протоколов
- `tod_baud_rate` - скорость UART для TOD (нс)
- `available_tod_baud_rates` - список доступных скоростей TOD
- `tod_correction` - коррекция TOD (нс)

**Служебные атрибуты:**
- `serialnum` - серийный номер устройства
- `irig_b_mode` - режим работы IRIG-B
- `mac_i2c` - управление I2C для MAC (атомных часов)
- `ts_window_adjust` - коррекция окна временных меток (нс)
- `clock_status_drift` - статус дрейфа часов (ppb)
- `clock_status_offset` - статус смещения часов (нс)
- `uevent` - события устройства

**Бинарные файлы:**
- `config` - конфигурация устройства (CONFIG_SIZE байт)
- `disciplining_config` - конфигурация дисциплинирования (ART_CONFIG_SIZE байт)
- `temperature_table` - температурная таблица (ART_TEMP_TABLE_SIZE байт)

**Символические ссылки:**
- `device` -> `../../../XXXX:XX:XX.X` - ссылка на PCI устройство
- `ptp` -> `../../ptp/ptpX` - ссылка на PTP устройство
- `ttyGNSS` -> `../../tty/ttyX` - ссылка на GNSS порт
- `ttyGNSS2` -> `../../tty/ttyX` - ссылка на вторичный GNSS порт (опционально)
- `ttyMAC` -> `../../tty/ttyX` - ссылка на MAC порт
- `ttyNMEA` -> `../../tty/ttyX` - ссылка на NMEA порт
- `i2c` -> `../../i2c/i2c-X` - ссылка на I2C шину (если доступна)

#### /sys/class/ptp/ptp*/

Системные атрибуты PTP устройства:

- `clock_name` - имя часов
- `max_adjustment` - максимальная коррекция частоты
- `n_alarm` - количество алармов
- `n_external_timestamps` - количество внешних временных меток
- `n_periodic_outputs` - количество периодических выходов
- `n_pins` - количество GPIO пинов

#### /sys/bus/pci/devices/*/

PCI специфичные атрибуты:

- `vendor` - ID производителя
- `device` - ID устройства
- `subsystem_vendor` - ID подсистемы производителя
- `subsystem_device` - ID подсистемы устройства

## Библиотечные функции

### libptp

Стандартная библиотека для работы с PTP:

```c
#include <linux/ptp_clock.h>

struct ptp_clock_caps caps;
ioctl(fd, PTP_CLOCK_GETCAPS, &caps);
```

### Управление временем

```c
struct ptp_clock_time time;
ioctl(fd, PTP_CLOCK_GETTIME, &time);
ioctl(fd, PTP_CLOCK_SETTIME, &time);
```

### Коррекция частоты

```c
int ppb = 1000; // 1 ppm
ioctl(fd, PTP_CLOCK_ADJFREQ, &ppb);
```

## Утилиты командной строки

### ptp4l

Демон PTP версии 4:

```bash
ptp4l -i eth0 -m -p /dev/ptp0
```

### phc2sys

Синхронизация системных часов с PTP:

```bash
phc2sys -s /dev/ptp0 -m
```

### testptp

Тестовая утилита:

```bash
testptp -d /dev/ptp0 -g
```

## Примеры использования API

### Работа с TimeCard через sysfs

```bash
# Проверка доступных устройств TimeCard
ls /sys/class/timecard/

# Настройка источника времени
echo "GNSS" > /sys/class/timecard/ocp0/clock_source

# Проверка синхронизации GNSS
cat /sys/class/timecard/ocp0/gnss_sync

# Настройка SMA коннекторов
echo "10MHz" > /sys/class/timecard/ocp0/sma1
echo "PPS" > /sys/class/timecard/ocp0/sma3

# Получение PTP устройства из TimeCard
PTP_DEV=$(basename $(readlink /sys/class/timecard/ocp0/ptp))
echo "PTP device: /dev/$PTP_DEV"
```

### Получение времени

```c
#include <sys/ioctl.h>
#include <linux/ptp_clock.h>

int get_ptp_time(int fd, struct timespec *ts) {
    struct ptp_clock_time pct;
    int ret = ioctl(fd, PTP_CLOCK_GETTIME, &pct);
    if (ret == 0) {
        ts->tv_sec = pct.sec;
        ts->tv_nsec = pct.nsec;
    }
    return ret;
}
```

### Установка времени

```c
int set_ptp_time(int fd, const struct timespec *ts) {
    struct ptp_clock_time pct;
    pct.sec = ts->tv_sec;
    pct.nsec = ts->tv_nsec;
    return ioctl(fd, PTP_CLOCK_SETTIME, &pct);
}
```

## Обработка ошибок

Все функции возвращают стандартные коды ошибок errno:

- `ENODEV` - устройство не найдено
- `EPERM` - недостаточно прав
- `EINVAL` - неверные параметры
- `EIO` - ошибка ввода-вывода