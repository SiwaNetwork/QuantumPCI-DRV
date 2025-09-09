# Тестирование и настройка сетевых карт Intel I210, I225, I226 с Quantum-PCI

## Обзор

Данное руководство описывает процедуры тестирования и настройки сетевых карт Intel I210, I225, I226 для работы с платой Quantum-PCI в системах высокоточной синхронизации времени.

## Поддерживаемые сетевые карты Intel

### Intel I210
- **Модель**: Intel I210 Gigabit Network Connection
- **PCI ID**: 8086:1533, 8086:1536, 8086:1537, 8086:1538, 8086:1539, 8086:153A, 8086:153B
- **Возможности**: Hardware timestamping, PTP v2, IEEE 1588
- **Точность**: ±100 нс (с правильной настройкой)

### Intel I225
- **Модель**: Intel I225 2.5 Gigabit Network Connection  
- **PCI ID**: 8086:15F2, 8086:15F3
- **Возможности**: Hardware timestamping, PTP v2, IEEE 1588, 2.5 Gbps
- **Точность**: ±50 нс (с правильной настройкой)

### Intel I226
- **Модель**: Intel I226 Gigabit Network Connection
- **PCI ID**: 8086:125B, 8086:125C, 8086:125D, 8086:125E, 8086:125F, 8086:1260, 8086:1261, 8086:1262, 8086:1263, 8086:1264
- **Возможности**: Hardware timestamping, PTP v2, IEEE 1588
- **Точность**: ±75 нс (с правильной настройкой)

## Системные требования

### Аппаратные требования
- Сетевая карта Intel I210/I225/I226
- Плата Quantum-PCI
- Linux система с ядром ≥ 5.4
- Минимум 1 ГБ RAM
- Свободный PCIe слот

### Программные требования
```bash
# Ubuntu/Debian
sudo apt-get install -y \
    linuxptp \
    ethtool \
    iperf3 \
    tcpdump \
    wireshark-common \
    build-essential \
    linux-headers-$(uname -r)

# RHEL/CentOS/Fedora
sudo dnf install -y \
    linuxptp \
    ethtool \
    iperf3 \
    tcpdump \
    wireshark \
    kernel-devel \
    gcc
```

## Обнаружение и проверка сетевых карт

### 1. Проверка PCI устройств
```bash
#!/bin/bash
# Скрипт обнаружения Intel сетевых карт

echo "=== Обнаружение Intel сетевых карт ==="

# Поиск Intel сетевых карт
lspci | grep -i "intel.*ethernet\|intel.*network"

# Детальная информация
echo -e "\n=== Детальная информация ==="
for device in $(lspci | grep -i "intel.*ethernet\|intel.*network" | cut -d' ' -f1); do
    echo "Устройство: $device"
    lspci -vvv -s $device | grep -E "(Device|Subsystem|Kernel driver|Kernel modules)"
    echo "---"
done

# Проверка драйверов
echo -e "\n=== Проверка драйверов ==="
lsmod | grep -E "igb|igc|e1000e"

# Проверка сетевых интерфейсов
echo -e "\n=== Сетевые интерфейсы ==="
ip link show | grep -A1 -B1 "state UP\|state DOWN"
```

### 2. Проверка поддержки hardware timestamping
```bash
#!/bin/bash
# Скрипт проверки hardware timestamping

INTERFACE="eth0"  # Замените на ваш интерфейс

echo "=== Проверка hardware timestamping для $INTERFACE ==="

# Проверка поддержки timestamping
echo "Поддерживаемые типы timestamping:"
ethtool -T $INTERFACE

# Проверка текущего состояния
echo -e "\nТекущее состояние timestamping:"
ethtool -T $INTERFACE | grep -E "SOF|SYS|HW"

# Проверка PTP поддержки
echo -e "\nPTP поддержка:"
ethtool -T $INTERFACE | grep -i ptp

# Проверка статистики
echo -e "\nСтатистика интерфейса:"
ethtool -S $INTERFACE | grep -E "timestamp|ptp|sync"
```

