#!/bin/bash

set -e
USER_DOCK=pibsas # modify for your use
OVERLEAF_DIR="$HOME/overleaf"
TOOLKIT_DIR="$HOME/overleaf-toolkit"
echo "=== Borrando repositorios existentes ==="
rm -rf "$OVERLEAF_DIR" "$TOOLKIT_DIR"

echo "=== Detectando sistema operativo ==="
OS_NAME=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

if [[ "$OS_NAME" == "ubuntu" ]]; then
    echo "=== Sistema detectado: Ubuntu ==="
    sudo apt update
    sudo apt install -y git curl uidmap gawk
elif [[ "$OS_NAME" == "raspbian" ]] || [[ "$OS_NAME" == "debian" ]]; then
    echo "=== Sistema detectado: Raspberry Pi OS (basado en Debian) ==="
    sudo apt update
    sudo apt install -y git curl uidmap gawk
else
    echo "Sistema operativo no compatible automáticamente. Instalación detenida."
    exit 1
fi

echo "=== Clonando repositorios ==="
git clone https://github.com/PIBSAS/overleaf.git "$OVERLEAF_DIR"
git clone https://github.com/overleaf/toolkit.git "$TOOLKIT_DIR"
TAG=$(cat "$HOME/overleaf-toolkit/lib/config-seed/version")

echo "== Instalar Docker =="
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

echo "== Instalar Docker Compose V2 y Docker Buildx=="
sudo apt install docker-compose-plugin -y
latest=$(curl -sSL https://api.github.com/repos/docker/buildx/releases/latest | grep -oP '"tag_name":\s*"v\K[0-9.]+' | head -n1) && \
mkdir -p ~/.docker/cli-plugins && \
curl -L "https://github.com/docker/buildx/releases/download/v${latest}/buildx-v${latest}.linux-arm64" -o ~/.docker/cli-plugins/docker-buildx && \
chmod +x ~/.docker/cli-plugins/docker-buildx

echo "=== Portar Overleaf a ARM64 para Raspberry Pi ==="
cd "$OVERLEAF_DIR/server-ce/"
export DOCKER_BUILDKIT=1
DOCKER_BUILDKIT=1 docker build -t sharelatex-base:arm64 -f Dockerfile-base .

echo "=== Modificando Dockerfile para que use la imagen creada e instale los paquetes de idioma español ==="
cd "$OVERLEAF_DIR/server-ce/"
sed -i 's|^ARG OVERLEAF_BASE_TAG=.*|ARG OVERLEAF_BASE_TAG=sharelatex-base:arm64|' Dockerfile
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

echo "== Construimos el port =="
cd "$OVERLEAF_DIR"
docker build -t sharelatex -f server-ce/Dockerfile .
docker tag sharelatex $USER_DOCK/sharelatex:$TAG

echo "== Editamos overleaf.rc=="
cd
DOCKER_IMAGE=sharelatex
rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"

#echo "== Editamos el script shared-functions =="
#cd
#shared_functions="$HOME/overleaf-toolkit/lib/shared-functions.sh"
#sed -i \
#  -e 's|image_name="quay.io/sharelatex/sharelatex-pro"|image_name="quay.io/sharelatex/sharelatex-pro:$version"|' \
#  -e 's|image_name="sharelatex/sharelatex"|image_name="sharelatex/sharelatex:$version"|' \
#  -e 's/export IMAGE="\$image_name:\$version"/export IMAGE="\$image_name"/' \
#  "$shared_functions"

echo "=== Inicializando toolkit ==="
cd "$TOOLKIT_DIR"
./bin/init

echo "=== Agregando cron para iniciar Overleaf al bootear ==="
(crontab -l 2>/dev/null | grep -vF '@reboot cd $HOME/overleaf-toolkit && ./bin/up -d'; echo '@reboot cd $HOME/overleaf-toolkit && ./bin/up -d') | crontab -

echo "== Levantando el servido Overleaf Community Edition (modo detach) ==="
cd "$TOOLKIT_DIR"
./bin/up -d

echo "=== Overleaf disponible en: http://$(hostname -I | awk '{print $1}'):80 ==="
echo "=== Crear cuenta en: http://$(hostname -I | awk '{print $1}'):80/launchpad ==="

post_install_overleaf_packages() {
    echo "=== Instalando paquetes adicionales dentro del contenedor ==="

    CONTAINER_NAME="sharelatex-pi"

    # Esperar a que el contenedor esté corriendo
    echo "Esperando a que el contenedor '$CONTAINER_NAME' esté activo..."
    while ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME\$"; do
        sleep 2
    done

    docker exec "$CONTAINER_NAME" bash -c '
        if [ ! -f /overleaf/.extras_installed ]; then
            echo "Instalando paquetes adicionales..."
            apt update && \
            apt install -y hunspell-es && \
            tlmgr install babel-spanish hyphen-spanish collection-langspanish && \
            tlmgr update --all && \
            touch /overleaf/.extras_installed
        else
            echo "Los paquetes ya están instalados, omitiendo..."
        fi
    '
}
