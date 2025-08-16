# Руководство по веб-мониторингу TimeCard PTP OCP

## Обзор

Веб-система мониторинга TimeCard PTP OCP предоставляет полнофункциональный интерфейс для отслеживания состояния устройств точного времени в реальном времени. Система включает множественные интерфейсы для различных сценариев использования.

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
                    │  TimeCard API   │
                    │   (Extended)    │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │  TimeCard       │
                    │  Hardware       │
                    └─────────────────┘
```

## Доступные интерфейсы

### 📊 Основной дашборд
- **URL**: http://localhost:8080/dashboard
- **Назначение**: Полнофункциональный интерфейс для администраторов
- **Особенности**:
  - Real-time мониторинг всех подсистем
  - Thermal status с цветовой индикацией
  - GNSS constellation tracking
  - Oscillator disciplining analysis
  - Advanced PTP metrics
  - Hardware status monitoring
  - Power consumption analysis
  - Intelligent alerting system
  - System health scoring

### 📱 Mobile PWA
- **URL**: http://localhost:8080/pwa
- **Назначение**: Мобильная версия для операторов
- **Особенности**:
  - Адаптивный дизайн для мобильных устройств
  - Офлайн support
  - Push notifications
  - Все функции desktop версии
  - Touch-friendly интерфейс

### 🖥️ Простой дашборд
- **URL**: http://localhost:8080/simple-dashboard
- **Назначение**: Быстрый обзор для мониторинга
- **Особенности**:
  - Современный дизайн
  - Автоматическое обновление каждые 5 секунд
  - Основные метрики в удобном формате
  - Адаптивная сетка карточек
  - Минималистичный интерфейс

### 🔧 REST API
- **URL**: http://localhost:8080/api/
- **Назначение**: Программный доступ к данным
- **Особенности**:
  - Полная документация API
  - JSON формат данных
  - WebSocket поддержка
  - Интеграция с внешними системами

## Быстрый старт

### 1. Установка зависимостей

```bash
cd ptp-monitoring
pip install --break-system-packages -r requirements.txt
```

### 2. Запуск системы

```bash
python3 demo-extended.py
```

### 3. Доступ к интерфейсам

После запуска откройте в браузере:
- http://localhost:8080/dashboard - основной дашборд
- http://localhost:8080/pwa - мобильная версия
- http://localhost:8080/simple-dashboard - простой дашборд

## Мониторинг подсистем

### 🌡️ Термальный мониторинг

Система отслеживает температуру 6 ключевых компонентов:

- **FPGA** - основной процессор
- **Oscillator** - опорный генератор
- **Board** - температура платы
- **Ambient** - окружающая среда
- **PLL** - фазовый синтезатор
- **DDR** - память

**Пороги температуры:**
- FPGA: Warning 70°C, Critical 85°C
- Oscillator: Warning 60°C, Critical 75°C
- Board: Warning 65°C, Critical 80°C
- Ambient: Warning 40°C, Critical 50°C

### ⚡ Мониторинг питания

Отслеживание 4 шин питания и токов:

- **3.3V** - логическое питание
- **1.8V** - память и интерфейсы
- **1.2V** - ядро FPGA
- **12V** - основное питание

**Метрики:**
- Напряжение каждой шины
- Отклонение от номинала
- Ток потребления по компонентам
- Общая мощность
- Эффективность

### 🛰️ GNSS мониторинг

Отслеживание спутниковых систем:

- **GPS** - американская система
- **GLONASS** - российская система
- **Galileo** - европейская система
- **BeiDou** - китайская система

**Метрики:**
- Количество спутников по системам
- Качество сигнала
- Точность позиционирования
- Состояние антенны
- Время до первого фикса

### ⚡ Анализ осциллятора

Мониторинг дисциплинирования:

- **Состояние блокировки**
- **Частотная ошибка**
- **Отклонение Аллана**
- **Время удержания**
- **Источник опоры**

### 📡 PTP метрики

Расширенные метрики протокола точного времени:

- **Смещение времени**
- **Задержка пути**
- **Статистика пакетов**
- **Качество синхронизации**
- **Состояние мастера**

### 🔧 Мониторинг оборудования

Отслеживание состояния:

- **LED индикаторы**
- **SMA разъемы**
- **FPGA состояние**
- **Сетевые порты**
- **Калибровка**

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