#!/usr/bin/env bash
# modulos/red.sh - Monitoreo de Conectividad y Tráfico de Red

obtener_estado_red() {
    # Busca la interfaz activa principal con ruta por defecto
    local iface=""
    if command -v ip >/dev/null 2>&1; then
        iface=$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -n 1)
    fi

    if [ -z "$iface" ]; then
        echo "Sin conexión de red activa"
        return
    fi

    local ip_addr=""
    ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    [ -z "$ip_addr" ] && ip_addr="N/A"

    # Lectura de bytes acumulados desde /proc/net/dev
    local rx_bytes=0
    local tx_bytes=0
    if [ -f "/proc/net/dev" ]; then
        rx_bytes=$(awk -v iface="$iface:" '$1 == iface {print $2}' /proc/net/dev)
        tx_bytes=$(awk -v iface="$iface:" '$1 == iface {print $10}' /proc/net/dev)
    fi

    # Cálculo de tasa de transferencia instantánea (KB/s) usando archivo de estado temporal
    local cache_file="/tmp/monitor_net_${iface}.tmp"
    local rx_speed="0.00 KB/s"
    local tx_speed="0.00 KB/s"
    local now
    now=$(date +%s)

    if [ -f "$cache_file" ]; then
        local prev_time prev_rx prev_tx
        read -r prev_time prev_rx prev_tx < "$cache_file"
        local delta_t=$(( now - prev_time ))

        # Si el intervalo es válido (ej. entre 1 y 60 segundos), calculamos velocidad
        if [ "$delta_t" -gt 0 ] && [ "$delta_t" -le 60 ] && [ "$rx_bytes" -ge "$prev_rx" ] 2>/dev/null; then
            local delta_rx=$(( rx_bytes - prev_rx ))
            local delta_tx=$(( tx_bytes - prev_tx ))
            rx_speed=$(awk -v b="$delta_rx" -v t="$delta_t" 'BEGIN { printf "%.2f KB/s", (b / t) / 1024 }')
            tx_speed=$(awk -v b="$delta_tx" -v t="$delta_t" 'BEGIN { printf "%.2f KB/s", (b / t) / 1024 }')
        fi
    fi

    # Actualizar cache para la siguiente iteración de watch o cron
    echo "$now $rx_bytes $tx_bytes" > "$cache_file" 2>/dev/null

    # Totales acumulados en MB
    local total_rx total_tx
    total_rx=$(awk -v b="$rx_bytes" 'BEGIN { printf "%.2f MB", b/1024/1024 }')
    total_tx=$(awk -v b="$tx_bytes" 'BEGIN { printf "%.2f MB", b/1024/1024 }')

    echo "Interfaz: ${iface} (${ip_addr}) | Velocidad: ↓ ${rx_speed} ↑ ${tx_speed} | Total: RX ${total_rx} TX ${total_tx}"
}