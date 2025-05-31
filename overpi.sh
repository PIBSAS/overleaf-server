#!/bin/bash

set -e

if [ -z "$USER_DOCK" ]; then
  echo "ERROR: Debes declarar la variable USER_DOCK para ejecutar el script."
  echo "Ejemplo: USER_DOCK=jaimito curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/overpi.sh | bash"
  exit 1
fi

# CONFIGURACIONES
TOOLKIT_REPO="https://github.com/overleaf/toolkit.git"
TOOLKIT_DIR="$HOME/overleaf-toolkit"
echo "Eliminando toolkit anterior (si existe)..."
sudo rm -rf "$TOOLKIT_DIR"
DOCKER_IMAGE="$USER_DOCK/sharelatex"

# Función para instalar Docker si no está
instalar_docker() {
    if ! command -v docker &> /dev/null; then
        echo "🚀 Instalando Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    else
        echo "✅ Docker ya está instalado."
    fi
}

# Clonar el toolkit si no existe
clonar_toolkit() {
    if [ ! -d "$TOOLKIT_DIR" ]; then
        echo "📦 Clonando Overleaf Toolkit..."
        git clone "$TOOLKIT_REPO" "$TOOLKIT_DIR"
    else
        echo "📁 Directorio $TOOLKIT_DIR ya existe. Lo uso tal cual."
    fi
}

modificar_config_seed() {
    echo "⚙️ Modificando archivos en lib/config-seed/..."

    local rc_file="$TOOLKIT_DIR/lib/config-seed/overleaf.rc"


    sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
    sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
    sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
    sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"

    echo "✅ Configuración personalizada aplicada en lib/config-seed/overleaf.rc"
}

# Inicializar toolkit (crea config/overleaf.rc)
inicializar_toolkit() {
    cd "$TOOLKIT_DIR"
    echo "⚙️ Ejecutando ./bin/init..."
    ./bin/init
}

# Iniciar Overleaf
iniciar_overleaf() {
    echo "🚀 Iniciando Overleaf..."
    ./bin/up -d
}

agregar_cron_inicio() {
    echo "🕒 Agregando cron para iniciar Overleaf al bootear..."
    local CRON_LINE="@reboot cd \$HOME/overleaf-toolkit && ./bin/up -d"

    # Evita duplicados
    (crontab -l 2>/dev/null | grep -vF "$CRON_LINE"; echo "$CRON_LINE") | crontab -
    echo "✅ Cron agregado con éxito."
}

# === EJECUCIÓN SECUENCIAL ===
instalar_docker
# 🔁 Limpiar si ya existe
if docker ps -a --format '{{.Names}}' | grep -q '^mongo\|^sharelatex\|^redis'; then
    echo "🛑 Deteniendo contenedores de Overleaf previos..."
    docker compose -f "$TOOLKIT_DIR/docker-compose.yml" down || true
fi

clonar_toolkit
modificar_config_seed
inicializar_toolkit
iniciar_overleaf
echo "=== Overleaf disponible en: http://$(hostname -I | awk '{print $1}'):80 ==="
echo "=== Crear cuenta en: http://$(hostname -I | awk '{print $1}'):80/launchpad ==="
agregar_cron_inicio
