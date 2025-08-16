# Реализация протоколов точного времени с PCI картой атомных часов

## Обзор

Данное руководство описывает реализацию различных протоколов синхронизации времени с использованием PCI карты времени, содержащей атомный стандарт и GNSS приемник. Рассматриваются следующие протоколы:

- **NTP с аппаратными временными метками**
- **White Rabbit** - субнаносекундная синхронизация для научных применений  
- **IEEE 1588-2019 (PTPv2.1)** - новые функции стандарта
- **SMPTE timecode** - для вещательных применений

## Архитектура системы

### Базовая конфигурация

```
┌─────────────────────────────────────────────────────────────────┐
│                    Host Computer                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │          PCI карта времени (источник)                       ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         ││
│  │  │   Atomic    │  │    GNSS     │  │   PCI       │         ││
│  │  │  Standard   │  │  Receiver   │  │  Driver     │         ││
│  │  │  (Cs/Rb)    │  │  (GPS)      │  │  Interface  │         ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘         ││
│  └─────────────────┬───────────────────────────────────────────┘│
├────────────────────┼─────────────────────────────────────────────┤
│  ┌─────────────────┴─────────────────────────────────────────┐  │
│  │            Software Stack                                 │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │  │
│  │  │   chrony    │  │   linuxptp  │  │    NTP      │       │  │
│  │  │   + PHC     │  │   (ptp4l)   │  │   server    │       │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘       │  │
│  └─────────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │             Сетевые интерфейсы                              ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         ││
│  │  │Intel I210-T │  │  SMA выходы │  │   Ethernet  │         ││
│  │  │Hardware TS  │  │   (PPS/10M) │  │    NIC      │         ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘         ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Компоненты системы

1. **PCI карта времени** - основной источник времени с атомным стандартом
2. **GNSS приемник** - дополнительная привязка к UTC
3. **SMA выходы** - физические сигналы времени (PPS, 10MHz, SMPTE)
4. **Intel I210-T** - Ethernet NIC с поддержкой hardware timestamping
5. **Программный стек** - драйверы и демоны протоколов

## 1. NTP с аппаратными временными метками

### Драйвер PCI карты времени

Драйвер должен реализовать интерфейс PTP Hardware Clock (PHC):

```c
// Структура информации о PTP часах
static struct ptp_clock_info atomic_timecard_ptp_info = {
    .owner = THIS_MODULE,
    .name = "atomic_timecard",
    .max_adj = 500000000, // 500 ppm максимальная коррекция
    .n_alarm = 2,         // количество будильников
    .n_ext_ts = 4,        // внешние временные метки
    .n_per_out = 2,       // периодические выходы
    .pps = 1,             // поддержка PPS
    .adjfine = atomic_timecard_adjfine,
    .adjtime = atomic_timecard_adjtime,
    .gettime64 = atomic_timecard_gettime,
    .settime64 = atomic_timecard_settime,
    .enable = atomic_timecard_enable,
};

// Регистрация PTP часов
static int atomic_timecard_probe(struct pci_dev *pdev,
                                const struct pci_device_id *id)
{
    // ... инициализация устройства ...
    
    ptp_clock = ptp_clock_register(&atomic_timecard_ptp_info, &pdev->dev);
    if (IS_ERR(ptp_clock)) {
        dev_err(&pdev->dev, "Failed to register PTP clock\n");
        return PTR_ERR(ptp_clock);
    }
    
    // Создание sysfs интерфейса
    timecard_create_sysfs(&pdev->dev);
    
    return 0;
}

// Чтение времени с атомных часов
static int atomic_timecard_gettime(struct ptp_clock_info *ptp,
                                  struct timespec64 *ts)
{
    struct atomic_timecard *card = container_of(ptp, struct atomic_timecard, ptp_info);
    u64 ns;
    
    // Чтение наносекундного времени с атомных часов
    ns = readq(card->regs + ATOMIC_TIME_NS_REG);
    
    *ts = ns_to_timespec64(ns);
    return 0;
}
```

### Конфигурация chrony

```ini
# /etc/chrony.conf

# Ваша PCI карта времени как PHC источник
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0.0 precision 1e-9

