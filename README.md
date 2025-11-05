# HERRAMIENTA DE RED v2.0 — `infoip.sh`

Pequeña suite en **Bash** para calcular y documentar redes IPv4 a partir de IPs/CIDR (locales o remotas) y **generar listas de objetivos para Nmap**. Crea informes en CSV con máscara, ID de red, broadcast, conteo de hosts y clasifica si la red es **Privada** o **Pública**.

> Autor: Rookie Ryu + GPT‑5  
> Licencia: MIT (sugerida — ajusta según tus necesidades)

---

## ✨ Características

- **Cálculo de redes** para entradas en formato `A.B.C.D/Prefijo` (ej. `192.168.1.10/24`).
- **Procesamiento masivo** desde un archivo local (`ips.txt` por defecto) o un archivo **remoto** (URL vía `curl`).
- **Informe CSV** con columnas:
  - `IP/CIDR`
  - `Netmask`
  - `Network ID`
  - `Broadcast`
  - `Total Direcciones`
  - `Hosts Usables`
  - `Tipo` (Privada / Pública)
- **Generador de objetivos para Nmap**: expande cada rango a **una IP por línea** en `./nmap_targets/…txt` y permite **lanzar escaneos** desde el propio script.
- **Gestión de informes**: guarda todos los CSV con timestamp en `~/Informes_Red` y permite abrir el último generado.
- **Modo interactivo** con menú claro, mensajes de ayuda y validaciones.

---

## 📦 Requisitos

- **Bash** 4+ (Linux/macOS).
- Utilidades estándar: `coreutils` (printf, wc, nl), `sed`, `awk` (presentes por defecto en la mayoría de distros).
- **curl** (para descargar archivos remotos). Opcional si no usas la opción 5.
- **nmap** (opcional) para escaneos desde la opción 6.

---

## 🗂️ Estructura de archivos generados

- **Informes CSV**: `~/Informes_Red/resultados_red_<origen>_<YYYY-mm-dd_HH-MM-SS>.csv`
- **Listas Nmap**: `./nmap_targets/nmap_targets_<YYYY-mm-dd_HH-MM-SS>.txt`

> *\<origen\>* puede ser `local`, `remoto` o vacío (según la acción).

---

## 🔧 Instalación

1) Copia el script al proyecto o a tu `$PATH`:
```bash
cp infoip.sh ~/bin/ && chmod +x ~/bin/infoip.sh
# o usarlo localmente
chmod +x infoip.sh
```

2) (Opcional) Instala Nmap si quieres lanzar escaneos desde el menú:
```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y nmap

# Fedora
sudo dnf install -y nmap

# macOS (Homebrew)
brew install nmap
```

---

## ▶️ Uso básico (menú interactivo)

Ejecuta el script:
```bash
./infoip.sh
```

Verás un menú similar a:
```
==========================================
         🧮 HERRAMIENTA DE RED v2.0
==========================================

1) Crear / Editar archivo local de IPs
2) Procesar archivo local y generar CSV
3) Calcular una IP/CIDR manual
4) Ver el último informe CSV
5) Descargar archivo remoto (URL) y procesar
6) Generar objetivos Nmap y (opcional) escanear
7) Ayuda
8) Salir
```

### 1) Crear / Editar archivo local de IPs
- Crea o edita un archivo (por defecto **`ips.txt`**) con **una línea por entrada** en formato `IP/Prefijo`.
- Acepta **añadir** o **sobrescribir** el contenido.
- Ejemplo de contenido:
  ```
  192.168.1.10/24
  10.0.0.1/8
  172.16.20.5/16
  8.8.8.8/32
  ```

### 2) Procesar archivo local y generar CSV
- Lee el archivo local (`ips.txt` por defecto), calcula cada entrada y guarda:
  - **CSV** en `~/Informes_Red/resultados_red_local_<timestamp>.csv`
  - Muestra un **resumen en pantalla** con columnas legibles

**Salida de ejemplo (tabla en consola):**
```
IP/CIDR           Netmask       Network ID     Broadcast       Total  Usables  Tipo
-----------------------------------------------------------------------------------
192.168.1.10/24   255.255.255.0 192.168.1.0    192.168.1.255   256    254      Privada
8.8.8.8/32        255.255.255.255 8.8.8.8      8.8.8.8         1      0        Pública
```

**Cabecera del CSV guardado:**
```csv
IP/CIDR,Netmask,Network ID,Broadcast,Total Direcciones,Hosts Usables,Tipo
```

### 3) Calcular una IP/CIDR manual
- Introduce una sola entrada `IP/Prefijo` (p.ej. `192.168.100.25/27`) y verás el cálculo detallado.
- Puedes **guardar ese único resultado** en un CSV con timestamp.

