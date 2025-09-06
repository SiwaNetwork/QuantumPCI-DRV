# Руководство по веб-мониторингу Quantum-PCI

## ⚠️ ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ О ОГРАНИЧЕНИЯХ

**Система мониторинга Quantum-PCI ограничена возможностями ptp_ocp драйвера Linux.**

### Доступные метрики (РЕАЛЬНЫЕ):
- ✅ PTP offset/drift из sysfs (`clock_status_offset`, `clock_status_drift`)
- ✅ GNSS статус синхронизации (`gnss_sync`)
- ✅ Конфигурация SMA разъемов (`sma1-4`)
- ✅ Источник синхронизации (`clock_source`)
- ✅ Серийный номер устройства (`serialnum`)

### НЕ доступные метрики (ОТСУТСТВУЮТ В ДРАЙВЕРЕ):
- ❌ Детальный мониторинг температуры (FPGA, Board, Ambient, DDR, PLL)
- ❌ Мониторинг питания и напряжений (3.3V, 1.8V, 1.2V, 12V)
- ❌ Детальный GNSS мониторинг (спутники по системам, качество сигнала)
- ❌ Состояние LED индикаторов и FPGA
- ❌ Анализ осциллятора и дисциплинирования

## Обзор

Веб-система мониторинга Quantum-PCI предоставляет **ограниченный** интерфейс для отслеживания **базовых** метрик устройств точного времени, доступных через ptp_ocp драйвер.

## Архитектура системы

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │    │   Mobile App    │    │   API Client    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Flask Server   │
                    │   (Port 8080)   │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Quantum-PCI    │
                    │  API (Extended) │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Quantum-PCI    │
                    │  Hardware       │
                    └─────────────────┘
```

## Доступные интерфейсы

### 📊 Реалистичный дашборд
- **URL**: http://localhost:8080/dashboard
- **Назначение**: Мониторинг ТОЛЬКО доступных метрик из ptp_ocp драйвера
- **Особенности**:
  - ✅ PTP offset и drift в реальном времени
  - ✅ GNSS статус синхронизации
  - ✅ Конфигурация SMA разъемов
  - ✅ Информация об устройстве
  - ⚠️ **Disclaimer о ограничениях драйвера**
  - ❌ НЕТ температурного мониторинга
  - ❌ НЕТ мониторинга питания
  - ❌ НЕТ детального GNSS

### 🔧 Realistic REST API
- **URL**: http://localhost:8080/api/
- **Назначение**: Программный доступ к РЕАЛЬНЫМ данным
- **Особенности**:
  - JSON формат данных
  - WebSocket поддержка для базовых метрик
  - Эндпоинт `/api/limitations` с описанием ограничений
  - Честная документация возможностей
  - Интеграция с внешними системами (ограниченная)

### ⚠️ Limitations Endpoint
- **URL**: http://localhost:8080/api/limitations
- **Назначение**: Подробное описание ограничений системы
- **Содержит**: Детальную информацию о том, что НЕ доступно в драйвере

## Быстрый старт

### 1. Установка зависимостей

```bash
cd ptp-monitoring
pip install --break-system-packages -r requirements.txt
```

### 2. Запуск системы

```bash
python3 quantum-pci-monitor.py
```

### 3. Доступ к интерфейсам

После запуска откройте в браузере:
- http://localhost:8080/dashboard - реалистичный дашборд
- http://localhost:8080/api/ - API документация
- http://localhost:8080/api/limitations - описание ограничений

### 4. Проверка драйвера

Убедитесь что драйвер загружен:
```bash
# Проверка драйвера
lsmod | grep ptp_ocp

# Проверка устройств
ls /sys/class/timecard/

