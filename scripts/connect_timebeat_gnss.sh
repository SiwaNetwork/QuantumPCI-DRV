#!/bin/bash
# Подключение к GNSS модулю Timebeat на разных портах

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║         📡 ПОИСК GNSS МОДУЛЯ TIMEBEAT                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Типичные скорости для GNSS модулей
BAUDRATES=(9600 4800 19200 38400 115200)
PORTS=(/dev/ttyS4 /dev/ttyS5 /dev/ttyS6 /dev/ttyS7 /dev/ttyS9)

for PORT in "${PORTS[@]}"; do
    if [ ! -e "$PORT" ]; then
        echo "⚠️  $PORT не существует, пропускаем"
        continue
    fi
    
    echo "🔍 Тестируем порт: $PORT"
    echo "────────────────────────────────────────────────────────────────────────────"
    
    for BAUD in "${BAUDRATES[@]}"; do
        echo -n "   Пробуем $BAUD бод... "
        
        # Попытка прямого чтения без stty
        RESULT=$(timeout 2 sudo dd if=$PORT bs=1 count=100 2>/dev/null | strings | grep -E '^\$G[NPL]' 2>/dev/null)
        
        if [ ! -z "$RESULT" ]; then
            echo "✅ НАЙДЕНЫ NMEA ДАННЫЕ!"
            echo ""
            echo "╔══════════════════════════════════════════════════════════════════════════╗"
            echo "║  ✅ GNSS МОДУЛЬ ОБНАРУЖЕН НА $PORT @ $BAUD БОД                      ║"
            echo "╚══════════════════════════════════════════════════════════════════════════╝"
            echo ""
            echo "Данные:"
            echo "$RESULT"
            echo ""
            echo "Для подключения используйте:"
            echo "  sudo minicom -D $PORT -b $BAUD"
            echo ""
            echo "Или для непрерывного мониторинга:"
            echo "  sudo cat $PORT"
            echo ""
            exit 0
        else
            echo "нет данных"
        fi
    done
    echo ""
done

echo "❌ GNSS модуль не обнаружен на стандартных портах"
echo ""
echo "Рекомендации:"
echo "  1. Проверьте физическое подключение TX/RX"
echo "  2. Убедитесь что модуль получает питание"
echo "  3. Попробуйте другой порт"
echo "  4. Проверьте что антенна подключена"


