# Monitoring Guide

# рџ•ђ TimeCard PTP OCP Real Monitoring

## рџ“‹ РћР±Р·РѕСЂ

РЎРёСЃС‚РµРјР° СЂРµР°Р»СЊРЅРѕРіРѕ РјРѕРЅРёС‚РѕСЂРёРЅРіР° TimeCard PTP OCP, РєРѕС‚РѕСЂР°СЏ С‡РёС‚Р°РµС‚ **СЂРµР°Р»СЊРЅС‹Рµ РґР°РЅРЅС‹Рµ** РёР· РґСЂР°Р№РІРµСЂР° СѓСЃС‚СЂРѕР№СЃС‚РІР° Р±РµР· РіРµРЅРµСЂР°С†РёРё РґРµРјРѕ-РґР°РЅРЅС‹С….

## вњ… Р РµР°Р»РёР·РѕРІР°РЅРЅС‹Рµ С„СѓРЅРєС†РёРё

### рџ“Ў **PTP РњРѕРЅРёС‚РѕСЂРёРЅРі**
- **Clock Offset**: Р РµР°Р»СЊРЅРѕРµ Р·РЅР°С‡РµРЅРёРµ РёР· `/sys/class/timecard/ocp0/clock_status_offset`
- **Clock Drift**: Р РµР°Р»СЊРЅРѕРµ Р·РЅР°С‡РµРЅРёРµ РёР· `/sys/class/timecard/ocp0/clock_status_drift`
- **Clock Source**: Р РµР°Р»СЊРЅС‹Р№ РёСЃС‚РѕС‡РЅРёРє РІСЂРµРјРµРЅРё РёР· `/sys/class/timecard/ocp0/clock_source`

### рџ›°пёЏ **GNSS РњРѕРЅРёС‚РѕСЂРёРЅРі**
- **Sync Status**: Р РµР°Р»СЊРЅС‹Р№ СЃС‚Р°С‚СѓСЃ РёР· `/sys/class/timecard/ocp0/gnss_sync`
- **Fix Type**: РћРїСЂРµРґРµР»СЏРµС‚СЃСЏ РЅР° РѕСЃРЅРѕРІРµ СЃС‚Р°С‚СѓСЃР° СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёРё
- **Alert Generation**: РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРёРµ Р°Р»РµСЂС‚С‹ РїСЂРё РїРѕС‚РµСЂРµ СЃРёРіРЅР°Р»Р°

### рџ”Њ **SMA РњРѕРЅРёС‚РѕСЂРёРЅРі**
- **SMA1-SMA4**: Р РµР°Р»СЊРЅС‹Рµ РґР°РЅРЅС‹Рµ РёР· `/sys/class/timecard/ocp0/sma1-4`
- **Connection Status**: РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРѕРµ РѕРїСЂРµРґРµР»РµРЅРёРµ РїРѕРґРєР»СЋС‡РµРЅРёСЏ
- **Signal Type**: Р§С‚РµРЅРёРµ С‚РёРїР° СЃРёРіРЅР°Р»Р° (IN/OUT)

### рџљЁ **РЎРёСЃС‚РµРјР° РђР»РµСЂС‚РѕРІ**
- **PTP Alerts**: РљСЂРёС‚РёС‡РµСЃРєРёРµ Р°Р»РµСЂС‚С‹ РїСЂРё Р±РѕР»СЊС€РѕРј offset
- **GNSS Alerts**: РљСЂРёС‚РёС‡РµСЃРєРёРµ Р°Р»РµСЂС‚С‹ РїСЂРё РїРѕС‚РµСЂРµ СЃРёРіРЅР°Р»Р°
- **Real-time Monitoring**: РћР±РЅРѕРІР»РµРЅРёРµ РєР°Р¶РґС‹Рµ 5 СЃРµРєСѓРЅРґ

## рџљЂ Р‘С‹СЃС‚СЂС‹Р№ СЃС‚Р°СЂС‚

### 1. Р—Р°РїСѓСЃРє РјРѕРЅРёС‚РѕСЂРёРЅРіР°
```bash
cd ptp-monitoring
./start-real-monitoring.sh start
```

### 2. РџСЂРѕРІРµСЂРєР° СЃС‚Р°С‚СѓСЃР°
```bash
./start-real-monitoring.sh status
```

### 3. РџСЂРѕСЃРјРѕС‚СЂ Р»РѕРіРѕРІ
```bash
./start-real-monitoring.sh logs
```

### 4. РћСЃС‚Р°РЅРѕРІРєР°
```bash
./start-real-monitoring.sh stop
```

## рџЊђ Р’РµР±-РёРЅС‚РµСЂС„РµР№СЃС‹

### РћСЃРЅРѕРІРЅС‹Рµ URL:
- **Dashboard**: http://localhost:8080/dashboard
- **API**: http://localhost:8080/api/
- **Main Page**: http://localhost:8080/

