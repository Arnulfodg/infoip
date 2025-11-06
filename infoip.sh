#!/usr/bin/env bash
# netinfo.sh - v2.0 (mejora: integración con Nmap)
# Herramienta de cálculo de redes (local, archivo o remoto)
# Creado por: midesmis

set -euo pipefail

# ===== CONFIG =====
DEFAULT_IPS_FILE="ips.txt"
REPORT_DIR="$HOME/Informes_Red"
NMAP_DIR="$(pwd)/nmap_targets"    # carpeta en el directorio donde se ejecuta el script
mkdir -p "$REPORT_DIR" "$NMAP_DIR"

# ===== COLORS =====
C_RESET=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_CYAN=""
C_WHITE=""
timestamp() { date +"%Y-%m-%d_%H-%M-%S"; }

# ===== MENU =====
show_menu() {
  clear
  cat <<-"EOF"
 /$$$$$$ /$$   /$$ /$$$$$$$$ /$$$$$$        /$$$$$$ /$$$$$$$ 
|_  $$_/| $$$ | $$| $$_____//$$__  $$      |_  $$_/| $$__  $$
  | $$  | $$$$| $$| $$     | $$  \ $$        | $$  | $$  \ $$
  | $$  | $$ $$ $$| $$$$$  | $$  | $$        | $$  | $$$$$$$/
  | $$  | $$  $$$$| $$__/  | $$  | $$        | $$  | $$____/ 
  | $$  | $$\  $$$| $$     | $$  | $$        | $$  | $$      
 /$$$$$$| $$ \  $$| $$     |  $$$$$$/       /$$$$$$| $$      
|______/|__/  \__/|__/      \______/       |______/|__/      


                   by midesmis

==========================================

1) Crear / Editar archivo local de IPs
2) Procesar archivo local de IPs
3) Calcular una IP manualmente
4) Ver último informe CSV
5) Descargar archivo remoto de IPs (URL)
6) Generar objetivos y escanear con Nmap
7) Ayuda / Ejemplo de uso
8) Salir

==========================================
EOF
}

# ===== AUX =====
int_to_ip() {
  local i=$1
  # Salida con newline para nmap, command substitution lo limpia para variables
  printf "%d.%d.%d.%d\n" \
    $(( (i >> 24) & 255 )) \
    $(( (i >> 16) & 255 )) \
    $(( (i >> 8) & 255 )) \
    $(( i & 255 ))
}

valid_cidr() {
  local cidr="$1"
  if [[ $cidr =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]{1,2})$ ]]; then
    IFS='/' read -r ip prefix <<< "$cidr"
    IFS='.' read -r a b c d <<< "$ip"
    for o in "$a" "$b" "$c" "$d"; do
      (( o >= 0 && o <= 255 )) || return 1
    done
    (( prefix >= 0 && prefix <= 32 )) || return 1
    return 0
  fi
  return 1
}

red_privada_o_publica() {
  local ip="$1"
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  if (( o1 == 10 )) || (( o1 == 172 && o2 >= 16 && o2 <= 31 )) || (( o1 == 192 && o2 == 168 )); then
    echo -e "Privada"
  else
    echo -e "Pública"
  fi
}

