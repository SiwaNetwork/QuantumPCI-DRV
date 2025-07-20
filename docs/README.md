# Документация PTP OCP драйвера

## Обзор

Комплексная документация для драйвера PTP OCP (Precision Time Protocol Open Compute Project), включающая поддержку устройств TimeCard.

## Новые возможности (2024)

### TimeCard sysfs интерфейс

Драйвер теперь создает расширенный интерфейс `/sys/class/timecard/ocpN/` для управления устройствами TimeCard:

- **Настройка источников времени** - GNSS, MAC, IRIG-B, external
- **Управление SMA коннекторами** - конфигурация входов и выходов
- **Калибровка задержек** - компенсация задержек кабелей и системы  
- **Мониторинг синхронизации** - статус GNSS и других источников
- **Автоматическое связывание устройств** - ссылки на PTP и tty устройства

### Комплексная поддержка протоколов точного времени

Добавлена полная поддержка для реализации различных протоколов с PCI картами атомных часов:

- **NTP с аппаратными временными метками** - интеграция с chrony и PHC
- **IEEE 1588-2019 (PTP v2.1)** - новые функции стандарта включая enhanced security
- **White Rabbit** - субнаносекундная синхронизация для научных применений
- **SMPTE timecode** - генерация для вещательных применений (25fps, 29.97fps, 30fps, 24fps)
- **Готовые скрипты интеграции** - автоматизация настройки и мониторинга

## Структура документации

### Руководства пользователя

- [`guides/quick-start.md`](guides/quick-start.md) - Быстрый старт с поддержкой TimeCard
- [`guides/installation.md`](guides/installation.md) - Установка драйвера
- [`guides/configuration.md`](guides/configuration.md) - Детальная конфигурация включая TimeCard
- [`guides/precision-time-protocols.md`](guides/precision-time-protocols.md) - **Комплексное руководство по протоколам точного времени** (NTP, PTP, White Rabbit, SMPTE)
- [`guides/troubleshooting.md`](guides/troubleshooting.md) - Устранение неполадок с TimeCard

### API документация

- [`api/userspace-api.md`](api/userspace-api.md) - API пользователя с TimeCard sysfs
- [`api/kernel-api.md`](api/kernel-api.md) - API ядра

### Инструменты

- [`tools/cli-tools.md`](tools/cli-tools.md) - Команды CLI включая работу с TimeCard
- [`tools/gui-manual.md`](tools/gui-manual.md) - Графические интерфейсы

### Примеры и интеграция

- [`examples/basic-setup/`](examples/basic-setup/) - Базовая настройка включая TimeCard скрипты
- [`examples/basic-setup/timecard-integration-scripts.md`](examples/basic-setup/timecard-integration-scripts.md) - **Готовые скрипты интеграции** для всех протоколов времени
- [`examples/integration/`](examples/integration/) - Интеграция с мониторингом TimeCard
- [`examples/advanced-config/`](examples/advanced-config/) - Продвинутые конфигурации
- [`examples/advanced-config/atomic-clock-ntp.conf`](examples/advanced-config/atomic-clock-ntp.conf) - Конфигурация chrony для атомных часов
- [`examples/advanced-config/ieee1588-2019.conf`](examples/advanced-config/ieee1588-2019.conf) - Конфигурация PTP v2.1 с новыми функциями

## Быстрый старт с TimeCard

```bash
# Проверка устройства TimeCard
ls /sys/class/timecard/

# Базовая настройка
echo "GNSS" > /sys/class/timecard/ocp0/clock_source
echo "PPS" > /sys/class/timecard/ocp0/sma3_out

# Проверка синхронизации
cat /sys/class/timecard/ocp0/gnss_sync

# Получение PTP устройства
PTP_DEV=$(basename $(readlink /sys/class/timecard/ocp0/ptp))
echo "PTP device: /dev/$PTP_DEV"
```

## Автоматизированные скрипты

В папке [`examples/basic-setup/timecard-scripts.md`](examples/basic-setup/timecard-scripts.md) доступны готовые скрипты:

- `configure-timecard.sh` - Автоматическая настройка
- `monitor-timecard.sh` - Мониторинг в реальном времени  
- `diagnose-timecard.sh` - Комплексная диагностика
- `reset-timecard.sh` - Сброс к заводским настройкам

## Мониторинг

Интеграция с системами мониторинга теперь включает метрики TimeCard:

```bash
# Prometheus метрики TimeCard
timecard_device_info{device="ocp0",serial="12345"} 1
timecard_gnss_locked{device="ocp0"} 1
timecard_clock_source_info{device="ocp0",source="GNSS"} 1
```

## Устранение неполадок

### Основные проверки

```bash
# Проверка драйвера
lsmod | grep ptp_ocp

# Проверка устройства
ls /sys/class/timecard/

# Диагностика
sudo diagnose-timecard
```

### Типичные проблемы

1. **TimeCard не обнаружено** - проверьте загрузку драйвера и PCI устройства
2. **GNSS не синхронизируется** - проверьте антенну и подождите до 15 минут
3. **SMA не работают** - проверьте конфигурацию и кабельные соединения
4. **Высокая задержка** - откалибруйте задержки кабелей

## Поддерживаемые устройства

- Facebook TimeCard (PCI ID: 1d9b:0400)
- Celestica TimeCard (PCI ID: 18d4:1008)  
- Orolia ART Card (PCI ID: 1ad7:a000)

## Системные требования

- Linux ядро 5.4+ (рекомендуется 5.15+)
- Root права для настройки
- PCI устройство TimeCard
- GNSS антенна (для синхронизации GNSS)

## Дополнительные ресурсы

- [Основная документация драйвера](../ДРАЙВЕРА/) - Исходная документация и код
- [LinuxPTP Documentation](../LinuxPTP_Documentation.md) - Документация LinuxPTP
- [Chrony Documentation](../Chrony_Documentation.md) - Документация Chrony

## Обратная связь

Для вопросов и предложений по улучшению документации обращайтесь к разработчикам проекта.