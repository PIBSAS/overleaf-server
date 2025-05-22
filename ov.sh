#!/bin/bash
set -euo pipefail

# Función para detectar el sistema
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            echo "ubuntu"
        elif [[ "$ID" == "raspbian" || "$ID" == "debian" ]] && [ -f /etc/rpi-issue ]; then
            echo "raspberry"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Función para verificar grupo docker
check_docker_group() {
    if ! groups | grep -qw docker; then
        echo "[!] Usuario no está en el grupo docker"
        return 1
    fi
    return 0
}

# Función para inicializar el toolkit
init_overleaf_toolkit() {
    echo "=== Inicializando Overleaf Toolkit ==="
    "$HOME/overleaf-toolkit/bin/init" || return 1
}

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

# =============== MAIN SCRIPT ===============

# 1. Instalar Docker si no existe
# Instalación directa sin verificaciones
echo "=== Instalando Docker ==="
sudo apt update
sudo apt install git -y

if grep -q "ubuntu" /etc/os-release; then
    sudo apt install docker.io docker-compose docker-buildx -y
elif grep -q "raspbian" /etc/os-release || (grep -q "debian" /etc/os-release && [ -f /etc/rpi-issue ]); then
    sudo apt install docker.io docker-compose -y
else
    echo "Sistema no soportado"
    exit 1
fi

# 2. Clonar repositorios
echo "=== Clonando repositorios ==="
[ ! -d "overleaf" ] && git clone https://github.com/PIBSAS/overleaf.git
[ ! -d "overleaf-toolkit" ] && git clone https://github.com/overleaf/toolkit.git ./overleaf-toolkit

# 3. Configuración inicial
init_overleaf_toolkit
configure_overleaf

# 4. Construir imágenes Docker
echo "=== Construyendo imágenes ==="
cd overleaf/server-ce/
export DOCKER_BUILDKIT=1
docker build -t local-sharelatex-base:arm64 -f Dockerfile-base .
sed -i 's/^FROM \$OVERLEAF_BASE_TAG$/FROM local-sharelatex-base:arm64/' Dockerfile
cd "$HOME/overleaf"
docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .

# 5. Iniciar servicios
echo "=== Iniciando servicios ==="
cd "$HOME/overleaf-toolkit"
if ! ./bin/up; then
    ./bin/up
fi

# 6. Instalar extras
echo "=== Instalando paquetes adicionales ==="
docker exec sharelatex bash -c "\
    apt update && \
    apt install -y hunspell-es && \
    tlmgr install babel-spanish hyphen-spanish collection-langspanish && \
    tlmgr update --all"

# 7. Reiniciar
echo "=== Reiniciando servicios ==="
./bin/restart

# 8. Mostrar información
IP=$(hostname -I | awk '{print $1}')
echo -e "\n[✓] Instalación completada!"
echo -e "URL de acceso: http://${IP}:80"
echo -e "Crear cuenta admin: http://${IP}/launchpad"
