#!/usr/bin/env bash
# modulos/alertas.sh - Evaluación de umbrales y despacho de alertas visuales y vía Resend

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

    # Escapar contenido HTML para estructurar un JSON seguro
    local json_payload
    json_payload=$(awk -v from="$remitente" -v to="$ALERT_EMAIL" -v subj="$asunto" -v html="$cuerpo_html" 'BEGIN {
        gsub(/\\/, "\\\\", html);
        gsub(/"/, "\\\"", html);
        gsub(/\r/, "", html);
        gsub(/\n/, "\\n", html);
        printf "{\"from\":\"%s\",\"to\":[\"%s\"],\"subject\":\"%s\",\"html\":\"%s\"}", from, to, subj, html;
    }')

    local respuesta
    respuesta=$(curl -s -w "\n%{http_code}" -X POST 'https://api.resend.com/emails' \
        -H "Authorization: Bearer ${RESEND_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: DebianMonitor/1.0" \
        -d "$json_payload" 2>/dev/null)

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

# Genera una plantilla HTML moderna tipo Tarjetas/Dashboard para el correo
generar_plantilla_html() {
    local hostname_servidor
    hostname_servidor=$(hostname 2>/dev/null || echo "debian-server")
    local fecha_hora="$1"
    local resumen_texto="$2"
    local uso_cpu="$3"
    local cpu_pct="$4"
    local uso_ram="$5"
    local ram_pct="$6"
    local uso_disco="$7"
    local disk_pct="$8"
    local estado_red="$9"

    # Estilos según criticidad
    local color_cpu="#27ae60"
    local badge_cpu="NORMAL"
    if [ "$cpu_pct" -ge "$CPU_THRESHOLD" ]; then
        color_cpu="#e74c3c"
        badge_cpu="CRÍTICO (${cpu_pct}% >= ${CPU_THRESHOLD}%)"
    fi

    local color_ram="#27ae60"
    local badge_ram="NORMAL"
    if [ "$ram_pct" -ge "$RAM_THRESHOLD" ]; then
        color_ram="#e74c3c"
        badge_ram="CRÍTICO (${ram_pct}% >= ${RAM_THRESHOLD}%)"
    fi

    local color_disk="#27ae60"
    local badge_disk="NORMAL"
    if [ "$disk_pct" -ge "$DISK_THRESHOLD" ]; then
        color_disk="#e74c3c"
        badge_disk="CRÍTICO (${disk_pct}% >= ${DISK_THRESHOLD}%)"
    fi

    cat <<EOF
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
</head>
<body style="margin:0; padding:20px; background-color:#f4f6f8; font-family:'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color:#333;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width:620px; margin:0 auto; background:#ffffff; border-radius:10px; overflow:hidden; box-shadow:0 4px 12px rgba(0,0,0,0.08);">
    <tr>
      <td style="background:#e74c3c; padding:25px 30px; text-align:center; color:#ffffff;">
        <h1 style="margin:0; font-size:22px; letter-spacing:0.5px;">⚠️ ALERTA DE SISTEMA: SERVIDOR DEBIAN</h1>
        <p style="margin:6px 0 0 0; font-size:14px; opacity:0.95;">Host: <strong>${hostname_servidor}</strong> | Fecha: ${fecha_hora}</p>
      </td>
    </tr>
    <tr>
      <td style="padding:25px 30px;">
        <div style="background:#fdf2e9; border-left:4px solid #e67e22; padding:12px 16px; margin-bottom:20px; border-radius:4px;">
          <strong style="color:#d35400;">Resumen del evento:</strong>
          <p style="margin:5px 0 0 0; font-size:15px; color:#555;">${resumen_texto}</p>
        </div>

        <h3 style="margin:0 0 15px 0; font-size:16px; color:#2c3e50; border-bottom:1px solid #eee; padding-bottom:8px;">Estado actual de los 4 recursos supervisados</h3>

        <!-- Tarjeta CPU -->
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:12px; background:#fafafa; border:1px solid #e1e4e8; border-radius:6px; padding:12px 16px;">
          <tr>
            <td width="35%"><strong>Microprocesador (CPU)</strong></td>
            <td width="35%">${uso_cpu}</td>
            <td width="30%" align="right"><span style="background:${color_cpu}; color:#fff; font-size:11px; padding:3px 8px; border-radius:12px; font-weight:bold;">${badge_cpu}</span></td>
          </tr>
        </table>

        <!-- Tarjeta RAM -->
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:12px; background:#fafafa; border:1px solid #e1e4e8; border-radius:6px; padding:12px 16px;">
          <tr>
            <td width="35%"><strong>Memoria RAM</strong></td>
            <td width="35%">${uso_ram}</td>
            <td width="30%" align="right"><span style="background:${color_ram}; color:#fff; font-size:11px; padding:3px 8px; border-radius:12px; font-weight:bold;">${badge_ram}</span></td>
          </tr>
        </table>

        <!-- Tarjeta Disco -->
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:12px; background:#fafafa; border:1px solid #e1e4e8; border-radius:6px; padding:12px 16px;">
          <tr>
            <td width="35%"><strong>Almacenamiento (/)</strong></td>
            <td width="35%">${uso_disco}</td>
            <td width="30%" align="right"><span style="background:${color_disk}; color:#fff; font-size:11px; padding:3px 8px; border-radius:12px; font-weight:bold;">${badge_disk}</span></td>
          </tr>
        </table>

        <!-- Tarjeta Red -->
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:20px; background:#fafafa; border:1px solid #e1e4e8; border-radius:6px; padding:12px 16px;">
          <tr>
            <td colspan="3" style="font-size:13px; color:#555;">
              <strong>Conectividad y Red:</strong><br>${estado_red}
            </td>
          </tr>
        </table>

        <div style="font-size:12px; color:#7f8c8d; text-align:center; padding-top:15px; border-top:1px solid #eee;">
          Computación Avanzada - Licenciatura en Sistemas de Información (FCyT UADER)<br>
          <em>Generado automáticamente por el servicio de monitoreo en Debian GNU/Linux</em>
        </div>
      </td>
    </tr>
  </table>
</body>
</html>
EOF
}

