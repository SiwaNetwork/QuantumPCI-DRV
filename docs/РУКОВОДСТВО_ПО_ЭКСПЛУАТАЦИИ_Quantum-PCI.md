### Руководство по эксплуатации Quantum‑PCI

Версия документа: 2.0  •  Назначение: эксплуатация платы Quantum‑PCI под Linux. Включены инструкции по драйверу, работе с прошивками и настройке Chrony/PTP.

---

### 1. Назначение и область применения

Плата Quantum‑PCI предназначена для высокоточного времени и синхронизации по протоколам PTP/IEEE‑1588 и NTP. Настоящее руководство описывает установку, подключение, установку драйвера, работу с прошивками и настройку системного времени в Linux.

---

### 2. Комплект поставки

- **Плата Quantum‑PCI**: 1 шт.
- **Антенна/кабель GNSS** (если предусмотрено комплектацией): 1 шт.
- **Документация**: электронная версия в репозитории.

---

### 3. Требования

#### Системные требования
- **ОС**: Ubuntu LTS 20.04/22.04/24.04 с ядром ≥ 5.4 (рекомендуется 5.15+)
- **Аппаратура**: PCIe слот (x1 электрически, совместим с x4/x8/x16 механически)
- **Права**: root/`sudo` для установки драйверов и конфигурации времени

#### Настройки BIOS
**Обязательно включите в BIOS:**
- **Для Intel CPU**: VT-d (Virtualization Technology for Directed I/O) или VT-x
- **Для AMD CPU**: IOMMU (Input-Output Memory Management Unit)

#### Пакеты для сборки
```bash
# Ubuntu/Debian
sudo apt-get install libncurses-dev flex bison openssl vim libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf zstd build-essential linux-headers-$(uname -r) linuxptp chrony ethtool pciutils kmod i2c-tools
```

#### Конфигурация ядра (для оптимальной работы)
Рекомендуемые опции ядра:
```
CONFIG_I2C_XILINX=m
CONFIG_MTD=y
CONFIG_MTD_SPI_NOR=m
CONFIG_SPI=y
CONFIG_SPI_ALTERA=m
CONFIG_SPI_BITBANG=m
CONFIG_SPI_MASTER=y
CONFIG_SPI_MEM=y
CONFIG_SPI_XILINX=m
CONFIG_I2C=y
CONFIG_I2C_OCORES=m
CONFIG_IKCONFIG=y
CONFIG_EEPROM_AT24=m
CONFIG_PTP_INTEL_PMC_TGPIO=y  # для TGPIO поддержки
CONFIG_PCIE_PTM=y             # для PTM поддержки
```

Примечание: Поддержка Windows в рамках данного руководства не рассматривается.

---

### 4. Меры безопасности

- Перед установкой отключайте питание сервера и используйте антистатические средства.
- Избегайте изгиба платы, усилий на разъёмы и кабели.
- При работе с прошивками используйте стабильное питание и не прерывайте процесс записи.

---

### 5. Описание изделия и архитектура

Плата представляет собой PCIe‑карту высокоточной синхронизации, обеспечивающую:
- Аппаратные часы PHC, доступные в Linux как `/dev/ptpX`.
- Вход/выход сигналов точного времени (например, 1PPS и 10MHz) через SMA‑разъёмы.
- Опциональные интерфейсы временных кодов (например, IRIG‑B/DCF), зависящие от аппаратной ревизии.
- Дисциплинирование высокостабильного генератора (OCXO/CSAC/TCXO) от GNSS или внешних опор.

Типовая архитектура:
- Логика на ПЛИС/FPGA формирует PHC, обрабатывает PPS/10MHz и взаимодействует с драйвером.
- GNSS‑приёмник (при наличии) даёт опорный PPS/TOD.
- Высокостабильный генератор обеспечивает удержание (holdover) при потере опоры.
- Драйвер ядра экспонирует устройства времени, пользователи работают через `linuxptp`/`chrony`.
- **PTM (Precision Time Measurement)**: современные карты поддерживают PCIe PTM для высокоточной синхронизации с минимальной задержкой.
- **TGPIO (Time-Aware GPIO)**: некоторые карты поддерживают временно-управляемые GPIO для прецизионного вывода сигналов.

---

### 6. Интерфейсы и разъёмы

#### PCIe интерфейс
- **Слот**: электрически x1 (механический разъём x4/x8/x16 совместим)
- **ОС**: Linux
- **Устройства в системе**: PHC `/dev/ptpX`, при наличии — PPS `/dev/ppsY`

#### SMA разъёмы
Карта имеет **4 конфигурируемых SMA разъёма** + **1 GNSS антенный вход**.

**Базовая конфигурация при старте:**
- **ANT1** (INPUT): Default 10MHz — вход опорной частоты 10 МГц
- **ANT2** (INPUT): Default 1 PPS — вход опорного импульса 1PPS  
- **ANT3** (OUTPUT): Default 10MHz — выход частоты 10 МГц от FPGA
- **ANT4** (OUTPUT): Default 1 PPS — выход импульса 1PPS от FPGA
- **GNSS**: SMA‑вход под активную GNSS антенну

#### Конфигурирование SMA
Направление (вход/выход) и назначение SMA разъёмов может быть изменено через:
- **TC SMA Selector IP core** (2 AXI slaves)
- Интерфейс sysfs: `/sys/class/timecard/ocp0/sma*_in` и `/sys/class/timecard/ocp0/sma*_out`

Примеры команд конфигурирования:
```bash
# Просмотр доступных сигналов
cat /sys/class/timecard/ocp0/available_sma_inputs
cat /sys/class/timecard/ocp0/available_sma_outputs

# Настройка SMA1 как вход для 10MHz
echo "10MHz" > /sys/class/timecard/ocp0/sma1_in

# Настройка SMA4 как выход PPS
echo "PPS" > /sys/class/timecard/ocp0/sma4_out

# Проверка текущей конфигурации
cat /sys/class/timecard/ocp0/sma1_in
cat /sys/class/timecard/ocp0/sma4_out
```

#### Рекомендации по подключению
- Используйте **50‑омные коаксиальные кабели** и качественные переходники
- Соблюдайте согласование и уровни сигналов
- Избегайте длинных трасс возле ВЧ‑источников помех
- Для точных измерений учитывайте задержки кабелей и калибруйте их через sysfs

---

### 7. Световая индикация

Карта имеет 4 светодиода (LED1-LED4), которые управляются непосредственно FPGA и показывают состояние различных компонентов:

#### Назначение светодиодов
- **LED1**: Индикатор работы FPGA — мигает с частотой внутренних часов FPGA (50MHz)
- **LED2**: Индикатор тактирования PCIe — мигает с частотой PCIe clock (62.5MHz)  
- **LED3**: PPS от FPGA — мигает синхронно с 1PPS от локальных часов (PPS Master)
- **LED4**: PPS от MAC — мигает синхронно с 1PPS от MAC (через дифференциальный буфер)

#### Диагностика по светодиодам
**Нормальная работа:**
- LED1: быстрое мигание (50MHz) — FPGA работает
- LED2: быстрое мигание (62.5MHz) — PCIe тактирование в норме
- LED3: мигание 1 раз в секунду — PPS от FPGA генерируется
- LED4: мигание 1 раз в секунду — PPS от MAC поступает

**Проблемы:**
- LED1 не мигает — проблема с FPGA или питанием
- LED2 не мигает — проблема с PCIe тактированием
- LED3 не мигает — нет PPS от локальных часов FPGA
- LED4 не мигает — нет PPS от MAC или проблема с входным сигналом

#### Проверка через команды
```bash
# Проверка состояния через dmesg
dmesg | grep -i "ptp_ocp\|led"

# Проверка PPS сигналов
cat /sys/class/timecard/ocp0/clock_source
cat /sys/class/timecard/ocp0/gnss_sync

# Проверка PTP устройства
ls -la /dev/ptp*
```

**Примечание**: Светодиоды подключены напрямую к FPGA (не через AXI GPIO Ext), поэтому их состояние отражает аппаратную работу компонентов в реальном времени.

---

### 8. Режимы работы

- Режим Grandmaster: карта синхронизирована от GNSS или внешнего 1PPS/10MHz и раздаёт время по PTP.
- Режим Ordinary/Slave: карта принимает время по PTP, может копировать PHC → системные часы.
- Режим Boundary: при наличии нескольких интерфейсов может ретранслировать время между сегментами сети.
- Удержание (holdover): при потере опоры поддерживается стабильность за счёт OCXO/CSAC; длительность и точность зависят от аппаратуры.

---

### 9. Типовые сценарии эксплуатации

1) Grandmaster c GNSS:
   - Подключите GNSS‑антенну, дождитесь фиксирования.
   - Настройте PTP‑домен и приоритеты в `ptp4l` для роли мастера.
   - Пример (фрагмент `ptp4l.conf`):

```ini
[global]
time_stamping         hardware
twoStepFlag           1
domainNumber          0
gmCapable             1
priority1             10
priority2             10
```

2) Клиент PTP (Ordinary/Slave):
   - Используйте запуск из раздела 15; PHC → системные часы через `phc2sys`.

3) Внешняя опора 10MHz/1PPS:
   - Подайте сигналы на входные SMA, включите соответствующий режим в прошивке/настройках.
   - Проверьте стабильность и задержки по журналам `ptp4l`/`phc2sys`.

---

### 10. Базовая конфигурация FPGA

При инициализации карты **TC ConfMaster** автоматически применяет базовую конфигурацию из файла `DefaultConfigFile.txt`. Эта конфигурация включает:

#### Компоненты, настраиваемые при старте

| **IP Core**          | **Конфигурация при старте**                                    |
|----------------------|---------------------------------------------------------------|
| **Adjustable Clock** | Включен с источником синхронизации 1 (ToD+PPS)               |
| **PPS Generator**     | Включен с высокой полярностью выходного импульса             |
| **PPS Slave**         | Включен с высокой полярностью входного импульса              |
| **ToD Slave**         | Включен с высокой полярностью UART входа                     |
| **SMA Selector**      | Настроен на вывод FPGA PPS и GNSS PPS через SMA разъёмы     |

#### Проверка базовой конфигурации

```bash
# Проверка источника синхронизации
cat /sys/class/timecard/ocp0/clock_source

# Проверка доступных источников
cat /sys/class/timecard/ocp0/available_clock_sources

# Проверка конфигурации SMA
cat /sys/class/timecard/ocp0/sma3_out  # должно показать "10MHz"
cat /sys/class/timecard/ocp0/sma4_out  # должно показать "PPS"

# Проверка статуса PPS генератора
cat /sys/class/timecard/ocp0/pps_generator_enable 2>/dev/null || echo "PPS generator status not available"
```

#### Изменение базовой конфигурации

Для изменения конфигурации по умолчанию можно:

1. **Через sysfs интерфейс** (временно, до перезагрузки):
```bash
# Изменение источника синхронизации
echo "GNSS" > /sys/class/timecard/ocp0/clock_source

# Переназначение SMA выходов
echo "IRIG" > /sys/class/timecard/ocp0/sma3_out
echo "DCF" > /sys/class/timecard/ocp0/sma4_out
```

2. **Через модификацию прошивки** (постоянно):
   - Изменить `DefaultConfigFile.txt` в прошивке
   - Перепрошить карту с новой конфигурацией

#### Сброс к базовой конфигурации

```bash
# Перезагрузка драйвера для применения базовой конфигурации
sudo rmmod ptp_ocp
sudo modprobe ptp_ocp

# Или полная перезагрузка системы
sudo reboot
```

### 11. Технические примечания

- Количество и назначение SMA‑портов могут отличаться по ревизиям; уточняйте маркировку на панели.
- Экспорт признака високосной секунды и дополнительные каналы (IRIG‑B, DCF77, SMPTE) зависят от прошивки.
- Для критичных применений рекомендуется резервирование опор времени и регулярная калибровка задержек кабелей.
- Базовая конфигурация применяется автоматически, но может быть изменена через sysfs или модификацией прошивки.

---

### 12. Установка платы и первичная проверка

1) **Подготовка системы**: убедитесь, что в BIOS включены VT-d/IOMMU (см. раздел 3).

2) **Проверка информации о системе** (полезно для диагностики):
```bash
# Информация о материнской плате
sudo dmidecode -t baseboard

# Информация о системе
sudo dmidecode -t system
```

3) Установите плату в совместимый слот PCIe и зафиксируйте винтом.
4) Подключите GNSS‑антенну (если предусмотрено) согласно маркировке.
5) Включите сервер и в Linux проверьте обнаружение устройства:

