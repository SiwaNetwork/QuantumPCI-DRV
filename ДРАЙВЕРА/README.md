# Драйвер PTP OCP

Драйвер ядра Linux для PTP OCP устройств.

## Поддерживаемые устройства

- Quantum-PCI TimeCard (PCI ID: 0x1d9b:0x0400)
- Orolia ART Card (PCI ID: 0x1ad7:0xa000)
- ADVA Timecard (PCI ID: 0x0b0b:0x0410)

Для добавления поддержки новых устройств см. [ДОБАВЛЕНИЕ_НОВЫХ_УСТРОЙСТВ.md](ДОБАВЛЕНИЕ_НОВЫХ_УСТРОЙСТВ.md).

## Документация

### Анализ и структура драйвера
- [АНАЛИЗ_ДРАЙВЕРА.md](АНАЛИЗ_ДРАЙВЕРА.md) — общий анализ функциональности драйвера
- [СТРУКТУРА_ДРАЙВЕРА.md](СТРУКТУРА_ДРАЙВЕРА.md) — архитектура и компоненты драйвера

### Соответствие PCI спецификации
- [СОПОСТАВЛЕНИЕ_PCI_ДРАЙВЕРА.md](СОПОСТАВЛЕНИЕ_PCI_ДРАЙВЕРА.md) — детальное сопоставление функциональности драйвера с требованиями PCI устройств
- [ТАБЛИЦА_СООТВЕТСТВИЯ_PCI.md](ТАБЛИЦА_СООТВЕТСТВИЯ_PCI.md) — таблицы соответствия функций, регистров и требований PCI

### Интерфейсы и использование
- [Sysfs интерфейс](../docs/РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md#интерфейс-sysfs) — подробное описание всех sysfs атрибутов и примеры использования

### Рекомендации и примеры
- [РЕКОМЕНДАЦИИ_ПО_УЛУЧШЕНИЮ.md](РЕКОМЕНДАЦИИ_ПО_УЛУЧШЕНИЮ.md)
- [ПРИМЕР_ДОБАВЛЕНИЯ_УСТРОЙСТВА.c](ПРИМЕР_ДОБАВЛЕНИЯ_УСТРОЙСТВА.c)
- [ПРИМЕР_POWER_MANAGEMENT.c](ПРИМЕР_POWER_MANAGEMENT.c)

## Инструкция

Убедитесь, что опция vt-d включена в BIOS.
Выполните перекомпиляцию (remake), затем загрузите модуль: `modprobe ptp_ocp`.

## Пример вывода sysfs
```
$ ls -g /sys/class/timecard/ocp0/
total 0
-r--r--r--. 1 root 4096 Sep  8 18:20 available_clock_sources
-r--r--r--. 1 root 4096 Sep  8 18:20 available_sma_inputs
-r--r--r--. 1 root 4096 Sep  8 18:20 available_sma_outputs
-rw-r--r--. 1 root 4096 Sep  8 18:20 clock_source
lrwxrwxrwx. 1 root    0 Sep  8 18:20 device -> ../../../0000:02:00.0
-rw-r--r--. 1 root 4096 Sep  8 18:20 external_pps_cable_delay
-r--r--r--. 1 root 4096 Sep  8 18:20 gnss_sync
-rw-r--r--. 1 root 4096 Sep  8 18:20 internal_pps_cable_delay
-rw-r--r--. 1 root 4096 Sep  8 18:20 irig_b_mode
drwxr-xr-x. 2 root    0 Sep  8 18:20 power
lrwxrwxrwx. 1 root    0 Sep  8 18:20 ptp -> ../../ptp/ptp4
-r--r--r--. 1 root 4096 Sep  8 18:20 serialnum
-rw-r--r--. 1 root 4096 Sep  8 18:20 sma1
-rw-r--r--. 1 root 4096 Sep  8 18:20 sma2
-rw-r--r--. 1 root 4096 Sep  8 21:04 sma3
-rw-r--r--. 1 root 4096 Sep  8 21:04 sma4
lrwxrwxrwx. 1 root    0 Sep  8 18:20 subsystem -> ../../../../../../class/timecard
lrwxrwxrwx. 1 root    0 Sep  8 18:20 ttyGNSS -> ../../tty/ttyS5
lrwxrwxrwx. 1 root    0 Sep  8 18:20 ttyGNSS2 -> ../../tty/ttyS?
lrwxrwxrwx. 1 root    0 Sep  8 18:20 ttyMAC -> ../../tty/ttyS6
lrwxrwxrwx. 1 root    0 Sep  8 18:20 ttyNMEA -> ../../tty/ttyS7
-rw-r--r--. 1 root 4096 Sep  8 18:20 uevent
-rw-r--r--. 1 root 4096 Sep  8 18:20 utc_tai_offset
```

Основной каталог ресурсов доступен по адресу `/sys/class/timecard/ocpN/`, где N — номер устройства (например, ocp0, ocp1), предоставляя ссылки на различные ресурсы TimeCard. Ссылки на устройства легко использовать в сценариях:

```
  tty=$(basename $(readlink /sys/class/timecard/ocp0/ttyGNSS))
  ptp=$(basename $(readlink /sys/class/timecard/ocp0/ptp))

  echo "/dev/$tty"
  echo "/dev/$ptp"
```

После успешной загрузки драйвера появляются:
* PTP POSIX clock, связанный с физическими аппаратными часами (PHC) на Quantum Card  (`/dev/ptp4`)
* GNSS serial `/dev/ttyS5`
* GNSS2 serial `/dev/ttyS?` (если поддерживается)
* Atomic clock serial `/dev/ttyS6`
* NMEA Master serial `/dev/ttyS7`
* i2c (`/dev/i2c-*`) device

Теперь можно использовать стандартные инструменты linuxptp, такие как phc2sys или ts2phc для копирования, синхронизации, настройки и т. д.

## Драйвер включен в основное ядро Linux
* Первоначальная примитивная версия ([5.2](https://git.kernel.org/pub/scm/linux/kernel/git/netdev/net-next.git/commit/?id=a7e1abad13f3f0366ee625831fecda2b603cdc17))
* Версия, раскрывающая все устройства ([5.15](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=773bda96492153e11d21eb63ac814669b51fc701))