### API Endpoints:
- **РЈСЃС‚СЂРѕР№СЃС‚РІР°**: `GET /api/devices`
- **Р РµР°Р»СЊРЅС‹Рµ РјРµС‚СЂРёРєРё**: `GET /api/metrics/real`
- **РђР»РµСЂС‚С‹**: `GET /api/alerts`
- **РЎС‚Р°С‚СѓСЃ СѓСЃС‚СЂРѕР№СЃС‚РІР°**: `GET /api/device/ocp0/status`

## рџ“Љ РџСЂРёРјРµСЂС‹ РґР°РЅРЅС‹С…

### Р РµР°Р»СЊРЅС‹Рµ PTP РґР°РЅРЅС‹Рµ:
```json
{
  "ptp": {
    "offset_ns": 0,
    "drift_ppb": 0,
    "clock_source": "PPS",
    "status": "normal"
  }
}
```

### Р РµР°Р»СЊРЅС‹Рµ GNSS РґР°РЅРЅС‹Рµ:
```json
{
  "gnss": {
    "sync_status": "LOST @ 2025-07-31T06:30:59",
    "fix_type": "NO_FIX",
    "status": "critical"
  }
}
```

### Р РµР°Р»СЊРЅС‹Рµ SMA РґР°РЅРЅС‹Рµ:
```json
{
  "sma": {
    "sma1": {"value": "IN: 10Mhz", "status": "connected"},
    "sma2": {"value": "IN: PPS1", "status": "connected"},
    "sma3": {"value": "OUT: 10Mhz", "status": "disconnected"},
    "sma4": {"value": "OUT: PHC", "status": "disconnected"}
  }
}
```

## рџ”§ РўРµС…РЅРёС‡РµСЃРєРёРµ РґРµС‚Р°Р»Рё

### РСЃС‚РѕС‡РЅРёРєРё РґР°РЅРЅС‹С…:
- **Sysfs Interface**: `/sys/class/timecard/ocp0/`
- **Real-time Reading**: РџСЂСЏРјРѕРµ С‡С‚РµРЅРёРµ РёР· РґСЂР°Р№РІРµСЂР°
- **No Demo Data**: РўРѕР»СЊРєРѕ СЂРµР°Р»СЊРЅС‹Рµ Р·РЅР°С‡РµРЅРёСЏ

### РђСЂС…РёС‚РµРєС‚СѓСЂР°:
- **Flask API**: Р’РµР±-СЃРµСЂРІРµСЂ РЅР° РїРѕСЂС‚Сѓ 8080
- **WebSocket**: Real-time РѕР±РЅРѕРІР»РµРЅРёСЏ
- **Background Monitoring**: Р¤РѕРЅРѕРІС‹Р№ СЃР±РѕСЂ РґР°РЅРЅС‹С…
- **Alert System**: РђРІС‚РѕРјР°С‚РёС‡РµСЃРєР°СЏ РіРµРЅРµСЂР°С†РёСЏ Р°Р»РµСЂС‚РѕРІ

### Р—Р°РІРёСЃРёРјРѕСЃС‚Рё:
- Python 3.x
- Flask
- Flask-SocketIO
- Flask-CORS

## рџљЁ РЎРёСЃС‚РµРјР° Р°Р»РµСЂС‚РѕРІ

### PTP РђР»РµСЂС‚С‹:
- **Warning**: Offset > 1000 ns
- **Critical**: Offset > 10000 ns

### GNSS РђР»РµСЂС‚С‹:
- **Critical**: РЎС‚Р°С‚СѓСЃ СЃРѕРґРµСЂР¶РёС‚ "LOST"

### РџСЂРёРјРµСЂ Р°Р»РµСЂС‚Р°:
```json
{
  "type": "gnss_lost",
  "message": "GNSS СЃРёРіРЅР°Р» РїРѕС‚РµСЂСЏРЅ: LOST @ 2025-07-31T06:30:59",
  "severity": "critical",
  "timestamp": 1753944389.3581305
}
```

## рџ“€ РњРѕРЅРёС‚РѕСЂРёРЅРі РІ СЂРµР°Р»СЊРЅРѕРј РІСЂРµРјРµРЅРё

### WebSocket СЃРѕР±С‹С‚РёСЏ:
- `device_update`: РћР±РЅРѕРІР»РµРЅРёСЏ РґР°РЅРЅС‹С… СѓСЃС‚СЂРѕР№СЃС‚РІР°
- `status_update`: РЎС‚Р°С‚СѓСЃ РїРѕРґРєР»СЋС‡РµРЅРёСЏ
- `error`: РћС€РёР±РєРё РјРѕРЅРёС‚РѕСЂРёРЅРіР°

### РћР±РЅРѕРІР»РµРЅРёРµ РґР°РЅРЅС‹С…:
- **РРЅС‚РµСЂРІР°Р»**: 5 СЃРµРєСѓРЅРґ
- **РСЃС‚РѕСЂРёСЏ**: РџРѕСЃР»РµРґРЅРёРµ 1000 Р·Р°РїРёСЃРµР№
- **РђР»РµСЂС‚С‹**: РџРѕСЃР»РµРґРЅРёРµ 500 Р°Р»РµСЂС‚РѕРІ

