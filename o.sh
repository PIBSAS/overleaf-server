#!/bin/bash

set -e

echo "=== Detectando sistema operativo ==="
OS_NAME=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

if [[ "$OS_NAME" == "ubuntu" ]]; then
    echo "=== Sistema detectado: Ubuntu ==="
    sudo apt update
    sudo apt install -y git docker.io docker-compose docker-buildx
elif [[ "$OS_NAME" == "raspbian" ]] || [[ "$OS_NAME" == "debian" ]]; then
    echo "=== Sistema detectado: Raspberry Pi OS (basado en Debian) ==="
    sudo apt update
    sudo apt install -y git docker.io docker-compose
else
    echo "Sistema operativo no compatible automáticamente. Instalación detenida."
    exit 1
fi

echo "=== Clonando repositorios ==="
git clone https://github.com/PIBSAS/overleaf.git
git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit

echo "=== Construyendo imagen base ARM64 ==="
cd overleaf/server-ce/
export DOCKER_BUILDKIT=1
docker build -t local-sharelatex-base:arm64 -f Dockerfile-base .

echo "=== Modificando Dockerfile principal ==="
cd ~/overleaf/server-ce/
sed -i 's|^FROM \$OVERLEAF_BASE_TAG|FROM local-sharelatex-base:arm64|' Dockerfile

cd ~/overleaf
docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .

echo "=== Inicializando toolkit ==="
cd ~/overleaf-toolkit
./bin/init

#echo "=== Configurando overleaf.rc ==="
#sed -i 's|# OVERLEAF_IMAGE_NAME=sharelatex/sharelatex|OVERLEAF_IMAGE_NAME=local-sharelatex:arm64|' config/overleaf.rc
#sed -i 's|OVERLEAF_LISTEN_IP=127.0.0.1|OVERLEAF_LISTEN_IP=0.0.0.0|' config/overleaf.rc

#echo "=== Modificando shared-functions.sh ==="
#sed -i 's|image_name="quay.io/sharelatex/sharelatex-pro"|image_name="quay.io/sharelatex/sharelatex-pro:$version"|' lib/shared-functions.sh
#sed -i 's|image_name="sharelatex/sharelatex"|image_name="sharelatex/sharelatex:$version"|' lib/shared-functions.sh
#sed -i 's|export IMAGE="\$image_name:\$version"|export IMAGE="$image_name"|' lib/shared-functions.sh

# Función para configurar Overleaf
configure_overleaf() {
    echo "=== Configurando Overleaf ==="
    local rc_file="$HOME/overleaf-toolkit/config/overleaf.rc"
    local shared_functions="$HOME/overleaf-toolkit/lib/shared-functions.sh"

    # Configurar overleaf.rc
    sed -i \
        -e 's/^# OVERLEAF_IMAGE_NAME=.*$/OVERLEAF_IMAGE_NAME=local-sharelatex:arm64/' \
        -e 's/^OVERLEAF_LISTEN_IP=127.0.0.1$/OVERLEAF_LISTEN_IP=0.0.0.0/' \
        "$rc_file"

    # Configurar shared-functions.sh
    sed -i \
        -e 's|image_name="quay.io/sharelatex/sharelatex-pro"|image_name="quay.io/sharelatex/sharelatex-pro:$version"|' \
        -e 's|image_name="sharelatex/sharelatex"|image_name="sharelatex/sharelatex:$version"|' \
        -e 's/export IMAGE="$image_name:$version"/export IMAGE="$image_name"/' \
        "$shared_functions"
}

configure_overleaf

echo "=== Levantando Overleaf Toolkit ==="
./bin/up

echo "=== Overleaf disponible en: http://<TU_IP>:80 ==="
echo "=== Crear cuenta en: http://<TU_IP>/launchpad ==="