## Настройка hardware timestamping

### 1. Включение hardware timestamping
```bash
#!/bin/bash
# Скрипт настройки hardware timestamping

INTERFACE="eth0"  # Замените на ваш интерфейс

echo "=== Настройка hardware timestamping для $INTERFACE ==="

# Остановка интерфейса
sudo ip link set $INTERFACE down

# Включение hardware timestamping
echo "Включение hardware timestamping..."
sudo ethtool -T $INTERFACE rx-filter on

# Настройка буферов
echo "Настройка буферов..."
sudo ethtool -G $INTERFACE rx 4096 tx 4096

# Настройка скорости и дуплекса
echo "Настройка скорости и дуплекса..."
sudo ethtool -s $INTERFACE speed 1000 duplex full autoneg off

# Включение интерфейса
sudo ip link set $INTERFACE up

# Проверка результата
echo -e "\n=== Проверка настройки ==="
ethtool -T $INTERFACE | grep -E "SOF|SYS|HW"
```

### 2. Настройка для Intel I225 (2.5 Gbps)
```bash
#!/bin/bash
# Специальная настройка для Intel I225

INTERFACE="eth0"

echo "=== Настройка Intel I225 ==="

# Остановка интерфейса
sudo ip link set $INTERFACE down

# Настройка для 2.5 Gbps
sudo ethtool -s $INTERFACE speed 2500 duplex full autoneg off

# Включение hardware timestamping
sudo ethtool -T $INTERFACE rx-filter on

# Настройка буферов для высоких скоростей
sudo ethtool -G $INTERFACE rx 8192 tx 8192

# Включение интерфейса
sudo ip link set $INTERFACE up

echo "Настройка завершена для 2.5 Gbps"
```

## Тестирование точности синхронизации

### 1. Базовый тест PTP
```bash
#!/bin/bash
# Базовый тест PTP с Intel сетевыми картами

INTERFACE="eth0"
DOMAIN="24"

echo "=== Базовый тест PTP ==="

# Создание конфигурации PTP
cat > /tmp/ptp4l-intel.conf << EOF
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               $DOMAIN
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware

[$INTERFACE]
network_transport          UDPv4
EOF

# Запуск PTP
echo "Запуск PTP4L..."
sudo ptp4l -f /tmp/ptp4l-intel.conf -i $INTERFACE -m
```

### 2. Тест точности с Quantum-PCI
```bash
#!/bin/bash
# Тест точности синхронизации с Quantum-PCI

INTERFACE="eth0"
TIMECARD_SYSFS="/sys/class/timecard/ocp0"

echo "=== Тест точности с Quantum-PCI ==="

# Проверка Quantum-PCI
if [ ! -d "$TIMECARD_SYSFS" ]; then
    echo "❌ Quantum-PCI не найден"
    exit 1
fi

echo "✅ Quantum-PCI найден: $(cat $TIMECARD_SYSFS/serialnum)"

# Настройка источника времени
echo "Настройка источника времени..."
echo "GNSS" > $TIMECARD_SYSFS/clock_source

# Ожидание синхронизации
echo "Ожидание синхронизации GNSS..."
for i in {1..30}; do
    if [ "$(cat $TIMECARD_SYSFS/gnss_sync)" = "1" ]; then
        echo "✅ GNSS синхронизирован"
        break
    fi
    echo "Ожидание... ($i/30)"
    sleep 10
done

# Запуск PTP с Quantum-PCI как источник
cat > /tmp/ptp4l-quantum-intel.conf << EOF
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               24
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware

[$INTERFACE]
network_transport          UDPv4
EOF

echo "Запуск PTP с Quantum-PCI..."
sudo ptp4l -f /tmp/ptp4l-quantum-intel.conf -i $INTERFACE -m
```