# ===== calc_network =====
calc_network() {
  local cidr="$1"
  local mode="${2:-}"

  if ! valid_cidr "$cidr"; then
    if [[ "$mode" == "--csv" ]]; then
      printf "%s,INVALID,INVALID,INVALID,0,0,INVALID\n" "$cidr"
      return 1
    else
      echo -e "Formato inválido -> $cidr"
      return 1
    fi
  fi

  local ip=${cidr%/*}
  local prefix=${cidr#*/}
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

  local ip_int=$(( (o1 << 24) + (o2 << 16) + (o3 << 8) + o4 ))
  local mask_int=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
  local net_int=$(( ip_int & mask_int ))
  local bcast_int=$(( net_int | ((1 << (32 - prefix)) - 1) ))
  local mask=$(int_to_ip "$mask_int")
  local net_id=$(int_to_ip "$net_int")
  local bcast=$(int_to_ip "$bcast_int")
  local total=$(( 2 ** (32 - prefix) ))
  local usable=$(( prefix >= 31 ? total : total - 2 ))
  local tipo_raw
  tipo_raw=$(red_privada_o_publica "$ip")
  local tipo_csv
  tipo_csv=$(echo -e "$tipo_raw" | sed 's/\x1b\[[0-9;]*m//g')

  if [[ "$mode" == "--csv" ]]; then
    printf "%s,%s,%s,%s,%s,%s,%s\n" \
      "$ip/$prefix" "$mask" "$net_id" "$bcast" "$total" "$usable" "$tipo_csv"
  else
    echo -e "------------------------------------------"
    echo -e "IP Entrada:        $ip/$prefix"
    echo -e "Máscara:           $mask"
    echo -e "Network ID:        $net_id"
    echo -e "Broadcast:         $bcast"
    echo -e "Total direcciones: $total"
    echo -e "Hosts utilizables: $usable"
    echo -e "Tipo de red:       $tipo_raw"
    echo -e "------------------------------------------"
  fi
}

# ===== Opción 1: crear/editar archivo local =====
crear_o_editar_archivo() {
  read -rp "Archivo (por defecto: ${DEFAULT_IPS_FILE}): " file
  file=${file:-$DEFAULT_IPS_FILE}

  if [ -f "$file" ]; then
    read -rp "El archivo existe. ¿(A)ñadir o (S)obreescribir? [A/S]: " resp
    resp=${resp:-A}
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        read -rp "$(echo -e "¿Seguro que quieres sobrescribir? Perderás el contenido."" [y/N]: ")" confirm_overwrite
        if [[ "$confirm_overwrite" =~ ^[Yy]$ ]]; then
            > "$file"
            echo -e "Archivo sobrescrito."
        else
            echo -e "Operación cancelada."
            read -rp "Presiona Enter para volver al menú..."
            return
        fi
    fi
  fi

  echo "Introduce IP/CIDR (una por línea, vacío para terminar):"
  while true; do
    read -rp "> " entry
    entry="$(echo "$entry" | xargs)"
    [[ -z "$entry" ]] && break
    if valid_cidr "$entry"; then
      echo "$entry" >> "$file"
    else
      echo -e "⚠️  Entrada inválida: $entry"
    fi
  done

  echo ""
  echo -e "Contenido de '$file':"
  nl -ba "$file"
  read -rp "Presiona Enter para volver al menú..."
}

# ===== Lógica de procesamiento (refactorizada) =====
_procesar_archivo_base() {
  local input_file="$1"
  local report_suffix="$2"

  local out="$REPORT_DIR/resultados_red_${report_suffix}_$(timestamp).csv"
  echo "IP/CIDR,Netmask,Network ID,Broadcast,Total Direcciones,Hosts Usables,Tipo" > "$out"

  echo ""
  echo -e "Procesando '$input_file'..."
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue

    if ! csvline=$(calc_network "$line" --csv); then
      echo -e "⚠️  Entrada inválida en el archivo: $line"
    fi
    printf "%s\n" "$csvline" >> "$out"
  done < "$input_file"

  echo ""
  echo -e "✅ Informe guardado en: $out"
  read -rp "¿Deseas verlo ahora? [y/N]: " ver
  [[ "$ver" =~ ^[Yy]$ ]] && column -t -s, "$out" || true
}

# ===== Opción 2: procesar archivo local =====
procesar_archivo() {
  read -rp "Ruta del archivo (por defecto: ${DEFAULT_IPS_FILE}): " file
  file=${file:-$DEFAULT_IPS_FILE}
  if [ ! -f "$file" ]; then
    echo -e "❌ No existe el archivo: $file"
    sleep 2
    return
  fi
  _procesar_archivo_base "$file" "local"
  read -rp "Presiona Enter para volver al menú..."
}

