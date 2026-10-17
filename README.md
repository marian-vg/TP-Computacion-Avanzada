# TP-Computacion-Avanzada: Sistema de Monitoreo en Debian GNU/Linux

Proyecto integrador para la cátedra **Computación Avanzada** - Licenciatura en Sistemas de Información (FCyT UADER).

Sistema modular en Bash para la supervisión y auditoría en tiempo real de recursos críticos en servidores Debian GNU/Linux, con registro histórico de eventos, rotación/compresión automática de logs y alertas remotas vía **Resend**.

---

## ⚡ Guía Rápida de Inicio (Quick Start)

### 1. Instalar herramientas necesarias (Debian Server / Zorin OS / Ubuntu)
En una terminal con permisos de superusuario, instalar todas las dependencias con un solo comando:
```bash
sudo apt update && sudo apt install -y curl procps iproute2 tar gzip stress-ng
```

### 2. Dar permisos y configurar credenciales
```bash
# Otorgar permisos de ejecución a todos los scripts
chmod +x monitor.sh test_stress.sh modulos/*.sh

# Crear archivo de configuración a partir de la plantilla
cp .env.example .env
```
> Editá `.env` (`nano .env`) y colocá tu `RESEND_API_KEY` y `ALERT_EMAIL`.

### 3. Comandos esenciales (Machete de ejecución)

| Qué querés hacer | Comando a ejecutar |
| :--- | :--- |
| **Panel interactivo navegable (Teclas 1-5, q)** | `./monitor.sh -i` |
| **Ver recurso aislado con detalle extendido** | `./monitor.sh --only cpu` *(o `ram`, `disk`, `net`)* |
| **Monitorear en vivo con watch** | `watch -n 2 ./monitor.sh` |
| **Test rápido de alertas por correo** | `./monitor.sh --cpu 1` |
| **Personalizar umbrales al vuelo** | `./monitor.sh --cpu 70 --ram 80 --disk 85` |
| **Personalizar cooldown de alertas (en min)** | `./monitor.sh --cooldown 1` |
| **Personalizar tamaño de rotación de logs** | `./monitor.sh --max-log-size 20` |
| **Lanzar menú interactivo de estrés (Demo)** | `./test_stress.sh` |
| **Ejecución única (para cron)** | `./monitor.sh` |
| **Ver ayuda completa de opciones** | `./monitor.sh --help` |

---

## 🚀 Arquitectura y Recursos Supervisados

El sistema implementa una arquitectura modular donde [`monitor.sh`](monitor.sh) actúa como orquestador central y delega la captura en módulos especializados dentro de [`modulos/`](modulos/):

1. **Microprocesador (`modulos/cpu.sh`):**
   * Muestreo instantáneo en ventana de 1 segundo mediante `vmstat 1 2` (Clase 3, diapositivas 13-15) y fallback con `top -bn1`.
   * Cálculo porcentual de tiempo de CPU ocupado (`100 - id`).
2. **Memoria Principal - RAM (`modulos/ram.sh`):**
   * Extracción de memoria física total y utilizada con `free -m` (Clase 3, diapositiva 16).
   * Cálculo de porcentaje de ocupación y detalle en megabytes.
3. **Memoria Secundaria - Disco (`modulos/disco.sh`):**
   * Supervisión de porcentaje y espacio libre/usado de la partición raíz (`/`) con `df -h` (Clase 4, diapositiva 21).
   * **Consumo y limpieza de archivos:** Análisis de tamaño con `du -m` (Clase 4) y rotación/empaquetado automático de logs con `tar` y compresión `gzip` (Clase 5, diapositivas 3-4) al alcanzar el umbral configurado.
4. **Red y Conectividad (`modulos/red.sh`):**
   * Detección automática de la interfaz de red activa e IP con `ip route` e `ip addr`.
   * Medición de tasa de transferencia instantánea (KB/s de bajada y subida) y totales acumulados en MB desde `/proc/net/dev`.
5. **Motor de Alertas y Cooldown (`modulos/alertas.sh`):**
   * Comparación de métricas contra umbrales configurables.
   * Notificación visual en consola y registro en [`logs/monitor.log`](logs/monitor.log).
   * Despacho de correos de alerta mediante API REST oficial de **Resend** vía `curl`.
   * Mecanismo de *cooldown* temporal para evitar saturación de envíos al monitorear en vivo.

---

## ⏰ Programación de Tareas con Cron

Para cumplir con la consigna de programar la ejecución en Debian Server:

1. Abrir el editor de tareas cron:
   ```bash
   crontab -e
   ```
2. Agregar la regla para ejecutar el monitor cada 5 minutos (o el intervalo deseado):
   ```cron
   */5 * * * * /ruta/absoluta/TP-Computacion-Avanzada/monitor.sh >/dev/null 2>&1
   ```

---

## 🔥 Demostración y Pruebas en Vivo (`test_stress.sh`)

Para realizar la defensa en vivo ante la cátedra y verificar el disparo de alertas y notificaciones a Resend:

1. **Terminal 1:** Mantener el monitor en tiempo real:
   ```bash
   watch -n 2 ./monitor.sh
   ```
2. **Terminal 2:** Abrir el menú interactivo de estrés:
   ```bash
   ./test_stress.sh
   ```

   El menú interactivo te permite:
   * Estresar CPU a un porcentaje exacto (ej. 85%) con `--cpu-load`.
   * Estresar RAM consumiendo un porcentaje calculado de la memoria total.
   * Estresar el subsistema de Disco con escrituras intensivas.
   * Lanzar un estrés combinado multirecurso con tiempo límite seguro (`--timeout`) para evitar que la máquina virtual se cuelgue.
