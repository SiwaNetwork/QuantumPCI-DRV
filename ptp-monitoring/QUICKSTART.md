# рџљЂ Quantum-PCI TimeCard PTP OCP Advanced Monitoring - Quick Start

Р‘С‹СЃС‚СЂРѕРµ СЂСѓРєРѕРІРѕРґСЃС‚РІРѕ РїРѕ Р·Р°РїСѓСЃРєСѓ РїРѕР»РЅРѕС„СѓРЅРєС†РёРѕРЅР°Р»СЊРЅРѕР№ СЃРёСЃС‚РµРјС‹ РјРѕРЅРёС‚РѕСЂРёРЅРіР° Quantum-PCI TimeCard PTP OCP v2.0.

> рџ“Њ **РџСЂРёРјРµС‡Р°РЅРёРµ**: Р”Р»СЏ РїРѕР»РЅРѕР№ РёРЅСЃС‚СЂСѓРєС†РёРё РїРѕ СѓСЃС‚Р°РЅРѕРІРєРµ РґСЂР°Р№РІРµСЂР° Рё Р±Р°Р·РѕРІРѕР№ РЅР°СЃС‚СЂРѕР№РєРµ СЃРј. [TIMECARD_РРќРЎРўР РЈРљР¦РРЇ_РћРџРўРРњРР—РР РћР’РђРќРќРђРЇ.md](../docs/architecture.md)

## вљЎ Р‘С‹СЃС‚СЂС‹Р№ Р·Р°РїСѓСЃРє РјРѕРЅРёС‚РѕСЂРёРЅРіР°

```bash
# РџСЂРµРґРїРѕР»Р°РіР°РµС‚СЃСЏ, С‡С‚Рѕ РґСЂР°Р№РІРµСЂ СѓР¶Рµ СѓСЃС‚Р°РЅРѕРІР»РµРЅ
cd ptp-monitoring
pip install -r requirements.txt
python3 demo-extended.py
```

## рџЋЇ Р§С‚Рѕ РІРєР»СЋС‡Р°РµС‚ СЂР°СЃС€РёСЂРµРЅРЅС‹Р№ РјРѕРЅРёС‚РѕСЂРёРЅРі

### вњЁ Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅС‹Рµ РІРѕР·РјРѕР¶РЅРѕСЃС‚Рё v2.0
- **рџЊЎпёЏ Thermal monitoring**: 6 С‚РµРјРїРµСЂР°С‚СѓСЂРЅС‹С… СЃРµРЅСЃРѕСЂРѕРІ (FPGA, oscillator, board, ambient, PLL, DDR)
- **вљЎ Power analysis**: 4 voltage rails + current consumption РїРѕ РєРѕРјРїРѕРЅРµРЅС‚Р°Рј
- **рџ›°пёЏ GNSS tracking**: GPS, GLONASS, Galileo, BeiDou СЃРѕР·РІРµР·РґРёСЏ
- **вљЎ Oscillator disciplining**: Allan deviation Р°РЅР°Р»РёР· + PI controller
- **рџ“Ў Advanced PTP**: Path delay analysis, packet statistics, master tracking
- **рџ”§ Hardware status**: LEDs, SMA connectors, FPGA info, network PHY
- **рџљЁ Smart alerting**: Configurable thresholds + real-time notifications
- **рџ“Љ Health scoring**: Comprehensive system assessment
- **рџ“€ Historical data**: Trending analysis + WebSocket live updates

## рџ”§ РЎРїРµС†РёС„РёС‡РЅР°СЏ РєРѕРЅС„РёРіСѓСЂР°С†РёСЏ РјРѕРЅРёС‚РѕСЂРёРЅРіР°

### РќР°СЃС‚СЂРѕР№РєР° threshold Р°Р»РµСЂС‚РѕРІ
РћС‚СЂРµРґР°РєС‚РёСЂСѓР№С‚Рµ С„Р°Р№Р» `api/timecard-extended-api.py`:

```python
alert_thresholds = {
    'thermal': {
        'fpga_temp': {'warning': 70, 'critical': 85},
        'osc_temp': {'warning': 60, 'critical': 75},
        # Р’Р°С€Рё РїРѕСЂРѕРіРё...
    },
    'ptp': {
        'offset_ns': {'warning': 1000, 'critical': 10000},
        # Р’Р°С€Рё РїРѕСЂРѕРіРё...
    }
}
```