## рџ”Ќ РћС‚Р»Р°РґРєР°

### РџСЂРѕРІРµСЂРєР° РґСЂР°Р№РІРµСЂР°:
```bash
ls -la /sys/class/timecard/ocp0/
```

### РџСЂРѕРІРµСЂРєР° РґР°РЅРЅС‹С…:
```bash
cat /sys/class/timecard/ocp0/clock_status_offset
cat /sys/class/timecard/ocp0/gnss_sync
cat /sys/class/timecard/ocp0/sma1
```

### Р›РѕРіРё API:
```bash
tail -f real-api.log
```

## вљ пёЏ РћРіСЂР°РЅРёС‡РµРЅРёСЏ

### Р”РѕСЃС‚СѓРїРЅС‹Рµ РґР°РЅРЅС‹Рµ:
- вњ… PTP offset Рё drift
- вњ… GNSS sync status
- вњ… SMA connector status
- вњ… Device information

### РќРµРґРѕСЃС‚СѓРїРЅС‹Рµ РґР°РЅРЅС‹Рµ:
- вќЊ РўРµРјРїРµСЂР°С‚СѓСЂРЅС‹Рµ СЃРµРЅСЃРѕСЂС‹ (РЅРµС‚ РІ РґСЂР°Р№РІРµСЂРµ)
- вќЊ РњРѕРЅРёС‚РѕСЂРёРЅРі РїРёС‚Р°РЅРёСЏ (РЅРµС‚ РІ РґСЂР°Р№РІРµСЂРµ)
- вќЊ Р”РµС‚Р°Р»СЊРЅС‹Рµ GNSS РґР°РЅРЅС‹Рµ (РЅРµС‚ РІ РґСЂР°Р№РІРµСЂРµ)
- вќЊ Р”Р°РЅРЅС‹Рµ РѕСЃС†РёР»Р»СЏС‚РѕСЂР° (РЅРµС‚ РІ РґСЂР°Р№РІРµСЂРµ)

## рџЋЇ РџСЂРµРёРјСѓС‰РµСЃС‚РІР°

1. **Р РµР°Р»СЊРЅС‹Рµ РґР°РЅРЅС‹Рµ**: РўРѕР»СЊРєРѕ С„Р°РєС‚РёС‡РµСЃРєРёРµ Р·РЅР°С‡РµРЅРёСЏ РёР· РґСЂР°Р№РІРµСЂР°
2. **РќР°РґРµР¶РЅРѕСЃС‚СЊ**: РќРµС‚ Р·Р°РІРёСЃРёРјРѕСЃС‚Рё РѕС‚ РґРµРјРѕ-РґР°РЅРЅС‹С…
3. **РџСЂРѕРёР·РІРѕРґРёС‚РµР»СЊРЅРѕСЃС‚СЊ**: РњРёРЅРёРјР°Р»СЊРЅР°СЏ РЅР°РіСЂСѓР·РєР° РЅР° СЃРёСЃС‚РµРјСѓ
4. **РўРѕС‡РЅРѕСЃС‚СЊ**: РџСЂСЏРјРѕРµ С‡С‚РµРЅРёРµ РёР· sysfs РёРЅС‚РµСЂС„РµР№СЃР°
5. **РђР»РµСЂС‚С‹**: РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРёРµ СѓРІРµРґРѕРјР»РµРЅРёСЏ Рѕ РїСЂРѕР±Р»РµРјР°С…

## рџ“ќ РљРѕРјР°РЅРґС‹ СѓРїСЂР°РІР»РµРЅРёСЏ

```bash
# Р—Р°РїСѓСЃРє
./start-real-monitoring.sh start

# РћСЃС‚Р°РЅРѕРІРєР°
./start-real-monitoring.sh stop

# РџРµСЂРµР·Р°РїСѓСЃРє
./start-real-monitoring.sh restart

# РЎС‚Р°С‚СѓСЃ
./start-real-monitoring.sh status

# Р›РѕРіРё
./start-real-monitoring.sh logs

# РЎРїСЂР°РІРєР°
./start-real-monitoring.sh help
```

## рџ”— РЎСЃС‹Р»РєРё

- **API Documentation**: http://localhost:8080/
- **Real Metrics**: http://localhost:8080/api/metrics/real
- **Device Status**: http://localhost:8080/api/device/ocp0/status
- **Alerts**: http://localhost:8080/api/alerts 

---

# Quantum-PCI TimeCard PTP OCP Extended Monitoring Stack

РџРѕР»РЅР°СЏ СЃРёСЃС‚РµРјР° РјРѕРЅРёС‚РѕСЂРёРЅРіР° Quantum-PCI TimeCard PTP OCP СЃ РёРЅС‚РµРіСЂР°С†РёРµР№ Grafana, Prometheus Рё AlertManager.

