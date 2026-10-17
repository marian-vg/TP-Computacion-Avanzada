#!/usr/bin/env bash
# modulos/ram.sh - Monitoreo de Memoria RAM

# Devuelve el porcentaje numérico entero de uso de RAM (0-100)
obtener_ram_pct() {
    local total_ram=0
    local used_ram=0
    local ram_pct=0

    # free en megabytes (MB) forzando locale neutro (Clase 3, diapositiva 16)
    if command -v free >/dev/null 2>&1; then
        total_ram=$(LC_ALL=C free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
        used_ram=$(LC_ALL=C free -m 2>/dev/null | awk '/^Mem:/ {print $3}')
    fi

    if [ -n "$total_ram" ] && [ "$total_ram" -gt 0 ] 2>/dev/null; then
        ram_pct=$(( (used_ram * 100) / total_ram ))
    fi

    echo "$ram_pct"
}

# Devuelve el texto formateado con detalle en MB para reportes y logs
obtener_uso_ram() {
    local total_ram
    local used_ram
    local ram_pct

    total_ram=$(LC_ALL=C free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
    used_ram=$(LC_ALL=C free -m 2>/dev/null | awk '/^Mem:/ {print $3}')

    if [ -n "$total_ram" ] && [ "$total_ram" -gt 0 ] 2>/dev/null; then
        ram_pct=$(( (used_ram * 100) / total_ram ))
        echo "${ram_pct}% (${used_ram} MB / ${total_ram} MB)"
    else
        echo "0% (0 MB / 0 MB)"
    fi
}