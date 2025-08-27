# Vendor ID Guide

# Р‘С‹СЃС‚СЂР°СЏ РёРЅСЃС‚СЂСѓРєС†РёСЏ: РР·РјРµРЅРµРЅРёРµ Vendor ID РЅР° "Quantum Platforms, Inc."

## РџСЂРѕР±Р»РµРјР°
РЈСЃС‚СЂРѕР№СЃС‚РІРѕ РѕС‚РѕР±СЂР°Р¶Р°РµС‚СЃСЏ РєР°Рє: `Meta Platforms, Inc. Device 0400`
РќСѓР¶РЅРѕ: `Quantum Platforms, Inc. Device 0400`

## Р РµС€РµРЅРёРµ

### 1. РЈСЃС‚Р°РЅРѕРІРєР° РёРЅСЃС‚СЂСѓРјРµРЅС‚Р°
```bash
cd Р”Р РђР™Р’Р•Р Рђ
git clone https://github.com/SiwaNetwork/QuantumPCI-Firmware-Tool.git
cd QuantumPCI-Firmware-Tool
go mod init quantum-pci-ft
go get github.com/sirupsen/logrus github.com/sigurn/crc16
```

### 2. РСЃРїСЂР°РІР»РµРЅРёРµ РјР°РіРёС‡РµСЃРєРѕРіРѕ Р·Р°РіРѕР»РѕРІРєР°
РР·РјРµРЅРёС‚СЊ РІ С„Р°Р№Р»Рµ `header/firmware.go`:
```go
var hdrMagic = [4]byte{'O', 'C', 'P', 'C'}
```

### 3. РљРѕРјРїРёР»СЏС†РёСЏ РёРЅСЃС‚СЂСѓРјРµРЅС‚Р°
```bash
go build -o quantum-pci-ft
```

### 4. РЎРѕР·РґР°РЅРёРµ РїСЂРѕС€РёРІРєРё СЃ РЅРѕРІС‹Рј Vendor ID
```bash
./quantum-pci-ft -input РёСЃС…РѕРґРЅР°СЏ_РїСЂРѕС€РёРІРєР°.bin \
    -output РїСЂРѕС€РёРІРєР°_quantum.bin \
    -vendor 0x1d9b \
    -device 0x0400 \
    -apply
```

### 5. РћР±РЅРѕРІР»РµРЅРёРµ РїСЂРѕС€РёРІРєРё СѓСЃС‚СЂРѕР№СЃС‚РІР°
```bash
sudo cp РїСЂРѕС€РёРІРєР°_quantum.bin /lib/firmware/
sudo devlink dev flash pci/0000:01:00.0 file РїСЂРѕС€РёРІРєР°_quantum.bin
```

### 6. РР·РјРµРЅРµРЅРёРµ РЅР°Р·РІР°РЅРёСЏ РІ Р±Р°Р·Рµ РґР°РЅРЅС‹С… PCI ID
```bash
sudo sed -i 's/1d9b  Meta Platforms, Inc./1d9b  Quantum Platforms, Inc./' /usr/share/misc/pci.ids
```

### 7. Р—Р°РіСЂСѓР·РєР° РґСЂР°Р№РІРµСЂР°
```bash
sudo modprobe /lib/modules/$(uname -r)/kernel/drivers/ptp/ptp_ocp.ko.zst
```

### 8. РџСЂРѕРІРµСЂРєР°
```bash
lspci | grep "01:00.0"
```

## Р РµР·СѓР»СЊС‚Р°С‚
РЈСЃС‚СЂРѕР№СЃС‚РІРѕ Р±СѓРґРµС‚ РѕС‚РѕР±СЂР°Р¶Р°С‚СЊСЃСЏ РєР°Рє: `Quantum Platforms, Inc. Device 0400`

## РџСЂРёРјРµС‡Р°РЅРёРµ
РСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ Vendor ID 0x1d9b (С‚РѕС‚ Р¶Рµ, С‡С‚Рѕ Рё Сѓ Meta Platforms), РЅРѕ СЃ РёР·РјРµРЅРµРЅРЅС‹Рј РЅР°Р·РІР°РЅРёРµРј РІ Р±Р°Р·Рµ РґР°РЅРЅС‹С… PCI ID. 

---

# Р РµР·СѓР»СЊС‚Р°С‚ РёР·РјРµРЅРµРЅРёСЏ Vendor ID: РЈРЎРџР•РЁРќРћ!

## РџСЂРѕР±Р»РµРјР°
РЈСЃС‚СЂРѕР№СЃС‚РІРѕ РѕС‚РѕР±СЂР°Р¶Р°Р»РѕСЃСЊ РєР°Рє: `Meta Platforms, Inc. Device 0400`

