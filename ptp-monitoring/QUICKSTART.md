# 🚀 Быстрый запуск PTP Monitoring System

## Демо запуск (без установки зависимостей)

```bash
# Переход в директорию
cd /workspace/ptp-monitoring

# Запуск демо сервера
python3 demo.py
```

**Доступ к интерфейсам:**
- 🏠 Главная: http://localhost:8080
- 💻 Dashboard: http://localhost:8080/dashboard  
- 📱 PWA: http://localhost:8080/pwa
- 📊 API: http://localhost:8080/api/metrics

## Полная установка

```bash
# Установка с помощью скрипта (требует sudo)
sudo bash scripts/install.sh
```

## Что создано

### 📁 Структура проекта
```
ptp-monitoring/
├── 🔧 api/              # Flask API сервер
│   ├── app.py           # Основное приложение  
│   └── ptp-api.py       # API модуль
├── 🌐 web/              # Desktop интерфейс
│   └── dashboard.html   # HTML dashboard
├── 📱 pwa/              # Mobile PWA
│   ├── index.html       # PWA приложение
│   ├── manifest.json    # PWA манифест
│   ├── sw.js           # Service Worker
│   └── icon.svg        # Иконка
├── ⚙️ config/           # Конфигурации
│   └── grafana-dashboard.json
├── 🔨 scripts/          # Скрипты установки  
│   └── install.sh
├── 🚀 demo.py           # Демо сервер
└── 📖 README.md         # Полная документация
```

### 🌐 Интерфейсы

1. **Desktop Dashboard** (`/dashboard`)
   - Real-time метрики PTP  
   - Управление сервисами
   - Просмотр конфигурации
   - Экспорт логов
   - WebSocket логи (в полной версии)

2. **Mobile PWA** (`/pwa`)
   - Адаптивный дизайн
   - Офлайн поддержка
   - Установка как приложение
   - Push уведомления

3. **REST API** (`/api/*`)
   - `GET /api/metrics` - Метрики PTP
   - `POST /api/restart/<service>` - Перезапуск
   - `GET /api/config` - Конфигурация  
   - `GET /api/logs/export` - Логи

### 🔗 Интеграции

- **Grafana**: Dashboard JSON для импорта
- **Prometheus**: Совместимость с Node Exporter
- **nginx**: Reverse proxy конфигурация
- **systemd**: Service файлы

## 🎯 Следующие шаги

1. **Для демо**: Запустите `python3 demo.py`
2. **Для production**: Запустите `sudo bash scripts/install.sh`
3. **Для Grafana**: Импортируйте `config/grafana-dashboard.json`
4. **Для PWA**: Откройте `/pwa` на мобильном устройстве

---

✨ **Готово!** Система мониторинга PTP OCP извлечена из документации и готова к использованию.