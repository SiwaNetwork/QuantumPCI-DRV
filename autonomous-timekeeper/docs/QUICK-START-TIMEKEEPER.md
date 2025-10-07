# 🕐 Быстрый старт: Quantum-PCI Time Keeper

## 📋 Описание

Настройка Quantum-PCI как **хранителя времени** для карт **БЕЗ навигационных приемников GNSS**. Система использует высокоточный генератор Quantum-PCI для автономного ведения времени при пропадании NTP серверов.

## 🚀 Быстрая установка

### 1. Автоматическая настройка (рекомендуется)

```bash
# Клонирование репозитория (если еще не сделано)
git clone https://github.com/SiwaNetwork/QuantumPCI-DRV.git
cd QuantumPCI-DRV

# Запуск автоматической настройки
sudo ./scripts/setup-quantum-timekeeper.sh
```

### 2. Ручная настройка

```bash
# Установка зависимостей
sudo apt update
sudo apt install chrony ntpdate bc

# Копирование конфигурации
sudo cp chrony-holdover.conf /etc/chrony/chrony.conf

# Настройка прав доступа
sudo chmod 666 /dev/ptp*
sudo mkdir -p /var/log/chrony
sudo chown chrony:chrony /var/log/chrony

# Перезапуск службы
sudo systemctl restart chrony
sudo systemctl enable chrony
```

## ✅ Проверка работы

```bash
# Проверка статуса синхронизации
chronyc tracking

# Проверка источников времени
chronyc sources -v

# Мониторинг системы
/usr/local/bin/quantum-timekeeper-monitor.sh
```

## 📊 Ожидаемые результаты

### При наличии сети:
- **Основные источники**: NTP серверы из интернета
- **Stratum**: 2-3
- **Точность**: < 10 мс
- **Статус**: Normal

### При потере сети:
- **Основной источник**: Quantum-PCI (PHC)
- **Stratum**: 2
- **Автономная работа**: Неограниченное время
- **Стабильность**: Высокая (дрейф < 100 ppm)

## 🔧 Полезные команды

```bash
# Мониторинг
/usr/local/bin/quantum-timekeeper-monitor.sh

# Тестирование сценария
/usr/local/bin/test-timekeeper-scenario.sh

# Статус синхронизации
chronyc tracking

# Источники времени
chronyc sources -v

# Перезапуск службы
sudo systemctl restart chrony

# Проверка логов
sudo tail -f /var/log/chrony/chrony.log
```

## 🌐 NTP сервер для клиентов

После настройки система работает как NTP сервер:

- **Порт**: 123
- **Stratum**: 2-3
- **Разрешенные сети**: 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12

### Настройка клиентов:

```bash
# На клиентских машинах
sudo apt install ntpdate

# Синхронизация с Quantum-PCI сервером
sudo ntpdate -s <IP_QUANTUM_PCI_SERVER>

# Или настройка chrony на клиенте
echo "server <IP_QUANTUM_PCI_SERVER> iburst" | sudo tee -a /etc/chrony/chrony.conf
sudo systemctl restart chrony
```

## 🚨 Устранение неполадок

### Quantum-PCI не обнаруживается:
```bash
# Проверка драйвера
lsmod | grep ptp_ocp
sudo modprobe ptp_ocp

# Проверка устройства
ls -la /sys/class/timecard/
ls -la /dev/ptp*
```

### Большой offset:
```bash
# Применение коррекции
sudo chronyc makestep

# Проверка правильного PTP устройства
# В /etc/chrony/chrony.conf изменить /dev/ptp0 на /dev/ptp1
```

### NTP серверы недоступны:
```bash
# Проверка сети
ping -c 3 8.8.8.8

# Проверка NTP серверов
ntpdate -q 0.pool.ntp.org
```

## 📚 Дополнительная документация

- **Полное руководство**: `docs/guides/quantum-pci-timekeeper-guide.md`
- **Веб-мониторинг**: `quantum-pci-monitoring/`
- **API документация**: http://localhost:8080/api/

## 🎯 Сценарий работы

1. **По умолчанию**: Синхронизация с NTP серверами из интернета
2. **При потере сети**: Автоматическое переключение на Quantum-PCI
3. **Автономная работа**: Высокоточный генератор ведет время
4. **При восстановлении сети**: Возврат к NTP серверам с коррекцией

## ✅ Готово!

Система настроена и готова к работе как надежный хранитель времени с автономным режимом при потере сетевого подключения.