> рџ“Њ **РџСЂРёРјРµС‡Р°РЅРёРµ**: Р”Р»СЏ Р±Р°Р·РѕРІРѕР№ СѓСЃС‚Р°РЅРѕРІРєРё Рё РЅР°СЃС‚СЂРѕР№РєРё Quantum-PCI TimeCard СЃРј. [TIMECARD_РРќРЎРўР РЈРљР¦РРЇ_РћРџРўРРњРР—РР РћР’РђРќРќРђРЇ.md](../docs/architecture.md)

## рџЏ—пёЏ РђСЂС…РёС‚РµРєС‚СѓСЂР° СЃРёСЃС‚РµРјС‹

```
в”Њв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”ђ    в”Њв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”ђ    в”Њв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”ђ
в”‚   Quantum-PCI TimeCard      в”‚    в”‚   Prometheus     в”‚    в”‚    Grafana      в”‚
в”‚   Extended API  в”‚в—„в”Ђв”Ђв–єв”‚   Exporter       в”‚в—„в”Ђв”Ђв–єв”‚   Dashboard     в”‚
в”‚   (Port 8080)   в”‚    в”‚   (Port 9090)    в”‚    в”‚   (Port 3000)   в”‚
в””в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”    в””в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”    в””в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”
         в”‚                       в”‚                       в”‚
         в”‚                       в–ј                       в”‚
         в”‚              в”Њв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”ђ              в”‚
         в”‚              в”‚   Prometheus    в”‚              в”‚
         в”‚              в”‚   (Port 9091)   в”‚              в”‚
         в”‚              в””в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”              в”‚
         в”‚                       в”‚                       в”‚
         в”‚                       в–ј                       в”‚
         в”‚              в”Њв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”ђ              в”‚
         в”‚              в”‚  AlertManager   в”‚              в”‚
         в”‚              в”‚   (Port 9093)   в”‚              в”‚
         в”‚              в””в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”              в”‚
         в”‚                                                в”‚
         в”‚              в”Њв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”ђ              в”‚
         в””в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв–єв”‚ VictoriaMetrics в”‚в—„в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”
                        в”‚   (Port 9009)   в”‚
                        в””в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”
```

## рџ“Љ РљРѕРјРїРѕРЅРµРЅС‚С‹ СЃРёСЃС‚РµРјС‹

### 1. Quantum-PCI TimeCard Extended API (РџРѕСЂС‚ 8080)
- **РћРїРёСЃР°РЅРёРµ**: Р Р°СЃС€РёСЂРµРЅРЅС‹Р№ API РґР»СЏ РјРѕРЅРёС‚РѕСЂРёРЅРіР° РІСЃРµС… Р°СЃРїРµРєС‚РѕРІ Quantum-PCI TimeCard
- **Р¤СѓРЅРєС†РёРё**:
  - Р’РµР±-РґР°С€Р±РѕСЂРґ СЃ real-time updates
  - REST API РґР»СЏ РІСЃРµС… РјРµС‚СЂРёРє
  - WebSocket РґР»СЏ live РґР°РЅРЅС‹С…
  - РЎРёСЃС‚РµРјС‹ Р°Р»РµСЂС‚РѕРІ Рё health scoring
  - РСЃС‚РѕСЂРёС‡РµСЃРєРёРµ РґР°РЅРЅС‹Рµ

### 2. Prometheus Exporter (РџРѕСЂС‚ 9090)
- **РћРїРёСЃР°РЅРёРµ**: Р­РєСЃРїРѕСЂС‚РµСЂ РјРµС‚СЂРёРє Quantum-PCI TimeCard РІ С„РѕСЂРјР°С‚Рµ Prometheus
- **РњРµС‚СЂРёРєРё**:
  - рџ“Ў **PTP**: offset, path delay, packet stats, performance score
  - рџЊЎпёЏ **Thermal**: 6 С‚РµРјРїРµСЂР°С‚СѓСЂРЅС‹С… СЃРµРЅСЃРѕСЂРѕРІ + РѕС…Р»Р°Р¶РґРµРЅРёРµ
  - вљЎ **Power**: 4 voltage rails + current consumption
  - рџ›°пёЏ **GNSS**: 4 constellation + accuracy + antenna status
  - вљЎ **Oscillator**: Allan deviation + stability + lock status
  - рџ”§ **Hardware**: LEDs, FPGA, network ports, SMA connectors
  - рџљЁ **Alerts**: Р°РєС‚РёРІРЅС‹Рµ + РёСЃС‚РѕСЂРёС‡РµСЃРєРёРµ РїРѕ severity
  - рџ“Љ **Health**: system + component scores

### 3. Prometheus (РџРѕСЂС‚ 9091)
- **РћРїРёСЃР°РЅРёРµ**: РЎРёСЃС‚РµРјР° СЃР±РѕСЂР° Рё С…СЂР°РЅРµРЅРёСЏ РјРµС‚СЂРёРє
- **Р¤СѓРЅРєС†РёРё**:
  - РЎР±РѕСЂ РјРµС‚СЂРёРє РєР°Р¶РґС‹Рµ 30 СЃРµРєСѓРЅРґ
  - Recording rules РґР»СЏ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹С… РјРµС‚СЂРёРє
  - Alert rules РґР»СЏ РІСЃРµС… РєРѕРјРїРѕРЅРµРЅС‚РѕРІ
  - Retention: 30 РґРЅРµР№