```bash
# Проверка обнаружения карты
sudo lspci -nn | grep -i 'ptp\|time\|quantum\|xilinx\|fpga' || true

# Детальная информация о карте (после загрузки драйвера)
sudo lspci -vvv | grep -A 20 -B 5 "ptp_ocp"

# Проверка поддержки PTM
sudo lspci -vvv | grep -A 10 "Precision Time Measurement"
```

6) **Проверка PTM поддержки** (если доступно):
```bash
# Поиск PTM возможностей
sudo lspci -vvv | grep -A 5 "PTMCap"
```

Ожидаемый вывод для карты с PTM:
```
PTMCap: Requester:+ Responder:- Root:-
PTMClockGranularity: 8ns
PTMControl: Enabled:+ RootSelected:-
PTMEffectiveGranularity: 4ns
```

Сверьтесь с `ДРАЙВЕРА/ТAБЛИЦА_СООТВЕТСТВИЯ_PCI.md` и `ДРАЙВЕРА/СОПОСТАВЛЕНИЕ_PCI_ДРАЙВЕРА.md` при необходимости.

---

### 13. Установка и загрузка драйвера (Ubuntu)

Исходники и готовые артефакты расположены в каталоге `ДРАЙВЕРА/` (файлы `ptp_ocp.c`, `ptp_ocp.ko`, `Makefile` и др.).

- **Установка зависимостей (Ubuntu):**

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) ethtool linuxptp chrony pciutils dkms kmod
```

- **Сборка (если требуется):**

```bash
cd ДРАЙВЕРА
make -j"$(nproc)"
```

- **Загрузка модуля (временная, до перезагрузки):**

```bash
cd ДРАЙВЕРА
sudo insmod ptp_ocp.ko 2>/dev/null || sudo modprobe ptp_ocp
```

- **Автозагрузка модуля (после перезагрузки):**

```bash
echo ptp_ocp | sudo tee /etc/modules-load.d/quantum-pci.conf
```

- **Проверка статуса драйвера:**

```bash
lsmod | grep ptp_ocp || true
dmesg -T | grep -i ptp_ocp || true
ls -l /dev/ptp*
```

Если используется Secure Boot, может потребоваться подпись модуля и регистрация ключа (MOK). Обратитесь к документации дистрибутива.

— Подпись модуля для Secure Boot (Ubuntu):

```bash
# 1) Создаём ключи
sudo mkdir -p /root/module-signing
cd /root/module-signing
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=PTP OCP Module/"

# 2) Регистрируем ключ (потребуется подтверждение при перезагрузке в MOK Manager)
sudo mokutil --import MOK.der
sudo reboot

# 3) Подписываем модуль после сборки
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 \
  /root/module-signing/MOK.priv /root/module-signing/MOK.der \
  ДРАЙВЕРА/ptp_ocp.ko

# 4) Загружаем модуль
sudo insmod ДРАЙВЕРА/ptp_ocp.ko || sudo modprobe ptp_ocp
```

---

### 14. Работа с прошивками

Скрипты расположены в `ДРАЙВЕРА/`:

- `check_firmware_type.sh` — определить тип прошивки.
- `convert_firmware.sh` — конвертировать формат прошивки при необходимости.
- `switch_firmware_type.sh` — переключить тип прошивки.
- `modify_firmware.sh` / `simple_modify_firmware.sh` — внести правки (ID, параметры).
- `flash_programmer.sh` — запись прошивки во флеш‑память устройства.

Пример последовательности:

```bash
cd ДРАЙВЕРА
./check_firmware_type.sh firmware.bin
./convert_firmware.sh firmware.bin firmware_conv.bin     # при необходимости
./switch_firmware_type.sh firmware_conv.bin              # при необходимости
sudo ./flash_programmer.sh firmware_conv.bin
```

Рекомендации:
- Используйте ИБП и не прерывайте питание во время прошивки.
- После прошивки выполните перезагрузку и проверьте логи `dmesg`.

Дополнительно см. `ДРАЙВЕРА/ИНСТРУКЦИЯ_ПО_РАБОТЕ_С_ПРОШИВКАМИ.md` и `ДРАЙВЕРА/ИНСТРУКЦИЯ_ПРОШИВКИ_ПРОГРАММАТОРОМ.md`.

---

### 15. Работа с GNSS приемником

После установки драйвера необходимо проверить и настроить работу с GNSS приемником (если присутствует на карте).

#### Проверка доступности GNSS портов

```bash
# Проверка доступных последовательных портов
ls -la /dev/ttyS* /dev/ttyGNSS* /dev/ttyMAC* /dev/ttyNMEA* 2>/dev/null

# Проверка связанных с картой портов (после загрузки драйвера)
find /sys/class/timecard/ocp* -name "tty*" -exec readlink {} \; 2>/dev/null
```

#### Метод 1: Использование gpsd (рекомендуется)

**Установка gpsd на Ubuntu:**

```bash
sudo apt update
sudo apt install gpsd gpsd-clients python3-gps
```

**Настройка и запуск:**

```bash
# Настройка скорости порта (обычно ttyS5 или ttyGNSS)
sudo stty -F /dev/ttyS5 speed 115200

# Запуск gpsd (замените /dev/ttyS5 на актуальный порт)
sudo gpsd /dev/ttyS5

# Проверка работы GNSS через cgps
cgps
```

**Пример вывода cgps при работающем GNSS:**
```
┌─────────────────────────────────────────────────┐
│    Time: 2024-01-15T12:34:56.000Z              │
│ Latitude:  55.123456789 N                      │
│Longitude:  37.987654321 E                      │
│ Altitude:    156.78 m                          │
│    Speed:      0.12 kph                        │
│  Heading:     45.6 deg (true)                  │
│    Climb:      0.0 m/min                       │
│   Status:      3D FIX (5 secs)                 │
│Satellites: 12 used, 15 in view                 │
└─────────────────────────────────────────────────┘
```

#### Метод 2: Прямое подключение через tio

**Установка tio на Ubuntu:**

```bash
sudo apt install tio
```

**Проверка сообщений GPS:**

```bash
# Мониторинг сообщений от GPS модуля
tio -b 115200 /dev/ttyS5

# Проверка NMEA сообщений от FPGA
tio -b 115200 /dev/ttyS0
```

**Пример NMEA сообщений:**
```
$GPGGA,123456.00,5512.34567,N,03759.87654,E,1,12,0.8,156.78,M,15.2,M,,*5A
$GPRMC,123456.00,A,5512.34567,N,03759.87654,E,0.12,45.6,150124,,,A*7B
$GPGSV,3,1,12,01,45,123,42,02,67,234,45,03,23,345,38,04,78,456,41*7C
```

Для выхода из tio нажмите `Ctrl+T`, затем `q`.

#### Метод 3: GUI инструмент pygpsclient

**Установка на Ubuntu:**

```bash
# Установка зависимостей
sudo apt update
sudo apt install python3 python3-pip python3-tkinter

# Обновление pip
python3 -m pip install --upgrade pip

# Установка необходимых библиотек
python3 -m pip install --upgrade Pillow
python3 -m pip install pygpsclient

# Для работы через VNC (если требуется удаленный доступ)
sudo apt install tigervnc-standalone-server tigervnc-xorg-extension
```

**Настройка VNC (если требуется удаленный GUI доступ):**

```bash
# Настройка VNC сервера
vncserver :1 -geometry 1024x768 -depth 24

# Установка пароля VNC (при первом запуске)
vncpasswd
```

**Запуск pygpsclient:**

```bash
# Локально (с GUI)
pygpsclient

# Через VNC
DISPLAY=:1 pygpsclient
```

#### Диагностика GNSS

**Проверка состояния GNSS через sysfs:**

```bash
# Проверка статуса GNSS синхронизации
cat /sys/class/timecard/ocp0/gnss_sync 2>/dev/null || echo "GNSS sysfs недоступен"

# Проверка источника времени
cat /sys/class/timecard/ocp0/clock_source 2>/dev/null || echo "Clock source недоступен"

# Проверка доступных источников времени
cat /sys/class/timecard/ocp0/available_clock_sources 2>/dev/null || echo "Available sources недоступны"

# Дополнительные атрибуты TOD (Time of Day)
cat /sys/class/timecard/ocp0/tod_protocol 2>/dev/null || echo "TOD protocol недоступен"
cat /sys/class/timecard/ocp0/available_tod_protocols 2>/dev/null || echo "Available TOD protocols недоступны"
cat /sys/class/timecard/ocp0/tod_baud_rate 2>/dev/null || echo "TOD baud rate недоступен"

# Проверка режима holdover
cat /sys/class/timecard/ocp0/holdover 2>/dev/null || echo "Holdover status недоступен"

# Статус дрейфа и смещения часов
cat /sys/class/timecard/ocp0/clock_status_drift 2>/dev/null || echo "Clock drift недоступен"
cat /sys/class/timecard/ocp0/clock_status_offset 2>/dev/null || echo "Clock offset недоступен"
```

**Возможные статусы GNSS:**
- `locked` - GNSS синхронизирован
- `unlocked` - GNSS не синхронизирован
- `holdover` - режим удержания времени

#### Устранение проблем с GNSS

**Частые проблемы:**

1. **GNSS порт не найден:**
```bash
# Проверка всех последовательных портов
dmesg | grep -i "tty\|uart\|serial"

# Проверка загруженного драйвера
lsmod | grep ptp_ocp
```

2. **Нет NMEA сообщений:**
```bash
# Проверка скорости порта
sudo stty -F /dev/ttyS5 -a

# Попробуйте разные скорости
for speed in 9600 38400 115200; do
    echo "Trying speed $speed"
    sudo stty -F /dev/ttyS5 speed $speed
    timeout 10s tio -b $speed /dev/ttyS5
done
```

3. **GNSS не получает фиксацию:**
   - Убедитесь, что GNSS антенна подключена и имеет питание
   - Проверьте, что антенна установлена с хорошим обзором неба
   - Дождитесь "холодного старта" (может занять до 15 минут)

#### Автоматизация запуска gpsd

**Создание systemd сервиса:**

```bash
sudo tee /etc/systemd/system/gpsd-timecard.service << EOF
[Unit]
Description=GPS daemon for TimeCard
After=network.target

[Service]
Type=forking
ExecStartPre=/bin/stty -F /dev/ttyS5 speed 115200
ExecStart=/usr/sbin/gpsd -n /dev/ttyS5
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Включение и запуск сервиса
sudo systemctl daemon-reload
sudo systemctl enable gpsd-timecard
sudo systemctl start gpsd-timecard

# Проверка статуса
sudo systemctl status gpsd-timecard
```

---

### 16. Настройка системного времени: варианты

- **PTP (linuxptp):** точная синхронизация через аппаратные метки времени (PHC, `/dev/ptpX`).
- **NTP (chrony/ntpd):** синхронизация с NTP‑серверами или локальным PHC как референсом.

Роль карты Quantum‑PCI:
- Предоставляет PHC‑часы (`/dev/ptpX`) и аппаратные метки времени для `ptp4l`.
- Может выступать как Grandmaster/Ordinary/Boundary в зависимости от конфигурации сети и прошивки.

---

### 17. Быстрый старт: PTP (linuxptp)

Установка:

```bash
sudo apt install -y linuxptp
```

Определите сетевой интерфейс с поддержкой аппаратной отметки (пример: `eno1`), проверьте возможности:

```bash
sudo ethtool -T eno1
```

Запуск `ptp4l` (Ordinary Clock, двухступенчатый, аппаратные метки):

```bash
sudo ptp4l -i eno1 -m -2 -s
# -m: лог в консоль, -2: two-step, -s: slaveOnly (пример для клиента)
```

Синхронизация системных часов от PHC:

```bash
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -O 0 -m
```

Альтернативно указать интерфейс:

```bash
sudo phc2sys -s eno1 -c CLOCK_REALTIME -O 0 -m
```

Проверка статуса и параметров через `pmc`:

```bash
sudo pmc -u -b 0 'GET GRANDMASTER_SETTINGS_NP' 'GET TIME_STATUS_NP'
```

Пример минимального конфига `ptp4l` (создайте файл, например `/etc/linuxptp/ptp4l.conf`):

```ini
[global]
verbose               1
twoStepFlag           1
time_stamping         hardware
tx_timestamp_timeout  50
logging_level         6

[eno1]
network_transport     UDPv4
delay_mechanism       E2E
```

Запуск с конфигом:

```bash
sudo ptp4l -f /etc/linuxptp/ptp4l.conf -m
```

Автозапуск можно настроить через systemd‑юниты `ptp4l.service` и `phc2sys.service` (примеры в документации `linuxptp`).

---

### 18. Быстрый старт: NTP (chrony)

Установка:

```bash
sudo apt install -y chrony
```

**Вариант 1: Базовая конфигурация клиента NTP** (`/etc/chrony/chrony.conf`):

```conf
pool pool.ntp.org iburst
rtcsync
makestep 1.0 3
```

**Вариант 2: Использование локального PHC как референс** (при наличии GNSS/точного PHC):

```conf
refclock PHC /dev/ptp0 poll 2 dpoll -2 offset 0.0 prefer
rtcsync
makestep 1.0 3
```

**Вариант 3: Прямая синхронизация PHC → система (рекомендуется)**

Согласно официальной документации Time Card, наиболее точный способ:

```bash
# Остановить конфликтующие службы
sudo systemctl stop systemd-timesyncd.service

