#!/usr/bin/env bash
# config.sh - Variables globales del sistema de monitoreo

# Directorio raíz del proyecto
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directorio y archivo de logs
LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/monitor.log"

# Umbrales de alerta (opcional, en porcentaje %)
CPU_THRESHOLD=80
RAM_THRESHOLD=85