### 4. Grafana (РџРѕСЂС‚ 3000)
- **РћРїРёСЃР°РЅРёРµ**: РЎРёСЃС‚РµРјР° РІРёР·СѓР°Р»РёР·Р°С†РёРё Рё dashboards
- **Р›РѕРіРёРЅ**: admin / timecard123
- **Р¤СѓРЅРєС†РёРё**:
  - Comprehensive Quantum-PCI TimeCard dashboard
  - 18 panels РґР»СЏ РІСЃРµС… Р°СЃРїРµРєС‚РѕРІ
  - Device selector
  - РђР»РµСЂС‚С‹ Рё Р°РЅРЅРѕС‚Р°С†РёРё
  - РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРёР№ import dashboard

### 5. AlertManager (РџРѕСЂС‚ 9093)
- **РћРїРёСЃР°РЅРёРµ**: РЎРёСЃС‚РµРјР° РѕР±СЂР°Р±РѕС‚РєРё Рё РјР°СЂС€СЂСѓС‚РёР·Р°С†РёРё Р°Р»РµСЂС‚РѕРІ
- **Р¤СѓРЅРєС†РёРё**:
  - Email СѓРІРµРґРѕРјР»РµРЅРёСЏ РїРѕ РєРѕРјРїРѕРЅРµРЅС‚Р°Рј
  - Slack РёРЅС‚РµРіСЂР°С†РёСЏ
  - Р“СЂСѓРїРїРёСЂРѕРІРєР° Рё РїРѕРґР°РІР»РµРЅРёРµ Р°Р»РµСЂС‚РѕРІ
  - Р­СЃРєР°Р»Р°С†РёСЏ РїРѕ severity

### 6. VictoriaMetrics (РџРѕСЂС‚ 9009)
- **РћРїРёСЃР°РЅРёРµ**: Long-term storage РґР»СЏ РјРµС‚СЂРёРє
- **Р¤СѓРЅРєС†РёРё**:
  - РҐСЂР°РЅРµРЅРёРµ РґР°РЅРЅС‹С… РґРѕ 1 РіРѕРґР°
  - РЎР¶Р°С‚РёРµ Рё РѕРїС‚РёРјРёР·Р°С†РёСЏ
  - Remote read/write РґР»СЏ Prometheus

## рџљЂ Р‘С‹СЃС‚СЂС‹Р№ Р·Р°РїСѓСЃРє

### Р РµР¶РёРј Docker (Р РµРєРѕРјРµРЅРґСѓРµС‚СЃСЏ)

```bash
# Р—Р°РїСѓСЃРє РїРѕР»РЅРѕР№ СЃРёСЃС‚РµРјС‹
./start-monitoring-stack.sh start docker

# РџСЂРѕРІРµСЂРєР° СЃС‚Р°С‚СѓСЃР°
./start-monitoring-stack.sh status

# РџСЂРѕСЃРјРѕС‚СЂ Р»РѕРіРѕРІ
./start-monitoring-stack.sh logs docker

# РћСЃС‚Р°РЅРѕРІРєР°
./start-monitoring-stack.sh stop docker
```

### Р РµР¶РёРј Development

```bash
# Р—Р°РїСѓСЃРє РІ dev СЂРµР¶РёРјРµ
./start-monitoring-stack.sh start dev

# РћСЃС‚Р°РЅРѕРІРєР°
./start-monitoring-stack.sh stop dev
```

## рџЊђ Р’РµР±-РёРЅС‚РµСЂС„РµР№СЃС‹

| РЎРµСЂРІРёСЃ | URL | Р›РѕРіРёРЅ | РћРїРёСЃР°РЅРёРµ |
|--------|-----|-------|----------|
| **Quantum-PCI TimeCard Dashboard** | http://localhost:8080 | - | РћСЃРЅРѕРІРЅРѕР№ РґР°С€Р±РѕСЂРґ Quantum-PCI TimeCard |
| **Grafana** | http://localhost:3000 | admin:timecard123 | РЎРёСЃС‚РµРјР° РјРѕРЅРёС‚РѕСЂРёРЅРіР° |
| **Prometheus** | http://localhost:9091 | - | РЎР±РѕСЂ РјРµС‚СЂРёРє |
| **AlertManager** | http://localhost:9093 | - | РЈРїСЂР°РІР»РµРЅРёРµ Р°Р»РµСЂС‚Р°РјРё |

## рџ“Љ API Endpoints