# Установить PHC время от системного времени (однократно при первом запуске)
sudo phc_ctl /dev/ptp0 set

# Запустить непрерывную синхронизацию система ← PHC
sudo phc2sys -c CLOCK_REALTIME -s /dev/ptp0 -O 0 -R 16 -u 8 -m
```

При корректной работе PTM вывод `phc2sys` должен показывать **delay 0 +/-**:
```
phc2sys[4503.063]: CLOCK_REALTIME rms 26 max 40 freq -17250 +/- 17 delay 0+/- 0
phc2sys[4503.564]: CLOCK_REALTIME rms 46 max 85 freq -17346 +/- 17 delay 0+/- 0
```

Применение настроек и проверка (для вариантов 1-2):

```bash
sudo systemctl restart chrony
chronyc tracking
chronyc sources -v
```

**Важно**: избегайте одновременного управления временем несколькими службами. Отключите `systemd-timesyncd`:

```bash
sudo systemctl stop systemd-timesyncd
sudo systemctl disable systemd-timesyncd
```

---

### 19. Эксплуатация и обслуживание

- Обеспечивайте охлаждение и чистоту разъёмов.
- Обновляйте драйвер и прошивку планово, тестируйте в стенде.
- Ведите журнал изменений конфигураций PTP/NTP.

---

### 20. Приложение: примеры systemd‑юнитов

`/etc/systemd/system/ptp4l.service`:

```ini
[Unit]
Description=linuxptp ptp4l
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/ptp4l -f /etc/linuxptp/ptp4l.conf -m
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/phc2sys.service`:

```ini
[Unit]
Description=linuxptp phc2sys
After=ptp4l.service
Requires=ptp4l.service

[Service]
Type=simple
ExecStart=/usr/sbin/phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -O 0 -m
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

Активация:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ptp4l phc2sys
```

---

### 21. Ссылки на материалы репозитория

- `ДРАЙВЕРА/ИНСТРУКЦИЯ_ПО_РАБОТЕ_С_ПРОШИВКАМИ.md`
- `ДРАЙВЕРА/ИНСТРУКЦИЯ_ПРОШИВКИ_ПРОГРАММАТОРОМ.md`
- `docs/guides/installation.md` и `docs/guides/linuxptp-guide.md`
- `docs/guides/chrony-guide.md` и `docs/guides/precision-time-protocols.md`

---

### 22. Поддержка

При обращении приложите версии ядра (`uname -a`), драйвера, вывод `dmesg` и конфигурационные файлы `ptp4l`/`chrony`.



---

### 23. Консолидированные инструкции из каталога docs

Этот раздел объединяет ключевые инструкции из встроенной документации: быстрый старт, установка, LinuxPTP, Chrony, детальная конфигурация и устранение неполадок.

— Быстрый старт (установка, сборка, загрузка модуля): см. разделы 6, 9–10 и сводка ниже.
— Полная установка и обновление: сводка по `installation` ниже.
— LinuxPTP/Chrony: сводки ниже + расширенные примеры конфигураций.
— Детальная конфигурация драйвера и sysfs: сводка ниже.
— Диагностика: сводка ниже.

---

### 24. Сводка: установка и обновление драйвера

- Зависимости (Debian/Ubuntu):

```bash
sudo apt update && sudo apt install -y \
  build-essential linux-headers-$(uname -r) git make gcc dkms pkg-config \
  linuxptp chrony ethtool pciutils usbutils kmod
