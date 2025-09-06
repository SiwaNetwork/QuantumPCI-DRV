# 🧭 Quantum-PCI — Оптимизированная инструкция

> Этот документ — каноническая точка входа. Для подробностей используйте ссылки на соответствующие руководства.

## 🚀 Быстрый старт

- **Проверка драйвера и устройства**:
```bash
lsmod | grep ptp_ocp || echo "Модуль ptp_ocp не загружен"
ls -la /sys/class/timecard/ || echo "Quantum-PCI устройство не обнаружено"
```
- **Быстрый старт по драйверу**: `docs/guides/quick-start.md`
- **Установка драйвера (подробно)**: `docs/guides/installation.md`
- **Базовая конфигурация**: `docs/guides/configuration.md`

## 🌐 Веб‑мониторинг

Выберите режим:
- **Real Monitoring (только реальные данные драйвера)**: `ptp-monitoring/REAL_MONITORING.md`
- **Extended Monitoring v2.0 (расширенная система)**: `ptp-monitoring/QUICKSTART.md`

Краткий запуск:
```bash
# Real Monitoring
cd ptp-monitoring
./start-real-monitoring.sh start

# Extended Monitoring v2.0
cd ptp-monitoring
pip install -r requirements.txt
python3 demo-extended.py
```

Дашборды по умолчанию:
- Dashboard: http://localhost:8080/dashboard
- API: http://localhost:8080/api/

## 🔧 Работа через sysfs (Quantum-PCI)

Подробно: `ДРАЙВЕРА/SYSFS_ИНТЕРФЕЙС.md`

Примеры:
```bash
# Источник времени
cat /sys/class/timecard/ocp0/clock_source
# Установка источника
echo "GNSS" > /sys/class/timecard/ocp0/clock_source

# Статус GNSS
cat /sys/class/timecard/ocp0/gnss_sync

# PTP устройство, связанное с TimeCard
basename $(readlink /sys/class/timecard/ocp0/ptp)
```

## 📚 Полезные материалы

- Архитектура: `TIMECARD_АРХИТЕКТУРА.md`
- Документация драйвера: `ДРАЙВЕРА/README.md`
- Сводный индекс документации: `docs/README.md`
- Руководства:
  - Быстрый старт: `docs/guides/quick-start.md`
  - Установка: `docs/guides/installation.md`
  - Конфигурация: `docs/guides/configuration.md`
  - Протоколы точного времени: `docs/guides/precision-time-protocols.md`
  - Устранение неполадок: `docs/guides/troubleshooting.md`

## 🛠️ Типичные проблемы

- Порт 8080 занят — измените порт или остановите конфликтующий процесс.
- Нет данных в Real Monitoring — проверьте наличие `/sys/class/timecard/ocp0/*`.
- Нет метрик в Extended Monitoring — см. `ptp-monitoring/MONITORING-STACK.md` раздел Troubleshooting.

---
Эта страница поддерживает единый вход в документацию и предотвращает дублирование. Используйте её как навигатор.