# Evalúa los recursos numéricos y coordina la alerta visual y externa
procesar_alertas() {
    local cpu_pct="$1"
    local uso_cpu="$2"
    local ram_pct="$3"
    local uso_ram="$4"
    local disk_pct="$5"
    local uso_disco="$6"
    local estado_red="$7"
    local fecha_hora
    fecha_hora=$(date "+%Y-%m-%d %H:%M:%S")

    local alertas_asunto=()
    local alertas_detalle=()

    if [ "$cpu_pct" -ge "$CPU_THRESHOLD" ]; then
        alertas_asunto+=("CPU llegó al ${cpu_pct}%")
        alertas_detalle+=("CPU al ${cpu_pct}% (Umbral: ${CPU_THRESHOLD}%)")
    fi

    if [ "$ram_pct" -ge "$RAM_THRESHOLD" ]; then
        alertas_asunto+=("RAM llegó al ${ram_pct}%")
        alertas_detalle+=("RAM al ${ram_pct}% (Umbral: ${RAM_THRESHOLD}%)")
    fi

    if [ "$disk_pct" -ge "$DISK_THRESHOLD" ]; then
        alertas_asunto+=("DISCO llegó al ${disk_pct}%")
        alertas_detalle+=("DISCO al ${disk_pct}% (Umbral: ${DISK_THRESHOLD}%)")
    fi

    # Si ningún recurso superó su umbral, finaliza sin alertas
    [ ${#alertas_asunto[@]} -eq 0 ] && return 0

    local resumen_asunto
    resumen_asunto=$(IFS=" | "; echo "${alertas_asunto[*]}")

    local resumen_detalle
    resumen_detalle=$(IFS=" | "; echo "${alertas_detalle[*]}")

    # Notificación en consola y log
    local mensaje_alerta="[⚠️ ALERTA DE SISTEMA] Recursos críticos detectados: ${resumen_detalle}"
    echo "$mensaje_alerta"
    echo "[${fecha_hora}] ${mensaje_alerta}" >> "$LOG_FILE"

    # Evaluación de Cooldown y despacho de correo
    if verificar_cooldown; then
        local asunto="Alerta del Servidor Debian: [${resumen_asunto}]"
        local cuerpo_html
        cuerpo_html=$(generar_plantilla_html "$fecha_hora" "$resumen_detalle" "$uso_cpu" "$cpu_pct" "$uso_ram" "$ram_pct" "$uso_disco" "$disk_pct" "$estado_red")
        enviar_alerta_resend "$asunto" "$cuerpo_html"
    else
        echo "[COOLDOWN ACTIVO] Alerta externa silenciada temporalmente para evitar saturación."
    fi
}