```

- Сборка и загрузка:

```bash
cd ДРАЙВЕРА
make clean && make
sudo insmod ptp_ocp.ko || sudo modprobe ptp_ocp
lsmod | grep ptp_ocp || true
dmesg -T | grep -i ptp_ocp || true
```

- Постоянная установка:

```bash
sudo make install && sudo depmod -a
echo "ptp_ocp" | sudo tee -a /etc/modules
sudo tee /etc/modprobe.d/ptp-ocp.conf << 'EOF'
# PTP OCP driver configuration
options ptp_ocp debug=0
EOF
```

- Udev правила (доступ пользователям):

```bash
sudo tee /etc/udev/rules.d/99-ptp.rules << 'EOF'
SUBSYSTEM=="ptp", GROUP="dialout", MODE="0664"
KERNEL=="ptp[0-9]*", GROUP="dialout", MODE="0664"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger
```

- Systemd автозагрузка модуля (опционально):

```bash
sudo tee /etc/systemd/system/ptp-ocp.service << 'EOF'
[Unit]
Description=PTP OCP Driver
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe ptp_ocp
ExecStop=/sbin/rmmod ptp_ocp
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now ptp-ocp.service
```

- Вариант через DKMS (обновления ядра):

```bash
sudo mkdir -p /usr/src/ptp-ocp-1.0
sudo cp -r ДРАЙВЕРА/* /usr/src/ptp-ocp-1.0/
sudo tee /usr/src/ptp-ocp-1.0/dkms.conf << 'EOF'
PACKAGE_NAME="ptp-ocp"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="ptp_ocp"
DEST_MODULE_LOCATION[0]="/kernel/drivers/ptp/"
AUTOINSTALL="yes"
EOF
sudo dkms add -m ptp-ocp -v 1.0
sudo dkms build -m ptp-ocp -v 1.0
sudo dkms install -m ptp-ocp -v 1.0
```

---

### 25. Сводка: LinuxPTP (ptp4l, phc2sys, ts2phc)

- Установка:

```bash
sudo apt update && sudo apt install -y linuxptp
```

- Проверка поддержки аппаратных меток и PHC:

```bash
ethtool -T eth0
ls /dev/ptp*
```

- Базовый запуск `ptp4l` и `phc2sys`:

```bash
sudo ptp4l -i eth0 -m            # авто-роль (OC)
sudo ptp4l -i eth0 -s -m         # принудительно slaveOnly
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -O 0 -m
```

- Конфиг `ptp4l` (минимум):

```ini
[global]
time_stamping         hardware
twoStepFlag           1
delay_mechanism       E2E
network_transport     UDPv4
```

- `ts2phc` для внешнего PPS (GPS/генератор):

```bash
sudo tee /etc/ts2phc.conf << 'EOF'
[global]
verbose 1
logging_level 6

[/dev/ptp0]
ts2phc.pin_index 0
ts2phc.channel 0
ts2phc.extts_polarity rising
ts2phc.extts_correction 0

[/dev/pps0]
ts2phc.master 1
EOF
sudo ts2phc -f /etc/ts2phc.conf -m
```

- Профили (пример): телеком/высокая точность см. расширенные примеры в конфигурации PTP. 

---

### 26. Сводка: Chrony (работа с PHC/PPS)

- Установка:

```bash
sudo apt update && sudo apt install -y chrony
```

- Базовая конфигурация клиента `/etc/chrony/chrony.conf`:

```conf
pool pool.ntp.org iburst
rtcsync
makestep 1.0 3
```

- Использование PHC и (опционально) PPS как источников:

```conf
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 stratum 1 prefer
# refclock PPS /dev/pps0 lock PHC precision 1e-9
```

- Команды проверки:

```bash
sudo systemctl restart chrony
chronyc tracking
chronyc sources -v
chronyc refclocks
```

---

### 27. Сводка: детальная конфигурация драйвера и sysfs

- Параметры модуля `/etc/modprobe.d/ptp-ocp.conf`:

```bash
options ptp_ocp debug=0
```

- Интерфейсы ядра:
  - PTP: `/sys/class/ptp/ptpN`, устройство `/dev/ptpN`.
  - Класс устройства: `/sys/class/timecard/ocpN` (если доступен в вашей сборке/прошивке).

- Примеры операций через sysfs (если класс устройства доступен):

```bash
BASE="/sys/class/timecard/ocp0"
[ -d "$BASE" ] || exit 0
cat $BASE/available_clock_sources
echo "GNSS" > $BASE/clock_source
echo "10MHz" > $BASE/sma1_in
echo "PPS"   > $BASE/sma2_in
echo "10MHz" > $BASE/sma3_out
echo "PPS"   > $BASE/sma4_out
echo "100"   > $BASE/external_pps_cable_delay
echo "37"    > $BASE/utc_tai_offset
```

- Конфигурация пинов PTP (если поддерживается):

```bash
PTP="/sys/class/ptp/ptp0"
echo "perout 0 0" > $PTP/pins/SMA1   # выход 1PPS/периодический
echo "extts 0 0"  > $PTP/pins/SMA2   # вход PPS
```

---

### 28. Сетевая оптимизация для PTP

```bash
# Проверка hardware timestamping
ethtool -T eth0

# Базовая настройка линка
sudo ethtool -s eth0 speed 1000 duplex full autoneg off

# Буферы и coalesce
sudo ethtool -G eth0 rx 4096 tx 4096
sudo ethtool -C eth0 rx-usecs 1 tx-usecs 1

# Multicast для PTP (при необходимости)
sudo ip maddr add 01:1B:19:00:00:00 dev eth0
sudo ip maddr add 01:80:C2:00:00:0E dev eth0

# Пример netplan (Ubuntu) для включения PTP интерфейса
sudo tee /etc/netplan/01-ptp.yaml << 'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      optional: true
EOF
sudo netplan apply

# Открыть UFW порты PTP (если UFW включён)
sudo ufw allow 319/udp comment "PTP Event"
sudo ufw allow 320/udp comment "PTP General"
```

Опционально: IRQ affinity и изоляция CPU для снижения джиттера.

---

### 29. Приложение A: Быстрый старт — полный текст

# Быстрый старт

## Обзор

Данное руководство поможет вам быстро начать работу с драйвером PTP OCP для временной синхронизации.

## Предварительные требования

### Системные требования

- Linux ядро версии 5.4 или выше
- Поддержка PCI в ядре
- Модули PTP включены в ядро
- Root права для установки драйвера

### Необходимые пакеты

```bash
# Ubuntu/Debian
sudo apt-get install build-essential linux-headers-$(uname -r) git

# CentOS/RHEL/Fedora
sudo yum install gcc kernel-devel kernel-headers git
# или для новых версий
sudo dnf install gcc kernel-devel kernel-headers git
```

## Быстрая установка

### 1. Получение исходного кода

```bash
git clone <repository-url>
cd ptp-ocp-driver
```

### 2. Сборка драйвера

```bash
cd ДРАЙВЕРА
make
```

### 3. Установка драйвера

```bash
sudo make install
sudo modprobe ptp_ocp
```

### 4. Проверка установки

```bash
# Проверка загрузки модуля
lsmod | grep ptp_ocp

# Проверка обнаружения TimeCard устройств
ls /sys/class/timecard/

# Проверка обнаружения PTP устройств
ls /dev/ptp*

# Проверка через dmesg
dmesg | grep ptp_ocp
```

## Первоначальная настройка

### Проверка устройства

```bash
# Проверка TimeCard устройства
if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "TimeCard device found"
    cat /sys/class/timecard/ocp0/serialnum
    cat /sys/class/timecard/ocp0/clock_source
else
    echo "TimeCard device not found"
fi

# Получение PTP устройства из TimeCard
if [ -L "/sys/class/timecard/ocp0/ptp" ]; then
    PTP_DEV=$(basename $(readlink /sys/class/timecard/ocp0/ptp))
    echo "PTP device: /dev/$PTP_DEV"
else
    PTP_DEV="ptp0"
fi

# Получение информации о PTP устройстве
sudo testptp -d /dev/$PTP_DEV -c

# Проверка capabilities
sudo testptp -d /dev/$PTP_DEV -k
```

### Базовая конфигурация

```bash
# Настройка TimeCard (если доступно)
if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "Configuring TimeCard..."
    echo "GNSS" > /sys/class/timecard/ocp0/clock_source
    echo "PPS" > /sys/class/timecard/ocp0/sma3_out
    echo "TimeCard configured"
fi

# Получение текущего времени
sudo testptp -d /dev/$PTP_DEV -g

# Установка времени (пример)
sudo testptp -d /dev/$PTP_DEV -t $(date +%s)

# Проверка точности
sudo testptp -d /dev/$PTP_DEV -o
```

## Первый тест

### Запуск демона PTP

```bash
# Установка LinuxPTP (если не установлен)
sudo apt-get install linuxptp  # Ubuntu/Debian
# или
sudo yum install linuxptp      # CentOS/RHEL

# Запуск PTP master (используя переменную PTP_DEV из предыдущего раздела)
sudo ptp4l -i eth0 -m -p /dev/$PTP_DEV

# В другом терминале - синхронизация системного времени
sudo phc2sys -s /dev/$PTP_DEV -m
```

### Проверка синхронизации

```bash
# Проверка синхронизации TimeCard (если доступно)
if [ -d "/sys/class/timecard/ocp0" ]; then
    echo "GNSS sync status: $(cat /sys/class/timecard/ocp0/gnss_sync)"
fi

# Проверка offset между PTP и системным временем
sudo phc2sys -s /dev/$PTP_DEV -c CLOCK_REALTIME -O 0 -u 10

# Проверка статистики
sudo testptp -d /dev/$PTP_DEV -o
```

## Типичные проблемы и решения

### Драйвер не загружается

```bash
# Проверка ошибок в dmesg
dmesg | tail -20

# Проверка зависимостей
modinfo ptp_ocp

# Принудительная загрузка
sudo insmod ./ptp_ocp.ko
```

### Устройство не обнаружено

```bash
# Проверка PCI устройств
lspci | grep -i ptp
lspci | grep -i time

# Проверка идентификаторов устройств
lspci -nn | grep -E "(1d9b|8086)"
```

### Проблемы с правами доступа

```bash
# Добавление пользователя в группу
sudo usermod -a -G dialout $USER

# Установка правил udev
echo 'SUBSYSTEM=="ptp", GROUP="dialout", MODE="0664"' | sudo tee /etc/udev/rules.d/99-ptp.rules
sudo udevadm control --reload-rules
```

## Следующие шаги

1. **Детальная конфигурация**: См. [configuration.md](configuration.md)
2. **Интеграция в систему**: См. [integration examples](../examples/integration/)
3. **Отладка**: См. [troubleshooting.md](troubleshooting.md)
4. **API документация**: См. [API reference](../api/)

## Полезные команды

### Проверка состояния

```bash
# Проверка времени
date; sudo testptp -d /dev/ptp0 -g

# Статистика PTP
sudo pmc -u -b 0 'GET DEFAULT_DATA_SET'
sudo pmc -u -b 0 'GET CURRENT_DATA_SET'
```

### Отладка

```bash
# Увеличение уровня логирования
echo 8 > /proc/sys/kernel/printk

# Проверка системного лога
journalctl -k -f | grep ptp
```

### Конфигурационные файлы

Примеры конфигурационных файлов находятся в директории `examples/`:

- `basic-setup/` - базовые конфигурации
- `advanced-config/` - продвинутые настройки
- `integration/` - интеграция с другими системами

---

### 30. Приложение B: Установка и настройка — полный текст

# Установка и настройка

## Обзор

Детальное руководство по установке и настройке драйвера PTP OCP.

## Системные требования

### Минимальные требования

- **ОС**: Linux с ядром версии 5.4+
- **Архитектура**: x86_64, ARM64
- **ОЗУ**: минимум 512 МБ
- **Дисковое пространство**: 100 МБ для исходников и сборки

### Рекомендуемые требования

- **ОС**: Linux с ядром версии 5.15+
- **ОЗУ**: 2 ГБ и более
- **Процессор**: современный многоядерный CPU

### Поддерживаемые дистрибутивы

- **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Debian**: 11 (Bullseye), 12 (Bookworm)
- **CentOS**: 8, 9
- **RHEL**: 8, 9
- **Fedora**: 35+
- **openSUSE**: Leap 15.4+

## Подготовка системы

### Установка зависимостей

#### Ubuntu/Debian

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка необходимых пакетов
sudo apt install -y \
    build-essential \
    linux-headers-$(uname -r) \
    git \
    make \
    gcc \
    dkms \
    pkg-config \
    linuxptp \
    chrony

# Дополнительные утилиты
sudo apt install -y \
    ethtool \
    pciutils \
    usbutils \
    kmod
```

#### CentOS/RHEL 8+

```bash
# Обновление системы
sudo dnf update -y

# Установка EPEL репозитория
sudo dnf install -y epel-release

# Установка необходимых пакетов
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y \
    kernel-devel \
    kernel-headers \
    git \
    make \
    gcc \
    dkms \
    pkg-config \
    linuxptp \
    chrony

# Дополнительные утилиты
sudo dnf install -y \
    ethtool \
    pciutils \
    usbutils \
    kmod
```

#### Fedora

```bash
# Обновление системы
sudo dnf update -y

# Установка необходимых пакетов
sudo dnf groupinstall -y "Development Tools" "C Development Tools and Libraries"
sudo dnf install -y \
    kernel-devel \
    kernel-headers \
    git \
    make \
    gcc \
    dkms \
    pkg-config \
    linuxptp \
    chrony
```

### Проверка ядра

```bash
# Проверка версии ядра
uname -r

# Проверка поддержки PTP
grep -i ptp /boot/config-$(uname -r)

# Проверка модулей PTP
find /lib/modules/$(uname -r) -name "*ptp*"
```

## Сборка и установка драйвера

### Получение исходного кода

```bash
# Клонирование репозитория
git clone <repository-url> ptp-ocp-driver
cd ptp-ocp-driver

# Переход в директорию с драйвером
cd ДРАЙВЕРА
```

### Сборка

```bash
# Проверка Makefile
cat Makefile

# Сборка модуля
make clean
make

# Проверка собранного модуля
ls -la *.ko
modinfo ptp_ocp.ko
```

### Установка

#### Временная установка

```bash
# Загрузка модуля
sudo insmod ptp_ocp.ko

# Проверка загрузки
lsmod | grep ptp_ocp
dmesg | tail -10
```

#### Постоянная установка

```bash
# Установка модуля в систему
sudo make install

# Обновление списка модулей
sudo depmod -a

# Автоматическая загрузка при старте
echo "ptp_ocp" | sudo tee -a /etc/modules

# Создание конфигурации modprobe
sudo tee /etc/modprobe.d/ptp-ocp.conf << EOF
# PTP OCP driver configuration
options ptp_ocp debug=0
EOF
```

#### Установка через DKMS

```bash
# Подготовка для DKMS
sudo mkdir -p /usr/src/ptp-ocp-1.0
sudo cp -r * /usr/src/ptp-ocp-1.0/

# Создание dkms.conf
sudo tee /usr/src/ptp-ocp-1.0/dkms.conf << EOF
PACKAGE_NAME="ptp-ocp"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="ptp_ocp"
DEST_MODULE_LOCATION[0]="/kernel/drivers/ptp/"
AUTOINSTALL="yes"
EOF

# Добавление в DKMS
sudo dkms add -m ptp-ocp -v 1.0
sudo dkms build -m ptp-ocp -v 1.0
sudo dkms install -m ptp-ocp -v 1.0
```

## Настройка системы

### Настройка udev правил

```bash
# Создание правил для устройств PTP
sudo tee /etc/udev/rules.d/99-ptp-ocp.rules << EOF
# PTP OCP device rules
SUBSYSTEM=="ptp", GROUP="dialout", MODE="0664"
KERNEL=="ptp[0-9]*", GROUP="dialout", MODE="0664"
EOF

# Перезагрузка правил udev
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Настройка групп пользователей

```bash
# Добавление пользователя в группы
sudo usermod -a -G dialout,tty $USER

# Проверка членства в группах
groups $USER
```

### Настройка systemd сервисов

```bash
# Создание сервиса для автозагрузки драйвера
sudo tee /etc/systemd/system/ptp-ocp.service << EOF
[Unit]
Description=PTP OCP Driver
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe ptp_ocp
ExecStop=/sbin/rmmod ptp_ocp
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Включение сервиса
sudo systemctl enable ptp-ocp.service
sudo systemctl start ptp-ocp.service
```

## Проверка установки

### Проверка драйвера

```bash
# Статус модуля
lsmod | grep ptp

# Информация о модуле
modinfo ptp_ocp

# Сообщения ядра
dmesg | grep -i ptp | tail -10
```

### Проверка устройств

```bash
# PTP устройства
ls -la /dev/ptp*

# PCI устройства
lspci | grep -i time
lspci | grep -i ptp

# Sysfs интерфейсы
ls -la /sys/class/ptp/
```

### Функциональная проверка

```bash
# Тест PTP устройства
sudo testptp -d /dev/ptp0 -c
sudo testptp -d /dev/ptp0 -g

# Проверка capabilities
sudo testptp -d /dev/ptp0 -k

# Тест GPIO (если поддерживается)
sudo testptp -d /dev/ptp0 -L
```

## Настройка сети

### Настройка сетевого интерфейса

```bash
# Проверка поддержки hardware timestamping
ethtool -T eth0

# Включение hardware timestamping
sudo ethtool -s eth0 speed 1000 duplex full autoneg off

# Настройка буферов
sudo ethtool -G eth0 rx 4096 tx 4096
```

### Настройка PTP профиля

```bash
# Создание базовой конфигурации PTP
sudo tee /etc/ptp4l.conf << EOF
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

[eth0]
network_transport          UDPv4
delay_mechanism            E2E
EOF
```

## Устранение проблем

### Общие проблемы

#### Модуль не загружается

```bash
# Проверка зависимостей
sudo modprobe --show-depends ptp_ocp

# Принудительная загрузка зависимостей
sudo modprobe ptp
sudo modprobe pps_core
```

#### Устройство не обнаруживается

```bash
# Проверка PCI устройств
sudo lspci -vvv | grep -A 20 -B 5 -i time

# Проверка IOMMU
dmesg | grep -i iommu

# Отключение IOMMU (если необходимо)
# Добавить в GRUB: intel_iommu=off или amd_iommu=off
```

#### Проблемы с правами доступа

```bash
# Проверка владельца устройства
ls -la /dev/ptp*

# Изменение прав временно
sudo chmod 666 /dev/ptp*

# Проверка SELinux/AppArmor
sudo getenforce  # для SELinux
sudo aa-status   # для AppArmor
```

### Логирование и отладка

```bash
# Включение отладочных сообщений
echo 'module ptp_ocp +p' | sudo tee /sys/kernel/debug/dynamic_debug/control

# Просмотр логов
sudo journalctl -k | grep ptp
tail /var/log/messages | grep ptp
```

## Обновление

### Обновление драйвера

```bash
# Остановка использования драйвера
sudo systemctl stop ptp4l
sudo rmmod ptp_ocp

# Получение обновлений
git pull origin main

# Пересборка и установка
cd ДРАЙВЕРА
make clean
make
sudo make install

# Перезагрузка драйвера
sudo modprobe ptp_ocp
```

### Обновление через DKMS

```bash
# Удаление старой версии
sudo dkms remove -m ptp-ocp -v 1.0 --all

# Установка новой версии
sudo dkms install -m ptp-ocp -v 1.1
```

## Деинсталляция

### Удаление драйвера

```bash
# Остановка сервисов
sudo systemctl stop ptp4l
sudo systemctl disable ptp-ocp.service

# Выгрузка модуля
sudo rmmod ptp_ocp

# Удаление файлов
sudo rm -f /lib/modules/$(uname -r)/kernel/drivers/ptp/ptp_ocp.ko
sudo rm -f /etc/systemd/system/ptp-ocp.service
sudo rm -f /etc/udev/rules.d/99-ptp-ocp.rules
sudo rm -f /etc/modprobe.d/ptp-ocp.conf

# Обновление базы модулей
sudo depmod -a

# Перезагрузка udev
sudo udevadm control --reload-rules
```

### Удаление через DKMS

```bash
sudo dkms remove -m ptp-ocp -v 1.0 --all
sudo rm -rf /usr/src/ptp-ocp-1.0
```

---

### 31. Приложение C: Документация по LinuxPTP — полный текст

# Документация по работе с LinuxPTP

## Оглавление
1. [Введение в LinuxPTP](#введение-в-linuxptp)
2. [Установка и настройка](#установка-и-настройка)
3. [PTP4L - основной демон PTP](#ptp4l---основной-демон-ptp)
4. [PHC2SYS - синхронизация системных часов](#phc2sys---синхронизация-системных-часов)
5. [TS2PHC - синхронизация с внешним источником времени](#ts2phc---синхронизация-с-внешним-источником-времени)
6. [Конфигурационные файлы](#конфигурационные-файлы)
7. [Практические примеры](#практические-примеры)
8. [Мониторинг и отладка](#мониторинг-и-отладка)
9. [Решение проблем](#решение-проблем)

## Введение в LinuxPTP

LinuxPTP - это реализация протокола Precision Time Protocol (PTP) для операционной системы Linux согласно стандарту IEEE 1588-2008. Пакет включает в себя несколько утилит для высокоточной синхронизации времени в сети.

### Основные компоненты:
- **ptp4l** - демон PTP для синхронизации сетевых интерфейсов
- **phc2sys** - утилита для синхронизации системных часов с PHC (PTP Hardware Clock)
- **ts2phc** - утилита для синхронизации PHC с внешним источником времени

### Преимущества PTP:
- Субмикросекундная точность синхронизации
- Автоматическая компенсация задержек сети
- Поддержка аппаратных временных меток
- Масштабируемость для больших сетей

## Установка и настройка

### Установка из пакетного менеджера

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install linuxptp
```

**RHEL/CentOS/Fedora:**
```bash
sudo yum install linuxptp
# или для новых версий
sudo dnf install linuxptp
```

### Проверка поддержки оборудования

Убедитесь, что сетевая карта поддерживает PTP:
```bash
# Проверка поддержки PTP временных меток
ethtool -T eth0

# Проверка наличия PHC
ls /dev/ptp*
```

### Настройка разрешений

```bash
# Добавление пользователя в группу для доступа к PTP устройствам
sudo usermod -a -G dialout $USER
```

## PTP4L - основной демон PTP

### Описание
`ptp4l` - это основной демон LinuxPTP, который реализует протокол PTP для синхронизации часов между устройствами в сети.

### Основные режимы работы

#### 1. Обычный режим (Ordinary Clock)
Устройство может быть либо мастером, либо слейвом:
```bash
# Запуск в режиме авто-выбора
sudo ptp4l -i eth0 -m

# Принудительный режим слейва
sudo ptp4l -i eth0 -s -m

# Принудительный режим мастера (через конфигурационный файл)
sudo ptp4l -i eth0 -f /etc/ptp4l-master.conf -m
```

#### 2. Граничные часы (Boundary Clock)
Устройство синхронизируется с одним портом и предоставляет время через другие:
```bash
sudo ptp4l -i eth0 -i eth1 -m
```

#### 3. Прозрачные часы (Transparent Clock)
Пересылает PTP сообщения с коррекцией времени прохождения:
```bash
sudo ptp4l -i eth0 -E -m
```

### Основные параметры командной строки

| Параметр | Описание |
|----------|----------|
| `-i <interface>` | Сетевой интерфейс для PTP |
| `-m` | Вывод сообщений в stdout |
| `-s` | Режим слейва |
| `-f <config>` | Конфигурационный файл |
| `-l <level>` | Уровень логирования (0-7) |
| `-q` | Тихий режим |
| `-v` | Подробный вывод |
| `-H` | Использование аппаратных временных меток |
| `-S` | Использование программных временных меток |
| `-E` | Режим E2E (End-to-End) |
| `-P` | Режим P2P (Peer-to-Peer) |

### Примеры использования

```bash
# Базовый запуск с автоопределением роли
sudo ptp4l -i eth0 -m

# Запуск с конфигурационным файлом
sudo ptp4l -f /etc/ptp4l.conf -m

# Запуск в режиме слейва с высоким уровнем логирования
sudo ptp4l -i eth0 -s -l 7 -m

# Запуск с несколькими интерфейсами (Boundary Clock)
sudo ptp4l -i eth0 -i eth1 -f /etc/ptp4l.conf -m
```

## PHC2SYS - синхронизация системных часов

### Описание
`phc2sys` синхронизирует системные часы Linux с PTP Hardware Clock (PHC) или наоборот.

### Основные режимы работы

#### 1. Синхронизация системных часов с PHC
```bash
# Автоматическое определение лучшего PHC
sudo phc2sys -a -r

# Синхронизация с конкретным PHC
sudo phc2sys -s /dev/ptp0 -w
```

#### 2. Синхронизация PHC с системными часами
```bash
# Синхронизация PHC с системными часами
sudo phc2sys -s CLOCK_REALTIME -c /dev/ptp0 -w
```

#### 3. Синхронизация между PHC
```bash
# Синхронизация одного PHC с другим
sudo phc2sys -s /dev/ptp0 -c /dev/ptp1 -w
```

### Основные параметры

| Параметр | Описание |
|----------|----------|
| `-a` | Автоматический режим |
| `-r` | Только чтение, без коррекции |
| `-s <clock>` | Источник времени |
| `-c <clock>` | Целевые часы |
| `-w` | Ожидание синхронизации ptp4l |
| `-O <offset>` | Смещение в наносекундах |
| `-R <rate>` | Частота обновления (Гц) |
| `-n <domain>` | PTP домен |
| `-u <summary>` | Интервал сводной статистики |
| `-m` | Вывод в stdout |

### Примеры использования

```bash
# Автоматическая синхронизация с мониторингом
sudo phc2sys -a -r -m

# Синхронизация системных часов с eth0
sudo phc2sys -s eth0 -w -m

# Синхронизация с настраиваемой частотой
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -R 8 -m

# Синхронизация с добавлением смещения
sudo phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -O 1000000 -m
```

## TS2PHC - синхронизация с внешним источником времени

### Описание
`ts2phc` синхронизирует PTP Hardware Clock с внешним источником времени, таким как GPS или другие высокоточные источники.

### Принцип работы
- Использует внешний сигнал PPS (Pulse Per Second)
- Синхронизирует PHC с внешним источником
- Может работать в качестве источника времени для ptp4l

### Основные параметры

| Параметр | Описание |
|----------|----------|
| `-c <phc>` | Целевой PHC для синхронизации |
| `-s <source>` | Источник времени |
| `-f <config>` | Конфигурационный файл |
| `-l <level>` | Уровень логирования |
| `-m` | Вывод в stdout |
| `-q` | Тихий режим |

### Конфигурация для GPS

```bash
# Создание конфигурационного файла для GPS
cat << EOF > /etc/ts2phc.conf
[global]
use_syslog 1
verbose 1
logging_level 6

[/dev/ptp0]
ts2phc.pin_index 0
ts2phc.channel 0
ts2phc.extts_polarity rising
ts2phc.extts_correction 0

[/dev/pps0]
ts2phc.master 1
EOF
```

### Примеры использования

```bash
# Синхронизация PHC с GPS через PPS
sudo ts2phc -c /dev/ptp0 -s /dev/pps0 -m

# Использование конфигурационного файла
sudo ts2phc -f /etc/ts2phc.conf -m

# Синхронизация нескольких PHC
sudo ts2phc -c /dev/ptp0 -c /dev/ptp1 -s /dev/pps0 -m
```

## Конфигурационные файлы

### Конфигурация ptp4l (/etc/ptp4l.conf)

```ini
[global]
# Основные настройки
dataset_comparison                 ieee1588
domainNumber                       0
priority1                          128
priority2                          128
clockClass                         248
clockAccuracy                      0xFE
offsetScaledLogVariance           0xFFFF
free_running                       0
freq_est_interval                  1
dscp_event                         0
dscp_general                       0
assume_two_step                    0

# Сетевые настройки
network_transport                  UDPv4
udp_ttl                           1
udp6_scope                        0x0E
uds_address                       /var/run/ptp4l

# Временные интервалы (в степенях двойки секунд)
logAnnounceInterval               1
logSyncInterval                   0
logMinDelayReqInterval            0
logMinPdelayReqInterval           0

# Тайм-ауты
announceReceiptTimeout            3
syncReceiptTimeout                0
delayAsymmetry                    0
fault_reset_interval              4
fault_badpeernet_interval         16

# Алгоритм выбора мастера
G.8275.defaultDS.localPriority    128

# Часы и временные метки
time_stamping                     hardware
twoStepFlag                       1
slaveOnly                         0
gmCapable                         1
p2p_dst_mac                       01:1B:19:00:00:00
p2p_dst_mac                       01:80:C2:00:00:0E

# Настройки интерфейса
delay_mechanism                   E2E
egressLatency                     0
ingressLatency                    0
boundary_clock_jbod               0

# Алгоритм управления часами
pi_proportional_const             0.0
pi_integral_const                 0.0
pi_proportional_scale             0.0
pi_proportional_exponent          -0.3
pi_proportional_norm_max          0.7
pi_integral_scale                 0.0
pi_integral_exponent              0.4
pi_integral_norm_max              0.3
step_threshold                    0.0
max_frequency                     900000000

# Ведение журнала
use_syslog                        1
verbose                           0
summary_interval                  0
kernel_leap                       1
check_fup_sync                    0
```

### Конфигурация для специфических случаев

#### Конфигурация Grandmaster Clock
```ini
[global]
priority1                         0
clockClass                        6
clockAccuracy                     0x20
free_running                      0
slaveOnly                         0
```

#### Конфигурация Slave Clock
```ini
[global]
slaveOnly                         1
priority1                         255
clockClass                        255
```

#### Конфигурация Boundary Clock
```ini
[global]
boundary_clock_jbod               1

[eth0]
masterOnly                        0
hybrid_e2e                        1

[eth1]
masterOnly                        1
```

## Практические примеры

### Сценарий 1: Простая клиент-серверная синхронизация

**На сервере (Master):**
```bash
# Запуск ptp4l в режиме мастера (через конфигурационный файл)
sudo ptp4l -i eth0 -f /etc/ptp4l-master.conf -m &

# Синхронизация системных часов с PHC
sudo phc2sys -s eth0 -w -m &
```

**На клиенте (Slave):**
```bash
# Запуск ptp4l в режиме слейва
sudo ptp4l -i eth0 -s -m &

# Синхронизация системных часов с PHC
sudo phc2sys -s eth0 -w -m &
```

### Сценарий 2: GPS-синхронизированный Grandmaster

```bash
# Синхронизация PHC с GPS
sudo ts2phc -c /dev/ptp0 -s /dev/pps0 -m &

# Запуск ptp4l как Grandmaster
sudo ptp4l -i eth0 -f /etc/ptp4l-gm.conf -m &

# Синхронизация системных часов
sudo phc2sys -s /dev/ptp0 -w -m &
```

### Сценарий 3: Boundary Clock

```bash
# Запуск boundary clock с двумя интерфейсами
sudo ptp4l -i eth0 -i eth1 -f /etc/ptp4l-bc.conf -m &

# Синхронизация системных часов с лучшим PHC
sudo phc2sys -a -r -m &
```

### Сценарий 4: Redundant Masters

**Первый мастер (приоритет 1):**
```ini
# /etc/ptp4l-master1.conf
[global]
priority1    100
clockClass   6
```

**Второй мастер (приоритет 2):**
```ini
# /etc/ptp4l-master2.conf
[global]
priority1    110
clockClass   6
```


## Решение проблем

### Частые проблемы и решения

#### 1. Отсутствие синхронизации

**Проблема:** ptp4l не синхронизируется
```bash
# Проверка поддержки аппаратных временных меток
ethtool -T eth0

# Проверка сетевого трафика PTP
sudo tcpdump -i eth0 port 319 or port 320

# Проверка firewall
sudo iptables -L | grep -E "(319|320)"
```

**Решение:**
```bash
# Открытие портов PTP
sudo iptables -A INPUT -p udp --dport 319 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 320 -j ACCEPT

# Принудительное использование программных временных меток
sudo ptp4l -i eth0 -S -m
```

#### 2. Большое смещение времени

**Проблема:** Большой offset между часами
```bash
# Проверка конфигурации PI контроллера
grep -E "pi_(proportional|integral)" /etc/ptp4l.conf

# Проверка step_threshold
grep step_threshold /etc/ptp4l.conf
```

**Решение:**
```ini
# Более агрессивные настройки PI контроллера
pi_proportional_const     0.7
pi_integral_const         0.3
step_threshold           20.0
```

#### 3. Проблемы с multicast

**Проблема:** PTP сообщения не доходят
```bash
# Проверка multicast маршрутов
ip route show | grep 224.0.1.129

# Проверка IGMP
cat /proc/net/igmp
```

**Решение:**
```bash
# Добавление multicast маршрута
sudo ip route add 224.0.1.129/32 dev eth0

# Использование unicast вместо multicast
# В конфигурации ptp4l:
# unicast_listен 1
# unicast_req_duration 3600
```

#### 4. Производительность PHC

**Проблема:** Нестабильная работа PHC
```bash
# Проверка стабильности частоты
watch -n 1 'phc_ctl /dev/ptp0 freq'

# Мониторинг джиттера
./monitor_offset.sh | awk '{print $6}' | sort -n | tail -20
```

**Решение:**
```ini
# Увеличение интервалов синхронизации
logSyncInterval          1
logMinDelayReqInterval   1
freq_est_interval        2
```

### Диагностические команды

```bash
# Полная диагностика системы PTP
cat << 'EOF' > ptp_diagnostics.sh
#!/bin/bash
echo "=== PTP System Diagnostics ==="
echo

echo "1. Network Interface Hardware Timestamping:"
for iface in $(ip link show | grep -o 'eth[0-9]*'); do
    echo "Interface $iface:"
    ethtool -T $iface 2>/dev/null | grep -E "(hardware-transmit|hardware-receive|hardware-raw-clock)"
done
echo

echo "2. Available PTP Hardware Clocks:"
ls -la /dev/ptp* 2>/dev/null
echo

echo "3. PTP Processes:"
ps aux | grep -E "(ptp4l|phc2sys|ts2phc)" | grep -v grep
echo

echo "4. Current PTP Status:"
sudo pmc -u -b 0 'GET CURRENT_DATA_SET' 2>/dev/null
echo

echo "5. Port States:"
sudo pmc -u -b 0 'GET PORT_DATA_SET' 2>/dev/null
echo

echo "6. Network Traffic (last 10 seconds):"
timeout 10 sudo tcpdump -i any -c 10 port 319 or port 320 2>/dev/null
echo

echo "7. System Clock vs PHC:"
for ptp in /dev/ptp*; do
    [ -e "$ptp" ] && echo "$ptp: $(phc_ctl $ptp cmp 2>/dev/null)"
done
EOF

chmod +x ptp_diagnostics.sh
sudo ./ptp_diagnostics.sh
```

### Автоматизация и systemd

#### Создание systemd сервисов

**ptp4l.service:**
```ini
[Unit]
Description=PTP Boundary/Ordinary Clock
After=network.target
Documentation=man:ptp4l

[Service]
Type=simple
ExecStart=/usr/sbin/ptp4l -f /etc/ptp4l.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**phc2sys.service:**
```ini
[Unit]
Description=Synchronize PHC with system clock
After=ptp4l.service
Requires=ptp4l.service
Documentation=man:phc2sys

[Service]
Type=simple
ExecStart=/usr/sbin/phc2sys -a -r
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Установка сервисов:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable ptp4l phc2sys
sudo systemctl start ptp4l phc2sys
```

## Заключение

LinuxPTP предоставляет мощные инструменты для высокоточной синхронизации времени в Linux-системах. Правильная настройка и мониторинг позволяют достичь субмикросекундной точности синхронизации, что критично для многих промышленных и телекоммуникационных приложений.

Ключевые моменты для успешного развертывания:
1. Проверка поддержки аппаратных временных меток
2. Правильная конфигурация сетевого оборудования
3. Постоянный мониторинг качества синхронизации
4. Автоматизация через systemd для надежности

Для получения дополнительной информации обращайтесь к man-страницам:
- `man ptp4l`
- `man phc2sys` 
- `man ts2phc`
- `man pmc`

---

### 32. Приложение D: Архитектура драйвера — полный текст

# Архитектура PTP OCP драйвера

## Обзор

Драйвер PTP OCP представляет собой комплексное решение для работы с картами точного времени в Linux. Он обеспечивает высокоточную синхронизацию времени, поддерживает множество стандартов и протоколов, и предоставляет гибкий интерфейс для управления всеми функциями карты.

## Поддерживаемые устройства

- **Quantum-PCI TimeCard** (PCI ID: 0x1d9b:0x0400)
- **Orolia ART Card** (PCI ID: 0x1ad7:0xa000)
- **ADVA Timecard** (PCI ID: 0x0b0b:0x0410)

## Функциональные возможности

### Временная синхронизация
- Поддержка PTP (Precision Time Protocol)
- Аппаратные часы PHC (Physical Hardware Clock)
- Синхронизация с GNSS (GPS/ГЛОНАСС)
- Поддержка атомных часов (MAC - Miniature Atomic Clock)

### Интерфейсы
- **Последовательные порты**: GNSS, MAC, NMEA
- **I2C шина**: для управления внешними устройствами
- **SPI**: для работы с flash-памятью
- **GPIO**: для управления сигналами

### Сигналы времени
- **PPS (Pulse Per Second)**: генерация и прием импульсов раз в секунду
- **IRIG-B**: поддержка временного кода IRIG-B
- **DCF77**: поддержка радиосигнала времени DCF77
- **10 МГц**: опорная частота

## Архитектура драйвера

### Регистры управления
- `ocp_reg`: основные регистры управления часами
- `tod_reg`: регистры Time of Day
- `ts_reg`: регистры временных меток
- `pps_reg`: регистры PPS
- `signal_reg`: регистры генератора сигналов

### Ресурсы устройства
Драйвер использует систему ресурсов для динамического обнаружения и инициализации компонентов карты:
- Память MMIO для регистров
- Векторы прерываний MSI/MSI-X
- Вспомогательные устройства (UART, I2C, SPI)

## Основные функции

### Управление временем
- `ptp_ocp_gettime()`: чтение текущего времени
- `ptp_ocp_settime()`: установка времени
- `ptp_ocp_adjtime()`: корректировка времени
- `ptp_ocp_adjfine()`: точная подстройка частоты

### PTM (Precision Time Measurement)
- Поддержка PCIe PTM для синхронизации времени через шину PCIe
- Автоматический расчет задержек передачи

### Управление сигналами
- Настройка входов/выходов SMA (SubMiniature version A)
- Генерация периодических сигналов
- Обработка внешних временных меток

## Интерфейс sysfs

Драйвер создает класс устройства `/sys/class/timecard/ocpN/`, где N - порядковый номер обнаруженного устройства (начиная с 0). Этот интерфейс предоставляет следующие атрибуты:

### Основные атрибуты конфигурации:
- `clock_source` - выбор источника часов (GNSS, MAC, IRIG-B, external)
- `available_clock_sources` - список доступных источников времени
- `sma[1-4]_in/out` - конфигурация SMA коннекторов как входов или выходов
- `available_sma_inputs/outputs` - доступные сигналы для SMA портов

### Атрибуты синхронизации и калибровки:
- `gnss_sync` - статус синхронизации с GNSS спутниками
- `external_pps_cable_delay` - задержка внешнего PPS кабеля (нс)
- `internal_pps_cable_delay` - задержка внутреннего PPS кабеля (нс)
- `pci_delay` - задержка PCIe шины (нс)
- `utc_tai_offset` - смещение UTC относительно TAI (секунды)

### Служебные атрибуты:
- `serialnum` - серийный номер устройства
- `irig_b_mode` - режим работы IRIG-B
- `uevent` - события устройства

### Символические ссылки на связанные устройства:
- `device` -> `../../../XXXX:XX:XX.X` - ссылка на PCI устройство
- `ptp` -> `../../ptp/ptpX` - ссылка на PTP часы
- `ttyGNSS` -> `../../tty/ttyX` - ссылка на GNSS последовательный порт
- `ttyMAC` -> `../../tty/ttyX` - ссылка на MAC последовательный порт
- `ttyNMEA` -> `../../tty/ttyX` - ссылка на NMEA последовательный порт
- `subsystem` -> `../../../../../../class/timecard` - ссылка на класс устройства

### Директории:
- `power/` - управление питанием устройства

## Особенности реализации

### Поддержка прошивок
- Загрузка прошивки через devlink
- Проверка совместимости прошивки с оборудованием
- Поддержка обновления FPGA и SOM

### Обработка ошибок
- Сторожевой таймер для контроля работоспособности
- Автоматическое восстановление при сбоях
- Детальное логирование ошибок

### Оптимизация производительности
- Использование MSI-X для минимизации задержек прерываний
- Прямой доступ к регистрам через MMIO
- Кэширование часто используемых значений

### Примечание по управлению питанием
- На текущий момент `suspend/resume` не реализованы; см. раздел с рекомендациями по улучшению.

## Заключение

Драйвер ptp_ocp представляет собой комплексное решение для работы с картами точного времени в Linux. Он обеспечивает высокоточную синхронизацию времени, поддерживает множество стандартов и протоколов, и предоставляет гибкий интерфейс для управления всеми функциями карты.

---

### 33. Приложение E: Полное руководство по Chrony — полный текст

# Полное руководство по Chrony

## Оглавление
1. [Введение в Chrony](#введение-в-chrony)
2. [Установка и настройка](#установка-и-настройка)
3. [Конфигурационные файлы](#конфигурационные-файлы)
4. [Команды управления](#команды-управления)
5. [Работа с PTP устройствами](#работа-с-ptp-устройствами)
6. [Скрипты автоматизации](#скрипты-автоматизации)
7. [Мониторинг и диагностика](#мониторинг-и-диагностика)
8. [Устранение неполадок](#устранение-неполадок)
9. [Интеграция с TimeCard](#интеграция-с-timecard)

## Введение в Chrony

Chrony - это универсальная реализация протокола NTP (Network Time Protocol), которая обеспечивает точную синхронизацию системных часов компьютера с NTP серверами, референсными часами (например, GPS приемником) или ручным вводом времени.

### Основные компоненты:
- **chronyd** - демон, выполняющий синхронизацию
- **chronyc** - утилита командной строки для мониторинга и управления

### Преимущества Chrony:
- Быстрая синхронизация после загрузки
- Работа с прерывистым сетевым соединением
- Поддержка аппаратных часов (PHC)
- Низкое потребление ресурсов
- Совместимость с виртуальными машинами

## Установка и настройка

### Установка из пакетного менеджера

#### Debian/Ubuntu:
```bash
sudo apt update
sudo apt install chrony
```

#### RHEL/CentOS/Fedora:
```bash
sudo yum install chrony
# или для новых версий
sudo dnf install chrony
```

#### openSUSE:
```bash
sudo zypper install chrony
```

### Базовая настройка

После установки необходимо:

1. Настроить конфигурационный файл `/etc/chrony/chrony.conf`
2. Запустить службу chronyd
3. Проверить статус синхронизации

```bash
# Запуск службы
sudo systemctl start chronyd
sudo systemctl enable chronyd

# Проверка статуса
chronyc tracking
chronyc sources
```

### Настройка разрешений

Для использования команд управления необходимо настроить доступ:

```bash
# В /etc/chrony/chrony.conf добавить:
allow 127.0.0.1
bindcmdaddress 127.0.0.1
```

## Конфигурационные файлы

### Основной файл конфигурации

Файл `/etc/chrony/chrony.conf` содержит все настройки chronyd.

#### Базовая конфигурация:
```bash
# Серверы времени
pool 2.pool.ntp.org iburst
server time1.google.com iburst
server time2.google.com iburst

# Файл для сохранения информации о дрейфе часов
driftfile /var/lib/chrony/drift

# Разрешить пошаговую коррекцию времени
makestep 1.0 3

# Синхронизация RTC
rtcsync

# Логирование
log tracking measurements statistics
logdir /var/log/chrony
```

### Работа с PTP устройствами

Для работы с PTP Hardware Clock (PHC):

```bash
# /etc/chrony/chrony.conf

# Использование PHC как источника времени
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 stratum 1 precision 1e-9

# Использование PPS сигнала
refclock PPS /dev/pps0 refid PPS precision 1e-9

# Комбинирование PHC и PPS
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 noselect
refclock PPS /dev/pps0 lock PHC precision 1e-9
```

## Команды управления

### Основные команды chronyc

```bash
# Информация о текущей синхронизации
chronyc tracking

# Список источников времени
chronyc sources -v

# Детальная статистика источников
chronyc sourcestats

# Информация о системных часах
chronyc rtcdata

# Принудительная синхронизация
chronyc makestep

# Добавление нового сервера
chronyc add server time.example.com

# Удаление сервера
chronyc delete time.example.com
```


## Работа с PTP устройствами

### Интеграция с LinuxPTP

Chrony может работать совместно с LinuxPTP для обеспечения высокоточной синхронизации:

```bash
# Запуск ptp4l для синхронизации PHC
sudo ptp4l -i eth0 -m

# Использование PHC в chrony
# /etc/chrony/chrony.conf
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0
```

### Настройка для TimeCard

Специфичная конфигурация для TimeCard устройств:

```bash
# /etc/chrony/chrony.conf

# TimeCard PHC как основной источник
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 stratum 1 prefer

# Резервные NTP серверы
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst

# Быстрая начальная синхронизация
makestep 1.0 3

# Точная настройка
maxupdateskew 100.0
corrtimeratio 3
maxdrift 500
```

## Скрипты автоматизации

### Автоматическая установка и настройка

```bash
#!/bin/bash
# install_chrony.sh - Автоматическая установка и базовая настройка Chrony

set -e

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}

# Установка Chrony
install_chrony() {
    local distro=$(detect_distro)
    
    echo "Установка Chrony для дистрибутива: $distro"
    
    case $distro in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y chrony
            ;;
        rhel|centos|fedora)
            sudo yum install -y chrony || sudo dnf install -y chrony
            ;;
        opensuse*)
            sudo zypper install -y chrony
            ;;
        *)
            echo "Неподдерживаемый дистрибутив: $distro"
            exit 1
            ;;
    esac
}

# Базовая конфигурация
configure_chrony() {
    echo "Настройка базовой конфигурации..."
    
    # Backup оригинального конфига
    sudo cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.backup
    
    # Создание новой конфигурации
    cat << EOF | sudo tee /etc/chrony/chrony.conf
# Chrony configuration
# Generated by install_chrony.sh

# NTP servers
pool 2.pool.ntp.org iburst
server time1.google.com iburst
server time2.google.com iburst
server time3.google.com iburst

# Record the rate at which the system clock gains/losses time
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
makestep 1.0 3

# Enable kernel synchronisation of the real-time clock
rtcsync

# Increase the minimum number of selectable sources
minsources 2

# Allow NTP client access from local network
allow 192.168.0.0/16
allow 10.0.0.0/8

# Serve time even if not synchronized to a time source
local stratum 10

# Specify file containing keys for NTP authentication
keyfile /etc/chrony/chrony.keys

# Specify directory for log files
logdir /var/log/chrony

# Select which information is logged
log measurements statistics tracking
EOF
}

# Запуск и включение службы
start_service() {
    echo "Запуск службы chronyd..."
    sudo systemctl restart chronyd
    sudo systemctl enable chronyd
}

# Проверка работы
verify_installation() {
    echo "Проверка установки..."
    sleep 5
    
    if systemctl is-active --quiet chronyd; then
        echo "✓ Служба chronyd активна"
    else
        echo "✗ Служба chronyd не запущена"
        return 1
    fi
    
    echo -e "\nСтатус синхронизации:"
    chronyc tracking
    
    echo -e "\nИсточники времени:"
    chronyc sources
}

# Основной процесс
main() {
    echo "=== Установка и настройка Chrony ==="
    
    install_chrony
    configure_chrony
    start_service
    verify_installation
    
    echo -e "\n=== Установка завершена ==="
    echo "Используйте 'chronyc' для управления и мониторинга"
}

main "$@"
```

### Настройка для работы с PTP

```bash
#!/bin/bash
# setup_chrony_ptp.sh - Настройка Chrony для работы с PTP устройствами

set -e

PTP_DEVICE=${1:-/dev/ptp0}
CHRONY_CONF="/etc/chrony/chrony.conf"

# Проверка наличия PTP устройства
check_ptp_device() {
    if [ ! -c "$PTP_DEVICE" ]; then
        echo "Ошибка: PTP устройство $PTP_DEVICE не найдено"
        echo "Использование: $0 [/dev/ptp_device]"
        exit 1
    fi
    
    echo "Найдено PTP устройство: $PTP_DEVICE"
}

# Определение типа PTP устройства
detect_ptp_type() {
    local ptp_name=$(basename $PTP_DEVICE)
    local sys_path="/sys/class/ptp/$ptp_name"
    
    if [ -f "$sys_path/clock_name" ]; then
        local clock_name=$(cat "$sys_path/clock_name")
        echo "Тип устройства: $clock_name"
        
        if [[ "$clock_name" == *"OCP"* ]]; then
            echo "Обнаружено TimeCard устройство"
            return 0
        fi
    fi
    
    return 1
}

# Настройка Chrony для PTP
configure_chrony_ptp() {
    echo "Настройка Chrony для работы с PTP..."
    
    # Backup
    sudo cp $CHRONY_CONF ${CHRONY_CONF}.backup.$(date +%Y%m%d_%H%M%S)
    
    # Добавление PTP конфигурации
    cat << EOF | sudo tee -a $CHRONY_CONF

# PTP Hardware Clock configuration
# Added by setup_chrony_ptp.sh

# Primary time source - PTP Hardware Clock
refclock PHC $PTP_DEVICE poll 0 dpoll -2 offset 0 stratum 1 precision 1e-9 prefer

# Optional: PPS signal if available
# refclock PPS /dev/pps0 lock PHC precision 1e-9

# Backup NTP servers
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst

# Increase clock adjustment speed for PTP
corrtimeratio 10
maxdrift 100

# Log PTP statistics
log refclocks measurements statistics
EOF
}

# Настройка для TimeCard
configure_timecard_specific() {
    echo "Применение специфичных настроек для TimeCard..."
    
    cat << EOF | sudo tee -a $CHRONY_CONF

# TimeCard specific settings
# High precision mode
maxupdateskew 5.0
maxslewrate 1000.0

# Prefer hardware timestamps
hwtimestamp *
EOF
}

# Перезапуск Chrony
restart_chrony() {
    echo "Перезапуск chronyd..."
    sudo systemctl restart chronyd
    sleep 3
}

# Проверка конфигурации
verify_config() {
    echo -e "\nПроверка конфигурации..."
    
    # Проверка источников
    chronyc sources -v
    
    # Проверка refclock
    chronyc refclocks
    
    echo -e "\nТекущий статус синхронизации:"
    chronyc tracking
}

# Основной процесс
main() {
    echo "=== Настройка Chrony для PTP ==="
    
    check_ptp_device
    
    if detect_ptp_type; then
        configure_chrony_ptp
        configure_timecard_specific
    else
        echo "Настройка остановлена из-за отсутствия PTP устройств"
        exit 1
    fi
    
    restart_chrony
    verify_config
    
    echo -e "\n=== Настройка завершена ==="
}

main "$@"
```



## Устранение неполадок

### Частые проблемы и решения

#### Chrony не может синхронизироваться

```bash
# Проверка доступности NTP серверов
chronyc sources -v

# Проверка firewall
sudo iptables -L -n | grep 123

# Проверка SELinux (для RHEL/CentOS)
getenforce
sudo semanage port -l | grep ntp
```

#### Большое отклонение времени

```bash
# Принудительная синхронизация
sudo chronyc makestep

# Увеличение скорости коррекции
echo "makestep 1 -1" | sudo tee -a /etc/chrony/chrony.conf
```

#### Проблемы с PHC/PTP

```bash
# Проверка PTP устройства
ls -la /dev/ptp*
cat /sys/class/ptp/ptp*/clock_name

