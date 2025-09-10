# Быстрая инструкция для .bin файлов

## Конвертация прошивки

### В Quantum Platforms
```bash
sudo ./convert_firmware.sh quantum my_firmware.bin
```

### В Meta Platforms
```bash
sudo ./convert_firmware.sh meta my_firmware.bin
```

## Прошивка устройства

```bash
# Quantum Platforms
sudo ./convert_firmware.sh flash my_firmware_quantum.bin "Quantum Platforms"

# Meta Platforms
sudo ./convert_firmware.sh flash my_firmware_meta.bin "Meta Platforms"
```

## Параметры по умолчанию

- **Vendor ID**: 0x1d9b
- **Device ID**: 0x0400
- **HW Revision**: 0x0001

## Важные замечания

1. Исходный .bin файл не изменяется — создается новый файл с заголовком
2. Размер увеличивается на 16 байт (размер заголовка)
3. Все команды требуют sudo

## Устранение неполадок

### Ошибка "Входной файл не найден"
```bash
ls -la my_firmware.bin
```

### Ошибка "No firmware header found"
- Проверьте правильность магического заголовка
- Убедитесь, что драйвер поддерживает оба типа заголовков
