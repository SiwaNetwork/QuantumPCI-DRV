# Справочник ioctl команд

## Обзор

Данный документ содержит полный справочник ioctl команд для работы с PTP устройствами.

## Общие команды PTP

### PTP_CLOCK_GETCAPS

Получение возможностей часов.

**Синтаксис:**
```c
ioctl(fd, PTP_CLOCK_GETCAPS, struct ptp_clock_caps *caps);
```

**Структура:**
```c
struct ptp_clock_caps {
    int max_adj;        /* Максимальная коррекция частоты в ppb */
    int n_alarm;        /* Количество программируемых алармов */
    int n_ext_ts;       /* Количество внешних временных меток */
    int n_per_out;      /* Количество периодических выходов */
    int pps;            /* Поддержка PPS */
    int n_pins;         /* Количество настраиваемых пинов */
    int cross_timestamping; /* Поддержка кросс-временных меток */
    int rsv[13];        /* Зарезервировано */
};
```

### PTP_CLOCK_GETTIME / PTP_CLOCK_GETTIME64

Получение текущего времени.

**Синтаксис:**
```c
ioctl(fd, PTP_CLOCK_GETTIME, struct ptp_clock_time *time);
ioctl(fd, PTP_CLOCK_GETTIME64, struct ptp_clock_time *time);
```

**Структура:**
```c
struct ptp_clock_time {
    __s64 sec;      /* Секунды */
    __u32 nsec;     /* Наносекунды */
    __u32 reserved;
};
```

### PTP_CLOCK_SETTIME / PTP_CLOCK_SETTIME64

Установка времени.

**Синтаксис:**
```c
ioctl(fd, PTP_CLOCK_SETTIME, struct ptp_clock_time *time);
ioctl(fd, PTP_CLOCK_SETTIME64, struct ptp_clock_time *time);
```

### PTP_CLOCK_ADJTIME / PTP_CLOCK_ADJTIME64

Коррекция времени.

**Синтаксис:**
```c
ioctl(fd, PTP_CLOCK_ADJTIME, struct timex *tx);
ioctl(fd, PTP_CLOCK_ADJTIME64, struct __kernel_timex *tx);
```

### PTP_CLOCK_ADJFREQ

Коррекция частоты.

**Синтаксис:**
```c
ioctl(fd, PTP_CLOCK_ADJFREQ, int *ppb);
```

**Параметры:**
- `ppb` - коррекция в частях на миллиард (parts per billion)

## Управление алармами

### PTP_ALARM_SET

Установка аларма.

**Синтаксис:**
```c
ioctl(fd, PTP_ALARM_SET, struct ptp_alarm *alarm);
```

**Структура:**
```c
struct ptp_alarm {
    struct ptp_clock_time time;  /* Время срабатывания */
    __u32 index;                 /* Индекс аларма */
    __u32 reserved[3];
};
```

### PTP_ALARM_CANCEL

Отмена аларма.

**Синтаксис:**
```c
ioctl(fd, PTP_ALARM_CANCEL, __u32 *index);
```

## Управление внешними временными метками

### PTP_EXTTS_REQUEST / PTP_EXTTS_REQUEST2

Запрос внешних временных меток.

**Синтаксис:**
```c
ioctl(fd, PTP_EXTTS_REQUEST, struct ptp_extts_request *req);
ioctl(fd, PTP_EXTTS_REQUEST2, struct ptp_extts_request *req);
```

**Структура:**
```c
struct ptp_extts_request {
    __u32 index;     /* Индекс входа */
    __u32 flags;     /* Флаги конфигурации */
    __u32 rsv[2];    /* Зарезервировано */
};
```

**Флаги:**
- `PTP_ENABLE_FEATURE` - включить функцию
- `PTP_RISING_EDGE` - срабатывание по переднему фронту
- `PTP_FALLING_EDGE` - срабатывание по заднему фронту
- `PTP_STRICT_FLAGS` - строгая проверка флагов

## Управление периодическими выходами

### PTP_PEROUT_REQUEST / PTP_PEROUT_REQUEST2

Настройка периодического выхода.

**Синтаксис:**
```c
ioctl(fd, PTP_PEROUT_REQUEST, struct ptp_perout_request *req);
ioctl(fd, PTP_PEROUT_REQUEST2, struct ptp_perout_request *req);
```

**Структура:**
```c
struct ptp_perout_request {
    union {
        struct ptp_clock_time start;  /* Время начала */
        struct ptp_clock_time phase;  /* Фаза */
    };
    struct ptp_clock_time period;     /* Период */
    __u32 index;                      /* Индекс выхода */
    __u32 flags;                      /* Флаги */
    union {
        struct ptp_clock_time on;     /* Время включения */
        __u32 rsv[4];                 /* Зарезервировано */
    };
};
```

## Управление GPIO пинами

### PTP_PIN_GETFUNC / PTP_PIN_GETFUNC2

Получение функции пина.

**Синтаксис:**
```c
ioctl(fd, PTP_PIN_GETFUNC, struct ptp_pin_desc *desc);
ioctl(fd, PTP_PIN_GETFUNC2, struct ptp_pin_desc *desc);
```

### PTP_PIN_SETFUNC / PTP_PIN_SETFUNC2

Установка функции пина.

**Синтаксис:**
```c
ioctl(fd, PTP_PIN_SETFUNC, struct ptp_pin_desc *desc);
ioctl(fd, PTP_PIN_SETFUNC2, struct ptp_pin_desc *desc);
```

**Структура:**
```c
struct ptp_pin_desc {
    char name[64];       /* Имя пина */
    __u32 index;         /* Индекс пина */
    __u32 func;          /* Функция пина */
    __u32 chan;          /* Канал */
    __u32 rsv[5];        /* Зарезервировано */
};
```

**Функции пина:**
- `PTP_PF_NONE` - не используется
- `PTP_PF_EXTTS` - внешняя временная метка
- `PTP_PF_PEROUT` - периодический выход
- `PTP_PF_PHYSYNC` - физическая синхронизация

## Системные команды

### PTP_SYS_OFFSET / PTP_SYS_OFFSET_PRECISE / PTP_SYS_OFFSET_EXTENDED

Измерение смещения системных часов.

**Синтаксис:**
```c
ioctl(fd, PTP_SYS_OFFSET, struct ptp_sys_offset *offset);
ioctl(fd, PTP_SYS_OFFSET_PRECISE, struct ptp_sys_offset_precise *offset);
ioctl(fd, PTP_SYS_OFFSET_EXTENDED, struct ptp_sys_offset_extended *offset);
```

## Коды возврата

Все ioctl команды возвращают:
- `0` при успехе
- `-1` при ошибке (errno устанавливается соответственно)

**Основные коды ошибок:**
- `ENOTTY` - неподдерживаемая команда
- `EINVAL` - неверные параметры
- `EBUSY` - ресурс занят
- `EPERM` - недостаточно прав
- `EIO` - ошибка ввода-вывода