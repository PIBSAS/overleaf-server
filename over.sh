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

# Función para actualizar grupos sin reboot
activate_docker_group() {
    echo "Activando grupo docker en sesión actual..."
    if command -v newgrp &>/dev/null; then
        exec sudo -u $USER newgrp docker <<EOGRP
        echo "Grupos actualizados. Continuando..."
        exec $0 "$@"
EOGRP
    else
        exec sudo -u $USER --login
    fi
}

# Función para inicializar el toolkit
init_overleaf_toolkit() {
    echo "=== Inicializando Overleaf Toolkit ==="
    if [ -d "$HOME/overleaf-toolkit/config" ] && [ -f "$HOME/overleaf-toolkit/config/overleaf.rc" ]; then
        echo "[✓] Configuración ya existe"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        cp "$HOME/overleaf-toolkit/config/overleaf.rc" "$HOME/overleaf-toolkit/config/overleaf.rc.backup_$TIMESTAMP"
        return 0
    fi
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

# Función mejorada para activar grupos
activate_docker_instant() {
    echo "Activando permisos de Docker instantáneamente..."
    
    # Pasar todas las funciones necesarias
    local funcs=$(declare -f detect_os check_docker_group init_overleaf_toolkit configure_overleaf 
                  activate_docker_instant verify_docker_access)
    
    # Solución 1: Usar sg (funciona en la mayoría de sistemas)
    if command -v sg >/dev/null; then
        exec sg docker -c "
            echo 'Permisos de Docker activados. Continuando...'
            $funcs
            $0 $@
        "
    # Solución 2: Alternativa para sistemas sin sg
    else
        exec sudo -u $USER -- bash -c "
            export PATH=$PATH
            $funcs
            $0 $@
        "
    fi
}

# Función para verificar Docker
verify_docker_access() {
    if ! docker ps >/dev/null 2>&1; then
        echo "Aplicando solución definitiva para permisos Docker..."
        
        # 1. Asegurar que el socket tenga permisos correctos
        sudo chown root:docker /var/run/docker.sock
        sudo chmod 660 /var/run/docker.sock
        
        # 2. Crear override para systemd
        sudo mkdir -p /etc/systemd/system/docker.socket.d
        echo "[Socket]
SocketMode=0660
SocketUser=root
SocketGroup=docker" | sudo tee /etc/systemd/system/docker.socket.d/override.conf >/dev/null
        
        # 3. Recargar servicios
        sudo systemctl daemon-reload
        sudo systemctl restart docker.socket docker.service
        
        # 4. Forzar actualización de grupos
        activate_docker_instant
    fi
}


# =============== MAIN SCRIPT ===============

# 1. Instalar Docker si no existe
if ! check_docker_group; then
    echo "=== Instalando Docker ==="
    sudo apt update
    sudo apt install git -y

    OS_TYPE=$(detect_os)
    case "$OS_TYPE" in
        ubuntu) sudo apt install docker.io docker-compose docker-buildx -y ;;
        raspberry) sudo apt install docker.io docker-compose -y ;;
        *) echo "Sistema no soportado"; exit 1 ;;
    esac

    # Configuración segura
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker $USER
    
    # Aplicar solución definitiva
    verify_docker_access
fi

# ... (el resto del script se mantiene igual)
# 2. Clonar repositorios
echo "=== Clonando repositorios ==="
[ ! -d "overleaf" ] && git clone https://github.com/PIBSAS/overleaf.git
[ ! -d "overleaf-toolkit" ] && git clone https://github.com/overleaf/toolkit.git overleaf-toolkit

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
    echo "[!] Reintentando..."
    docker rm -f overleaf sharelatex redis mongo
    docker rmi local-sharelatex:arm64
    cd "$HOME/overleaf"
    docker build -t local-sharelatex:arm64 -f server-ce/Dockerfile .
    cd "$HOME/overleaf-toolkit"
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