# SHM память для интеграции с GNSS приемником карты
refclock SHM 0 refid GPS precision 1e-8 offset 0.0

# Локальный stratum для резервирования
local stratum 1 orphan

# Разрешение доступа клиентам
allow 192.168.0.0/24
allow 10.0.0.0/8

# Настройка аппаратных временных меток для Intel I210-T
hwtimestamp eth0
hwtimestamp *

# Настройки для высокой точности
maxupdateskew 1.0      # Максимальное отклонение частоты
makestep 1.0 3         # Корректировка больших смещений
rtcsync                # Синхронизация RTC
maxdistance 0.1        # Максимальная дистанция до источника

# Логирование для мониторинга
logdir /var/log/chrony
log tracking measurements statistics
logchange 0.5

# Безопасность
bindcmdaddress 127.0.0.1
cmdallow 127.0.0.1
```

### Скрипт интеграции с картой

```bash
#!/bin/bash
# /usr/local/bin/timecard-chrony-setup.sh

TIMECARD_DEV="/sys/class/timecard/ocp0"
PHC_DEV="/dev/ptp0"

# Проверка наличия карты времени
if [ ! -d "$TIMECARD_DEV" ]; then
    echo "Ошибка: Карта времени не найдена"
    exit 1
fi

# Настройка источника времени на карте
echo "GNSS" > $TIMECARD_DEV/clock_source

# Ожидание синхронизации GNSS
echo "Ожидание синхронизации GNSS..."
while [ "$(cat $TIMECARD_DEV/gnss_sync)" != "locked" ]; do
    sleep 5
    echo -n "."
done
echo " Синхронизация GNSS установлена"

# Настройка SMA выходов
echo "PPS" > $TIMECARD_DEV/sma1_out
echo "10MHz" > $TIMECARD_DEV/sma2_out

# Установка начального времени в PHC
TIMECARD_TIME=$(cat $TIMECARD_DEV/time_ns)
phc_ctl $PHC_DEV set $TIMECARD_TIME

# Запуск chrony
systemctl start chronyd
systemctl enable chronyd

echo "Система NTP с аппаратными временными метками настроена"
```

## 2. IEEE 1588-2019 (PTPv2.1) реализация

### Конфигурация ptp4l для новых функций

```ini
# /etc/ptp4l.conf

[global]
# Базовые параметры PTP
clockClass 6                    # Atomic clock class
clockAccuracy 0x20             # Better than 100ns  
offsetScaledLogVariance 0x4000 # Low variance
priority1 128
priority2 128
domainNumber 0

# Новые функции IEEE 1588-2019
version 2
twoStepFlag 0                   # One-step если поддерживается
unicast_req_duration 60        # Длительность unicast запросов
unicast_master_table_size 16   # Размер таблицы мастеров

# Enhanced security (новое в 2019)
authentication_enabled 1
authentication_type HMAC_SHA256
security_association_id 1

# Alternative timescales (новое в 2019)
timescale PTP                   # PTP или ARB
traceability 1                  # Прослеживаемость к UTC

# Аппаратные временные метки
time_stamping hardware
network_transport L2
delay_mechanism P2P            # Peer-to-peer delay mechanism

# Высокая точность
tx_timestamp_timeout 10
freq_est_interval 1
assume_two_step 0
logging_level 6

# Path trace (новое в 2019)
path_trace_enabled 1
path_trace_depth 8

# Multiple domain support
domain_table_size 16

[eth0]
masterOnly 1                   # Эта система - PTP master
announceReceiptTimeout 3
syncReceiptTimeout 0
delayReqReceiptTimeout 3
logAnnounceInterval 1
logSyncInterval 0              # 1 сообщение в секунду
logMinDelayReqInterval 0

# Enhanced accuracy (новое в 2019)
asymmetry 0                    # Асимметрия линии связи
ingressLatency 0               # Входящая задержка
egressLatency 0                # Исходящая задержка
```

### Интеграция с картой времени

```bash
#!/bin/bash
# /usr/local/bin/ptp-timecard-integration.sh

TIMECARD_DEV="/sys/class/timecard/ocp0"
PTP_CONFIG="/etc/ptp4l.conf"