# ===== Opción 3: IP manual =====
ip_manual() {
  read -rp "Introduce IP/CIDR: " input
  if ! valid_cidr "$input"; then
    echo -e "Formato inválido."
    read -rp "Presiona Enter para volver al menú..."
    return
  fi

  calc_network "$input"

  read -rp "¿Guardar este único resultado en CSV con timestamp? [y/N]: " save
  save=${save:-N}
  if [[ "$save" =~ ^[Yy]$ ]]; then
    local out="$REPORT_DIR/resultados_red_$(timestamp).csv"
    echo "IP/CIDR,Netmask,Network ID,Broadcast,Total Direcciones,Hosts Usables,Tipo" > "$out"
    csvline=$(calc_network "$input" --csv)
    printf "%s\n" "$csvline" >> "$out"
    echo -e "✅ Guardado en $out"
  fi

  read -rp "Presiona Enter para volver al menú..."
}

# ===== Opción 4: ver último CSV =====
ver_ultimo_csv() {
  local last
  last=$(ls -1t "$REPORT_DIR"/resultados_red_*.csv 2>/dev/null | head -n1 || true)
  if [[ -z "$last" ]]; then
    echo -e "No hay informes guardados."
  else
    echo -e "Mostrando: $last"
    echo -e "------------------------------------------"
    column -t -s, "$last"
    echo -e "------------------------------------------"
  fi
  read -rp "Presiona Enter para volver..."
}

# ===== Opción 5: descargar remoto =====
descargar_remoto() {
  read -rp "Introduce URL del archivo de IPs (ej. https://.../ips.txt): " url
  [[ -z "$url" ]] && return
  local tmpfile="/tmp/ips_remote_$(timestamp).txt"
  echo -e "Descargando desde $url..."
  if ! curl -fsSL "$url" -o "$tmpfile"; then
    echo -e "❌ No se pudo descargar el archivo remoto."
    rm -f "$tmpfile"
    sleep 2
    return
  fi
  echo -e "Archivo descargado en $tmpfile"
  echo ""
  read -rp "¿Deseas procesarlo ahora y guardar el informe? [y/N]: " proc
  if [[ "$proc" =~ ^[Yy]$ ]]; then
    _procesar_archivo_base "$tmpfile" "remoto"
  fi
  rm -f "$tmpfile"
  read -rp "Presiona Enter para volver al menú..."
}

