# Быстрая инструкция: Изменение Vendor ID на "Quantum Platforms, Inc."

## Проблема
Устройство отображается как: `Meta Platforms, Inc. Device 0400`
Нужно: `Quantum Platforms, Inc. Device 0400`

## Решение

### 1. Установка инструмента
```bash
cd ДРАЙВЕРА
git clone https://github.com/SiwaNetwork/QuantumPCI-Firmware-Tool.git
cd QuantumPCI-Firmware-Tool
go mod init quantum-pci-ft
go get github.com/sirupsen/logrus github.com/sigurn/crc16
```

### 2. Исправление магического заголовка
Изменить в файле `header/firmware.go`:
```go
var hdrMagic = [4]byte{'O', 'C', 'P', 'C'}
```

### 3. Компиляция инструмента
```bash
go build -o quantum-pci-ft
```

### 4. Создание прошивки с новым Vendor ID
```bash
./quantum-pci-ft -input исходная_прошивка.bin \
    -output прошивка_quantum.bin \
    -vendor 0x1d9b \
    -device 0x0400 \
    -apply
```

### 5. Обновление прошивки устройства
```bash
sudo cp прошивка_quantum.bin /lib/firmware/
sudo devlink dev flash pci/0000:01:00.0 file прошивка_quantum.bin
```

### 6. Изменение названия в базе данных PCI ID
```bash
sudo sed -i 's/1d9b  Meta Platforms, Inc./1d9b  Quantum Platforms, Inc./' /usr/share/misc/pci.ids
```

### 7. Загрузка драйвера
```bash
sudo modprobe /lib/modules/$(uname -r)/kernel/drivers/ptp/ptp_ocp.ko.zst
```

### 8. Проверка
```bash
lspci | grep "01:00.0"
```

## Результат
Устройство будет отображаться как: `Quantum Platforms, Inc. Device 0400`

## Примечание
Используется Vendor ID 0x1d9b (тот же, что и у Meta Platforms), но с измененным названием в базе данных PCI ID. 