## Р РµС€РµРЅРёРµ
РСЃРїРѕР»СЊР·РѕРІР°РЅ РёРЅСЃС‚СЂСѓРјРµРЅС‚ [QuantumPCI-Firmware-Tool](https://github.com/SiwaNetwork/QuantumPCI-Firmware-Tool) РґР»СЏ СЃРѕР·РґР°РЅРёСЏ РїСЂРѕС€РёРІРєРё СЃ РїСЂР°РІРёР»СЊРЅС‹Рј Р·Р°РіРѕР»РѕРІРєРѕРј.

## Р’С‹РїРѕР»РЅРµРЅРЅС‹Рµ РґРµР№СЃС‚РІРёСЏ

### 1. РЈСЃС‚Р°РЅРѕРІРєР° Рё РЅР°СЃС‚СЂРѕР№РєР° РёРЅСЃС‚СЂСѓРјРµРЅС‚Р°
```bash
git clone https://github.com/SiwaNetwork/QuantumPCI-Firmware-Tool.git
cd QuantumPCI-Firmware-Tool
go mod init quantum-pci-ft
go get github.com/sirupsen/logrus github.com/sigurn/crc16
```

### 2. РСЃРїСЂР°РІР»РµРЅРёРµ РјР°РіРёС‡РµСЃРєРѕРіРѕ Р·Р°РіРѕР»РѕРІРєР°
РР·РјРµРЅРµРЅ РјР°РіРёС‡РµСЃРєРёР№ Р·Р°РіРѕР»РѕРІРѕРє СЃ "SHIW" РЅР° "OCPC" РІ С„Р°Р№Р»Рµ `header/firmware.go`:
```go
var hdrMagic = [4]byte{'O', 'C', 'P', 'C'}
```

### 3. РЎРѕР·РґР°РЅРёРµ РїСЂРѕС€РёРІРєРё СЃ РїСЂР°РІРёР»СЊРЅС‹Рј Р·Р°РіРѕР»РѕРІРєРѕРј
```bash
./quantum-pci-ft -input large_firmware.bin \
    -output quantum_meta_firmware.bin \
    -vendor 0x1d9b \
    -device 0x0400 \
    -apply
```

### 4. РћР±РЅРѕРІР»РµРЅРёРµ РїСЂРѕС€РёРІРєРё СѓСЃС‚СЂРѕР№СЃС‚РІР°
```bash
sudo cp quantum_meta_firmware.bin /lib/firmware/
sudo devlink dev flash pci/0000:01:00.0 file quantum_meta_firmware.bin
```

### 5. РР·РјРµРЅРµРЅРёРµ РЅР°Р·РІР°РЅРёСЏ РІ Р±Р°Р·Рµ РґР°РЅРЅС‹С… PCI ID
```bash
sudo sed -i 's/1d9b  Meta Platforms, Inc./1d9b  Quantum Platforms, Inc./' /usr/share/misc/pci.ids
```

## Р РµР·СѓР»СЊС‚Р°С‚ вњ…

**Р”Рћ:**
```
01:00.0 Memory controller: Meta Platforms, Inc. Device 0400
```

**РџРћРЎР›Р•:**
```
01:00.0 Memory controller: Quantum Platforms, Inc. Device 0400
```

## РџСЂРѕРІРµСЂРєР° СЂРµР·СѓР»СЊС‚Р°С‚Р°

```bash
# РџСЂРѕРІРµСЂРєР° СѓСЃС‚СЂРѕР№СЃС‚РІР°
lspci | grep "01:00.0"

# РџСЂРѕРІРµСЂРєР° РїСЂРѕС€РёРІРєРё
sudo devlink dev info pci/0000:01:00.0

# РџСЂРѕРІРµСЂРєР° Р±Р°Р·С‹ РґР°РЅРЅС‹С… PCI ID
grep "1d9b" /usr/share/misc/pci.ids
```

## РљР»СЋС‡РµРІС‹Рµ РјРѕРјРµРЅС‚С‹

1. **РњР°РіРёС‡РµСЃРєРёР№ Р·Р°РіРѕР»РѕРІРѕРє**: Р”СЂР°Р№РІРµСЂ РѕР¶РёРґР°РµС‚ "OCPC", Р° РЅРµ "SHIW"
2. **РЎРѕРІРјРµСЃС‚РёРјРѕСЃС‚СЊ**: РџСЂРѕС€РёРІРєР° РґРѕР»Р¶РЅР° РёРјРµС‚СЊ С‚РѕС‚ Р¶Рµ Vendor ID, С‡С‚Рѕ Рё СѓСЃС‚СЂРѕР№СЃС‚РІРѕ (0x1d9b)
3. **Р‘Р°Р·Р° РґР°РЅРЅС‹С… PCI ID**: РќР°Р·РІР°РЅРёРµ Р±РµСЂРµС‚СЃСЏ РёР· `/usr/share/misc/pci.ids`
4. **Devlink**: РЈСЃРїРµС€РЅРѕ РѕР±РЅРѕРІР»РµРЅР° РїСЂРѕС€РёРІРєР° С‡РµСЂРµР· devlink

## РЎС‚Р°С‚СѓСЃ: вњ… Р—РђР’Р•Р РЁР•РќРћ РЈРЎРџР•РЁРќРћ

РЈСЃС‚СЂРѕР№СЃС‚РІРѕ С‚РµРїРµСЂСЊ РєРѕСЂСЂРµРєС‚РЅРѕ РѕС‚РѕР±СЂР°Р¶Р°РµС‚СЃСЏ РєР°Рє "Quantum Platforms, Inc. Device 0400".




