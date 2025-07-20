# Пользовательский API

## Обзор

Данный документ описывает пользовательский API для работы с драйвером PTP OCP.

## Интерфейсы устройств

### /dev/ptp*

Основной интерфейс для работы с PTP устройством.

#### Основные операции

```c
int fd = open("/dev/ptp0", O_RDWR);
```

### Sysfs интерфейсы

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
ptp4l -i eth0 -m -s /dev/ptp0
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

## Примеры использования

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