### РРЅС‚РµСЂРІР°Р»С‹ РѕР±РЅРѕРІР»РµРЅРёСЏ
```python
# Р’ TimeCardDashboard РєР»Р°СЃСЃ (timecard-dashboard.html)
updateInterval = 5000;      # РџРѕР»РЅРѕРµ РѕР±РЅРѕРІР»РµРЅРёРµ (5 СЃРµРє)
quickUpdateInterval = 2000; # WebSocket updates (2 СЃРµРє)
backgroundInterval = 60000; # РСЃС‚РѕСЂРёСЏ РјРµС‚СЂРёРє (1 РјРёРЅ)
```

## рџЋ“ Р Р°СЃС€РёСЂРµРЅРЅС‹Рµ API endpoints

### Export Р»РѕРіРѕРІ
```bash
curl http://localhost:8080/api/logs/export > timecard-logs.txt
```

### Restart СЃРµСЂРІРёСЃРѕРІ
```bash
curl -X POST http://localhost:8080/api/restart/ptp4l
curl -X POST http://localhost:8080/api/restart/chronyd
```

### РџРѕР»СѓС‡РµРЅРёРµ РёСЃС‚РѕСЂРёРё РјРµС‚СЂРёРє
```bash
curl http://localhost:8080/api/metrics/history/timecard0
```

### WebSocket РїРѕРґРєР»СЋС‡РµРЅРёРµ (JavaScript)
```javascript
const socket = io();
socket.on('metrics_update', (data) => {
    console.log('New metrics:', data);
});
```

## рџЊџ РћС‚Р»РёС‡РёСЏ РѕС‚ Р±Р°Р·РѕРІРѕР№ РІРµСЂСЃРёРё

| Feature | Basic v1.0 | Extended v2.0 |
|---------|------------|---------------|
| PTP Metrics | вњ… Basic | вњ… Advanced |
| Thermal Monitoring | вќЊ | вњ… 6 sensors |
| Power Monitoring | вќЊ | вњ… 4 rails |
| GNSS Tracking | вќЊ | вњ… 4 constellations |
| Oscillator Analysis | вќЊ | вњ… Allan deviation |
| Hardware Status | вќЊ | вњ… Complete |
| Alerting System | вќЊ | вњ… Intelligent |
| Health Scoring | вќЊ | вњ… Comprehensive |
| Historical Data | вќЊ | вњ… Full tracking |
| WebSocket Updates | вњ… Basic | вњ… Advanced |

## рџ“€ Performance РјРѕРЅРёС‚РѕСЂРёРЅРі

### РЎРёСЃС‚РµРјРЅС‹Рµ С‚СЂРµР±РѕРІР°РЅРёСЏ
- **CPU**: ~1-2% РЅР° СЃРѕРІСЂРµРјРµРЅРЅС‹С… СЃРёСЃС‚РµРјР°С…
- **Memory**: ~50-100 MB
- **Network**: РњРёРЅРёРјР°Р»СЊРЅС‹Р№ С‚СЂР°С„РёРє
- **Storage**: ~1 MB/РґРµРЅСЊ Р»РѕРіРѕРІ

### РћРїС‚РёРјРёР·Р°С†РёСЏ РґР»СЏ production
```python
# РЈРјРµРЅСЊС€РёС‚СЊ РёРЅС‚РµСЂРІР°Р»С‹ РґР»СЏ production
updateInterval = 10000;     # 10 СЃРµРєСѓРЅРґ РІРјРµСЃС‚Рѕ 5
backgroundInterval = 300000; # 5 РјРёРЅСѓС‚ РІРјРµСЃС‚Рѕ 1

# РћС‚РєР»СЋС‡РёС‚СЊ РѕС‚Р»Р°РґРѕС‡РЅС‹Рµ СЃРѕРѕР±С‰РµРЅРёСЏ
socketio.run(app, debug=False, ...)
```

---
**Quantum-PCI TimeCard PTP OCP Advanced Monitoring System v2.0**  
*Professional-grade monitoring for precision timing applications*