# Проверка прав доступа
sudo chmod 666 /dev/ptp0

# Проверка в chrony
chronyc refclocks
```

### Отладочный режим

Для детальной диагностики можно запустить chronyd в отладочном режиме:

```bash
# Остановка службы
sudo systemctl stop chronyd

# Запуск в отладочном режиме
sudo chronyd -d -d

# Или с логированием в файл
sudo chronyd -d -l /tmp/chronyd.debug
```

## Интеграция с TimeCard

### Оптимальная конфигурация для TimeCard

```bash
# /etc/chrony/chrony.conf

# TimeCard как основной источник времени
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 stratum 0 precision 1e-9 prefer trust

# Дополнительные источники для резервирования
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst

# Агрессивная синхронизация для высокой точности
corrtimeratio 100
maxupdateskew 5.0
maxslewrate 1000.0

# Использование hardware timestamps
hwtimestamp eth0

# Мониторинг и логирование
log measurements statistics tracking refclocks
logdir /var/log/chrony

# Локальный NTP сервер
allow 192.168.0.0/16
local stratum 1
```

### Скрипт проверки интеграции

```bash
#!/bin/bash
# check_timecard_chrony.sh

echo "=== TimeCard + Chrony Integration Check ==="

# Проверка TimeCard
if [ -c /dev/ptp0 ]; then
    echo "✓ TimeCard устройство найдено"
    
    # Проверка sysfs
    if [ -d /sys/class/timecard/ocp0 ]; then
        echo "✓ TimeCard sysfs доступен"
        echo "  Clock source: $(cat /sys/class/timecard/ocp0/clock_source)"
        echo "  GNSS status: $(cat /sys/class/timecard/ocp0/gnss_sync)"
    fi
