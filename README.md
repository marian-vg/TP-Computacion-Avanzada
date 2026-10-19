# TP-Computacion-Avanzada: Sistema de Monitoreo en Debian GNU/Linux

Proyecto integrador para la cátedra **Computación Avanzada** - Licenciatura en Sistemas de Información (FCyT UADER).

Sistema modular en Bash para la supervisión y auditoría en tiempo real de recursos críticos en servidores Debian GNU/Linux, con registro histórico de eventos, rotación/compresión automática de logs y alertas remotas vía **Resend** (correo electrónico) y **Telegram Bot**.

---

## ⚡ Guía Rápida de Inicio (Quick Start)

### 1. Instalar dependencias necesarias (Debian Server / Zorin OS / Ubuntu)
En una terminal con permisos de superusuario (`root` o `sudo`):
```bash
sudo apt update && sudo apt install -y curl procps iproute2 tar gzip stress-ng
```

### 2. Otorgar permisos y configurar variables
```bash
# Otorgar permisos de ejecución a todos los scripts
chmod +x monitor.sh test_stress.sh modulos/*.sh

# Crear archivo de configuración a partir de la plantilla
cp .env.example .env
```
> Edite `.env` (`nano .env`) y configure sus credenciales de Resend (`RESEND_API_KEY`, `ALERT_EMAIL`) y/o Telegram (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`).

---

### 3. Machete de Comandos Esenciales

#### Monitoreo en tiempo real (para operadores humanos)
| Qué desea hacer | Comando a ejecutar | Descripción breve |
| :--- | :--- | :--- |
| **Panel interactivo (Recomendado)** | `./monitor.sh -i` | Dashboard continuo. Navega con teclas `1` a `5`, configura umbrales con `u` y sale con `q`. |
| **Monitoreo con utilidad estándar watch** | `watch -n 2 ./monitor.sh` | Actualiza la vista general cada 2 segundos en modo solo lectura. |
| **Ver solo un recurso con detalle** | `./monitor.sh --only cpu` | Muestra el estado del recurso y su vista extendida (`cpu`, `ram`, `disk`, `net`). |

#### Pruebas de alertas y personalización de umbrales
| Qué desea hacer | Comando a ejecutar | Descripción breve |
| :--- | :--- | :--- |
| **Disparar alerta inmediata de prueba** | `./monitor.sh --cpu 1` | Reduce el umbral de CPU para forzar el envío de notificación. |
| **Personalizar umbrales al vuelo** | `./monitor.sh --cpu 70 --ram 80 --disk 85` | Modifica los límites de alarma para esta ejecución. |
| **Ajustar tiempo de enfriamiento (cooldown)** | `./monitor.sh --cooldown 1` | Fija el tiempo de espera entre alertas externas en minutos. |
| **Fijar límite para rotación de logs** | `./monitor.sh --max-log-size 20` | Define el tamaño en MB antes de comprimir el log con tar+gzip. |

#### Demostración y automatización
| Qué desea hacer | Comando a ejecutar | Descripción breve |
| :--- | :--- | :--- |
| **Menú interactivo de estrés** | `./test_stress.sh` | Genera sobrecargas controladas en CPU, RAM o Disco para la defensa. |
| **Ejecución desatendida (para cron)** | `./monitor.sh` | Realiza una única comprobación, registra el log y finaliza. |
| **Consultar ayuda de parámetros** | `./monitor.sh --help` | Lista todas las opciones disponibles en consola. |

---

## 🚀 Arquitectura y Recursos Supervisados

El sistema implementa una arquitectura modular donde [`monitor.sh`](monitor.sh) actúa como orquestador central y delega la captura en módulos especializados dentro de [`modulos/`](modulos/):

1. **Microprocesador (`modulos/cpu.sh`):**
   * Muestreo instantáneo en ventana de 1 segundo mediante `vmstat 1 2` (Clase 3, diapositivas 13-15) y mecanismo de respaldo con `top -bn1`.
   * Cálculo porcentual de tiempo de CPU ocupado (`100 - id`).
   * Vista aislada con carga promedio (`uptime`) y los 5 procesos con mayor consumo (`ps aux`).

2. **Memoria Principal - RAM (`modulos/ram.sh`):**
   * Extracción de memoria física total y utilizada con `free -m` (Clase 3, diapositiva 16).
   * Cálculo de porcentaje de ocupación y detalle en megabytes.
   * Vista aislada con desglose de Buffers, Cached y Swap disponible.

3. **Memoria Secundaria - Disco (`modulos/disco.sh`):**
   * Supervisión de porcentaje y espacio libre/usado de la partición raíz (`/`) con `df -h` (Clase 4, diapositiva 21).
   * **Consumo y limpieza de archivos:** Análisis de tamaño con `du -m` (Clase 4) y rotación/empaquetado automático de logs con `tar` y compresión `gzip` (Clase 5, diapositivas 3-4) al alcanzar el umbral configurado.

4. **Red y Conectividad (`modulos/red.sh`):**
   * Detección automática de la interfaz de red activa e IP con `ip route` e `ip addr`.
   * Medición de tasa de transferencia instantánea (KB/s de bajada y subida) y totales acumulados en MB desde `/proc/net/dev`.
   * Vista aislada con puertos abiertos en escucha mediante `ss` o `netstat`.

5. **Motor de Alertas y Cooldown (`modulos/alertas.sh`):**
   * Comparación de métricas contra umbrales configurables.
   * Notificación visual en consola y registro histórico en [`logs/monitor.log`](logs/monitor.log).
   * Despacho de correos HTML mediante la API REST de **Resend** vía `curl`.
   * Despacho de mensajes formateados al canal de **Telegram** vía bot API.
   * Mecanismo de *cooldown* temporal compartido para evitar saturación de envíos.

---

## ⏰ Programación de Tareas con Cron

Para cumplir con la consigna de programar la ejecución periódica en Debian Server:

1. Abrir el editor de tareas cron:
   ```bash
   crontab -e
   ```
2. Agregar la regla para ejecutar el monitor cada 5 minutos (o el intervalo deseado):
   ```cron
   */5 * * * * /ruta/absoluta/TP-Computacion-Avanzada/monitor.sh >/dev/null 2>&1
   ```

> [!NOTE]
> La ejecución sin parámetros (`./monitor.sh`) está diseñada específicamente para entornos automatizados como cron: efectúa una sola pasada, escribe en el log, despacha alertas si corresponde y finaliza inmediatamente liberando memoria.

---

## 🔥 Demostración y Pruebas en Vivo (`test_stress.sh`)

Para realizar la defensa en vivo ante la cátedra y verificar el funcionamiento simultáneo del monitor y las alertas:

### Paso 1: Terminal 1 (Monitor del Sistema)
Se recomienda utilizar el **Modo Interactivo**:
```bash
./monitor.sh -i
```
* **Ventajas:** Permite cambiar de vista al instante con las teclas numéricas (`1` para General, `2` para CPU con Top 5 procesos, `3` para RAM, `4` para Disco, `5` para Red), ajustar umbrales en caliente con `u` y salir con `q`.
* **Alternativa con `watch`:** Si se desea emplear la herramienta estándar vista en Clase 3, ejecute `watch -n 2 ./monitor.sh`. Tenga en cuenta que `watch` es de solo lectura y no admite interacción por teclado.

### Paso 2: Terminal 2 (Generador de Estrés)
Inicie la herramienta de simulación de carga:
```bash
./test_stress.sh
```

El menú interactivo permite:
* Estresar CPU a un porcentaje exacto (ej. 85%) con `--cpu-load`.
* Estresar RAM consumiendo un porcentaje calculado de la memoria total.
* Estresar el subsistema de Disco con escrituras intensivas de I/O.
* Lanzar una prueba combinada multirecurso con tiempo límite seguro (`--timeout`) para evitar congelamientos en la máquina virtual.

---

### Comparativa: Panel Interactivo (`-i`) vs Utilidad `watch`

| Criterio | Panel Interactivo (`./monitor.sh -i`) | Utilidad GNU `watch` (`watch -n 2 ...`) |
| :--- | :--- | :--- |
| **Interacción** | **Total:** Permite navegar entre recursos con teclas `1`-`5`. | **Solo lectura:** No transfiere eventos de teclado al script. |
| **Detalle de Procesos** | Permite ver el Top 5 de procesos de CPU al instante. | Solo muestra la vista fijada al iniciar. |
| **Eficiencia de Procesos** | **Alta:** Mantiene un único proceso en memoria; la pausa es gestionada por el kernel vía `read -t 2`. | Genera un ciclo recurrente de `fork()` y `exec()` cada 2 segundos. |
| **Uso Recomendado** | **Demostraciones en vivo** y supervisión interactiva del administrador. | Automatizaciones externas o monitoreo pasivo en pantallas secundarias. |
