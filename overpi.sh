#!/bin/bash

set -e

# CONFIGURACIÓN
TOOLKIT_REPO="https://github.com/overleaf/toolkit.git"
TOOLKIT_DIR="overleaf-toolkit"
DOCKER_IMAGE="pibsas/sharelatex-base"

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

# Descargar imagen Docker
descargar_imagen() {
    echo "🐳 Descargando imagen Docker: $DOCKER_IMAGE"
    docker pull "$DOCKER_IMAGE"
}

# Iniciar Overleaf
iniciar_overleaf() {
    echo "🚀 Iniciando Overleaf..."
    ./bin/up -d
}

# === EJECUCIÓN SECUENCIAL ===
instalar_docker
# 🔁 Limpiar si ya existe
if docker ps -a --format '{{.Names}}' | grep -q '^mongo\|^sharelatex\|^redis'; then
    echo "🛑 Deteniendo contenedores de Overleaf previos..."
    docker compose -f "$TOOLKIT_DIR/docker-compose.yml" down || true
fi

if [ -d "$TOOLKIT_DIR" ]; then
    echo "🧹 Eliminando toolkit existente..."
    sudo rm -rf "$TOOLKIT_DIR"
fi
clonar_toolkit
modificar_config_seed
inicializar_toolkit
#descargar_imagen
iniciar_overleaf