else
    echo "✗ TimeCard устройство не найдено"
fi

# Проверка Chrony
if systemctl is-active --quiet chronyd; then
    echo "✓ Chronyd активен"
    
    # Проверка использования PHC
    if chronyc refclocks | grep -q PHC; then
        echo "✓ PHC источник настроен"
        chronyc refclocks
    else
        echo "✗ PHC источник не найден"
    fi
else
    echo "✗ Chronyd не запущен"
fi

echo -e "\n=== Текущий статус синхронизации ==="
chronyc tracking
```

## Заключение

Chrony предоставляет гибкую и надежную систему синхронизации времени, особенно эффективную при работе с аппаратными источниками времени, такими как TimeCard. Правильная настройка и мониторинг позволяют достичь микросекундной точности синхронизации.

### Полезные ссылки
- [Официальная документация Chrony](https://chrony.tuxfamily.org/documentation.html)
- [Chrony FAQ](https://chrony.tuxfamily.org/faq.html)
- [Сравнение Chrony и NTPd](https://chrony.tuxfamily.org/comparison.html)

---

### 34. Приложение F: Детальная конфигурация — полный текст

# Детальная конфигурация

## Обзор

Подробное руководство по настройке драйвера PTP OCP и связанных компонентов для различных сценариев использования.

## Архитектура системы

### Компоненты системы

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Приложения    │    │   LinuxPTP      │    │   Chrony/NTP    │
│                 │    │   (ptp4l)       │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│                        Пользовательское пространство               │
└─────────────────────────────────────────────────────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│                           Ядро Linux                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐   │
│  │ PTP Core    │    │ Network     │    │   Timekeeping       │   │
│  │ Subsystem   │    │ Stack       │    │   Subsystem         │   │
│  └─────────────┘    └─────────────┘    └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │
┌─────────────────────────────────────────────────────────────────┐
│                       PTP OCP Driver                           │
│  ┌─────────────────┐              ┌─────────────────────────┐   │
│  │ TimeCard Class  │              │    PTP Interface        │   │
│  │ /sys/class/     │              │    /sys/class/ptp/      │   │
│  │ timecard/ocpN/  │  <-------->  │    /dev/ptp*           │   │
│  └─────────────────┘              └─────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │
┌─────────────────────────────────────────────────────────────────┐
│                       PCI Hardware                             │
└─────────────────────────────────────────────────────────────────┘
```

