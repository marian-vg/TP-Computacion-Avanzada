#!/usr/bin/env bash
# monitor.sh - Script principal de monitoreo del servidor Debian

# Obtener ruta absoluta del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar configuración
source "${SCRIPT_DIR}/config.sh"

# Cargar módulos
source "${SCRIPT_DIR}/modulos/cpu.sh"
source "${SCRIPT_DIR}/modulos/ram.sh"
source "${SCRIPT_DIR}/modulos/red.sh"

# Asegurar existencia del directorio de logs
mkdir -p "$LOG_DIR"

generar_reporte() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    local uso_cpu
    uso_cpu=$(obtener_uso_cpu)

    local uso_ram
    uso_ram=$(obtener_uso_ram)

    local estado_red
    estado_red=$(obtener_estado_red)

    local salida="[${timestamp}] | CPU: ${uso_cpu} | RAM: ${uso_ram} | RED: ${estado_red}"

    # Imprimir en consola estándar
    echo "$salida"

    # Registrar en el archivo de log
    echo "$salida" >> "$LOG_FILE"
}

# Ejecución principal
generar_reporte