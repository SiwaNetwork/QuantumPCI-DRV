# Изменения: Замена TimeCard на Quantum-PCI TimeCard

## Обзор изменений

Во всех документах и файлах проекта были выполнены следующие замены:
- "TimeCard" → "Quantum-PCI TimeCard"
- "Facebook TimeCard" → "Quantum-PCI TimeCard"
- Удалены упоминания "Celestica TimeCard", "Meta TimeCard" и других вариантов карт

## Измененные файлы

### Документация (Markdown файлы)
1. `/workspace/TIMECARD_БЫСТРАЯ_СПРАВКА.md`
2. `/workspace/TIMECARD_ИНСТРУКЦИЯ_ОПТИМИЗИРОВАННАЯ.md`
3. `/workspace/ptp-monitoring/MONITORING-STACK.md`
4. `/workspace/ptp-monitoring/README.md`
5. `/workspace/ptp-monitoring/QUICKSTART.md`
6. `/workspace/docs/tools/cli-tools.md`
7. `/workspace/docs/README.md`
8. `/workspace/docs/api/web-api.md`
9. `/workspace/docs/guides/precision-time-protocols.md`
10. `/workspace/docs/examples/basic-setup/timecard-integration-scripts.md`
11. `/workspace/docs/examples/basic-setup/timecard-scripts.md`

### Файлы драйверов
1. `/workspace/ДРАЙВЕРА/README.md`
2. `/workspace/ДРАЙВЕРА/АНАЛИЗ_ДРАЙВЕРА.md`
3. `/workspace/ДРАЙВЕРА/СТРУКТУРА_ДРАЙВЕРА.md`
4. `/workspace/ДРАЙВЕРА/СОПОСТАВЛЕНИЕ_PCI_ДРАЙВЕРА.md`
5. `/workspace/ДРАЙВЕРА/ДОБАВЛЕНИЕ_НОВЫХ_УСТРОЙСТВ.md`
6. `/workspace/ДРАЙВЕРА/РЕКОМЕНДАЦИИ_ПО_УЛУЧШЕНИЮ.md`

### Исходные коды
1. `/workspace/ДРАЙВЕРА/ptp_ocp.c`
   - `PCI_VENDOR_ID_FACEBOOK` → `PCI_VENDOR_ID_QUANTUM_PCI`
   - `PCI_DEVICE_ID_FACEBOOK_TIMECARD` → `PCI_DEVICE_ID_QUANTUM_PCI_TIMECARD`
   - `ocp_fb_driver_data` → `ocp_quantum_pci_driver_data`
   - Удалены определения для Celestica

2. `/workspace/ДРАЙВЕРА/ПРИМЕР_ДОБАВЛЕНИЯ_УСТРОЙСТВА.c`
   - Обновлены примеры с новыми именами

3. `/workspace/test_gnss_sma_status.sh`
4. `/workspace/gnss_sma_monitor_fixed.py`
   - `timecard_sysfs` → `quantum_pci_timecard_sysfs`

5. `/workspace/ptp-monitoring/simple-dashboard.html`
6. `/workspace/ptp-monitoring/demo-extended.py`
7. `/workspace/ptp-monitoring/api/timecard-extended-api.py`
8. `/workspace/ptp-monitoring/api/prometheus-exporter.py`
9. `/workspace/ptp-monitoring/start-monitoring-stack.sh`

## Поддерживаемые устройства после изменений

| Производитель | PCI ID | Модель |
|--------------|--------|--------|
| Quantum-PCI | 0x1d9b:0x0400 | TimeCard |
| Orolia | 0x1ad7:0xa000 | ART Card |
| ADVA | 0x0b0b:0x0410 | Timecard |

## Примечания

1. Orolia ART Card оставлена без изменений, так как это отдельный продукт
2. Пути к системным файлам (`/sys/class/timecard/`) остались без изменений для совместимости
3. Имена файлов с префиксом "timecard-" в API и скриптах остались без изменений для совместимости
4. Метрики Prometheus с префиксом "timecard_" остались без изменений для совместимости с существующими дашбордами