# Если нет устройств - проверьте PCI
lspci -d 1d9b:
```

## РЕАЛЬНЫЕ возможности мониторинга

### ✅ Доступные метрики (из ptp_ocp драйвера)

#### 📊 PTP мониторинг
- **clock_status_offset** - смещение времени в наносекундах
- **clock_status_drift** - дрейф частоты в ppb
- **clock_source** - текущий источник синхронизации

#### 🛰️ GNSS мониторинг (базовый)
- **gnss_sync** - статус синхронизации GNSS
- Возможные значения: SYNC, LOST, UNKNOWN

#### 🔌 SMA разъемы
- **sma1-4** - конфигурация каждого разъема
- **available_sma_inputs** - доступные входные сигналы
- **available_sma_outputs** - доступные выходные сигналы

#### 📋 Информация об устройстве
- **serialnum** - серийный номер
- **available_clock_sources** - доступные источники времени

### ❌ НЕ доступные метрики (отсутствуют в драйвере)

#### 🌡️ Температурный мониторинг
- ❌ **FPGA температура** - нет hwmon интеграции
- ❌ **Board температура** - нет датчиков в sysfs
- ❌ **Ambient температура** - не реализовано
- ❌ **DDR температура** - отсутствует
- ❌ **PLL температура** - не доступно
- ⚠️ **temperature_table** - только для ART Card

#### ⚡ Мониторинг питания
- ❌ **Напряжения шин** (3.3V, 1.8V, 1.2V, 12V) - не реализовано
- ❌ **Токи потребления** - отсутствует в драйвере
- ❌ **Мощность** - нет power management
- ❌ **Эффективность** - не вычисляется

#### 🛰️ Детальный GNSS
- ❌ **Количество спутников** по системам - не доступно
- ❌ **Качество сигнала** - нет в sysfs
- ❌ **Точность позиционирования** - не реализовано
- ❌ **Состояние антенны** - отсутствует

#### 🔧 Аппаратный статус
- ❌ **LED индикаторы** - нет интерфейса
- ❌ **FPGA состояние** - не экспортируется
- ❌ **Сетевые порты** - не мониторятся
- ❌ **Калибровка** - нет статуса

## Настройка алертов

### Конфигурация порогов

Отредактируйте файл `api/timecard-extended-api.py`:

```python
alert_thresholds = {
    'thermal': {
        'fpga_temp': {'warning': 70, 'critical': 85},
        'osc_temp': {'warning': 60, 'critical': 75},
        'board_temp': {'warning': 65, 'critical': 80},
        'ambient_temp': {'warning': 40, 'critical': 50}
    },
    'ptp': {
        'offset_ns': {'warning': 1000, 'critical': 10000},
        'path_delay_ns': {'warning': 5000, 'critical': 10000}
    },
    'gnss': {
        'satellites_used': {'warning': 4, 'critical': 2},
        'signal_strength_db': {'warning': 30, 'critical': 20}
    },
    'power': {
        'voltage_deviation_percent': {'warning': 10, 'critical': 20}
    }
}
```

### Типы алертов

- **Warning** - предупреждение, требует внимания
- **Critical** - критическая ситуация, требует немедленного вмешательства

### Уведомления

Алерты отображаются:
- В веб-интерфейсе
- В API `/api/alerts`
- Через WebSocket события

## Интеграция с внешними системами

### Prometheus

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'timecard'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/api/metrics/extended'
```

### Grafana

Импортируйте дашборд для TimeCard с метриками:
- `timecard_thermal_temperature`
- `timecard_ptp_offset_ns`
- `timecard_gnss_satellites`
- `timecard_power_voltage`

### Nagios/Icinga

```bash
# Проверка состояния
curl -s http://localhost:8080/api/metrics/extended | \
  jq '.timecard0.overall_health'

# Проверка алертов
curl -s http://localhost:8080/api/alerts | \
  jq '.total_critical'
```

## Производительность

### Системные требования

- **CPU**: ~1-2% на современных системах
- **Memory**: ~50-100 MB
- **Network**: Минимальный трафик
- **Storage**: ~1 MB/день логов

