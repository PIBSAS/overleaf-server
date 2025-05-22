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

#Función para actualizar grupos sin reboot
activate_docker_group() {
    echo "Activando grupo docker en sesión actual..."

    # Para shells que soportan newgrp
    if command -v newgrp &>/dev/null; then
        exec sudo -u $USER newgrp docker <<EOGRP
        echoo "Grupos actualizados. Continuando..."
        exec $0 "$@"
EOGRP
    else
        # Metodo para shell sin newgrp
        exec sudo -u $USER --login
    fi
}

# Función para manejar la inicialización del toolkit
init_overleaf_toolkit() {
    echo "=== Configurando Overleaf Toolkit ==="
    
    if [ -d "$HOME/overleaf-toolkit/config" ] && [ -f "$HOME/overleaf-toolkit/config/overleaf.rc" ]; then
        echo "[!] Archivos de configuración ya existen. Usando configuración existente."
        
        # Hacer backup de la configuración existente
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        cp "$HOME/overleaf-toolkit/config/overleaf.rc" "$HOME/overleaf-toolkit/config/overleaf.rc.backup_$TIMESTAMP"
        echo "  → Se creó backup en: $HOME/overleaf-toolkit/config/overleaf.rc.backup_$TIMESTAMP"
    else
        # Inicializar si no existe la configuración
        "$HOME/overleaf-toolkit/bin/init"
    fi
}

# Función para modificar la configuración
configure_overleaf() {
    local rc_file="$HOME/overleaf-toolkit/config/overleaf.rc"
    local shared_functions="$HOME/overleaf-toolkit/lib/shared-functions.sh"
    
    echo "=== Aplicando configuraciones personalizadas ==="
    
    # Modificar overleaf.rc
    if grep -q "OVERLEAF_IMAGE_NAME=local-sharelatex:arm64" "$rc_file"; then
        echo "  → Configuración de imagen ya existe, omitiendo..."
    else
        sed -i \
            -e 's/^# OVERLEAF_IMAGE_NAME=.*$/OVERLEAF_IMAGE_NAME=local-sharelatex:arm64/' \
            -e 's/^OVERLEAF_LISTEN_IP=127.0.0.1$/OVERLEAF_LISTEN_IP=0.0.0.0/' \
            "$rc_file"
        echo "  → Configuración de imagen y IP actualizada"
    fi
    
    # Modificar shared-functions.sh
    if grep -q 'export IMAGE="$image_name"' "$shared_functions"; then
        echo "  → Configuración de funciones ya existe, omitiendo..."
    else
        sed -i \
            -e 's|image_name="quay.io/sharelatex/sharelatex-pro"|image_name="quay.io/sharelatex/sharelatex-pro:$version"|' \
            -e 's|image_name="sharelatex/sharelatex"|image_name="sharelatex/sharelatex:$version"|' \
            -e 's/export IMAGE="$image_name:$version"/export IMAGE="$image_name"/' \
            "$shared_functions"
        echo "  → Configuración de funciones actualizada"
    fi
}

# Configuración inicial de Docker
if ! check_docker_group; then
    echo "=== Instalando dependencias ==="
    sudo apt update
    sudo apt install git -y

    # Detectar sistema operativo
    OS_TYPE=$(detect_os)
    
    case "$OS_TYPE" in
        ubuntu)
            echo "Instalando Docker para Ubuntu..."
            sudo apt install docker.io docker-compose docker-buildx -y
            ;;
        raspberry)
            echo "Instalando Docker para Raspberry Pi..."
            sudo apt install docker.io docker-compose -y
            ;;
        *)
            echo "Opción inválida. Saliendo."
            exit 1
            ;;
    esac

    # Agregar usuario a grupo docker
    sudo usermod -aG docker "$USER"
    activate_docker_group
fi

# ==============================
# Continuación después del reinicio
# ==============================

echo "=== Clonando repositorios ==="
if [ ! -d "overleaf" ]; then
    git clone https://github.com/PIBSAS/overleaf.git
fi

if [ ! -d "overleaf-toolkit" ]; then
    git clone https://github.com/overleaf/toolkit.git overleaf-toolkit
fi

init_overleaf_toolkit
configure_overleaf

echo "=== Construyendo imágenes Docker ARM64 ==="
cd overleaf/server-ce/ || exit
export DOCKER_BUILDKIT=1
docker build -t local-sharelatex-base:arm64 -f Dockerfile-base .

# Modificar Dockerfile
sed -i 's/^FROM \$OVERLEAF_BASE_TAG$/FROM local-sharelatex-base:arm64/' Dockerfile

# Construir imagen principal
cd "$HOME/overleaf" || exit
docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .

echo "=== Configurando Overleaf Toolkit ==="
cd "$HOME/overleaf-toolkit" || exit
./bin/init

# Editar configuración
sed -i \
    -e 's/^# OVERLEAF_IMAGE_NAME=.*$/OVERLEAF_IMAGE_NAME=local-sharelatex:arm64/' \
    -e 's/^OVERLEAF_LISTEN_IP=127.0.0.1$/OVERLEAF_LISTEN_IP=0.0.0.0/' \
    config/overleaf.rc

# Modificar funciones compartidas
sed -i \
    -e 's|image_name="quay.io/sharelatex/sharelatex-pro"|image_name="quay.io/sharelatex/sharelatex-pro:$version"|' \
    -e 's|image_name="sharelatex/sharelatex"|image_name="sharelatex/sharelatex:$version"|' \
    -e 's/export IMAGE="$image_name:$version"/export IMAGE="$image_name"/' \
    lib/shared-functions.sh

echo "=== Iniciando servicios Overleaf ==="
if ! ./bin/up; then
    echo "[!] Error al iniciar, reintentando..."
    docker rm -f overleaf sharelatex redis mongo
    docker rmi local-sharelatex:arm64
    cd "$HOME/overleaf" || exit
    docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .
    cd "$HOME/overleaf-toolkit" || exit
    ./bin/up
fi

echo "=== Instalando paquetes adicionales ==="
docker exec sharelatex bash -c "\
    apt update && \
    apt install -y hunspell-es && \
    tlmgr install babel-spanish hyphen-spanish collection-langspanish && \
    tlmgr update --all"

echo "=== Reiniciando servicios ==="
./bin/restart

# Mostrar información de acceso
IP=$(hostname -I | awk '{print $1}')
echo -e "\n[+] Instalación completada!"
echo -e "Accede a Overleaf en: http://${IP}:80"
echo -e "Crea el usuario admin en: http://${IP}/launchpad\n"
