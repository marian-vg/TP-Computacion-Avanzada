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

# Devuelve vista ampliada detallada de memoria (Clase 3: free detallado, ps aux)
obtener_detalle_ram() {
    echo "--- DETALLE EXTENDIDO DE MEMORIA RAM Y SWAP ---"
    
    # 1. Desglose de memoria física y swap con free -h (Clase 3, diapositiva 16)
    if command -v free >/dev/null 2>&1; then
        echo "Estado general de memoria (legible para humanos):"
        LC_ALL=C free -h 2>/dev/null | sed 's/^/  /'
    fi

    # 2. Top 5 procesos consumidores de memoria RAM (ps aux --sort=-%mem)
    echo -e "\nTop 5 procesos con mayor consumo de RAM:"
    local listado=""
    if command -v ps >/dev/null 2>&1; then
        listado=$(LC_ALL=C ps -eo pid,user,%cpu,%mem,comm --sort=-%mem 2>/dev/null | head -n 6)
        if [ -n "$listado" ]; then
            echo "$listado" | awk 'NR==1 {printf "  %-7s %-12s %-8s %-8s %s\n", $1, $2, $3, $4, $5} NR>1 {printf "  %-7s %-12s %-8s %-8s %s\n", $1, $2, $3, $4, $5}'
        else
            ps 2>/dev/null | head -n 6 | sed 's/^/  /'
        fi
    else
        echo "  ps no disponible en este entorno."
    fi
}