### Quantum-PCI TimeCard API
- `GET /api/health` - Health check
- `GET /api/metrics/extended` - Р’СЃРµ СЂР°СЃС€РёСЂРµРЅРЅС‹Рµ РјРµС‚СЂРёРєРё
- `GET /api/metrics/ptp/advanced` - РџСЂРѕРґРІРёРЅСѓС‚С‹Рµ PTP РјРµС‚СЂРёРєРё
- `GET /api/metrics/thermal` - РўРµРїР»РѕРІС‹Рµ РјРµС‚СЂРёРєРё
- `GET /api/metrics/power` - РњРµС‚СЂРёРєРё РїРёС‚Р°РЅРёСЏ
- `GET /api/metrics/gnss` - GNSS РјРµС‚СЂРёРєРё
- `GET /api/metrics/oscillator` - РњРµС‚СЂРёРєРё РѕСЃС†РёР»Р»СЏС‚РѕСЂР°
- `GET /api/metrics/hardware` - РђРїРїР°СЂР°С‚РЅС‹Рµ РјРµС‚СЂРёРєРё
- `GET /api/alerts` - РўРµРєСѓС‰РёРµ Р°Р»РµСЂС‚С‹
- `GET /api/devices` - РЎРїРёСЃРѕРє СѓСЃС‚СЂРѕР№СЃС‚РІ

### Prometheus Exporter
- `GET /metrics` - Р’СЃРµ РјРµС‚СЂРёРєРё РІ С„РѕСЂРјР°С‚Рµ Prometheus

## рџљЁ РЎРёСЃС‚РµРјР° Р°Р»РµСЂС‚РѕРІ

### РљСЂРёС‚РёС‡РµСЃРєРёРµ Р°Р»РµСЂС‚С‹ (Critical)
- **PTP Offset > 1ms** - РљСЂРёС‚РёС‡РµСЃРєРѕРµ РѕС‚РєР»РѕРЅРµРЅРёРµ PTP
- **Temperature > 85В°C** - РљСЂРёС‚РёС‡РµСЃРєР°СЏ С‚РµРјРїРµСЂР°С‚СѓСЂР°
- **Voltage deviation > 10%** - РљСЂРёС‚РёС‡РµСЃРєРѕРµ РѕС‚РєР»РѕРЅРµРЅРёРµ РЅР°РїСЂСЏР¶РµРЅРёСЏ
- **GNSS Fix Lost** - РџРѕС‚РµСЂСЏ GNSS С„РёРєСЃР°С†РёРё
- **Oscillator Unlocked** - Р Р°Р·Р±Р»РѕРєРёСЂРѕРІРєР° РѕСЃС†РёР»Р»СЏС‚РѕСЂР°

### РџСЂРµРґСѓРїСЂРµР¶РґРµРЅРёСЏ (Warning)
- **PTP Path Delay > 10ms** - Р’С‹СЃРѕРєР°СЏ Р·Р°РґРµСЂР¶РєР° PTP
- **Temperature > 75В°C** - Р’С‹СЃРѕРєР°СЏ С‚РµРјРїРµСЂР°С‚СѓСЂР°
- **Voltage deviation > 5%** - РћС‚РєР»РѕРЅРµРЅРёРµ РЅР°РїСЂСЏР¶РµРЅРёСЏ
- **Low GNSS accuracy** - РќРёР·РєР°СЏ С‚РѕС‡РЅРѕСЃС‚СЊ GNSS
- **High oscillator frequency error** - РћС€РёР±РєР° С‡Р°СЃС‚РѕС‚С‹

## рџ“€ Grafana Dashboard

### РџР°РЅРµР»Рё РјРѕРЅРёС‚РѕСЂРёРЅРіР°:
1. **System Overview** - РћР±С‰РёР№ health score РІСЃРµС… РєРѕРјРїРѕРЅРµРЅС‚РѕРІ
2. **PTP Offset** - Р“СЂР°С„РёРє PTP offset РІ СЂРµР°Р»СЊРЅРѕРј РІСЂРµРјРµРЅРё
3. **Path Delay & Variance** - Р—Р°РґРµСЂР¶РєР° Рё РІР°СЂРёР°С†РёСЏ PTP
4. **Temperature Monitoring** - 6 С‚РµРјРїРµСЂР°С‚СѓСЂРЅС‹С… СЃРµРЅСЃРѕСЂРѕРІ
5. **Power Rails** - 4 voltage rails
6. **GNSS Satellites** - РљРѕР»РёС‡РµСЃС‚РІРѕ СЃРїСѓС‚РЅРёРєРѕРІ
7. **GNSS Constellations** - Pie chart СЃРѕР·РІРµР·РґРёР№
8. **GNSS Accuracy** - РўРѕС‡РЅРѕСЃС‚СЊ РїРѕР·РёС†РёРѕРЅРёСЂРѕРІР°РЅРёСЏ
9. **Oscillator Status** - РЎС‚Р°С‚СѓСЃ Р±Р»РѕРєРёСЂРѕРІРєРё
10. **Frequency Error** - РћС€РёР±РєР° С‡Р°СЃС‚РѕС‚С‹ РѕСЃС†РёР»Р»СЏС‚РѕСЂР°
11. **Allan Deviation** - РЎС‚Р°Р±РёР»СЊРЅРѕСЃС‚СЊ РѕСЃС†РёР»Р»СЏС‚РѕСЂР°
12. **Power Consumption** - РџРѕС‚СЂРµР±Р»РµРЅРёРµ РјРѕС‰РЅРѕСЃС‚Рё
13. **Current Consumption** - РџРѕС‚СЂРµР±Р»РµРЅРёРµ С‚РѕРєР°
14. **Hardware Status** - LED, FPGA, network ports
15. **Network Ports** - РЎС‚Р°С‚СѓСЃ СЃРµС‚РµРІС‹С… РїРѕСЂС‚РѕРІ
16. **Active Alerts** - РўР°Р±Р»РёС†Р° Р°РєС‚РёРІРЅС‹С… Р°Р»РµСЂС‚РѕРІ
17. **PTP Packet Statistics** - РЎС‚Р°С‚РёСЃС‚РёРєР° PTP РїР°РєРµС‚РѕРІ
18. **System Health Trends** - РўСЂРµРЅРґС‹ Р·РґРѕСЂРѕРІСЊСЏ СЃРёСЃС‚РµРјС‹

### РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРёРµ С„СѓРЅРєС†РёРё:
- **Device Selector** - Р’С‹Р±РѕСЂ СѓСЃС‚СЂРѕР№СЃС‚РІР°
- **Auto-refresh** РєР°Р¶РґС‹Рµ 30 СЃРµРєСѓРЅРґ
- **Threshold coloring** - Р¦РІРµС‚РѕРІР°СЏ РёРЅРґРёРєР°С†РёСЏ
- **Alert annotations** - РђРЅРЅРѕС‚Р°С†РёРё Р°Р»РµСЂС‚РѕРІ
- **Drill-down links** - РЎСЃС‹Р»РєРё РЅР° РґРµС‚Р°Р»Рё

## рџ”§ РљРѕРЅС„РёРіСѓСЂР°С†РёСЏ

### Prometheus (config/prometheus.yml)
- РРЅС‚РµСЂРІР°Р» СЃР±РѕСЂР°: 30 СЃРµРєСѓРЅРґ
- Retention: 30 РґРЅРµР№
- Recording rules РґР»СЏ Р°РіСЂРµРіР°С†РёРё
- Alert rules РґР»СЏ РІСЃРµС… РєРѕРјРїРѕРЅРµРЅС‚РѕРІ

### AlertManager (config/alertmanager.yml)
- Email СѓРІРµРґРѕРјР»РµРЅРёСЏ РїРѕ РєРѕРјР°РЅРґР°Рј
- Slack РёРЅС‚РµРіСЂР°С†РёСЏ
- Р“СЂСѓРїРїРёСЂРѕРІРєР° РїРѕ severity
- РџРѕРґР°РІР»РµРЅРёРµ РґСѓР±Р»РёСЂРѕРІР°РЅРЅС‹С… Р°Р»РµСЂС‚РѕРІ

### Grafana
- РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРёР№ import dashboards
- Datasource provisioning
- Persistent storage

## рџ“Љ РњРµС‚СЂРёРєРё Prometheus

### PTP РњРµС‚СЂРёРєРё
```promql
# PTP offset
timecard_ptp_offset_nanoseconds{device_id="timecard0"}

# Path delay
timecard_ptp_path_delay_nanoseconds{device_id="timecard0"}

# Packet loss
timecard_ptp_packet_loss_percent{device_id="timecard0"}

# Performance score
timecard_ptp_performance_score{device_id="timecard0"}
```

### РўРµРїР»РѕРІС‹Рµ РјРµС‚СЂРёРєРё
```promql
# РўРµРјРїРµСЂР°С‚СѓСЂС‹
timecard_temperature_celsius{device_id="timecard0",sensor="fpga_temp"}
timecard_temperature_celsius{device_id="timecard0",sensor="osc_temp"}

# РЎРєРѕСЂРѕСЃС‚СЊ РІРµРЅС‚РёР»СЏС‚РѕСЂР°
timecard_fan_speed_rpm{device_id="timecard0"}

# Thermal throttling
timecard_thermal_throttling{device_id="timecard0"}
```

### GNSS РјРµС‚СЂРёРєРё
```promql
# РЎРїСѓС‚РЅРёРєРё
timecard_gnss_satellites{device_id="timecard0",constellation="gps",type="used"}

# РўРѕС‡РЅРѕСЃС‚СЊ
timecard_gnss_accuracy{device_id="timecard0",type="time",unit="nanoseconds"}

# РЎС‚Р°С‚СѓСЃ Р°РЅС‚РµРЅРЅС‹
timecard_gnss_antenna_status{device_id="timecard0"}
```