### Оптимизация

```python
# Уменьшить интервалы для production
updateInterval = 10000;     # 10 секунд вместо 5
backgroundInterval = 300000; # 5 минут вместо 1

# Отключить отладочные сообщения
socketio.run(app, debug=False, ...)
```

### Масштабирование

- **Вертикальное**: Увеличьте ресурсы сервера
- **Горизонтальное**: Запустите несколько экземпляров за балансировщиком

## Устранение неполадок

### Проблемы запуска

1. **Module not found**
   ```bash
   pip install --break-system-packages -r requirements.txt
   ```

2. **Port 8080 already in use**
   ```bash
   sudo lsof -i :8080
   # Или измените порт в коде
   ```

3. **Extended API not found**
   ```bash
   ls -la api/
   chmod +x api/timecard-extended-api.py
   ```

### Проблемы веб-интерфейса

1. **Дашборд не загружается**
   - Проверьте консоль браузера (F12)
   - Убедитесь, что сервер запущен
   - Проверьте логи: `tail -f monitoring.log`

2. **WebSocket не работает**
   - Откройте Developer Tools в браузере
   - Проверьте вкладку Network -> WS
   - Убедитесь, что нет блокировки firewall

3. **API не отвечает**
   ```bash
   curl -v http://localhost:8080/api/metrics
   ```

### Проблемы мониторинга

1. **Нет данных от TimeCard**
   - Проверьте драйвер: `lsmod | grep ptp_ocp`
   - Проверьте устройство: `ls /sys/class/timecard/`
   - Проверьте права доступа

2. **Неточные метрики**
   - Проверьте калибровку
   - Убедитесь в стабильности GNSS
   - Проверьте качество кабельных соединений

## Безопасность

### Рекомендации для production

1. **HTTPS**
   ```python
   socketio.run(app, host='0.0.0.0', port=8080, 
                ssl_context='adhoc')
   ```

2. **Аутентификация**
   ```python
   from flask_httpauth import HTTPBasicAuth
   auth = HTTPBasicAuth()
   ```

3. **Firewall**
   ```bash
   ufw allow 8080/tcp
   ```

4. **Логирование**
   ```python
   import logging
   logging.basicConfig(level=logging.INFO)
   ```

## Резервное копирование

### Конфигурация

```bash
# Backup конфигурации
cp -r ptp-monitoring/config/ backup/
cp ptp-monitoring/api/timecard-extended-api.py backup/
```

### Данные

```bash
# Backup логов
cp monitoring.log backup/
cp -r logs/ backup/
```

## Обновления

### Обновление системы

```bash
# Остановить сервер
pkill -f demo-extended.py

# Обновить код
git pull origin main

# Переустановить зависимости
pip install --break-system-packages -r requirements.txt

# Запустить заново
python3 demo-extended.py
```

### Миграция данных

При обновлении API версии:
1. Сделайте backup текущих данных
2. Проверьте совместимость API
3. Обновите клиентские приложения
4. Протестируйте новую версию

## Поддержка

### Логи

- **Основной лог**: `monitoring.log`
- **API лог**: Встроенный в Flask
- **WebSocket лог**: В консоли сервера

### Отладка

```bash
# Запуск в debug режиме
python3 demo-extended.py --debug

# Подробные логи
export FLASK_ENV=development
python3 demo-extended.py
```

### Контакты

Для технической поддержки:
- Создайте issue в репозитории
- Обратитесь к разработчикам проекта
- Проверьте документацию API

## Заключение

Веб-система мониторинга TimeCard PTP OCP предоставляет мощный инструмент для отслеживания состояния устройств точного времени. Система масштабируема, безопасна и готова для production использования.

Для получения дополнительной информации обратитесь к:
- [API документации](../api/web-api.md)
- [Руководству пользователя](guides/quick-start.md)
- [Примерам интеграции](examples/) 