### 4) Ver el último informe CSV
- Abre el **informe más reciente** en `~/Informes_Red`. Útil para revisar resultados previos.

### 5) Descargar archivo remoto (URL) y procesar
- Descarga un archivo remoto de IPs/CIDR (una por línea) usando `curl` y, si deseas, **lo procesa y guarda** un informe CSV.
- Ejemplo de URL válida: `https://example.com/mis_ips.txt`

### 6) Generar objetivos Nmap y (opcional) escanear
- **Origen de datos**: el **último CSV** generado o el **archivo local** (`ips.txt`).
- **Expansión**: cada rango se convierte a **una IP por línea** y se guarda en `./nmap_targets/nmap_targets_<timestamp>.txt`.
- **Escaneo** (opcional): si hay Nmap instalado, el script puede lanzar:
  1. **Ping scan** (descubre hosts activos, sin puertos): `nmap -sn -iL archivo.txt`
  2. **Top 1000 puertos (TCP SYN)** rápido: `nmap -sS -T4 -iL archivo.txt`
  3. **Detección de servicios y versiones**: `nmap -sV -iL archivo.txt`

**Ejemplo completo:**
```bash
# 1) Preparo mis rangos
cat > ips.txt <<'EOF'
192.168.1.10/24
10.0.0.1/8
172.16.20.5/16
8.8.8.8/32
EOF

# 2) Genero objetivos para Nmap desde el archivo local
./infoip.sh   # -> Opción 6 -> “Desde un archivo de IPs local”

# 3) Lanza un escaneo rápido (ping scan) fuera del script
nmap -sn -iL ./nmap_targets/nmap_targets_2025-11-05_18-30-00.txt
```

---

## 🧠 Validaciones y comportamiento

- **Formato** válido: `A.B.C.D/Prefijo` con `A..D` ∈ `[0,255]` y `Prefijo` ∈ `[0,32]`.
- **Tipo de red**: se clasifica como **Privada** para `10.0.0.0/8`, `172.16.0.0/12` y `192.168.0.0/16`; en caso contrario, **Pública**.
- Prefijos **/31** y **/32** se tratan adecuadamente:
  - `/32`: solo 1 dirección (sin hosts utilizables).
  - `/31`: dos direcciones (ambas listadas en objetivos).

---

## 🛡️ Permisos y seguridad

- No requiere privilegios de administrador para calcular redes ni generar CSV.
- **Nmap** sí puede requerir privilegios para ciertos tipos de escaneo (p. ej., SYN con `-sS` en algunos sistemas). Si es necesario:
  ```bash
  sudo nmap -sS -iL ./nmap_targets/archivo.txt
  ```

---

## ❗ Solución de problemas

- **`Formato inválido`** al procesar: revisa que cada línea sea `IP/Prefijo` correcto. El script ignora líneas vacías y comentarios `#`.
- **No se genera CSV**: verifica permisos de escritura en `~/Informes_Red` y que el disco no esté lleno.
- **Descarga remota falla**: confirma conectividad y que la URL sea accesible; instala `curl` si falta.
- **Nmap no encontrado**: instala `nmap` (ver sección *Instalación*) o desactiva la ejecución de escaneo al generar objetivos.
- **Permiso denegado al ejecutar**: asegúrate de marcar el script como ejecutable:
  ```bash
  chmod +x ./infoip.sh
  ```

---

## 🔍 Ejemplos de entradas útiles

```
# Privadas
10.0.0.1/8
172.16.5.10/12
192.168.100.25/27

# Públicas /32 (hosts sueltos)
1.1.1.1/32
8.8.8.8/32

# Comentarios y espacios se ignoran
# 203.0.113.0/24
```

---

## 🧪 Prueba rápida sin archivo

```bash
./infoip.sh            # Opción 3
# Introduce: 192.168.1.10/24
# Verás máscara 255.255.255.0, red 192.168.1.0, broadcast 192.168.1.255, 256 totales, 254 usables, Tipo: Privada
```

---

## 📁 Variables y rutas (config por defecto)

- `DEFAULT_IPS_FILE="ips.txt"` — archivo local por defecto.
- `REPORT_DIR="$HOME/Informes_Red"` — carpeta de informes CSV.
- `NMAP_DIR="$(pwd)/nmap_targets"` — carpeta de objetivos Nmap (relativa al directorio de ejecución).

> Puedes modificar estas variables al inicio del script si necesitas otras rutas.

---

## 🧾 Licencia

Este proyecto se sugiere bajo **MIT**. Ajusta el texto de licencia según tu necesidad corporativa o personal.

---

## 👤 Créditos

- Autoría original: **Rookie Ryu**
- Mejoras y documentación: **GPT‑5 Thinking**