## Конфигурация драйвера

### Параметры модуля

#### Основные параметры

```bash
# Файл: /etc/modprobe.d/ptp-ocp.conf

# Уровень отладки (0-7)
options ptp_ocp debug=0

# Принудительное включение устройства
options ptp_ocp force_enable=0

# Таймаут инициализации (в секундах)
options ptp_ocp init_timeout=30

# Режим GPIO
options ptp_ocp gpio_mode=auto
```

#### Отладочные параметры

```bash
# Детальная отладка
options ptp_ocp debug=7

# Отладка только инициализации
options ptp_ocp debug=1

# Отладка GPIO операций
options ptp_ocp gpio_debug=1
```

### Конфигурация через sysfs

#### Основные атрибуты

```bash
# Базовый путь к устройству
PTP_DEVICE="/sys/class/ptp/ptp0"

# Чтение информации о часах
cat $PTP_DEVICE/clock_name
cat $PTP_DEVICE/max_adjustment

# Конфигурация пинов
echo "1 2 0" > $PTP_DEVICE/pins/pin0
echo "2 3 0" > $PTP_DEVICE/pins/pin1
```

#### GPIO конфигурация

```bash
# Настройка GPIO пинов
GPIO_BASE="/sys/class/ptp/ptp0"

# Список доступных пинов
ls $GPIO_BASE/pins/

# Конфигурация пина как выход
echo "perout 0 0" > $GPIO_BASE/pins/SMA1

# Конфигурация пина как вход
echo "extts 0 0" > $GPIO_BASE/pins/SMA2
```

### Конфигурация TimeCard

#### Основные операции с TimeCard

```bash
# Базовый путь к TimeCard устройству
TIMECARD_BASE="/sys/class/timecard/ocp0"

# Проверка доступности устройства
if [ -d "$TIMECARD_BASE" ]; then
    echo "TimeCard device found"
else
    echo "TimeCard device not found"
    exit 1
fi

# Просмотр доступных источников времени
cat $TIMECARD_BASE/available_clock_sources

# Установка источника времени
echo "GNSS" > $TIMECARD_BASE/clock_source

# Проверка синхронизации GNSS
cat $TIMECARD_BASE/gnss_sync
```

#### Конфигурация SMA коннекторов

```bash
# Просмотр доступных сигналов
cat $TIMECARD_BASE/available_sma_inputs
cat $TIMECARD_BASE/available_sma_outputs

# Настройка SMA1 как вход для 10MHz
echo "10MHz" > $TIMECARD_BASE/sma1_in

# Настройка SMA2 как вход для PPS
echo "PPS" > $TIMECARD_BASE/sma2_in

# Настройка SMA3 как выход 10MHz
echo "10MHz" > $TIMECARD_BASE/sma3_out

# Настройка SMA4 как выход PPS
echo "PPS" > $TIMECARD_BASE/sma4_out
```

#### Калибровка задержек

