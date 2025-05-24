#!/bin/bash

set -e

# CONFIGURACIÓN
OVERLEAF_REPO="https://github.com/overleaf/overleaf.git"
OVERLEAF_DIR="overleaf"
TOOLKIT_REPO="https://github.com/overleaf/toolkit.git"
TOOLKIT_DIR="overleaf-toolkit"
DOCKER_IMAGE="sharelatex:arm64"

# Función para instalar Docker si no está
instalar_docker() {
    if ! command -v docker &> /dev/null; then
        echo "🚀 Instalando Docker rootless..."
        sudo apt install git curl uidmap docker-compose-plugin awk -y
        curl -fsSL https://get.docker.com/rootless | sh
        echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
        echo 'export DOCKER_HOST=unix:///run/user/1000/docker.sock' >> ~/.bashrc
        source ~/.bashrc
    else
        echo "✅ Docker ya está instalado."
    fi
}

install_docker_buildx() {
    echo "🔍 Obteniendo la última versión de Docker Buildx..."
    latest=$(curl -sSL https://api.github.com/repos/docker/buildx/releases/latest | grep -oP '"tag_name":\s*"v\K[0-9.]+' | head -n1)

    if [[ -z "$latest" ]]; then
      echo "❌ No se pudo obtener la versión más reciente de Buildx."
      return 1
    fi

    echo "📦 Última versión: v${latest}"
    echo "📁 Creando directorio para los plugins de Docker..."
    mkdir -p $HOME/.docker/cli-plugins

    echo "⬇️ Descargando Buildx v${latest} para ARM64..."
    curl -L "https://github.com/docker/buildx/releases/download/v${latest}/buildx-v${latest}.linux-arm64" -o $HOME/.docker/cli-plugins/docker-buildx

    echo "🔧 Haciendo ejecutable el plugin..."
    chmod +x $HOME/.docker/cli-plugins/docker-buildx

    echo "✅ Docker Buildx v${latest} instalado correctamente."
}


# Clonar el toolkit si no existe
clonar_overleaf() {
    if [ ! -d "$OVERLEAF_DIR" ]; then
        echo "📦 Clonando Overleaf Toolkit..."
        git clone "$OVERLEAF_REPO" "$OVERLEAF_DIR"
    else
        echo "📁 Directorio $OVERLEAF_DIR ya existe. Lo uso tal cual."
    fi
}

build_sharelatex_base() {
    echo "📂 Cambiando al directorio $HOME/overleaf/server-ce..."
    cd $HOME/overleaf/server-ce || {
      echo "❌ No se pudo acceder al directorio $HOME/overleaf/server-ce"
      return 1
    }
  
    echo "🚧 Construyendo imagen Docker sharelatex-base:arm64 con BuildKit..."
    DOCKER_BUILDKIT=1 docker build -t sharelatex-base:arm64 -f Dockerfile-base .
  
    if [[ $? -eq 0 ]]; then
      echo "✅ Imagen sharelatex-base:arm64 construida exitosamente."
    else
      echo "❌ Error al construir la imagen sharelatex-base:arm64."
      return 1
    fi
}

patch_overleaf_dockerfile() {
    local dockerfile_path="$HOME/overleaf/server-ce/Dockerfile"
  
    echo "📂 Cambiando al directorio del proyecto..."
    cd "$HOME/overleaf/server-ce" || {
      echo "❌ No se pudo acceder al directorio $HOME/overleaf/server-ce"
      return 1
    }
  
    echo "🔧 Modificando ARG OVERLEAF_BASE_TAG en Dockerfile..."
    sed -i 's|^ARG OVERLEAF_BASE_TAG=.*|ARG OVERLEAF_BASE_TAG=sharelatex-base:arm64|' Dockerfile
  
    echo "🧩 Insertando comandos para paquetes en español después de EXPOSE..."
    awk '/^EXPOSE/ {
        print;
        print "# Paquetes adicionales para soporte en español";
        print "RUN apt-get update && apt-get install -y hunspell-es && \\";
        print "    tlmgr install babel-spanish hyphen-spanish collection-langspanish && \\";
        print "    tlmgr update --all && \\";
        print "    apt-get clean && \\";
        print "    rm -rf /var/lib/apt/lists/*";
        next
    }1' Dockerfile > Dockerfile.tmp && mv Dockerfile.tmp Dockerfile
  
    echo "✅ Dockerfile modificado correctamente."
}

build_sharelatex_image() {
    echo "📂 Cambiando al directorio \$HOME/overleaf..."
    cd "$HOME/overleaf" || {
      echo "❌ No se pudo acceder al directorio \$HOME/overleaf"
      return 1
    }
  
    echo "🚧 Construyendo imagen Docker sharelatex:arm64 desde server-ce/Dockerfile..."
    docker build -t sharelatex:arm64 -f server-ce/Dockerfile .
  
    if [[ $? -eq 0 ]]; then
      echo "✅ Imagen sharelatex:arm64 construida exitosamente."
    else
      echo "❌ Error al construir la imagen sharelatex:arm64."
      return 1
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
    sed -i "s|^OVERLEAF_PORT=.*|OVERLEAF_PORT=8080|" "$rc_file"
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

if [ -d "$TOOLKIT_DIR" ]; then
    echo "🧹 Eliminando toolkit existente..."
    sudo rm -rf "$TOOLKIT_DIR"
fi
install_docker_buildx
clonar_overleaf
build_sharelatex_base
patch_overleaf_dockerfile
build_sharelatex_image
clonar_toolkit
modificar_config_seed
inicializar_toolkit
iniciar_overleaf
agregar_cron_inicio
