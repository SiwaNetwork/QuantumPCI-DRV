# Изменение Vendor ID устройства с "Meta Platforms, Inc." на "Quantum Platforms, Inc."

## Проблема
При использовании драйвера PTP OCP устройство отображается как:
```
01:00.0 Memory controller: Meta Platforms, Inc. Device 0400
```

Требуется изменить название на:
```
01:00.0 Memory controller: Quantum Platforms, Inc. Device 0400
```

## Решение

### 1. Изменения в драйвере

В файле `ptp_ocp.c` добавлены новые определения:

```c
/* Добавляем новое определение для Quantum Platforms, Inc. */
#ifndef PCI_VENDOR_ID_QUANTUM_PLATFORMS
#define PCI_VENDOR_ID_QUANTUM_PLATFORMS 0x1d9c
#endif

#ifndef PCI_DEVICE_ID_QUANTUM_PLATFORMS_TIMECARD
#define PCI_DEVICE_ID_QUANTUM_PLATFORMS_TIMECARD 0x0400
#endif
```

И добавлено новое устройство в таблицу PCI:

```c
static const struct pci_device_id ptp_ocp_pcidev_id[] = {
	{ PCI_DEVICE_DATA(QUANTUM_PCI, TIMECARD, &ocp_quantum_pci_driver_data) },
	{ PCI_DEVICE_DATA(ADVA, TIMECARD, &ocp_adva_driver_data) },
	{ PCI_DEVICE_DATA(OROLIA, ARTCARD, &ocp_art_driver_data) },
	{ PCI_DEVICE_DATA(QUANTUM_PLATFORMS, TIMECARD, &ocp_quantum_pci_driver_data) },
	{ }
};
```

### 2. Использование QuantumPCI-Firmware-Tool

Инструмент [QuantumPCI-Firmware-Tool](https://github.com/SiwaNetwork/QuantumPCI-Firmware-Tool) позволяет создавать прошивки с новым Vendor ID.

#### Установка инструмента:
```bash
git clone https://github.com/SiwaNetwork/QuantumPCI-Firmware-Tool.git
cd QuantumPCI-Firmware-Tool
go mod init quantum-pci-ft
go get github.com/sirupsen/logrus github.com/sigurn/crc16
```

#### Исправление магического заголовка:
Необходимо изменить магический заголовок с "SHIW" на "OCPC" в файле `header/firmware.go`:
```go
var hdrMagic = [4]byte{'O', 'C', 'P', 'C'}
```

#### Компиляция инструмента:
```bash
go build -o quantum-pci-ft
```

#### Создание прошивки с новым Vendor ID:
```bash
./quantum-pci-ft -input исходная_прошивка.bin \
    -output прошивка_quantum.bin \
    -vendor 0x1d9b \
    -device 0x0400 \
    -apply
```

#### Проверка созданной прошивки:
```bash
./quantum-pci-ft -input прошивка_quantum.bin
```

### 3. Обновление базы данных PCI ID

Изменена запись в `/usr/share/misc/pci.ids`:

```bash
sudo sed -i 's/1d9b  Meta Platforms, Inc./1d9b  Quantum Platforms, Inc./' /usr/share/misc/pci.ids
```

Результат:
```
1d9b  Quantum Platforms, Inc.
        0010  Networking DOM Engine
        0011  IO Bridge
```

### 4. Обновление прошивки устройства

После создания прошивки с новым Vendor ID, обновите устройство:

```bash
# Скопируйте прошивку в директорию firmware
sudo cp прошивка_quantum.bin /lib/firmware/

# Обновите прошивку через devlink
sudo devlink dev flash pci/0000:01:00.0 file прошивка_quantum.bin

# Загрузите драйвер (если не загружен)
sudo modprobe /lib/modules/$(uname -r)/kernel/drivers/ptp/ptp_ocp.ko.zst
```

### 5. Проверка результата

После обновления прошивки и драйвера, устройство должно отображаться как:

```bash
lspci -vvv | grep "01:00.0"
```

Результат:
```
01:00.0 Memory controller: Quantum Platforms, Inc. Device 0400
```

## Важные замечания

1. **Vendor ID 0x1d9c** - новый ID для Quantum Platforms, Inc.
2. **Device ID 0x0400** - остается тем же для совместимости
3. **Прошивка** - должна быть обновлена с новым Vendor ID
4. **Драйвер** - поддерживает оба Vendor ID (0x1d9b и 0x1d9c)

## Формат заголовка прошивки

Инструмент добавляет 16-байтный заголовок к прошивке:

| Поле | Размер | Описание |
|------|--------|----------|
| Магические байты | 4 байта | 'SHIW' |
| PCI Vendor ID | 2 байта | 0x1d9c |
| PCI Device ID | 2 байта | 0x0400 |
| Размер образа | 4 байта | Размер прошивки |
| HW Revision | 2 байта | Ревизия оборудования |
| CRC16 | 2 байта | Контрольная сумма |

## Альтернативные решения

1. **Изменение существующего Vendor ID** - не рекомендуется, так как 0x1d9b уже зарегистрирован
2. **Локальная база данных PCI ID** - временное решение
3. **Официальная регистрация** - подача заявки на новый Vendor ID в PCI-SIG 