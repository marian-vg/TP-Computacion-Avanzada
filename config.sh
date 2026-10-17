#!/usr/bin/env bash
# config.sh - Variables globales del sistema de monitoreo

# Directorio raíz del proyecto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar variables de entorno locales si existe el archivo .env
if [ -f "${BASE_DIR}/.env" ]; then
    # shellcheck source=/dev/null
    source "${BASE_DIR}/.env"
fi

# Directorio y archivo de logs
LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/monitor.log"

# Umbrales de alerta del sistema (en porcentaje %)
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
RAM_THRESHOLD="${RAM_THRESHOLD:-85}"
DISK_THRESHOLD="${DISK_THRESHOLD:-85}"

# Umbral de tamaño para rotación y compresión de logs (en MB)
LOG_MAX_SIZE_MB="${LOG_MAX_SIZE_MB:-50}"

# Tiempo de enfriamiento (cooldown) para alertas externas en minutos
ALERT_COOLDOWN_MINUTES="${ALERT_COOLDOWN_MINUTES:-5}"

# Ruta del archivo de cooldown en Linux (compartido entre Resend y Telegram)
COOLDOWN_FILE="/tmp/monitor_alert_cooldown"

# Credenciales externas (cargadas desde .env)
RESEND_API_KEY="${RESEND_API_KEY:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
ALERT_FROM="${ALERT_FROM:-Alertas Debian <onboarding@resend.dev>}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"