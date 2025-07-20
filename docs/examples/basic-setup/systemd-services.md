# Настройка systemd сервисов

## PTP4L сервис

Создайте файл `/etc/systemd/system/ptp4l.service`:

```ini
[Unit]
Description=Precision Time Protocol (PTP) daemon
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/ptp4l -f /etc/ptp4l.conf -m
Restart=always
RestartSec=5
User=root
Group=root

# Настройки для real-time приоритета
Nice=-20
IOSchedulingClass=1
IOSchedulingPriority=4

[Install]
WantedBy=multi-user.target
```

## PHC2SYS сервис

Создайте файл `/etc/systemd/system/phc2sys.service`:

```ini
[Unit]
Description=Synchronize system clock to PTP hardware clock
After=ptp4l.service
Requires=ptp4l.service

[Service]
Type=simple
ExecStart=/usr/sbin/phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -w -m -q -R 256
Restart=always
RestartSec=5
User=root
Group=root

# Настройки для real-time приоритета
Nice=-20
IOSchedulingClass=1
IOSchedulingPriority=4

[Install]
WantedBy=multi-user.target
```

## Активация сервисов

```bash
# Перезагрузка конфигурации systemd
sudo systemctl daemon-reload

# Включение автозапуска
sudo systemctl enable ptp4l.service
sudo systemctl enable phc2sys.service

# Запуск сервисов
sudo systemctl start ptp4l.service
sudo systemctl start phc2sys.service

# Проверка статуса
sudo systemctl status ptp4l.service
sudo systemctl status phc2sys.service
```

## Мониторинг

```bash
# Просмотр логов
journalctl -u ptp4l.service -f
journalctl -u phc2sys.service -f

# Проверка работы
sudo systemctl is-active ptp4l.service
sudo systemctl is-active phc2sys.service
```