# ===== Opción 6: generar y escanear con Nmap =====
generar_nmap_targets() {
  echo ""
  echo -e "=== Generador de objetivos Nmap ==="
  echo -e "1) Desde el último CSV generado"
  echo -e "2) Desde un archivo de IPs local (${DEFAULT_IPS_FILE})"
  read -rp "Elige una opción [1-2]: " origen

  local src_list=()
  if [[ "$origen" == "1" ]]; then
    src=$(ls -1t "$REPORT_DIR"/resultados_red_*.csv 2>/dev/null | head -n1 || true)
    if [[ -z "$src" ]]; then
      echo -e "❌ No hay CSV disponible."; sleep 2; return
    fi
    echo -e "Usando $src"
    while IFS=, read -r cidr _rest; do
      [[ "$cidr" == "IP/CIDR" ]] && continue
      cidr="$(echo "$cidr" | xargs)"
      [[ -z "$cidr" ]] && continue
      src_list+=("$cidr")
    done < "$src"
  elif [[ "$origen" == "2" ]]; then
    if [[ ! -f "$DEFAULT_IPS_FILE" ]]; then
      echo -e "❌ No existe $DEFAULT_IPS_FILE"; sleep 2; return
    fi
    while IFS= read -r line;
    do
      line="${line%%#*}"
      line="$(echo "$line" | xargs)"
      [[ -z "$line" ]] && continue
      src_list+=("$line")
    done < "$DEFAULT_IPS_FILE"
  else
    echo -e "Opción inválida"; return
  fi

  local out="${NMAP_DIR}/nmap_targets_$(timestamp).txt"
  : > "$out"

  echo -e "Generando IPs de cada rango (una por línea) en: $out ..."

  for cidr in "${src_list[@]}"; do
    if ! valid_cidr "$cidr"; then
      echo -e "Saltando entrada inválida: $cidr"
      continue
    fi
    IFS='/' read -r ip prefix <<< "$cidr"
    IFS='.' read -r a b c d <<< "$ip"
    ip_int=$(( (a << 24) + (b << 16) + (c << 8) + d ))
    mask_int=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
    start=$(( ip_int & mask_int ))
    total=$(( 2 ** (32 - prefix) ))

    if (( prefix == 32 )); then
      int_to_ip "$start" >> "$out"
      continue
    fi

    if (( prefix >= 31 )); then
      for ((i=0; i<total; i++)); do
        host_int=$(( start + i ))
        int_to_ip "$host_int" >> "$out"
      done
    else
      for ((i=1; i<total-1; i++)); do
        host_int=$(( start + i ))
        int_to_ip "$host_int" >> "$out"
      done
    fi
  done

  local count
  count=$(wc -l < "$out" || true)
  echo ""
  echo -e "✅ Archivo generado con $count direcciones."
  echo -e "Ubicación: $out"
  echo ""
  echo "Ejemplo de uso con nmap:"
  echo -e "   nmap -sS -Pn -iL $out"
  echo ""

  if ! command -v nmap &> /dev/null; then
      echo -e "Nmap no está instalado. No se puede ejecutar un escaneo."
      read -rp "Presiona Enter para volver al menú..."
      return
  fi

  read -rp "¿Deseas ejecutar un escaneo Nmap ahora? [y/N]: " run_scan
  if [[ "$run_scan" =~ ^[Yy]$ ]]; then
    echo -e "\n--- Tipos de Escaneo Nmap ---"
    echo -e "1) Escaneo Rápido (Ping Scan, no-ports)"
    echo -e "2) Escaneo de Puertos Comunes (Top 1000, TCP SYN)"
    echo -e "3) Detección de Servicios y Versiones (Intensivo)"
    read -rp "Elige un tipo de escaneo [1-3]: " scan_type

    local nmap_command
    case "$scan_type" in
      1) nmap_command="nmap -sn -iL $out" ;; 
      2) nmap_command="nmap -sS -T4 -iL $out" ;; 
      3) nmap_command="nmap -sV -iL $out" ;; 
      *) echo -e "Opción de escaneo no válida."; sleep 2; return ;; 
    esac

    echo -e "\nEjecutando comando: $nmap_command\n"
    eval "$nmap_command"
  fi

  read -rp "Presiona Enter para volver al menú..."
}

# ===== Opción 7: ayuda =====
ayuda() {
  clear
  cat <<-"EOF"
📘 AYUDA Y EJEMPLOS
------------------------------------------
1️⃣ Crear/editar archivo de IPs locales (una IP/CIDR por línea).
2️⃣ Procesar ese archivo -> generará un informe CSV en ~/Informes_Red
3️⃣ Calcular una IP manualmente sin crear archivo (si NO guardas, igualmente verás la salida)
4️⃣ Descargar y procesar un archivo remoto
6️⃣ Generar archivo de objetivos y escanear con Nmap
------------------------------------------
EOF
  read -rp "Presiona Enter para volver al menú..."
}

# ===== MAIN LOOP =====
while true; do
  show_menu
  read -rp "Elige una opción [1-8]: " op
  case "$op" in
    1) crear_o_editar_archivo ;; 
    2) procesar_archivo ;; 
    3) ip_manual ;; 
    4) ver_ultimo_csv ;; 
    5) descargar_remoto ;; 
    6) generar_nmap_targets ;; 
    7) ayuda ;; 
    8) clear; echo -e "👋 Saliendo..."; exit 0 ;; 
    *) echo -e "Opción no válida"; sleep 1 ;; 
  esac
done
