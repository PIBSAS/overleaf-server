#!/bin/bash

set -e

if [ -z "$USER_DOCK" ]; then
  echo "ERROR: Debes declarar la variable USER_DOCK para ejecutar el script."
  echo "Ejemplo: USER_DOCK=jaimito curl -sSL https://raw.githubusercontent.com/PIBSAS/overleaf-server/main/dockerhub.sh | bash"
  exit 1
fi

#USER_DOCK=pibsas # modify for your use
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
git clone https://github.com/overleaf/overleaf.git "$OVERLEAF_DIR"
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
cd "$OVERLEAF_DIR/server-ce"
sed -i 's|^ARG OVERLEAF_BASE_TAG=.*|ARG OVERLEAF_BASE_TAG=sharelatex-base:arm64|' Dockerfile
awk '/^EXPOSE/ {
    print;
    print "# Paquetes adicionales para soporte en español";
    print "RUN apt-get update && apt-get install -y hunspell-es && \\";
    print "    tlmgr update --self && \\";
    print "    tlmgr install babel-spanish hyphen-spanish collection-langspanish newunicodechar float jknapltx tools collection-mathscience mathtools amsmath amsfonts enumitem cancel microtype tcolorbox && \\";
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
DOCKER_IMAGE=$USER_DOCK/sharelatex
rc_file="$HOME/overleaf-toolkit/lib/config-seed/overleaf.rc"
sed -i "s|^# *OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
sed -i "s|^OVERLEAF_IMAGE_NAME=.*|OVERLEAF_IMAGE_NAME=$DOCKER_IMAGE|" "$rc_file"
sed -i "s|^OVERLEAF_LISTEN_IP=.*|OVERLEAF_LISTEN_IP=0.0.0.0|" "$rc_file"
sed -i "s|^SIBLING_CONTAINERS_ENABLED=.*|SIBLING_CONTAINERS_ENABLED=false|" "$rc_file"

echo "== Subiendo imagen a tu Docker Hub =="
docker push "$USER_DOCK/sharelatex:$TAG" || {
  echo "❌ Falló el push. ¿Olvidaste hacer 'docker login' antes de ejecutar el script?"
  exit 1
}
