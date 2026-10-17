#!/usr/bin/env bash
# modulos/disco.sh - Monitoreo de Memoria Secundaria (Disco) y Limpieza de Archivos

# Devuelve el porcentaje numérico entero de uso de la partición principal (0-100)
# Comando df de Clase 4 (diapositiva 21)
obtener_disco_pct() {
    local punto_montaje="${1:-/}"
    local disco_pct=0

    if command -v df >/dev/null 2>&1; then
        # Se indexa relativo a NF (penúltima columna) para soportar nombres de dispositivos con espacios
        disco_pct=$(LC_ALL=C df -k "$punto_montaje" 2>/dev/null | awk 'NR>1 {pct=$(NF-1); gsub("%","",pct); print pct}' | head -n 1)
    fi

    echo "${disco_pct:-0}"
}

# Devuelve el texto formateado con espacio usado, total y libre
obtener_uso_disco() {
    local punto_montaje="${1:-/}"
    local salida=""

    if command -v df >/dev/null 2>&1; then
        salida=$(LC_ALL=C df -h "$punto_montaje" 2>/dev/null | awk 'NR>1 {print $(NF-1) " (" $(NF-3) " usado / " $(NF-4) " total | Libre: " $(NF-2) ")"}' | head -n 1)
    fi

    if [ -n "$salida" ]; then
        echo "$salida"
    else
        echo "0% (0G / 0G | Libre: 0G)"
    fi
}

# Gestión de limpieza y rotación de logs (Consumo y limpieza - Clase 5: tar y gzip)
gestionar_limpieza_logs() {
    local archivo_log="${LOG_FILE:-logs/monitor.log}"
    local max_mb="${LOG_MAX_SIZE_MB:-50}"
    local dir_logs
    dir_logs=$(dirname "$archivo_log")

    [ ! -f "$archivo_log" ] && return 0

    # Obtener tamaño actual del archivo en MB con 'du' (Clase 4, diapositiva 22)
    local tamano_mb=0
    if command -v du >/dev/null 2>&1; then
        tamano_mb=$(LC_ALL=C du -m "$archivo_log" 2>/dev/null | awk '{print $1}')
    fi

    # Disparador 1: Si el archivo de log supera el umbral configurado (ej. 50 MB)
    if [ -n "$tamano_mb" ] && [ "$tamano_mb" -ge "$max_mb" ] 2>/dev/null; then
        local timestamp
        timestamp=$(date "+%Y%m%d_%H%M%S")
        local archivo_tar="${dir_logs}/backup_monitor_${timestamp}.tar.gz"

        # Empaquetado y compresión con tar + gzip (Clase 5, diapositivas 3 y 4)
        tar -czf "$archivo_tar" -C "$dir_logs" "$(basename "$archivo_log")" 2>/dev/null
        
        # Vaciar el log activo preservando permisos
        : > "$archivo_log"

        echo "[MANTENIMIENTO] Log rotado y comprimido: ${archivo_tar} (${tamano_mb} MB alcanzados)"
    fi

    # Disparador 2 (Emergencia de Disco): Si el disco supera el umbral global
    local pct_actual
    pct_actual=$(obtener_disco_pct "/")
    if [ "$pct_actual" -ge "${DISK_THRESHOLD:-85}" ] 2>/dev/null; then
        # Limpieza de respaldos comprimidos de más de 7 días para liberar espacio
        find "$dir_logs" -name "backup_monitor_*.tar.gz" -mtime +7 -delete 2>/dev/null
    fi
}
