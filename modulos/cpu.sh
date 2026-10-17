#!/usr/bin/env bash
# modulos/cpu.sh - Monitoreo de Microprocesador

# Devuelve el porcentaje numérico entero de uso de CPU (0-100)
obtener_cpu_pct() {
    local cpu_idle=""
    local cpu_used=0

    # Estrategia primaria: vmstat con 2 muestras de 1 segundo (Clase 3, diapositivas 13-15)
    # La columna 15 corresponde al tiempo inactivo ('id') en la salida estándar de vmstat
    if command -v vmstat >/dev/null 2>&1; then
        cpu_idle=$(LC_ALL=C vmstat 1 2 2>/dev/null | tail -n 1 | awk '{print $15}')
    fi

    # Fallback secundario si vmstat falla o no está disponible: top en modo batch
    if [ -z "$cpu_idle" ] && command -v top >/dev/null 2>&1; then
        cpu_idle=$(LC_ALL=C top -bn1 2>/dev/null | grep -i "Cpu(s)" | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /id/) print $i}' | tr -dc '0-9.' | cut -d'.' -f1)
    fi

    # Si se obtuvo idle, calcular uso; de lo contrario reportar 0
    if [ -n "$cpu_idle" ]; then
        cpu_used=$(( 100 - cpu_idle ))
        [ "$cpu_used" -lt 0 ] && cpu_used=0
        [ "$cpu_used" -gt 100 ] && cpu_used=100
    fi

    echo "$cpu_used"
}

# Devuelve el texto formateado para reportes y visualización
obtener_uso_cpu() {
    local pct
    pct=$(obtener_cpu_pct)
    echo "${pct}%"
}

# Devuelve vista ampliada detallada del procesador (Clase 3: uptime, ps aux)
obtener_detalle_cpu() {
    echo "--- DETALLE EXTENDIDO DE MICROPROCESADOR (CPU) ---"
    
    # 1. Carga promedio del sistema (uptime - Clase 3, diapositivas 6-7)
    if command -v uptime >/dev/null 2>&1; then
        echo "Carga promedio (1, 5, 15 min): $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    fi

    # 2. Top 5 procesos consumidores de CPU (ps aux --sort=-%cpu - Clase 3, diapositivas 9-12)
    echo -e "\nTop 5 procesos con mayor consumo de CPU:"
    local listado=""
    if command -v ps >/dev/null 2>&1; then
        listado=$(LC_ALL=C ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -n 6)
        if [ -n "$listado" ]; then
            echo "$listado" | awk 'NR==1 {printf "  %-7s %-12s %-8s %-8s %s\n", $1, $2, $3, $4, $5} NR>1 {printf "  %-7s %-12s %-8s %-8s %s\n", $1, $2, $3, $4, $5}'
        else
            ps 2>/dev/null | head -n 6 | sed 's/^/  /'
        fi
    else
        echo "  ps no disponible en este entorno."
    fi
}