### РњРµС‚СЂРёРєРё РїРёС‚Р°РЅРёСЏ
```promql
# РќР°РїСЂСЏР¶РµРЅРёСЏ
timecard_voltage_volts{device_id="timecard0",rail="3v3"}

# РћС‚РєР»РѕРЅРµРЅРёСЏ РЅР°РїСЂСЏР¶РµРЅРёСЏ
timecard_voltage_deviation_percent{device_id="timecard0",rail="3v3"}

# РџРѕС‚СЂРµР±Р»РµРЅРёРµ РјРѕС‰РЅРѕСЃС‚Рё
timecard_power_consumption_watts{device_id="timecard0",type="total"}
```

## рџђ› Troubleshooting

### 1. РЎРµСЂРІРёСЃС‹ РЅРµ Р·Р°РїСѓСЃРєР°СЋС‚СЃСЏ
```bash
# РџСЂРѕРІРµСЂРєР° РїРѕСЂС‚РѕРІ
sudo lsof -i :8080,9090,9091,3000,9093

# РџСЂРѕРІРµСЂРєР° Docker
docker-compose ps
docker-compose logs

# РџСЂРѕРІРµСЂРєР° Р·Р°РІРёСЃРёРјРѕСЃС‚РµР№
./start-monitoring-stack.sh help
```

### 2. РќРµС‚ РјРµС‚СЂРёРє РІ Grafana
```bash
# РџСЂРѕРІРµСЂРєР° Prometheus targets
curl http://localhost:9091/api/v1/targets

# РџСЂРѕРІРµСЂРєР° exporter
curl http://localhost:9090/metrics

# РџСЂРѕРІРµСЂРєР° API
curl http://localhost:8080/api/health
```

### 3. РќРµ РїСЂРёС…РѕРґСЏС‚ Р°Р»РµСЂС‚С‹
```bash
# РџСЂРѕРІРµСЂРєР° AlertManager
curl http://localhost:9093/api/v1/alerts

# РџСЂРѕРІРµСЂРєР° rules
curl http://localhost:9091/api/v1/rules

# РџСЂРѕРІРµСЂРєР° РєРѕРЅС„РёРіСѓСЂР°С†РёРё
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### 4. РџСЂРѕР±Р»РµРјС‹ СЃ РїСЂРѕРёР·РІРѕРґРёС‚РµР»СЊРЅРѕСЃС‚СЊСЋ
```bash
# РњРѕРЅРёС‚РѕСЂРёРЅРі СЂРµСЃСѓСЂСЃРѕРІ
docker stats

# РџСЂРѕРІРµСЂРєР° РјРµС‚СЂРёРє СЃРёСЃС‚РµРјС‹
curl http://localhost:9100/metrics

# Р›РѕРіРё СЃРµСЂРІРёСЃРѕРІ
./start-monitoring-stack.sh logs docker
```

## рџ“ќ Р›РѕРіРёСЂРѕРІР°РЅРёРµ

### РЈСЂРѕРІРЅРё Р»РѕРіРёСЂРѕРІР°РЅРёСЏ:
- **DEBUG** - Р”РµС‚Р°Р»СЊРЅР°СЏ РѕС‚Р»Р°РґРѕС‡РЅР°СЏ РёРЅС„РѕСЂРјР°С†РёСЏ
- **INFO** - РћР±С‰Р°СЏ РёРЅС„РѕСЂРјР°С†РёСЏ Рѕ СЂР°Р±РѕС‚Рµ
- **WARNING** - РџСЂРµРґСѓРїСЂРµР¶РґРµРЅРёСЏ
- **ERROR** - РћС€РёР±РєРё

### РџСЂРѕСЃРјРѕС‚СЂ Р»РѕРіРѕРІ:
```bash
# Р’СЃРµ СЃРµСЂРІРёСЃС‹
./start-monitoring-stack.sh logs docker

# РљРѕРЅРєСЂРµС‚РЅС‹Р№ СЃРµСЂРІРёСЃ
docker-compose logs -f timecard-api
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## рџ”ђ Р‘РµР·РѕРїР°СЃРЅРѕСЃС‚СЊ

### Р РµРєРѕРјРµРЅРґР°С†РёРё:
1. **Grafana**: РЎРјРµРЅРёС‚Рµ РїР°СЂРѕР»СЊ РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ
2. **Prometheus**: РќР°СЃС‚СЂРѕР№С‚Рµ authentication
3. **AlertManager**: РќР°СЃС‚СЂРѕР№С‚Рµ SMTP credentials
4. **Network**: РСЃРїРѕР»СЊР·СѓР№С‚Рµ internal networks
5. **SSL/TLS**: РќР°СЃС‚СЂРѕР№С‚Рµ HTTPS РґР»СЏ production

### Р‘СЌРєР°РїС‹:
```bash
# Prometheus data
docker-compose exec prometheus tar -czf /prometheus-backup.tar.gz /prometheus

# Grafana data
docker-compose exec grafana tar -czf /grafana-backup.tar.gz /var/lib/grafana
```

## рџ“љ Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅС‹Рµ СЂРµСЃСѓСЂСЃС‹

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Quantum-PCI TimeCard PTP OCP Specification](https://www.opencompute.org/documents/ocp-timecard-specification-1-0-pdf)