```bash
# Установка задержки внешнего PPS кабеля (в наносекундах)
echo "100" > $TIMECARD_BASE/external_pps_cable_delay

# Установка задержки внутреннего PPS
echo "50" > $TIMECARD_BASE/internal_pps_cable_delay

# Установка задержки PCIe
echo "25" > $TIMECARD_BASE/pci_delay

# Установка смещения UTC-TAI (в секундах)
echo "37" > $TIMECARD_BASE/utc_tai_offset

# Коррекция окна временных меток (в наносекундах)
echo "0" > $TIMECARD_BASE/ts_window_adjust 2>/dev/null || echo "ts_window_adjust недоступен"

# Коррекция TOD (в наносекундах)
echo "0" > $TIMECARD_BASE/tod_correction 2>/dev/null || echo "tod_correction недоступен"
```

#### Получение информации о устройстве

```bash
# Серийный номер
cat $TIMECARD_BASE/serialnum

# Конфигурация IRIG-B
cat $TIMECARD_BASE/irig_b_mode
echo "B003" > $TIMECARD_BASE/irig_b_mode

# Получение связанных устройств
PTP_DEV=$(basename $(readlink $TIMECARD_BASE/ptp))
GNSS_TTY=$(basename $(readlink $TIMECARD_BASE/ttyGNSS))
MAC_TTY=$(basename $(readlink $TIMECARD_BASE/ttyMAC))
NMEA_TTY=$(basename $(readlink $TIMECARD_BASE/ttyNMEA))

echo "PTP device: /dev/$PTP_DEV"
echo "GNSS port: /dev/$GNSS_TTY"
echo "MAC port: /dev/$MAC_TTY"
echo "NMEA port: /dev/$NMEA_TTY"

# Дополнительные порты (если доступны)
GNSS2_TTY=$(basename $(readlink $TIMECARD_BASE/ttyGNSS2 2>/dev/null)) 2>/dev/null
[ -n "$GNSS2_TTY" ] && echo "GNSS2 port: /dev/$GNSS2_TTY"

# I2C шина (если доступна)
I2C_BUS=$(basename $(readlink $TIMECARD_BASE/i2c 2>/dev/null)) 2>/dev/null
[ -n "$I2C_BUS" ] && echo "I2C bus: /dev/$I2C_BUS"
```

#### Работа с бинарными конфигурациями

```bash
# Резервное копирование конфигурации устройства
cp $TIMECARD_BASE/config /backup/timecard_config_$(date +%Y%m%d).bin

# Резервное копирование конфигурации дисциплинирования
cp $TIMECARD_BASE/disciplining_config /backup/disciplining_config_$(date +%Y%m%d).bin

# Резервное копирование температурной таблицы
cp $TIMECARD_BASE/temperature_table /backup/temperature_table_$(date +%Y%m%d).bin

# Проверка размеров файлов конфигурации
ls -la $TIMECARD_BASE/{config,disciplining_config,temperature_table} 2>/dev/null

# ВНИМАНИЕ: Восстановление конфигураций требует осторожности!
# cp /backup/timecard_config_YYYYMMDD.bin $TIMECARD_BASE/config
```

#### Управление MAC I2C (атомные часы)

```bash
# Проверка доступности MAC I2C интерфейса
if [ -f $TIMECARD_BASE/mac_i2c ]; then
    echo "MAC I2C interface available"
    
    # Чтение состояния MAC I2C
    cat $TIMECARD_BASE/mac_i2c
    
    # Примеры команд MAC I2C (осторожно!)
    # echo "command" > $TIMECARD_BASE/mac_i2c
else
    echo "MAC I2C interface not available"
fi
```

#### Скрипт автоматической конфигурации

```bash
#!/bin/bash
# Файл: /usr/local/bin/configure-timecard.sh

TIMECARD_BASE="/sys/class/timecard/ocp0"

# Проверка устройства
if [ ! -d "$TIMECARD_BASE" ]; then
    echo "Error: TimeCard device not found"
    exit 1
fi

# Базовая конфигурация
echo "GNSS" > $TIMECARD_BASE/clock_source
echo "10MHz" > $TIMECARD_BASE/sma1_in
echo "PPS" > $TIMECARD_BASE/sma2_in
echo "10MHz" > $TIMECARD_BASE/sma3_out
echo "PPS" > $TIMECARD_BASE/sma4_out

# Калибровка задержек (настройте под ваши кабели)
echo "100" > $TIMECARD_BASE/external_pps_cable_delay
echo "50" > $TIMECARD_BASE/internal_pps_cable_delay
echo "25" > $TIMECARD_BASE/pci_delay
echo "37" > $TIMECARD_BASE/utc_tai_offset

# Настройка IRIG-B
echo "B003" > $TIMECARD_BASE/irig_b_mode

echo "TimeCard configured successfully"

# Ожидание синхронизации GNSS
echo "Waiting for GNSS sync..."
timeout=60
while [ $timeout -gt 0 ]; do
    sync_status=$(cat $TIMECARD_BASE/gnss_sync)
    if [ "$sync_status" = "locked" ]; then
        echo "GNSS synchronized"
        break
    fi
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "Warning: GNSS sync timeout"
fi
```

## PTP конфигурация

### Базовая конфигурация ptp4l

#### Файл /etc/ptp4l.conf

```ini
[global]
# Общие настройки
verbose                    1
time_stamping              hardware
tx_timestamp_timeout       50
use_syslog                 1
logSyncInterval           -3
logMinDelayReqInterval    -3
logAnnounceInterval        1
announceReceiptTimeout     3
syncReceiptTimeout         0
delay_mechanism            E2E
network_transport          UDPv4

# Настройки домена
domainNumber               0
priority1                  128
priority2                  128
clockClass                 248
clockAccuracy              0xFE
offsetScaledLogVariance    0xFFFF

# Профиль временной синхронизации
dataset_comparison         ieee1588
G.8275.defaultDS.localPriority 128

# Настройки сервера
serverOnly                 0
slaveOnly                  0
free_running               0

# Фильтрация и сервосистема
step_threshold             0.000002
first_step_threshold       0.000020
max_frequency              900000000
clock_servo                pi
pi_proportional_const      0.0
pi_integral_const          0.0
pi_proportional_scale      0.0
pi_proportional_exponent   -0.3
pi_proportional_norm_max   0.7
pi_integral_scale          0.0
pi_integral_exponent       0.4
pi_integral_norm_max       0.3

# Настройки сети
dscp_event                 46
dscp_general               34
socket_priority            0

[eth0]
# Настройки сетевого интерфейса
network_transport          UDPv4
delay_mechanism            E2E
```

### Продвинутая конфигурация

#### Телеком профиль (G.8275.1)

```ini
[global]
dataset_comparison         G.8275.x
G.8275.defaultDS.localPriority 128
domainNumber               24
priority1                  128
priority2                  128
clockClass                 165
clockAccuracy              0x21
offsetScaledLogVariance    0x4E5D
free_running               0
freq_est_interval          1
assume_two_step            0
tx_timestamp_timeout       10
check_fup_sync             0
clock_servo                linreg
step_threshold             0.000002
first_step_threshold       0.000020
max_frequency              900000000
sanity_freq_limit          200000000
ntpshm_segment             0
msg_interval_request       0
servo_num_offset_values    10
servo_offset_threshold     0
write_phase_mode           0
network_transport          L2
ptp_dst_mac                01:1B:19:00:00:00
p2p_dst_mac                01:80:C2:00:00:0E
udp6_scope                 0x0E
uds_address                /var/run/ptp4l
logging_level              6
verbose                    0
use_syslog                 1
userDescription            "PTP OCP Telecom Profile"
manufacturerIdentity       00:00:00
summary_interval           0
kernel_leap                1
check_fup_sync             0
clock_class_threshold      7
G.8275.portDS.localPriority 128

[eth0]
logAnnounceInterval        0
logSyncInterval           -4
logMinDelayReqInterval    -4
logMinPdelayReqInterval   -4
announceReceiptTimeout     3
syncReceiptTimeout         3
delay_mechanism            P2P
network_transport          L2
masterOnly                 0
G.8275.portDS.localPriority 128
```

#### High Accuracy Profile

```ini
[global]
dataset_comparison         ieee1588
domainNumber               0
priority1                  128
priority2                  128
clockClass                 6
clockAccuracy              0x20
offsetScaledLogVariance    0x436A
free_running               0
freq_est_interval          1
assume_two_step            0
tx_timestamp_timeout       1
check_fup_sync             0
clock_servo                pi
step_threshold             0.000000002
first_step_threshold       0.000000020
max_frequency              900000000
pi_proportional_const      0.0
pi_integral_const          0.0
pi_proportional_scale      0.0
pi_proportional_exponent   -0.3
pi_proportional_norm_max   0.7
pi_integral_scale          0.0
pi_integral_exponent       0.4
pi_integral_norm_max       0.3
servo_num_offset_values    10
servo_offset_threshold     0
write_phase_mode           0
network_transport          UDPv4
delay_mechanism            E2E
time_stamping              hardware
twoStepFlag                1
summary_interval           0
kernel_leap                1
check_fup_sync             0

[eth0]
logAnnounceInterval       -2
logSyncInterval           -5
logMinDelayReqInterval    -5
announceReceiptTimeout     3
syncReceiptTimeout         3
delay_mechanism            E2E
network_transport          UDPv4
```

## Сетевая конфигурация

### Настройка сетевого интерфейса

#### Hardware timestamping

```bash
# Проверка поддержки
ethtool -T eth0

# Настройка интерфейса для PTP
sudo ethtool -s eth0 speed 1000 duplex full autoneg off

# Оптимизация буферов
sudo ethtool -G eth0 rx 4096 tx 4096
sudo ethtool -C eth0 rx-usecs 1 tx-usecs 1
```

#### Multicast конфигурация

```bash
# Настройка multicast для PTP
sudo ip maddr add 01:1b:19:00:00:00 dev eth0
sudo ip maddr add 01:80:c2:00:00:0e dev eth0

# Проверка multicast групп
ip maddr show dev eth0
```

### Оптимизация производительности

#### Настройка IRQ affinity

```bash
#!/bin/bash
# Скрипт для настройки IRQ affinity

# Найти IRQ для сетевого интерфейса
ETH_IRQ=$(grep eth0 /proc/interrupts | awk -F: '{print $1}' | tr -d ' ')

# Привязать IRQ к определенному CPU
echo 2 > /proc/irq/$ETH_IRQ/smp_affinity

# Изоляция CPU для real-time обработки
echo 2 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
```

#### Настройка ядра для real-time

```bash
# Файл: /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash isolcpus=1,2 nohz_full=1,2 rcu_nocbs=1,2"

# Обновление grub
sudo update-grub
```

## Chrony интеграция

### Конфигурация chronyd

#### Файл /etc/chrony/chrony.conf

```bash
# Использование PTP в качестве источника времени
refclock PHC /dev/ptp0 poll 0 dpoll -2 offset 0 stratum 1

# Альтернативные источники
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst

# Настройки синхронизации
makestep 1.0 3
rtcsync
driftfile /var/lib/chrony/drift
logdir /var/log/chrony

# Разрешения
allow 192.168.0.0/16
allow 10.0.0.0/8

# Локальные настройки
local stratum 2
smoothtime 400 0.01 leaponly
```

### phc2sys конфигурация

#### Автоматическая синхронизация

```bash
# Systemd сервис: /etc/systemd/system/phc2sys.service
[Unit]
Description=Synchronize system clock to PTP hardware clock
After=ptp4l.service
Requires=ptp4l.service

[Service]
ExecStart=/usr/sbin/phc2sys -s /dev/ptp0 -c CLOCK_REALTIME -w -m -q -R 256
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```


## Безопасность

### Настройка firewall

```bash
# PTP порты
sudo ufw allow 319/udp comment "PTP Event"
sudo ufw allow 320/udp comment "PTP General"

# Для multicast (если необходимо)
sudo iptables -I INPUT -d 224.0.1.129 -j ACCEPT
sudo iptables -I INPUT -d 224.0.0.107 -j ACCEPT
```

### Контроль доступа

```bash
# Ограничение доступа к PTP устройствам
# Файл: /etc/security/limits.conf
@ptp    hard    rtprio    99
@ptp    soft    rtprio    99

# Создание группы для PTP
sudo groupadd ptp
sudo usermod -a -G ptp ptp4l_user
```

## Профили конфигураций

### Telecom профиль

Оптимизирован для телекоммуникационных применений с высокими требованиями к точности.

### Industrial профиль

Подходит для промышленных автоматических систем с умеренными требованиями к точности.

### Datacenter профиль

Оптимизирован для синхронизации в дата-центрах с большим количеством серверов.

### Testing профиль

Конфигурация для тестирования и отладки системы.
