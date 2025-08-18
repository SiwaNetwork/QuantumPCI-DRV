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
go build -o quantum-pci-ft
```

### 2. Создание прошивки с новым Vendor ID
```bash
./quantum-pci-ft -input исходная_прошивка.bin \
    -output прошивка_quantum.bin \
    -vendor 0x1d9c \
    -device 0x0400 \
    -apply
```

### 3. Обновление драйвера
```bash
cd ..
make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
sudo rmmod ptp_ocp
sudo insmod ptp_ocp.ko
```

### 4. Обновление прошивки устройства
```bash
sudo devlink dev flash pci/0000:01:00.0 file прошивка_quantum.bin
```

### 5. Проверка
```bash
lspci -vvv | grep "01:00.0"
```

## Результат
Устройство будет отображаться как: `Quantum Platforms, Inc. Device 0400`

## Примечание
База данных PCI ID уже обновлена в системе с новым Vendor ID 0x1d9c. 