# Быстрая инструкция для работы с готовыми .bin файлами

## 🚀 Если у вас уже есть .bin файл прошивки

### Шаг 1: Конвертация в Quantum Platforms (SHIW)

```bash
# Базовый вариант (автоматическое имя файла)
sudo ./convert_firmware.sh quantum my_firmware.bin

# С указанием выходного файла
sudo ./convert_firmware.sh quantum my_firmware.bin quantum_firmware.bin
```

### Шаг 2: Конвертация в Meta Platforms (OCPC)

```bash
# Базовый вариант (автоматическое имя файла)
sudo ./convert_firmware.sh meta my_firmware.bin

# С указанием выходного файла
sudo ./convert_firmware.sh meta my_firmware.bin meta_firmware.bin
```

### Шаг 3: Прошивка устройства

```bash
# Прошить Quantum Platforms прошивкой
sudo ./convert_firmware.sh flash my_firmware_quantum.bin "Quantum Platforms"

# Прошить Meta Platforms прошивкой
sudo ./convert_firmware.sh flash my_firmware_meta.bin "Meta Platforms"
```

## ⚙️ Параметры по умолчанию

- **Vendor ID**: 0x1d9b
- **Device ID**: 0x0400
- **HW Revision**: 0x0001
- **CRC**: 0x0000 (пока не вычисляется)

## 🛠️ Структура создаваемого заголовка

```
[4 байта] Магический заголовок (SHIW/OCPC)
[2 байта] Vendor ID (0x1d9b, little-endian)
[2 байта] Device ID (0x0400, little-endian)
[4 байта] Размер исходного .bin файла (little-endian)
[2 байта] Ревизия оборудования (0x0001, little-endian)
[2 байта] CRC (0x0000)
[N байт]  Данные исходного .bin файла
```

## ⚠️ Важные замечания

1. **Исходный .bin файл не изменяется** - создается новый файл с заголовком
2. **Размер увеличивается на 16 байт** (размер заголовка)
3. **Автоматическое именование**: если не указать выходной файл, добавляется суффикс `_quantum` или `_meta`
4. **Права администратора**: все команды требуют sudo

## 🔧 Устранение неполадок

### Ошибка "Входной файл не найден"
```bash
# Проверьте, что файл существует
ls -la my_firmware.bin

# Убедитесь, что путь правильный
pwd
```

### Ошибка "No firmware header found"
- Убедитесь, что драйвер поддерживает оба типа заголовков
- Проверьте правильность магического заголовка

### Ошибка "Firmware image compatibility check failed"
- Проверьте Vendor ID и Device ID в заголовке
- Убедитесь, что размер образа указан правильно

 
