# TP-Computacion-Avanzada: Sistema de Monitoreo en Debian GNU/Linux

Proyecto integrador para la cátedra **Computación Avanzada** - Licenciatura en Sistemas de Información (FCyT UADER).

Sistema modular en Bash para la supervisión y auditoría en tiempo real de recursos críticos en servidores Debian GNU/Linux, con registro histórico de eventos, rotación/compresión automática de logs y alertas remotas vía **Resend**.

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

## 🛠️ Instalación y Configuración

### 1. Clonar el repositorio y dar permisos de ejecución
```bash
git clone <URL_DEL_REPOSITORIO>
cd TP-Computacion-Avanzada
chmod +x monitor.sh modulos/*.sh
```

### 2. Configurar credenciales para alertas (Resend)
Copiar la plantilla de entorno:
```bash
cp .env.example .env
```
Editar `.env` con un editor de texto (`nano .env`):
```env
RESEND_API_KEY="re_tu_api_key_aqui"
ALERT_EMAIL="tu_correo@dominio.com"
ALERT_FROM="Alertas Debian <onboarding@resend.dev>"
```

---

## 💻 Modos de Uso

### A. Ejecución individual (One-Shot / Tarea Cron)
Ejecuta una medición única, actualiza el log y finaliza:
```bash
./monitor.sh
```

### B. Personalización de Umbrales por Banderas (CLI)
Podés sobrescribir los umbrales de [`config.sh`](config.sh) directamente desde la línea de comandos:
```bash
./monitor.sh --cpu 75 --ram 80 --disk 85 --max-log-size 20
```

* Parámetros disponibles:
  * `--cpu <%>`: Umbral de alerta de CPU.
  * `--ram <%>`: Umbral de alerta de RAM.
  * `--disk <%>`: Umbral de alerta de Disco.
  * `--max-log-size <MB>`: Límite de tamaño del archivo `monitor.log` antes de comprimirlo en `.tar.gz`.
  * `-h, --help`: Muestra la ayuda de sintaxis.

### C. Monitoreo en Tiempo Real (Consola interactiva)
Aprovechando la utilidad nativa `watch` (Clase 3, diapositiva 20):
```bash
watch -n 2 ./monitor.sh
```
* O con umbrales personalizados:
```bash
watch -n 2 ./monitor.sh --cpu 60 --ram 70
```

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

## 🔥 Demostración y Pruebas de Estrés (`test_stress.sh`)

Para realizar la defensa en vivo ante la cátedra y verificar el disparo de alertas y notificaciones a Resend:

1. **Instalar `stress-ng` en Debian Server / Zorin OS:**
   ```bash
   sudo apt update && sudo apt install -y stress-ng
   ```

2. **Ejecutar la demostración en dos terminales en paralelo:**
   * **Terminal 1:** Mantener el monitor en tiempo real:
     ```bash
     watch -n 2 ./monitor.sh
     ```
   * **Terminal 2:** Abrir el menú interactivo de estrés:
     ```bash
     chmod +x test_stress.sh
     ./test_stress.sh
     ```

   * El menú te permite:
     * Estresar CPU a un porcentaje exacto (ej. 85%) con `--cpu-load`.
     * Estresar RAM consumiendo un porcentaje calculado de la memoria total.
     * Estresar el subsistema de Disco con escrituras intensivas.
     * Lanzar un estrés combinado multirecurso con tiempo límite seguro (`--timeout`) para evitar que la máquina virtual se cuelgue.

