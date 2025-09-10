# Документация Quantum-PCI

## Обзор

Комплексная документация для продукта Quantum-PCI - высокоточной карты синхронизации времени с поддержкой PTP OCP (Precision Time Protocol Open Compute Project) и веб-системой мониторинга.

> 📖 **Главная страница проекта**: См. [основной README](../README.md) в корне репозитория для общего обзора
> 
> 📚 **Полное руководство**: См. [РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md](РУКОВОДСТВО_ПО_ЭКСПЛУАТАЦИИ_Quantum-PCI.md) для детальных инструкций

## Новые возможности (2024)

### 🎯 Веб-система мониторинга v2.0

Добавлена полнофункциональная веб-система мониторинга с множественными интерфейсами:

- **🏠 Главная страница** - http://localhost:8080/ (красивый дашборд)
- **📊 Обычный дашборд** - http://localhost:8080/dashboard
- **🎯 Реалистичный дашборд** - http://localhost:8080/realistic-dashboard
- **🔧 REST API** - http://localhost:8080/api/ (полная документация API)

#### Возможности веб-мониторинга:
- **📊 Базовые PTP метрики** (offset, drift из sysfs)
- **🛰️ GNSS статус синхронизации** (SYNC/LOST)
- **🔌 SMA конфигурация** (разъемы 1-4)
- **📋 Информация об устройстве** (серийный номер, источники времени)
- **🔔 Система алертов** с настраиваемыми порогами
- **📉 Оценка состояния** с базовой диагностикой
- **🔋 WebSocket обновления** в реальном времени

> ⚠️ **Ограничения**: Текущий драйвер `ptp_ocp` предоставляет ограниченный набор метрик. Детальный мониторинг температуры, питания, GNSS созвездий и расширенные PTP метрики пока недоступны. См. [ROADMAP](ptp-monitoring/ROADMAP.md) для планов развития.

### Quantum-PCI sysfs интерфейс

Драйвер создает расширенный интерфейс `/sys/class/timecard/ocpN/` для управления устройствами Quantum-PCI:

- **Настройка источников времени** - GNSS, MAC, IRIG-B, external
- **Управление SMA коннекторами** - конфигурация входов и выходов
- **Калибровка задержек** - компенсация задержек кабелей и системы
- **Мониторинг синхронизации** - статус GNSS и других источников
- **Автоматическое связывание устройств** - ссылки на PTP и tty устройства

### Комплексная поддержка протоколов точного времени

Добавлена полная поддержка для реализации различных протоколов с PCI картами атомных часов:

- **NTP с аппаратными временными метками** - интеграция с chrony и PHC
- **IEEE 1588-2019 (PTP v2.1)** - новые функции стандарта включая enhanced security

- **Готовые скрипты интеграции** - автоматизация настройки и мониторинга

## Структура документации

### Руководства пользователя

- [`guides/quick-start.md`](guides/quick-start.md) - Быстрый старт с Quantum-PCI
- [`guides/installation.md`](guides/installation.md) - Установка драйвера
- [`guides/configuration.md`](guides/configuration.md) - Детальная конфигурация Quantum-PCI
- [`guides/precision-time-protocols.md`](guides/precision-time-protocols.md) - **Комплексное руководство по протоколам точного времени** (NTP, PTP)
- [`guides/intel-network-cards-testing.md`](guides/intel-network-cards-testing.md) - **Тестирование и настройка Intel сетевых карт I210, I225, I226**
- [`guides/troubleshooting.md`](guides/troubleshooting.md) - Устранение неполадок с Quantum-PCI

### API документация

- [`api/userspace-api.md`](api/userspace-api.md) - API пользователя с Quantum-PCI sysfs
- [`api/kernel-api.md`](api/kernel-api.md) - API ядра
- [`api/web-api.md`](api/web-api.md) - **Веб API для мониторинга** (новое)

### Инструменты

- [`tools/cli-tools.md`](tools/cli-tools.md) - Команды CLI для работы с Quantum-PCI
- [`tools/gui-manual.md`](tools/gui-manual.md) - Графические интерфейсы
- [`tools/web-monitoring.md`](tools/web-monitoring.md) - **Руководство по веб-мониторингу** (новое)

### Примеры и интеграция

- [`examples/basic-setup/`](examples/basic-setup/) - Базовая настройка Quantum-PCI
- [`examples/basic-setup/timecard-integration-scripts.md`](examples/basic-setup/timecard-integration-scripts.md) - **Готовые скрипты интеграции** для всех протоколов времени
- [`examples/integration/`](examples/integration/) - Интеграция с мониторингом Quantum-PCI
- [`examples/advanced-config/`](examples/advanced-config/) - Продвинутые конфигурации
- [`examples/advanced-config/atomic-clock-ntp.conf`](examples/advanced-config/atomic-clock-ntp.conf) - Конфигурация chrony для атомных часов
- [`examples/advanced-config/ieee1588-2019.conf`](examples/advanced-config/ieee1588-2019.conf) - Конфигурация PTP v2.1 с новыми функциями

