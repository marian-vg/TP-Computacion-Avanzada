#!/usr/bin/env bash
# monitor.sh - Script principal de monitoreo del servidor Debian GNU/Linux

# Obtener ruta absoluta del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar configuración base
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

# Función de ayuda
mostrar_ayuda() {
    cat <<EOF
Uso: $(basename "$0") [OPCIONES]

Script modular de monitoreo de recursos del sistema para Debian GNU/Linux.
Compatible con ejecución individual (cron) o continua (watch -n 2 ./monitor.sh).

Opciones de umbrales:
  --cpu <porcentaje>         Umbral de alerta para CPU (defecto: ${CPU_THRESHOLD}%)
  --ram <porcentaje>         Umbral de alerta para RAM (defecto: ${RAM_THRESHOLD}%)
  --disk <porcentaje>        Umbral de alerta para Disco raíz (defecto: ${DISK_THRESHOLD}%)
  --max-log-size <megabytes> Tamaño máximo del log antes de rotar y comprimir con tar+gzip (defecto: ${LOG_MAX_SIZE_MB} MB)
  -h, --help                 Muestra esta ayuda y finaliza

Ejemplos:
  $0
  $0 --cpu 70 --ram 80 --disk 90
  $0 --max-log-size 20
  watch -n 2 "$0 --cpu 75"
EOF
}

# Parseo de banderas de línea de comandos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu)
            CPU_THRESHOLD="$2"
            shift 2
            ;;
        --ram)
            RAM_THRESHOLD="$2"
            shift 2
            ;;
        --disk)
            DISK_THRESHOLD="$2"
            shift 2
            ;;
        --max-log-size|--log-size)
            LOG_MAX_SIZE_MB="$2"
            shift 2
            ;;
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        *)
            echo "Opción no reconocida: $1"
            mostrar_ayuda
            exit 1
            ;;
    esac
done

# Cargar módulos del sistema
# shellcheck source=modulos/cpu.sh
source "${SCRIPT_DIR}/modulos/cpu.sh"
# shellcheck source=modulos/ram.sh
source "${SCRIPT_DIR}/modulos/ram.sh"
# shellcheck source=modulos/disco.sh
source "${SCRIPT_DIR}/modulos/disco.sh"
# shellcheck source=modulos/red.sh
source "${SCRIPT_DIR}/modulos/red.sh"
# shellcheck source=modulos/alertas.sh
source "${SCRIPT_DIR}/modulos/alertas.sh"

# Asegurar existencia del directorio de logs
mkdir -p "$LOG_DIR"

generar_reporte() {
    # 1. Mantenimiento y control de tamaño de logs (Clase 4 y 5)
    local msg_rotacion
    msg_rotacion=$(gestionar_limpieza_logs)
    [ -n "$msg_rotacion" ] && echo "$msg_rotacion"

    # 2. Recolección de métricas numéricas y textos descriptivos
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    local cpu_pct uso_cpu
    cpu_pct=$(obtener_cpu_pct)
    uso_cpu=$(obtener_uso_cpu)

    local ram_pct uso_ram
    ram_pct=$(obtener_ram_pct)
    uso_ram=$(obtener_uso_ram)

    local disk_pct uso_disco
    disk_pct=$(obtener_disco_pct "/")
    uso_disco=$(obtener_uso_disco "/")

    local estado_red
    estado_red=$(obtener_estado_red)

    # 3. Presentación formateada para consola (ideal para watch)
    echo "======================================================================"
    echo "       PANEL DE MONITOREO DE SERVIDOR DEBIAN - FCyT UADER"
    echo "======================================================================"
    echo " Timestamp : ${timestamp}"
    echo " CPU       : ${uso_cpu} (Umbral: ${CPU_THRESHOLD}%)"
    echo " RAM       : ${uso_ram} (Umbral: ${RAM_THRESHOLD}%)"
    echo " DISCO (/) : ${uso_disco} (Umbral: ${DISK_THRESHOLD}%)"
    echo " RED       : ${estado_red}"
    echo "======================================================================"

    # 4. Registro en archivo de log (formato estructurado por línea)
    local linea_log="[${timestamp}] | CPU: ${uso_cpu} | RAM: ${uso_ram} | DISCO: ${uso_disco} | RED: ${estado_red}"
    echo "$linea_log" >> "$LOG_FILE"

    # 5. Evaluación de umbrales y despacho de alertas externas
    procesar_alertas "$cpu_pct" "$ram_pct" "$disk_pct" "$linea_log"
}

# Ejecución principal
generar_reporte