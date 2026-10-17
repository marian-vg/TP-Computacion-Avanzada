#!/usr/bin/env bash
# test_stress.sh - Herramienta interactiva para simular sobrecargas con stress-ng
# Cátedra: Computación Avanzada - FCyT UADER

# Códigos de color ANSI para interfaz
AZUL="\033[1;34m"
VERDE="\033[1;32m"
AMARILLO="\033[1;33m"
ROJO="\033[1;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Manejo limpio de señales (Ctrl+C)
trap 'echo -e "\n${AMARILLO}[!] Prueba cancelada por el usuario. Finalizando procesos...${RESET}"; pkill -P $$ stress-ng 2>/dev/null; exit 0' SIGINT SIGTERM

# Verificación de instalación de stress-ng
verificar_dependencias() {
    if ! command -v stress-ng >/dev/null 2>&1; then
        echo -e "${ROJO}[ERROR] 'stress-ng' no se encuentra instalado en este sistema.${RESET}"
        echo -e "${AMARILLO}Para instalarlo en Debian, Ubuntu o Zorin OS ejecutá:${RESET}"
        echo -e "  sudo apt update && sudo apt install -y stress-ng\n"
        read -r -p "Presioná ENTER para salir..."
        exit 1
    fi
}

# 1. Estrés de CPU por porcentaje
estresar_cpu() {
    clear
    echo -e "${CYAN}=== 1. ESTRÉS CONTROLADO DE CPU ===${RESET}\n"
    read -r -p "Porcentaje objetivo de CPU (1-100) [defecto: 85]: " cpu_pct
    cpu_pct="${cpu_pct:-85}"

    read -r -p "Duración de la prueba en segundos [defecto: 20]: " seg
    seg="${seg:-20}"

    echo -e "\n${VERDE}[+] Iniciando estrés de CPU al ${cpu_pct}% durante ${seg} segundos...${RESET}"
    echo -e "${AMARILLO}Mirá la otra terminal con 'watch -n 2 ./monitor.sh' para ver el impacto en vivo.${RESET}\n"

    stress-ng --cpu 0 --cpu-load "$cpu_pct" --timeout "${seg}s" --metrics-brief

    echo -e "\n${VERDE}[✓] Prueba finalizada exitosamente.${RESET}"
    read -r -p "Presioná ENTER para volver al menú..."
}

