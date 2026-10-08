#!/usr/bin/env bash
# modulos/red.sh - Monitoreo de Red

obtener_estado_red() {
    # Busca la interfaz activa principal (excluyendo 'lo' - loopback)
    local iface
    iface=$(ip route | grep '^default' | awk '{print $5}' | head -n 1)

    if [ -z "$iface" ]; then
        echo "Sin conexión de red activa"
        return
    fi

    local ip_addr
    ip_addr=$(ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    # Bytes recibidos y transmitidos desde /proc/net/dev
    local rx_bytes
    local tx_bytes
    rx_bytes=$(awk -v iface="$iface:" '$1 == iface { printf "%.2f MB", $2/1024/1024 }' /proc/net/dev)
    tx_bytes=$(awk -v iface="$iface:" '$1 == iface { printf "%.2f MB", $10/1024/1024 }' /proc/net/dev)

    echo "Interfaz: ${iface} | IP: ${ip_addr} | RX: ${rx_bytes} | TX: ${tx_bytes}"
}