### 3. Тест производительности
```bash
#!/bin/bash
# Тест производительности Intel сетевых карт

INTERFACE="eth0"
DURATION="60"  # секунд

echo "=== Тест производительности ==="

# Тест пропускной способности
echo "Тест пропускной способности..."
iperf3 -c 192.168.1.100 -t $DURATION -i 1

# Тест задержки
echo -e "\nТест задержки..."
ping -c 100 192.168.1.100 | tail -1

# Тест PTP производительности
echo -e "\nТест PTP производительности..."
sudo ptp4l -f /tmp/ptp4l-intel.conf -i $INTERFACE -m -l 7 | head -20
```

## Мониторинг и диагностика

### 1. Мониторинг PTP статистики
```bash
#!/bin/bash
# Мониторинг PTP статистики

INTERFACE="eth0"

echo "=== PTP Статистика для $INTERFACE ==="

# Статистика PTP пакетов
echo "PTP пакеты:"
ethtool -S $INTERFACE | grep -E "ptp|timestamp"

# Статистика задержек
echo -e "\nСтатистика задержек:"
cat /sys/class/ptp/ptp0/stats

# Текущее время PTP
echo -e "\nТекущее время PTP:"
sudo testptp -d /dev/ptp0 -g

# Частота PTP
echo -e "\nЧастота PTP:"
sudo testptp -d /dev/ptp0 -f
```

### 2. Диагностика проблем
```bash
#!/bin/bash
# Диагностика проблем с Intel сетевыми картами

INTERFACE="eth0"

echo "=== Диагностика Intel сетевых карт ==="

# Проверка драйвера
echo "1. Проверка драйвера:"
lsmod | grep -E "igb|igc|e1000e"
dmesg | grep -i "intel.*ethernet" | tail -5

# Проверка hardware timestamping
echo -e "\n2. Проверка hardware timestamping:"
ethtool -T $INTERFACE | grep -E "SOF|SYS|HW"

# Проверка ошибок
echo -e "\n3. Проверка ошибок:"
ethtool -S $INTERFACE | grep -E "error|drop|miss"

# Проверка температуры
echo -e "\n4. Проверка температуры:"
ethtool -m $INTERFACE 2>/dev/null | grep -i temp || echo "Температура недоступна"

# Проверка PTP
echo -e "\n5. Проверка PTP:"
ls -la /dev/ptp* 2>/dev/null || echo "PTP устройства не найдены"
```

## Интеграция с системой мониторинга Quantum-PCI