# 2. Estrés de Memoria RAM
estresar_ram() {
    clear
    echo -e "${CYAN}=== 2. ESTRÉS DE MEMORIA RAM ===${RESET}\n"

    local total_ram=0
    if command -v free >/dev/null 2>&1; then
        total_ram=$(LC_ALL=C free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
    fi
    total_ram="${total_ram:-2048}"

    echo -e "Memoria RAM total detectada: ${AMARILLO}${total_ram} MB${RESET}"
    read -r -p "Porcentaje objetivo de RAM (1-95) [defecto: 85]: " ram_pct
    ram_pct="${ram_pct:-85}"

    local bytes_mb=$(( (total_ram * ram_pct) / 100 ))

    read -r -p "Duración de la prueba en segundos [defecto: 20]: " seg
    seg="${seg:-20}"

    echo -e "\n${VERDE}[+] Consumiendo ~${bytes_mb} MB de RAM (${ram_pct}%) durante ${seg} segundos...${RESET}"
    echo -e "${AMARILLO}Mirá la otra terminal con 'watch -n 2 ./monitor.sh' para ver el impacto en vivo.${RESET}\n"

    stress-ng --vm 1 --vm-bytes "${bytes_mb}M" --timeout "${seg}s" --metrics-brief

    echo -e "\n${VERDE}[✓] Prueba finalizada exitosamente.${RESET}"
    read -r -p "Presioná ENTER para volver al menú..."
}

# 3. Estrés de Entrada/Salida y Escritura de Disco
estresar_disco() {
    clear
    echo -e "${CYAN}=== 3. ESTRÉS DE DISCO (I/O Y ESCRITURA) ===${RESET}\n"

    read -r -p "Tamaño de archivo de escritura temporal en MB [defecto: 256]: " tam_mb
    tam_mb="${tam_mb:-256}"

    read -r -p "Duración de la prueba en segundos [defecto: 20]: " seg
    seg="${seg:-20}"

    echo -e "\n${VERDE}[+] Iniciando escritura intensiva en disco (${tam_mb} MB) durante ${seg} segundos...${RESET}"
    echo -e "${AMARILLO}Mirá la otra terminal con 'watch -n 2 ./monitor.sh' para ver el impacto en vivo.${RESET}\n"

    stress-ng --hdd 2 --hdd-bytes "${tam_mb}M" --timeout "${seg}s" --metrics-brief

    echo -e "\n${VERDE}[✓] Prueba finalizada exitosamente.${RESET}"
    read -r -p "Presioná ENTER para volver al menú..."
}

# 4. Estrés Multirecurso Personalizado (Combo)
estresar_multirecurso() {
    clear
    echo -e "${CYAN}=== 4. ESTRÉS PERSONALIZADO MULTIRECURSO (COMBO) ===${RESET}\n"

    read -r -p "Porcentaje objetivo de CPU (1-100) [defecto: 80]: " cpu_pct
    cpu_pct="${cpu_pct:-80}"

    local total_ram=0
    if command -v free >/dev/null 2>&1; then
        total_ram=$(LC_ALL=C free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
    fi
    total_ram="${total_ram:-2048}"

    read -r -p "Porcentaje objetivo de RAM (1-95) [defecto: 85]: " ram_pct
    ram_pct="${ram_pct:-85}"
    local bytes_mb=$(( (total_ram * ram_pct) / 100 ))

    read -r -p "¿Incluir estrés de disco? (s/n) [defecto: s]: " inc_disco
    inc_disco="${inc_disco:-s}"

    read -r -p "Duración de la prueba en segundos [defecto: 25]: " seg
    seg="${seg:-25}"

    local args=(--cpu 0 --cpu-load "$cpu_pct" --vm 1 --vm-bytes "${bytes_mb}M" --timeout "${seg}s" --metrics-brief)
    if [[ "$inc_disco" =~ ^[sS]$ ]]; then
        args+=(--hdd 1 --hdd-bytes 256M)
    fi

    echo -e "\n${VERDE}[+] Disparando prueba combinada (CPU: ${cpu_pct}%, RAM: ~${bytes_mb}MB) durante ${seg}s...${RESET}"
    echo -e "${AMARILLO}Mirá la otra terminal para observar cómo saltan múltiples alertas simultáneas.${RESET}\n"

    stress-ng "${args[@]}"

    echo -e "\n${VERDE}[✓] Prueba combinada finalizada.${RESET}"
    read -r -p "Presioná ENTER para volver al menú..."
}

# Bucle principal de menú
mostrar_menu() {
    verificar_dependencias

    while true; do
        clear
        echo -e "${AZUL}======================================================================${RESET}"
        echo -e "       ${CYAN}GENERADOR DE ESTRÉS PARA DEMOSTRACIÓN EN VIVO (stress-ng)${RESET}"
        echo -e "            Cátedra: Computación Avanzada - FCyT UADER"
        echo -e "${AZUL}======================================================================${RESET}"
        echo -e "  ${VERDE}1)${RESET} Estresar Microprocesador (CPU) con porcentaje específico"
        echo -e "  ${VERDE}2)${RESET} Estresar Memoria RAM (consumir porcentaje de memoria)"
        echo -e "  ${VERDE}3)${RESET} Estresar Memoria Secundaria (Disco / I/O pesada)"
        echo -e "  ${VERDE}4)${RESET} Estresar Múltiples Recursos a la vez (Personalizado)"
        echo -e "  ${VERDE}5)${RESET} Salir"
        echo -e "${AZUL}======================================================================${RESET}"
        read -r -p "Seleccioná una opción [1-5]: " opcion

        case "$opcion" in
            1) estresar_cpu ;;
            2) estresar_ram ;;
            3) estresar_disco ;;
            4) estresar_multirecurso ;;
            5) echo -e "\n${VERDE}¡Éxitos en la demostración!${RESET}\n"; exit 0 ;;
            *) echo -e "${ROJO}Opción inválida.${RESET}"; sleep 1 ;;
        esac
    done
}

mostrar_menu
