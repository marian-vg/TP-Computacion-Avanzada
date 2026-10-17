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
        # Asegurar límites válidos (0 a 100)
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