### 1. Расширение веб-мониторинга
```python
#!/usr/bin/env python3
# Расширение веб-мониторинга для Intel сетевых карт

import subprocess
import json
import time
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

def get_intel_network_stats():
    """Получение статистики Intel сетевых карт"""
    stats = {}
    
    try:
        # Получение списка интерфейсов
        result = subprocess.run(['ip', 'link', 'show'], capture_output=True, text=True)
        interfaces = []
        for line in result.stdout.split('\n'):
            if ': eth' in line and 'state UP' in line:
                interface = line.split(':')[1].strip()
                interfaces.append(interface)
        
        for interface in interfaces:
            # Проверка, что это Intel карта
            pci_info = subprocess.run(['ethtool', '-i', interface], 
                                    capture_output=True, text=True)
            if 'intel' in pci_info.stdout.lower():
                # Получение статистики
                ethtool_stats = subprocess.run(['ethtool', '-S', interface], 
                                             capture_output=True, text=True)
                
                # Получение timestamping информации
                timestamping = subprocess.run(['ethtool', '-T', interface], 
                                            capture_output=True, text=True)
                
                stats[interface] = {
                    'ethtool_stats': ethtool_stats.stdout,
                    'timestamping': timestamping.stdout,
                    'timestamp': time.time()
                }
    
    except Exception as e:
        stats['error'] = str(e)
    
    return stats

@app.route('/api/intel-network')
def intel_network_api():
    """API для получения статистики Intel сетевых карт"""
    return jsonify(get_intel_network_stats())

@app.route('/intel-network-dashboard')
def intel_network_dashboard():
    """Дашборд для мониторинга Intel сетевых карт"""
    template = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Intel Network Cards Monitor</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .card { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
            .status-ok { background-color: #d4edda; }
            .status-warning { background-color: #fff3cd; }
            .status-error { background-color: #f8d7da; }
            pre { background-color: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        </style>
    </head>
    <body>
        <h1>Intel Network Cards Monitor</h1>
        <div id="content"></div>
        
        <script>
            function updateData() {
                fetch('/api/intel-network')
                    .then(response => response.json())
                    .then(data => {
                        let html = '';
                        for (const [interface, stats] of Object.entries(data)) {
                            if (interface !== 'error') {
                                html += `
                                    <div class="card status-ok">
                                        <h3>Interface: ${interface}</h3>
                                        <h4>Timestamping Support:</h4>
                                        <pre>${stats.timestamping}</pre>
                                        <h4>Statistics:</h4>
                                        <pre>${stats.ethtool_stats}</pre>
                                    </div>
                                `;
                            }
                        }
                        if (data.error) {
                            html += `<div class="card status-error"><h3>Error:</h3><p>${data.error}</p></div>`;
                        }
                        document.getElementById('content').innerHTML = html;
                    })
                    .catch(error => {
                        document.getElementById('content').innerHTML = 
                            `<div class="card status-error"><h3>Error:</h3><p>${error}</p></div>`;
                    });
            }
            
            updateData();
            setInterval(updateData, 5000);
        </script>
    </body>
    </html>
    """
    return render_template_string(template)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081, debug=True)
```

## Примеры конфигурации

### 1. Конфигурация для высокоточного PTP
```bash
# /etc/ptp4l-intel-high-precision.conf
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               24
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0
logAnnounceInterval        0
logSyncInterval            -4
logMinDelayReqInterval     -4
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

### 2. Конфигурация для телекоммуникаций
```bash
# /etc/ptp4l-intel-telecom.conf
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               44
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF
free_running               0
freq_est_interval          1
dscp_event                 0
dscp_general               0
logAnnounceInterval        0
logSyncInterval            -3
logMinDelayReqInterval     -3
announceReceiptTimeout     3
syncReceiptTimeout         0
delayAsymmetry             0
fault_reset_interval       4
fault_badpep_interval      16
delay_mechanism            E2E
time_stamping              hardware
tx_timestamp_timeout       10
check_fup_sync             0

[eth0]
network_transport          UDPv4
```

## Устранение неполадок

### Частые проблемы и решения

#### 1. Hardware timestamping не работает
```bash
# Проверка поддержки
ethtool -T eth0

# Решение: обновление драйвера
sudo modprobe -r igb  # или igc, e1000e
sudo modprobe igb

# Проверка версии драйвера
modinfo igb | grep version
```

#### 2. Высокая задержка PTP
```bash
# Оптимизация буферов
sudo ethtool -G eth0 rx 8192 tx 8192

# Отключение энергосбережения
echo 'on' | sudo tee /sys/bus/pci/drivers/igb/*/power/control

# Настройка CPU affinity
sudo taskset -c 0 ptp4l -f /etc/ptp4l.conf -i eth0
```

#### 3. Проблемы с 2.5 Gbps на I225
```bash
# Проверка кабеля и коммутатора
ethtool eth0

# Принудительная настройка скорости
sudo ethtool -s eth0 speed 2500 duplex full autoneg off

# Проверка поддержки 2.5G
ethtool eth0 | grep -i "advertised\|supported"
```

## Заключение

Данное руководство предоставляет комплексные инструкции по тестированию и настройке сетевых карт Intel I210, I225, I226 для работы с Quantum-PCI. Следуя этим инструкциям, вы сможете достичь высокой точности синхронизации времени в вашей системе.

Для получения дополнительной поддержки обращайтесь к документации Intel или к разработчикам проекта Quantum-PCI.
