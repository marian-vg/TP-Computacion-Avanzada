#!/usr/bin/env bash
# modulos/alertas.sh - Evaluación de umbrales y despacho de alertas vía Resend

# Verifica si está activo el tiempo de enfriamiento (cooldown)
# Retorna 0 si SE PUEDE enviar alerta, 1 si está en cooldown (silenciado)
verificar_cooldown() {
    local cooldown_segundos=$(( ${ALERT_COOLDOWN_MINUTES:-5} * 60 ))
    local cooldown_archivo="${COOLDOWN_FILE:-/tmp/monitor_resend_cooldown}"
    local ahora
    ahora=$(date +%s)

    if [ -f "$cooldown_archivo" ]; then
        local ultimo_envio
        ultimo_envio=$(cat "$cooldown_archivo" 2>/dev/null)
        if [ -n "$ultimo_envio" ]; then
            local transcurrido=$(( ahora - ultimo_envio ))
            if [ "$transcurrido" -lt "$cooldown_segundos" ]; then
                return 1 # En cooldown
            fi
        fi
    fi

    return 0 # Habilitado para enviar
}

# Actualiza la marca de tiempo del último envío exitoso
actualizar_cooldown() {
    local cooldown_archivo="${COOLDOWN_FILE:-/tmp/monitor_resend_cooldown}"
    date +%s > "$cooldown_archivo" 2>/dev/null
}

# Despacha correo electrónico mediante la API REST oficial de Resend vía cURL
enviar_alerta_resend() {
    local asunto="$1"
    local cuerpo_html="$2"

    if [ -z "$RESEND_API_KEY" ] || [ -z "$ALERT_EMAIL" ]; then
        echo "[INFO ALERTA] Credenciales de Resend no configuradas en .env (se omite envío de correo)."
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "[ERROR ALERTA] curl no está instalado en el sistema."
        return 1
    fi

    local remitente="${ALERT_FROM:-Alertas Debian <onboarding@resend.dev>}"

    # Escapar comillas dobles en el cuerpo HTML para el JSON
    local payload_json
    payload_json=$(cat <<EOF
{
  "from": "${remitente}",
  "to": ["${ALERT_EMAIL}"],
  "subject": "${asunto}",
  "html": "${cuerpo_html}"
}
EOF
)

    local respuesta
    respuesta=$(curl -s -w "\n%{http_code}" -X POST 'https://api.resend.com/emails' \
        -H "Authorization: Bearer ${RESEND_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: DebianMonitor/1.0" \
        -d "$payload_json" 2>/dev/null)

    local http_code
    http_code=$(echo "$respuesta" | tail -n 1)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        actualizar_cooldown
        echo "[ALERTA ENVIADA] Notificación enviada exitosamente a ${ALERT_EMAIL} vía Resend."
        return 0
    else
        echo "[ERROR RESEND] Falló el envío de correo. Código HTTP: ${http_code}."
        return 1
    fi
}

# Evalúa los recursos numéricos y coordina la alerta visual y externa
procesar_alertas() {
    local cpu_pct="$1"
    local ram_pct="$2"
    local disk_pct="$3"
    local reporte_linea="$4"

    local alertas=()

    [ "$cpu_pct" -ge "$CPU_THRESHOLD" ] && alertas+=("CPU al ${cpu_pct}% (Umbral: ${CPU_THRESHOLD}%)")
    [ "$ram_pct" -ge "$RAM_THRESHOLD" ] && alertas+=("RAM al ${ram_pct}% (Umbral: ${RAM_THRESHOLD}%)")
    [ "$disk_pct" -ge "$DISK_THRESHOLD" ] && alertas+=("DISCO al ${disk_pct}% (Umbral: ${DISK_THRESHOLD}%)")

    # Si no se superó ningún umbral, finaliza
    [ ${#alertas[@]} -eq 0 ] && return 0

    local resumen_alertas
    resumen_alertas=$(IFS=" | "; echo "${alertas[*]}")

    # Notificación en consola y log
    local mensaje_alerta="[⚠️ ALERTA DE SISTEMA] Recursos críticos detectados: ${resumen_alertas}"
    echo "$mensaje_alerta"
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ${mensaje_alerta}" >> "$LOG_FILE"

    # Evaluación de Cooldown para Resend
    if verificar_cooldown; then
        local asunto="[ALERTA CRÍTICA] Servidor Debian: ${resumen_alertas}"
        local cuerpo="<h3>Atención: Se han superado umbrales en el servidor</h3><p><strong>Detalle:</strong> ${resumen_alertas}</p><p><strong>Reporte completo:</strong><br><code>${reporte_linea}</code></p><p><small>Enviado automáticamente por Debian Monitor Script</small></p>"
        enviar_alerta_resend "$asunto" "$cuerpo"
    else
        echo "[COOLDOWN ACTIVO] Alerta externa silenciada temporalmente para evitar saturación."
    fi
}