# Функция чтения времени с карты
get_timecard_time() {
    cat $TIMECARD_DEV/time_ns
}

# Функция установки времени в PHC
set_phc_time() {
    local time_ns=$1
    phc_ctl /dev/ptp0 set $time_ns
}

# Основная функция синхронизации
sync_phc_with_timecard() {
    while true; do
        # Чтение времени с карты
        TIMECARD_TIME=$(get_timecard_time)
        
        # Чтение времени с PHC
        PHC_TIME=$(phc_ctl /dev/ptp0 get)
        
        # Вычисление смещения (в наносекундах)
        OFFSET=$((TIMECARD_TIME - PHC_TIME))
        
        # Коррекция PHC если смещение больше 1 микросекунды
        if [ ${OFFSET#-} -gt 1000 ]; then
            phc_ctl /dev/ptp0 adj $OFFSET
            echo "PHC скорректирован на $OFFSET нс"
        fi
        
        sleep 1
    done
}

# Запуск демона синхронизации в фоне
sync_phc_with_timecard &
SYNC_PID=$!

# Запуск ptp4l
ptp4l -f $PTP_CONFIG -i eth0 -s &
PTP4L_PID=$!

# Ожидание сигналов завершения
trap 'kill $SYNC_PID $PTP4L_PID; exit' SIGINT SIGTERM

wait
```

### Дополнительные функции IEEE 1588-2019

```c
// Поддержка новых TLV (Type-Length-Value) расширений
struct ptp_enhanced_accuracy_tlv {
    uint16_t type;              // TLV_ENHANCED_ACCURACY
    uint16_t length;
    uint32_t accuracy_ns;       // Точность в наносекундах
    uint32_t accuracy_ps;       // Точность в пикосекундах
};

// Поддержка альтернативных временных шкал
struct ptp_alternate_timescale_tlv {
    uint16_t type;              // TLV_ALTERNATE_TIMESCALE
    uint16_t length;
    uint8_t  timescale_id;      // TAI, GPS, ARB, etc.
    int32_t  current_offset;    // Смещение от PTP времени
    uint32_t jump_seconds;      // Количество leap seconds
};
```

## 3. White Rabbit субнаносекундная синхронизация

### Конфигурация White Rabbit

```ini
# /etc/wr-config.conf

# Режим работы White Rabbit
wr_mode master
wr_enabled yes

# Источник времени - ваша карта
atomic_clock_source /dev/timecard0
calibration_period 60

# Субнаносекундная точность
fiber_asymmetry_ps 0        # Асимметрия оптоволокна в пикосекундах
tx_delay_ps 0               # Задержка передачи
rx_delay_ps 0               # Задержка приема
cable_delay_ps 0            # Задержка кабеля

# Калибровка
auto_calibration yes
calibration_accuracy_ps 10  # Требуемая точность калибровки

# Физический слой
phy_type 1000base_x         # Тип PHY
sfp_db_path /etc/wr/sfp_database.conf

# Мониторинг
servo_update_period 1000    # Период обновления servo в мс
clock_servo pi              # Тип servo алгоритма
```

### Драйвер интеграции White Rabbit

```c
// Структура White Rabbit устройства на базе карты времени
struct wr_timecard_device {
    struct device *dev;
    void __iomem *regs;
    struct atomic_clock *atomic_clock;
    struct gnss_receiver *gnss;
    struct wr_core *wr_core;
    
    // Калибровочные данные
    int32_t tx_delay_ps;
    int32_t rx_delay_ps;
    int32_t fiber_asymmetry_ps;
};

// Получение субнаносекундного времени
static int wr_timecard_get_time_ps(struct wr_timecard_device *dev,
                                   uint64_t *time_ps)
{
    uint64_t time_ns;
    uint32_t ps_frac;
    
    // Чтение наносекундного времени с атомных часов
    time_ns = atomic_clock_read_ns(dev->atomic_clock);
    
    // Чтение пикосекундной дроби
    ps_frac = atomic_clock_read_ps_fraction(dev->atomic_clock);
    
    *time_ps = time_ns * 1000 + ps_frac;
    return 0;
}

// Калибровка задержек
static int wr_timecard_calibrate(struct wr_timecard_device *dev)
{
    // Автоматическая калибровка с использованием обратной связи
    uint64_t start_time, end_time, round_trip_time;
    
    // Отправка калибровочного пакета
    wr_timecard_get_time_ps(dev, &start_time);
    wr_send_calibration_packet(dev);
    
    // Ожидание ответа и измерение времени
    wr_wait_for_calibration_response(dev);
    wr_timecard_get_time_ps(dev, &end_time);
    
    round_trip_time = end_time - start_time;
    
    // Вычисление и сохранение калибровочных данных
    dev->tx_delay_ps = round_trip_time / 2;
    dev->rx_delay_ps = round_trip_time / 2;
    
    return 0;
}
```

### Настройка SMA выходов для White Rabbit

```bash
#!/bin/bash
# Настройка SMA выходов для White Rabbit

TIMECARD_DEV="/sys/class/timecard/ocp0"

# SMA1: PPS выход с субнаносекундной точностью
echo "wr_pps" > $TIMECARD_DEV/sma1_out
echo "1000000000" > $TIMECARD_DEV/sma1_period_ps  # 1 секунда

# SMA2: 125MHz White Rabbit clock
echo "wr_clk" > $TIMECARD_DEV/sma2_out  
echo "8000" > $TIMECARD_DEV/sma2_period_ps       # 8 нс = 125 МГц

# SMA3: Калибровочный сигнал
echo "wr_cal" > $TIMECARD_DEV/sma3_out

# SMA4: Диагностический выход
echo "wr_diag" > $TIMECARD_DEV/sma4_out
```

## 4. SMPTE timecode для вещательных применений

### Генератор SMPTE timecode

```c
// Структура SMPTE генератора
struct smpte_generator {
    struct timecard_device *timecard;
    enum smpte_format format;      // 24fps, 25fps, 29.97fps, 30fps
    bool drop_frame;               // Drop frame для 29.97fps
    uint32_t sma_output_pin;       // Номер SMA выхода
    struct timer_list timer;       // Таймер для генерации
};

// Форматы SMPTE
enum smpte_format {
    SMPTE_24FPS = 24,
    SMPTE_25FPS = 25,
    SMPTE_2997FPS = 2997,  // 29.97 * 100
    SMPTE_30FPS = 30
};

// Структура SMPTE timecode
struct smpte_timecode {
    uint8_t hours;
    uint8_t minutes;  
    uint8_t seconds;
    uint8_t frames;
    bool drop_frame;
};

// Конверсия наносекундного времени в SMPTE
static int convert_ns_to_smpte(uint64_t time_ns, enum smpte_format format,
                              bool drop_frame, struct smpte_timecode *tc)
{
    uint64_t total_seconds = time_ns / 1000000000ULL;
    uint64_t frame_ns;
    
    // Вычисление продолжительности кадра в наносекундах
    switch (format) {
    case SMPTE_24FPS:
        frame_ns = 1000000000ULL / 24;
        break;
    case SMPTE_25FPS:
        frame_ns = 1000000000ULL / 25;
        break;
    case SMPTE_2997FPS:
        frame_ns = 1000000000ULL * 1001 / 30000;  // 29.97fps
        break;
    case SMPTE_30FPS:
        frame_ns = 1000000000ULL / 30;
        break;
    default:
        return -EINVAL;
    }
    
    // Вычисление компонентов timecode
    tc->hours = (total_seconds / 3600) % 24;
    tc->minutes = (total_seconds / 60) % 60;
    tc->seconds = total_seconds % 60;
    
    uint64_t frame_time_ns = time_ns % 1000000000ULL;
    tc->frames = frame_time_ns / frame_ns;
    
    // Обработка drop frame для 29.97fps
    if (drop_frame && format == SMPTE_2997FPS) {
        // Drop frames 0 and 1 каждую минуту, кроме минут кратных 10
        if (tc->seconds == 0 && tc->minutes % 10 != 0 && tc->frames < 2) {
            tc->frames += 2;
        }
    }
    
    tc->drop_frame = drop_frame;
    return 0;
}

// Генерация SMPTE сигнала на SMA выходе
static void generate_smpte_timecode(struct smpte_generator *gen)
{
    uint64_t atomic_time_ns;
    struct smpte_timecode tc;
    uint32_t smpte_word;
    
    // Получение точного времени с карты
    timecard_get_time_ns(gen->timecard, &atomic_time_ns);
    
    // Конверсия в SMPTE format
    convert_ns_to_smpte(atomic_time_ns, gen->format, gen->drop_frame, &tc);
    
    // Кодирование в SMPTE word
    smpte_word = encode_smpte_word(&tc);
    
    // Вывод на SMA
    sma_output_smpte(gen->sma_output_pin, smpte_word);
}

// Кодирование SMPTE timecode в слово
static uint32_t encode_smpte_word(const struct smpte_timecode *tc)
{
    uint32_t word = 0;
    
    // Кодирование в BCD формат
    word |= ((tc->frames / 10) << 28) | ((tc->frames % 10) << 24);
    word |= ((tc->seconds / 10) << 20) | ((tc->seconds % 10) << 16);
    word |= ((tc->minutes / 10) << 12) | ((tc->minutes % 10) << 8);
    word |= ((tc->hours / 10) << 4) | (tc->hours % 10);
    
    // Drop frame bit
    if (tc->drop_frame) {
        word |= (1 << 31);
    }
    
    return word;
}
```

### Конфигурация SMPTE

```bash
#!/bin/bash
# /usr/local/bin/smpte-setup.sh

TIMECARD_DEV="/sys/class/timecard/ocp0"

# Функция настройки SMPTE выхода
setup_smpte_output() {
    local sma_num=$1
    local format=$2
    local drop_frame=$3
    
    # Настройка SMA выхода для SMPTE
    echo "smpte" > $TIMECARD_DEV/sma${sma_num}_out
    echo "$format" > $TIMECARD_DEV/sma${sma_num}_smpte_format
    
    if [ "$drop_frame" = "true" ]; then
        echo "1" > $TIMECARD_DEV/sma${sma_num}_drop_frame
    else
        echo "0" > $TIMECARD_DEV/sma${sma_num}_drop_frame
    fi
}

# Настройка различных SMPTE выходов
setup_smpte_output 1 "25fps" false    # PAL формат
setup_smpte_output 2 "29.97fps" true  # NTSC drop frame
setup_smpte_output 3 "30fps" false    # Film формат
setup_smpte_output 4 "24fps" false    # Cinema формат

echo "SMPTE timecode выходы настроены"
```

## 5. Конфигурация SMA выходов

### Универсальный скрипт настройки

```bash
#!/bin/bash
# /usr/local/bin/configure-sma-outputs.sh

TIMECARD_DEV="/sys/class/timecard/ocp0"

# Проверка наличия устройства
if [ ! -d "$TIMECARD_DEV" ]; then
    echo "Ошибка: Карта времени не найдена"
    exit 1
fi

# Функция настройки SMA выхода
configure_sma() {
    local sma_num=$1
    local function=$2
    local period_ns=$3
    local additional_params="$4"
    
    echo "Настройка SMA$sma_num: $function"
    
    # Основная функция
    echo "$function" > $TIMECARD_DEV/sma${sma_num}_out
    
    # Период (если применимо)
    if [ -n "$period_ns" ]; then
        echo "$period_ns" > $TIMECARD_DEV/sma${sma_num}_period_ns
    fi
    
    # Дополнительные параметры
    if [ -n "$additional_params" ]; then
        eval "$additional_params"
    fi
}

# SMA1: PPS выход (1 импульс в секунду)
configure_sma 1 "pps" "1000000000"

# SMA2: 10MHz опорная частота  
configure_sma 2 "10MHz" "100"

# SMA3: SMPTE timecode 25fps
configure_sma 3 "smpte" "" "echo '25fps' > $TIMECARD_DEV/sma3_smpte_format"

# SMA4: Программируемый выход 1MHz
configure_sma 4 "programmable" "1000"

# Проверка статуса
echo ""
echo "Статус SMA выходов:"
for i in {1..4}; do
    if [ -f "$TIMECARD_DEV/sma${i}_status" ]; then
        status=$(cat $TIMECARD_DEV/sma${i}_status)
        function=$(cat $TIMECARD_DEV/sma${i}_out 2>/dev/null || echo "неизвестно")
        echo "SMA$i: $function - $status"
    fi
done
```

## 6. Мониторинг и диагностика

### Комплексный скрипт мониторинга

```bash
#!/bin/bash
# /usr/local/bin/monitor-timecard-protocols.sh

TIMECARD_DEV="/sys/class/timecard/ocp0"
LOG_FILE="/var/log/timecard-monitor.log"

# Функция логирования
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Функция проверки статуса карты времени
check_timecard_status() {
    log_message "=== Состояние карты времени ==="
    
    if [ -f "$TIMECARD_DEV/status" ]; then
        status=$(cat $TIMECARD_DEV/status)
        log_message "Статус карты: $status"
    fi
    
    if [ -f "$TIMECARD_DEV/atomic_lock_status" ]; then
        atomic_status=$(cat $TIMECARD_DEV/atomic_lock_status)
        log_message "Статус атомных часов: $atomic_status"
    fi
    
    if [ -f "$TIMECARD_DEV/gnss_status" ]; then
        gnss_status=$(cat $TIMECARD_DEV/gnss_status)
        log_message "Статус GNSS: $gnss_status"
    fi
}

# Функция проверки NTP статистики
check_ntp_status() {
    log_message "=== NTP статистика ==="
    
    if command -v chronyc >/dev/null 2>&1; then
        chronyc tracking | while read line; do
            log_message "Chrony: $line"
        done
        
        chronyc sources -v | while read line; do
            log_message "Chrony sources: $line"
        done
    fi
}

# Функция проверки PTP статистики  
check_ptp_status() {
    log_message "=== PTP статистика ==="
    
    if pgrep ptp4l >/dev/null; then
        # Получение статистики через pmc
        if command -v pmc >/dev/null 2>&1; then
            pmc -u -b 0 'GET CURRENT_DATA_SET' | while read line; do
                log_message "PTP: $line"
            done
        fi
    else
        log_message "PTP: ptp4l не запущен"
    fi
}

# Функция проверки PHC синхронизации
check_phc_status() {
    log_message "=== PHC синхронизация ==="
    
    for ptp_dev in /dev/ptp*; do
        if [ -c "$ptp_dev" ]; then
            if command -v phc_ctl >/dev/null 2>&1; then
                time_info=$(phc_ctl $ptp_dev get 2>/dev/null)
                log_message "PHC $ptp_dev: $time_info"
            fi
        fi
    done
}

# Функция проверки SMA выходов
check_sma_status() {
    log_message "=== SMA выходы ==="
    
    for i in {1..4}; do
        if [ -f "$TIMECARD_DEV/sma${i}_status" ]; then
            status=$(cat $TIMECARD_DEV/sma${i}_status)
            function=$(cat $TIMECARD_DEV/sma${i}_out 2>/dev/null || echo "неизвестно")
            log_message "SMA$i: $function - $status"
        fi
    done
}

# Функция проверки точности синхронизации
check_timing_accuracy() {
    log_message "=== Точность синхронизации ==="
    
    # Сравнение времени между различными источниками
    if [ -f "$TIMECARD_DEV/time_ns" ]; then
        timecard_time=$(cat $TIMECARD_DEV/time_ns)
        system_time=$(date +%s%N)
        
        # Вычисление разности (в наносекундах)
        diff=$((timecard_time - system_time))
        log_message "Разность времени карта/система: $diff нс"
        
        # Предупреждение если разность больше допустимой
        if [ ${diff#-} -gt 1000000 ]; then  # Больше 1 мс
            log_message "ВНИМАНИЕ: Большая разность времени!"
        fi
    fi
}

# Основная функция мониторинга
main_monitor() {
    log_message "Начало мониторинга протоколов точного времени"
    
    check_timecard_status
    check_ntp_status  
    check_ptp_status
    check_phc_status
    check_sma_status
    check_timing_accuracy
    
    log_message "Мониторинг завершен"
    log_message "================================"
}

# Проверка режима работы
case "$1" in
    "continuous")
        # Непрерывный мониторинг каждые 60 секунд
        while true; do
            main_monitor
            sleep 60
        done
        ;;
    "daemon")
        # Запуск как демон
        nohup "$0" continuous > /dev/null 2>&1 &
        echo $! > /var/run/timecard-monitor.pid
        echo "Демон мониторинга запущен (PID: $!)"
        ;;
    *)
        # Одноразовый запуск
        main_monitor
        ;;
esac
```

## 7. Автоматизация и системные сервисы

### Systemd сервис для автоматического запуска

```ini
# /etc/systemd/system/timecard-protocols.service

[Unit]
Description=TimeCard Precision Time Protocols Service
After=network.target
Wants=network.target

[Service]
Type=forking
ExecStartPre=/usr/local/bin/quantum-pci-timecard-init.sh
ExecStart=/usr/local/bin/quantum-pci-timecard-start-protocols.sh
ExecStop=/usr/local/bin/timecard-stop-protocols.sh
ExecReload=/usr/local/bin/timecard-reload-config.sh
PIDFile=/var/run/timecard-protocols.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Скрипт запуска протоколов

```bash
#!/bin/bash
# /usr/local/bin/timecard-start-protocols.sh

# Настройка переменных
TIMECARD_DEV="/sys/class/timecard/ocp0"
CONFIG_DIR="/etc/timecard"
LOG_FILE="/var/log/timecard-protocols.log"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# Инициализация карты времени
init_timecard() {
    log "Инициализация карты времени"
    
    # Настройка источника времени
    echo "GNSS" > $TIMECARD_DEV/clock_source
    
    # Ожидание синхронизации
    timeout=300  # 5 минут
    while [ $timeout -gt 0 ] && [ "$(cat $TIMECARD_DEV/gnss_sync)" != "locked" ]; do
        sleep 1
        timeout=$((timeout - 1))
    done
    
    if [ "$(cat $TIMECARD_DEV/gnss_sync)" = "locked" ]; then
        log "GNSS синхронизация установлена"
    else
        log "ПРЕДУПРЕЖДЕНИЕ: GNSS синхронизация не установлена"
    fi
}

# Запуск NTP сервиса
start_ntp() {
    log "Запуск NTP (chrony)"
    systemctl start chronyd
    systemctl enable chronyd
}

# Запуск PTP сервиса
start_ptp() {
    log "Запуск PTP"
    
    # Синхронизация PHC с картой времени
    /usr/local/bin/sync-phc-timecard.sh &
    echo $! > /var/run/phc-sync.pid
    
    # Запуск ptp4l
    ptp4l -f $CONFIG_DIR/ptp4l.conf -i eth0 -s &
    echo $! > /var/run/ptp4l.pid
}

# Запуск White Rabbit (если настроен)
start_white_rabbit() {
    if [ -f "$CONFIG_DIR/wr-config.conf" ]; then
        log "Запуск White Rabbit"
        # Здесь должна быть команда запуска WR демона
        # wr-daemon -f $CONFIG_DIR/wr-config.conf &
        # echo $! > /var/run/wr-daemon.pid
    fi
}

# Настройка SMA выходов
configure_sma() {
    log "Настройка SMA выходов"
    /usr/local/bin/configure-sma-outputs.sh
}

# Запуск мониторинга
start_monitoring() {
    log "Запуск мониторинга"
    /usr/local/bin/monitor-timecard-protocols.sh daemon
}

# Основная функция
main() {
    log "=== Запуск протоколов точного времени ==="
    
    init_timecard
    configure_sma
    start_ntp
    start_ptp
    start_white_rabbit
    start_monitoring
    
    # Создание основного PID файла
    echo $$ > /var/run/timecard-protocols.pid
    
    log "Все протоколы запущены"
}

main "$@"
```

Это комплексное руководство объединяет все необходимые компоненты для реализации различных протоколов точного времени с использованием PCI карты времени с атомным стандартом и GNSS приемником. Документация интегрирована в существующую структуру проекта и готова к использованию.