## Быстрый старт

> 📖 **Для быстрого старта** см. [основной README](../README.md#быстрый-старт) в корне репозитория

## Веб-интерфейсы мониторинга

### 🏠 Главная страница
- **URL**: http://localhost:8080/
- **Возможности**:
  - Красивый дашборд с современным дизайном
  - Real-time мониторинг базовых метрик
  - PTP offset/drift мониторинг
  - GNSS sync статус
  - SMA конфигурация
  - Система алертов

### 📊 Обычный дашборд
- **URL**: http://localhost:8080/dashboard
- **Возможности**:
  - Стандартный интерфейс мониторинга
  - Автоматическое обновление каждые 5 секунд
  - Основные метрики в удобном формате
  - Адаптивная сетка карточек

### 🎯 Реалистичный дашборд
- **URL**: http://localhost:8080/realistic-dashboard
- **Возможности**:
  - Реалистичные ожидания от системы
  - Честное отображение ограничений
  - Фокус на доступных метриках
  - Понятные объяснения возможностей

### 🔧 API Reference
- **URL**: http://localhost:8080/api/
- **Extended endpoints**:
  - `/api/devices` - Список TimeCard устройств
  - `/api/device/{id}/status` - Полный статус устройства
  - `/api/metrics/extended` - Расширенные метрики
  - `/api/alerts` - Система алертов
  - `/api/config` - Конфигурация

## Автоматизированные скрипты

В папке [`examples/basic-setup/timecard-scripts.md`](examples/basic-setup/timecard-scripts.md) доступны готовые скрипты:

- `configure-timecard.sh` - Автоматическая настройка
- `monitor-timecard.sh` - Мониторинг в реальном времени
- `diagnose-timecard.sh` - Комплексная диагностика
- `reset-timecard.sh` - Сброс к заводским настройкам

### Скрипты тестирования Intel сетевых карт

В папке [`scripts/`](../scripts/) доступны специализированные скрипты для работы с Intel сетевыми картами:

- [`intel-network-testing.sh`](../scripts/intel-network-testing.sh) - **Комплексное тестирование Intel I210, I225, I226**
- [`quick-intel-setup.sh`](../scripts/quick-intel-setup.sh) - **Быстрая настройка Intel сетевых карт**
- [`intel-monitoring-integration.py`](../scripts/intel-monitoring-integration.py) - **Интеграция мониторинга с системой Quantum-PCI**

#### Быстрый старт с Intel сетевыми картами:
```bash
# Быстрая настройка и запуск PTP
sudo ./scripts/quick-intel-setup.sh setup

# Проверка статуса
sudo ./scripts/quick-intel-setup.sh status

# Комплексное тестирование
sudo ./scripts/intel-network-testing.sh
```

## Мониторинг

> 📊 **Подробная информация о мониторинге** см. [основной README](../README.md#мониторинг) и [ptp-monitoring/README.md](../ptp-monitoring/README.md)

## Устранение неполадок

### Основные проверки

```bash
# Проверка драйвера
lsmod | grep ptp_ocp

# Проверка устройств
ls /sys/class/timecard/

# Проверка веб-сервера
curl http://localhost:8080/api/metrics

# Диагностика
sudo diagnose-timecard
```

### Проблемы с веб-мониторингом

1. **Сервер не запускается** - проверьте зависимости: `pip install -r requirements.txt`
2. **Порт 8080 занят** - измените порт в коде или остановите конфликтующий процесс
3. **API не отвечает** - проверьте логи: `tail -f monitoring.log`
4. **Дашборд не загружается** - проверьте консоль браузера на ошибки JavaScript

### Типичные проблемы Quantum-PCI

1. **Quantum-PCI не обнаружено** - проверьте загрузку драйвера и PCI устройств
2. **GNSS не синхронизируется** - проверьте антенну и подождите до 15 минут
3. **SMA не работают** - проверьте конфигурацию и кабельные соединения
4. **Высокая задержка** - откалибруйте задержки кабелей

## Поддерживаемые устройства

- Quantum-PCI (PCI ID: 1d9b:0400)
- Orolia ART Card (PCI ID: 1ad7:a000)  
- ADVA Timecard (PCI ID: 0b0b:0410)

> 📋 **Системные требования** см. [основной README](../README.md#системные-требования)

## Дополнительные ресурсы

- [Основная документация драйвера](../ДРАЙВЕРА/) - Исходная документация и код
- [LinuxPTP Guide](guides/linuxptp-guide.md) - Документация LinuxPTP
- [Chrony Guide](guides/chrony-guide.md) - Документация Chrony
- [Веб-мониторинг](../ptp-monitoring/) - Система веб-мониторинга

## Обратная связь

Для вопросов и предложений по улучшению документации обращайтесь к разработчикам проекта.
