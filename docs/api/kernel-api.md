# API драйвера ядра

## Обзор

Данный документ описывает API драйвера ядра для работы с устройствами временной синхронизации PTP.

## Основные функции драйвера

### Инициализация и освобождение ресурсов

```c
static int ptp_ocp_probe(struct pci_dev *pdev, const struct pci_device_id *id);
static void ptp_ocp_remove(struct pci_dev *pdev);
```

### Управление устройством

```c
static int ptp_ocp_adjfine(struct ptp_clock_info *ptp_info, long scaled_ppm);
static int ptp_ocp_adjtime(struct ptp_clock_info *ptp_info, s64 delta_ns);
static int ptp_ocp_gettime(struct ptp_clock_info *ptp_info, struct timespec64 *ts);
static int ptp_ocp_settime(struct ptp_clock_info *ptp_info, const struct timespec64 *ts);
```

### GPIO управление

```c
static int ptp_ocp_enable(struct ptp_clock_info *ptp_info, struct ptp_clock_request *rq, int on);
static int ptp_ocp_verify(struct ptp_clock_info *ptp_info, unsigned int pin, enum ptp_pin_function func, unsigned int chan);
```

## Структуры данных

### ptp_ocp

Основная структура драйвера, содержащая:
- Указатели на PCI устройство
- Конфигурацию PTP
- Состояние GPIO
- Конфигурацию синхронизации

### ptp_ocp_ext_info

Информация о внешних источниках синхронизации.

## Интерфейсы ядра

### PTP подсистема

Драйвер интегрируется с подсистемой PTP ядра Linux через структуру `ptp_clock_info`.

### PCI подсистема

Регистрация и управление PCI устройством через стандартные механизмы ядра.

### GPIO подсистема

Управление GPIO через стандартный интерфейс ядра.

## Обработка прерываний

Драйвер использует MSI-X прерывания для обработки событий от аппаратуры.

## Отладка

Для отладки используются стандартные механизмы ядра:
- `dev_dbg()`, `dev_info()`, `dev_warn()`, `dev_err()`
- Sysfs интерфейсы
- Debugfs (при наличии)

## Совместимость

Драйвер совместим с ядрами Linux версии 5.4 и выше.