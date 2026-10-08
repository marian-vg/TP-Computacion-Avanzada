#!/usr/bin/env bash
# modulos/ram.sh - Monitoreo de Memoria RAM

obtener_uso_ram() {
    # Utiliza free en megabytes (MB)
    local total_ram
    local used_ram
    total_ram=$(free -m | awk '/Mem:/ {print $2}')
    used_ram=$(free -m | awk '/Mem:/ {print $3}')
    
    local ram_pct=$(( (used_ram * 100) / total_ram ))
    echo "${ram_pct}% (${used_ram} MB / ${total_ram} MB)"
}