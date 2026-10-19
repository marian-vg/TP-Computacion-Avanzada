#!/usr/bin/env bash
# monitor.sh - Script principal de monitoreo del servidor Debian GNU/Linux
# Cátedra: Computación Avanzada - FCyT UADER

# Obtener ruta absoluta del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar configuración base
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

# Variables de control
MODO_SOLO=""
MODO_INTERACTIVO=0

# Función de ayuda
mostrar_ayuda() {
    cat <<EOF
Uso: $(basename "$0") [OPCIONES]

Script modular de monitoreo de recursos del sistema para Debian GNU/Linux.
Compatible con ejecución desatendida (cron), por banderas y modo interactivo.

Opciones de ejecución:
  -i, --interactive          Abre el panel interactivo navegable en consola con teclas de acceso rápido
  -o, --only <recurso>       Muestra únicamente un recurso específico y su detalle ampliado
                             Recursos válidos: cpu | ram | disk | net

Opciones de umbrales:
  --cpu <porcentaje>         Umbral de alerta para CPU (defecto: ${CPU_THRESHOLD}%)
  --ram <porcentaje>         Umbral de alerta para RAM (defecto: ${RAM_THRESHOLD}%)
  --disk <porcentaje>        Umbral de alerta para Disco raíz (defecto: ${DISK_THRESHOLD}%)
  --cooldown <minutos>       Tiempo de enfriamiento para alertas en minutos (defecto: ${ALERT_COOLDOWN_MINUTES} min)
  --max-log-size <megabytes> Tamaño máximo del log antes de rotar y comprimir con tar+gzip (defecto: ${LOG_MAX_SIZE_MB} MB)
  -h, --help                 Muestra esta ayuda y finaliza

Ejemplos:
  $0                         # Ejecución única (ideal para cron)
  $0 -i                      # Panel interactivo en tiempo real
  $0 --cooldown 1            # Alertas con cooldown de 1 minuto
  $0 --only cpu              # Vista aislada de CPU con Top 5 procesos
  watch -n 2 "$0 --only ram" # Monitoreo en vivo de RAM con watch
EOF
}

# Parseo de banderas de línea de comandos
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--interactive)
            MODO_INTERACTIVO=1
            shift
            ;;
        -o|--only)
            MODO_SOLO=$(echo "$2" | tr '[:upper:]' '[:lower:]')
            shift 2
            ;;
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
        --cooldown|--cooldown-minutes)
            ALERT_COOLDOWN_MINUTES="$2"
            shift 2
            ;;
        --cooldown=*|--cooldown-minutes=*)
            ALERT_COOLDOWN_MINUTES="${1#*=}"
            shift
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

# Genera reporte global para cron o consola estándar
generar_reporte_general() {
    local msg_rotacion
    msg_rotacion=$(gestionar_limpieza_logs)
    [ -n "$msg_rotacion" ] && echo "$msg_rotacion"

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

    echo "======================================================================"
    echo "       PANEL DE MONITOREO DE SERVIDOR DEBIAN - FCyT UADER"
    echo "======================================================================"
    echo " Timestamp : ${timestamp}"
    echo " CPU       : ${uso_cpu} (Umbral: ${CPU_THRESHOLD}%)"
    echo " RAM       : ${uso_ram} (Umbral: ${RAM_THRESHOLD}%)"
    echo " DISCO (/) : ${uso_disco} (Umbral: ${DISK_THRESHOLD}%)"
    echo " RED       : ${estado_red}"
    echo "======================================================================"

    local linea_log="[${timestamp}] | CPU: ${uso_cpu} | RAM: ${uso_ram} | DISCO: ${uso_disco} | RED: ${estado_red}"
    echo "$linea_log" >> "$LOG_FILE"

    procesar_alertas "$cpu_pct" "$uso_cpu" "$ram_pct" "$uso_ram" "$disk_pct" "$uso_disco" "$estado_red"
}

# Muestra un único recurso con su vista extendida
generar_reporte_aislado() {
    local recurso="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    echo "======================================================================"
    echo "       RECURSO AISLADO: ${recurso^^} - [${timestamp}]"
    echo "======================================================================"

    case "$recurso" in
        cpu)
            local cpu_pct uso_cpu
            cpu_pct=$(obtener_cpu_pct)
            uso_cpu=$(obtener_uso_cpu)
            echo "Consumo actual: ${uso_cpu} (Umbral de alerta: ${CPU_THRESHOLD}%)"
            echo ""
            obtener_detalle_cpu
            ;;
        ram)
            local ram_pct uso_ram
            ram_pct=$(obtener_ram_pct)
            uso_ram=$(obtener_uso_ram)
            echo "Consumo actual: ${uso_ram} (Umbral de alerta: ${RAM_THRESHOLD}%)"
            echo ""
            obtener_detalle_ram
            ;;
        disk|disco)
            local disk_pct uso_disco
            disk_pct=$(obtener_disco_pct "/")
            uso_disco=$(obtener_uso_disco "/")
            echo "Ocupación raíz (/): ${uso_disco} (Umbral de alerta: ${DISK_THRESHOLD}%)"
            echo ""
            obtener_detalle_disco
            ;;
        net|red)
            local estado_red
            estado_red=$(obtener_estado_red)
            echo "Estado actual: ${estado_red}"
            echo ""
            obtener_detalle_red
            ;;
        *)
            echo "Recurso no válido: '$recurso'. Usá: cpu | ram | disk | net"
            exit 1
            ;;
    esac
    echo "======================================================================"
}

# Bucle interactivo navegable sin romper comandos
ejecutar_modo_interactivo() {
    local vista_actual="general"

    while true; do
        salida=$(
        case "$vista_actual" in
            general)
                generar_reporte_general
                ;;
            cpu)
                generar_reporte_aislado "cpu"
                ;;
            ram)
                generar_reporte_aislado "ram"
                ;;
            disk)
                generar_reporte_aislado "disk"
                ;;
            net)
                generar_reporte_aislado "net"
                ;;
        esac
        )
        clear
        echo "$salida"

        echo -e "\n[Atajos] (1) General | (2) CPU | (3) RAM | (4) Disco | (5) Red | (q/ENTER) Volver/Salir"
        
        # Espera de 2 segundos sin bloquear para permitir navegación inmediata
        local tecla=""
        read -r -t 2 -n 1 tecla

        case "$tecla" in
            1) vista_actual="general" ;;
            2) vista_actual="cpu" ;;
            3) vista_actual="ram" ;;
            4) vista_actual="disk" ;;
            5) vista_actual="net" ;;
            q|Q|b|B)
                if [ "$vista_actual" != "general" ]; then
                    vista_actual="general"
                else
                    echo -e "\nSaliendo del monitor..."
                    break
                fi
                ;;
            "")
                # Timeout cumplido: continúa el bucle refrescando automáticamente
                ;;
        esac
    done
}

# --- Ejecución Principal ---
if [ "$MODO_INTERACTIVO" -eq 1 ]; then
    ejecutar_modo_interactivo
elif [ -n "$MODO_SOLO" ]; then
    generar_reporte_aislado "$MODO_SOLO"
else
    generar_reporte_general
fi
