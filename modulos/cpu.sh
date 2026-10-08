#!/usr/bin/env bash
# modulos/cpu.sh - Monitoreo de Microprocesador

obtener_uso_cpu() {
    # Extrae el uso de CPU restando el porcentaje inactivo (idle)
    # top en modo batch (-b) con 1 sola iteración (-n 1)
    local cpu_idle
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d',' -f1 | cut -d'.' -f1)
    
    local cpu_used=$(( 100 - cpu_idle ))
    echo "${cpu_used}%"
}